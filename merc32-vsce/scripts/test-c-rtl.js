'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const repoRoot = path.resolve(__dirname, '..', '..');
const toolchainRoot = process.env.MERC32_TOOLCHAIN_ROOT
    ? path.resolve(process.env.MERC32_TOOLCHAIN_ROOT)
    : path.resolve(__dirname, '..');
const { compileCFile } = require(path.join(toolchainRoot, 'out', 'cCompiler'));
const { SimpleCPUAssembler } = require(path.join(toolchainRoot, 'out', 'assembler'));

const commandTimeoutEnv = 'MERC32_RTL_COMMAND_TIMEOUT_MS';
const defaultCommandTimeoutMs = 120_000;

function parseCommandTimeoutMs(value) {
    if (value === undefined) return defaultCommandTimeoutMs;
    const normalized = value.trim();
    if (!/^[1-9][0-9]*$/.test(normalized)) {
        throw new Error(`${commandTimeoutEnv} must be a positive integer`);
    }
    const timeoutMs = Number(normalized);
    if (!Number.isSafeInteger(timeoutMs)) {
        throw new Error(`${commandTimeoutEnv} must be a positive integer`);
    }
    return timeoutMs;
}

const commandTimeoutMs = parseCommandTimeoutMs(process.env[commandTimeoutEnv]);

// Compile the checked-in examples verbatim through the public C17 toolchain.
const firmwareTests = [
    { name: 'cpu_arithmetic_test' },
    { name: 'cpu_memory_test' },
    { name: 'cpu_control_test' },
    { name: 'cpu_interrupt_test', irq: true },
];

function run(command, args) {
    const result = spawnSync(command, args, {
        encoding: 'utf8',
        timeout: commandTimeoutMs,
        windowsHide: true,
    });
    if (result.error) {
        let detail = result.error.message;
        if (result.error.code === 'ENOENT') detail = `${command} was not found on PATH`;
        else if (result.error.code === 'ETIMEDOUT') detail = `${command} timed out after ${commandTimeoutMs} ms`;
        throw new Error(detail);
    }
    return result;
}

function requireSuccess(label, result) {
    if (result.status === 0) return;
    const output = `${result.stdout || ''}${result.stderr || ''}`.trim();
    const detail = result.signal
        ? `${label} terminated by signal ${result.signal}`
        : Number.isInteger(result.status)
            ? `${label} failed with exit code ${result.status}`
            : `${label} failed without an exit code`;
    throw new Error(`${detail}${output ? `\n${output}` : ''}`);
}

function writeMemoryImage(file, machineCodes) {
    assert.ok(machineCodes.length > 0 && machineCodes.length <= 65_536,
        `invalid ROM image size: ${machineCodes.length} words`);
    fs.writeFileSync(file, `${machineCodes.map((word) => (word >>> 0).toString(16).padStart(8, '0')).join('\n')}\n`, 'ascii');
}

function runFirmwareTest(test) {
    const sourceFile = path.join(repoRoot, 'example', test.name + '.c');
    const compile = compileCFile(sourceFile, {
        optimization: test.optimization,
        moduleName: test.name,
    });
    const assembled = new SimpleCPUAssembler().assemble(compile.assembly, {
        sourceFileName: test.name + '.asm',
    });
    const top = test.irq ? 'tinyc_irq_tb' : 'tinyc_cpu_tb';
    const halt = assembled.debugSymbols.match(/^\S+_halt\s*=\s*(\d+)/m);
    assert(halt, test.name + ': missing public startup halt');
    assert.ok(assembled.machineCodes.length > 0, `${test.name} linked object must assemble`);

    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'merc32-tinyc-rtl-'));
    try {
        const memoryPath = path.join(tempDir, `${test.name}.mem`);
        const simulationPath = path.join(tempDir, `${top}.vvp`);
        writeMemoryImage(memoryPath, assembled.machineCodes);
        const rtlFiles = [
            'rtl/cpu/core.v', 'rtl/misc/mul.v', 'rtl/misc/div.v', 'rtl/sim/' + top + '.v',
        ].map(file => path.join(repoRoot, file));
        const compileResult = run('iverilog', [
            '-Wall', '-Wno-timescale', '-g2005', '-s', top,
            '-o', simulationPath, ...rtlFiles,
        ]);
        if (compileResult.stderr) process.stderr.write(compileResult.stderr);
        requireSuccess(`${test.name} RTL compilation`, compileResult);

        const simulationResult = run('vvp', [
            simulationPath,
            `+ROM_FILE=${memoryPath.replace(/\\/g, '/')}`,
            `+ROM_WORDS=${assembled.machineCodes.length}`,
            '+POISON_RAM',
            ...(test.irq ? ['+CHECK_COMPLETION'] : []),
            `+HALT_PC=${halt[1]}`, '+RETURN_VALUE=0', '+STACK_TOP=134479872',
        ]);
        if (simulationResult.stdout) process.stdout.write(simulationResult.stdout);
        if (simulationResult.stderr) process.stderr.write(simulationResult.stderr);
        requireSuccess(`${test.name} RTL simulation`, simulationResult);
        const output = `${simulationResult.stdout || ''}\n${simulationResult.stderr || ''}`;
        assert.doesNotMatch(output, /^TEST (?:FAIL|TIMEOUT)/m,
            `${test.name} RTL simulation reported firmware failure`);
        const passMarkers = output.match(/^TEST PASS$/gm) || [];
        assert.strictEqual(passMarkers.length, 1,
            `${test.name} RTL simulation reported ${passMarkers.length} TEST PASS markers; expected exactly 1`);
        console.log(`${test.name} RTL execution test passed (${test.optimization}, ${assembled.machineCodes.length} words)`);
    } finally {
        fs.rmSync(tempDir, { recursive: true, force: true });
    }
}

const selectedTests = process.argv.includes('--irq-only') ? firmwareTests.filter(test => test.name === 'cpu_interrupt_test') : firmwareTests;
assert(selectedTests.length > 0);
const optimizations = process.argv.includes('--basic') ? ['basic'] : ['none', 'basic'];
for (const optimization of optimizations) {
    for (const test of selectedTests) runFirmwareTest({ ...test, optimization });
}
console.log(`MERC32 CPU C17 RTL suite passed (${selectedTests.length * optimizations.length} executions)`);
