'use strict';

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function runInstalledHost(executable, args, options) {
    const files = ['host.stdout.log', 'host.stderr.log'].map(name => path.join(options.cwd, name));
    const descriptors = [];
    let result;
    try {
        for (const file of files) descriptors.push(fs.openSync(file, 'wx'));
        // Desktop helpers can outlive Code while inheriting its output handles.
        result = spawnSync(executable, args, {
            ...options,
            stdio: ['ignore', ...descriptors],
        });
    } finally {
        for (const descriptor of descriptors) fs.closeSync(descriptor);
    }
    const output = files.map(file => {
        if (fs.statSync(file).size > 32 * 1024 * 1024) {
            throw new Error(`Installed VSIX host log exceeds 32 MiB: ${file}`);
        }
        return fs.readFileSync(file, 'utf8');
    });
    return { ...result, stdout: output[0], stderr: output[1] };
}

module.exports = { runInstalledHost };
