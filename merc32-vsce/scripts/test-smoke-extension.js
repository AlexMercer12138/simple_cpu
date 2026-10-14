const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { runIcarusElaboration } = require('./smoke-extension/suite/icarus');
const { withHostCompilerBlocked } = require('./smoke-extension/suite/process-launch-guard');

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'merc32-icarus-timeout-unit-'));
try {
    const hardwareRoot = path.join(root, 'hardware');
    const hardwareFile = path.join(hardwareRoot, 'all_peripherals_soc.v');
    fs.mkdirSync(hardwareRoot);
    let received;
    const timedOut = Object.assign(new Error('spawnSync iverilog ETIMEDOUT'), { code: 'ETIMEDOUT' });
    assert.throws(() => runIcarusElaboration({
        outputDir: root,
        hardwareFile,
        topModule: 'all_peripherals_soc',
        timeoutMs: 1234,
        spawnSync(command, args, options) {
            received = { command, args, options };
            fs.writeFileSync(path.join(root, 'all_peripherals.vvp'), 'partial');
            return { error: timedOut, signal: 'SIGKILL', status: null, stdout: '', stderr: '' };
        },
    }), /Icarus elaboration timed out after 1234 ms; child terminated with SIGKILL/u,
    'Icarus timeout was not distinguishable from launch/elaboration failures');
    assert.strictEqual(received.command, 'iverilog');
    assert.strictEqual(received.options.timeout, 1234, 'Icarus child did not receive a direct timeout');
    assert.strictEqual(received.options.killSignal, 'SIGKILL',
        'timed-out Icarus child was not forcibly terminated');
    assert.strictEqual(received.options.cwd, root);
    assert.deepStrictEqual(received.args.filter((argument) => argument.endsWith('.v')),
        [hardwareFile]);
    assert.ok(!received.args.includes('-f') && !received.args.includes('files.f'));
    assert.ok(received.args.includes('-s') && received.args.includes('all_peripherals_soc'));
    assert.ok(!fs.existsSync(path.join(root, 'all_peripherals.vvp')),
        'timed-out Icarus child left a partial elaboration artifact behind');
} finally {
    fs.rmSync(root, { recursive: true, force: true });
}

console.log('Installed smoke Icarus timeout contracts passed.');

function testInstalledHostOutput() {
    const { runInstalledHost } = require('./vsix-smoke-host');
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'merc32-host-output-unit-'));
    let descendantPid;
    try {
        const parentSource = [
            'const { spawn } = require("child_process");',
            'const child = spawn(process.execPath, ["-e", "setTimeout(() => {}, 10000)"],',
            '    { detached: true, cwd: require("os").tmpdir(),',
            '      stdio: ["ignore", process.stdout, process.stderr] });',
            'console.log(child.pid);',
            'console.error("parent stderr");',
            'child.unref();',
        ].join('\n');
        const result = runInstalledHost(process.execPath, ['-e', parentSource], {
            cwd: root, env: process.env, timeout: 2000,
        });
        descendantPid = Number(result.stdout.trim());
        assert.ifError(result.error);
        assert.strictEqual(result.status, 0);
        assert.ok(Number.isInteger(descendantPid) && descendantPid > 0);
        assert.strictEqual(result.stderr.trim(), 'parent stderr');
    } finally {
        if (descendantPid) {
            try { process.kill(descendantPid); } catch (error) {
                if (error.code !== 'ESRCH') throw error;
            }
        }
        fs.rmSync(root, { recursive: true, force: true });
    }
    for (const [source, expectation] of [
        ['process.exitCode = 7', (result) => assert.strictEqual(result.status, 7)],
        ['setTimeout(() => {}, 10000)', (result) => {
            assert.strictEqual(result.error?.code, 'ETIMEDOUT');
            assert.notStrictEqual(result.status, 0);
        }],
    ]) {
        const failureRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'merc32-host-failure-unit-'));
        try {
            expectation(runInstalledHost(process.execPath, ['-e', source], {
                cwd: failureRoot, env: process.env, timeout: 500,
            }));
        } finally { fs.rmSync(failureRoot, { recursive: true, force: true }); }
    }
    console.log('Installed smoke host exit and inherited-output contracts passed.');
}

async function testHostCompilerGuard() {
    const childProcess = require('child_process');
    const names = ['exec', 'execFile', 'execFileSync', 'fork', 'spawn', 'spawnSync'];
    const originalMethods = Object.fromEntries(names.map((name) => [name, childProcess[name]]));
    const environmentNames = ['PATH', 'Path', 'PATHEXT', 'CC', 'CXX', 'AR', 'AS', 'LD'];
    const originalEnvironment = Object.fromEntries(environmentNames.map((name) => [name, process.env[name]]));
    process.env.CC = 'host-cc';
    let guardedFailure;
    try {
        await withHostCompilerBlocked(async () => {
            assert.strictEqual(process.env.PATH, '');
            if (process.platform === 'win32') assert.strictEqual(process.env.Path, '');
            else assert.strictEqual(process.env.Path, undefined);
            assert.strictEqual(process.env.PATHEXT, undefined);
            assert.strictEqual(process.env.CC, undefined);
            const { spawnSync } = require('child_process');
            assert.throws(
                () => spawnSync(process.execPath, ['--version']),
                (error) => error?.code === 'MERC32_PROCESS_LAUNCH_DENIED'
                    && error.processApi === 'spawnSync',
                'a child-process reference acquired after guard installation escaped blocking',
            );
            throw new Error('forced guarded-action failure');
        });
    } catch (error) {
        guardedFailure = error;
    }
    assert.match(guardedFailure?.message || '', /forced guarded-action failure/u);
    for (const name of names) {
        assert.strictEqual(childProcess[name], originalMethods[name],
            `child_process.${name} was not restored`);
    }
    for (const name of environmentNames) {
        if (name === 'CC') assert.strictEqual(process.env[name], 'host-cc');
        else if (originalEnvironment[name] === undefined) assert.strictEqual(process.env[name], undefined);
        else assert.strictEqual(process.env[name], originalEnvironment[name]);
    }
    if (originalEnvironment.CC === undefined) delete process.env.CC;
    else process.env.CC = originalEnvironment.CC;
}

async function testSearchProcessException() {
    const childProcess = require('child_process');
    const originalSpawn = childProcess.spawn;
    const oldOverride = process.env.MERC32_SMOKE_RIPGREP_EXECUTABLE;
    try {
        process.env.MERC32_SMOKE_RIPGREP_EXECUTABLE = process.execPath;
        await withHostCompilerBlocked(async () => {
            assert.throws(() => childProcess.spawn(process.execPath, ['--version']),
                (error) => error.code === 'MERC32_PROCESS_LAUNCH_DENIED',
                'an environment variable alone must not grant process access');
        });
        await withHostCompilerBlocked(async () => {
            assert.strictEqual(process.env.PATH, '');
            await new Promise((resolve, reject) => {
                const child = childProcess.spawn(process.execPath, ['--version'], {
                    stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true,
                });
                let output = '';
                child.stdout.on('data', chunk => { output += chunk; });
                child.once('error', reject);
                child.once('close', code => {
                    try {
                        assert.strictEqual(code, 0);
                        assert.strictEqual(output.trim(), process.version);
                        resolve();
                    } catch (error) { reject(error); }
                });
            });
            for (const launch of [
                () => childProcess.spawn(`${process.execPath}.compiler`, []),
                () => childProcess.spawn(path.basename(process.execPath), []),
                () => childProcess.spawn(process.execPath, [], { shell: true }),
                () => childProcess.spawn(process.execPath, { shell: true }),
                () => childProcess.spawnSync(process.execPath, ['--version']),
            ]) assert.throws(launch, (error) => error.code === 'MERC32_PROCESS_LAUNCH_DENIED');
        }, { searchExecutable: process.execPath });
        assert.strictEqual(childProcess.spawn, originalSpawn);
    } finally {
        if (oldOverride === undefined) delete process.env.MERC32_SMOKE_RIPGREP_EXECUTABLE;
        else process.env.MERC32_SMOKE_RIPGREP_EXECUTABLE = oldOverride;
    }
}

testHostCompilerGuard().then(testSearchProcessException).then(testInstalledHostOutput).then(() => {
    console.log('Installed smoke pre-activation process/compiler guard contracts passed.');
}).catch((error) => {
    console.error(error.stack || error.message);
    process.exitCode = 1;
});
