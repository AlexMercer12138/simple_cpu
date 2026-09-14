'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { formatAssemblyOutput } = require('../out/outputFormatters');
const { assembleFile } = require('../out/assemblyService');

test('MI defaults to full-width Hex words and exact automatic depth', () => {
    assert.equal(formatAssemblyOutput([1, 0x89abcdef, -1], 'mi', 'test'),
        '#File_format=Hex\n#Address_depth=3\n#Data_width=32\n00000001\n89ABCDEF\nFFFFFFFF\n');
    assert.equal(formatAssemblyOutput([], 'mi', 'empty'),
        '#File_format=Hex\n#Address_depth=1\n#Data_width=32\n00000000\n');
});

test('MI uses the same Hex words as COE and MIF', () => {
    const words = [0, 1, 0x89abcdef, -1];
    const lines = formatAssemblyOutput(words, 'mi', 'test').trimEnd().split('\n');
    const coe = formatAssemblyOutput(words, 'coe', 'test');
    const mif = formatAssemblyOutput(words, 'mif', 'test');
    assert.match(coe, /memory_initialization_radix=16;/);
    assert.match(mif, /DATA_RADIX=HEX;/);
    assert.equal(lines.length, 7);
    for (const word of lines.slice(3)) {
        assert.match(word, /^[0-9A-F]{8}$/);
        assert.ok(coe.includes(word));
        assert.ok(mif.includes(word));
    }
});

test('MI rejects invalid words', () => {
    for (const word of [NaN, 1.5, 0x100000000, -0x80000001]) {
        assert.throws(() => formatAssemblyOutput([word], 'mi', 'test'), /word/);
    }
});

test('assembly pipeline writes MI without any format-specific options', () => {
    const parent = path.resolve(__dirname, '..', '.test-results');
    fs.mkdirSync(parent, { recursive: true });
    const dir = fs.mkdtempSync(path.join(parent, 'mi-output-'));
    const result = assembleFile('.prog test\nmov r1, 1\n', path.join(dir, 'test.asm'), 'mi', 'normal', dir);
    assert.equal(result.outputFile, path.join(dir, 'test.mi'));
    assert.equal(fs.readFileSync(result.outputFile, 'utf8'),
        '#File_format=Hex\n#Address_depth=1\n#Data_width=32\n00010100\n');
});
