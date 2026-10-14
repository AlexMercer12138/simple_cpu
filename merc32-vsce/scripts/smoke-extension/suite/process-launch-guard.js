'use strict';

const childProcess = require('child_process');
const path = require('path');

const PROCESS_METHODS = Object.freeze([
    'exec', 'execSync', 'execFile', 'execFileSync', 'fork', 'spawn', 'spawnSync',
]);
const COMPILER_ENVIRONMENT = new Set([
    'AR', 'AS', 'CC', 'CXX', 'LD', 'PATH', 'PATHEXT',
]);

async function withHostCompilerBlocked(action, { searchExecutable } = {}) {
    if (typeof action !== 'function') throw new TypeError('guarded action must be a function');
    if (searchExecutable !== undefined
        && (typeof searchExecutable !== 'string' || !path.isAbsolute(searchExecutable))) {
        throw new TypeError('search executable must be an absolute path');
    }
    const methodDescriptors = new Map(PROCESS_METHODS.map((name) => [
        name,
        Object.getOwnPropertyDescriptor(childProcess, name),
    ]));
    const environment = Object.entries(process.env)
        .filter(([name]) => COMPILER_ENVIRONMENT.has(name.toLocaleUpperCase('en-US')));
    const clearCompilerEnvironment = () => {
        for (const name of Object.keys(process.env)) {
            if (COMPILER_ENVIRONMENT.has(name.toLocaleUpperCase('en-US'))) delete process.env[name];
        }
    };
    try {
        for (const name of PROCESS_METHODS) {
            Object.defineProperty(childProcess, name, {
                configurable: true,
                enumerable: methodDescriptors.get(name)?.enumerable ?? true,
                value: blockedMethod(name, methodDescriptors.get(name)?.value, searchExecutable),
                writable: true,
            });
        }
        clearCompilerEnvironment();
        process.env.PATH = '';
        return await action();
    } finally {
        for (const [name, descriptor] of methodDescriptors) {
            if (descriptor === undefined) delete childProcess[name];
            else Object.defineProperty(childProcess, name, descriptor);
        }
        clearCompilerEnvironment();
        for (const [name, value] of environment) process.env[name] = value;
    }
}

function blockedMethod(name, original, searchExecutable) {
    return function (...args) {
        const options = Array.isArray(args[1]) ? args[2] : args[1];
        if (name === 'spawn' && searchExecutable !== undefined
            && typeof args[0] === 'string' && path.isAbsolute(args[0])
            && path.resolve(args[0]) === path.resolve(searchExecutable)
            && !options?.shell) {
            return original.apply(this, args);
        }
        const caller = new Error().stack?.split('\n').slice(2).join('\n');
        const error = new Error(
            `host process launch is forbidden during installed extension audit: ${name}`
            + (caller ? `\n${caller}` : ''));
        error.code = 'MERC32_PROCESS_LAUNCH_DENIED';
        error.processApi = name;
        throw error;
    };
}

module.exports = { withHostCompilerBlocked };
