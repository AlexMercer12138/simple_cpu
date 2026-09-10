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

test('MI matches the Gowin Bin example and zero-fills the declared depth', () => {
    const output = formatAssemblyOutput([1], 'mi', 'test', {
        fileFormat: 'Bin', addressDepth: 256, dataWidth: 8,
    });
    const lines = output.trimEnd().split('\n');
    assert.deepEqual(lines.slice(0, 4), [
        '#File_format=Bin', '#Address_depth=256', '#Data_width=8', '00000001',
    ]);
    assert.equal(lines.length, 259);
    assert.ok(lines.slice(4).every(line => line === '00000000'));
});

test('MI Hex retains leading zeros and constrains unused high bits', () => {
    assert.equal(formatAssemblyOutput([0x1ff, 0], 'mi', 'test', {
        fileFormat: 'Hex', addressDepth: 3, dataWidth: 9,
    }), '#File_format=Hex\n#Address_depth=3\n#Data_width=9\n1FF\n000\n000\n');
    assert.throws(() => formatAssemblyOutput([0x200], 'mi', 'test', { dataWidth: 9 }), /Data_width/);
    assert.throws(() => formatAssemblyOutput([-1], 'mi', 'test', { dataWidth: 8 }), /Data_width/);
});

test('MI rejects invalid headers, insufficient depth and invalid words', () => {
    for (const options of [
        { fileFormat: 'octal' }, { addressDepth: -1 }, { addressDepth: 1.5 },
        { addressDepth: NaN }, { dataWidth: 0 }, { dataWidth: 33 }, { dataWidth: 7.5 },
    ]) assert.throws(() => formatAssemblyOutput([1], 'mi', 'test', options));
    assert.throws(() => formatAssemblyOutput([1, 2], 'mi', 'test', { addressDepth: 1 }), /Address_depth/);
    for (const word of [NaN, 1.5, 0x100000000, -0x80000001]) {
        assert.throws(() => formatAssemblyOutput([word], 'mi', 'test'), /word/);
    }
});

test('assembly pipeline writes configured MI and preserves existing output on overflow', () => {
    const parent = path.resolve(__dirname, '..', '.test-results');
    fs.mkdirSync(parent, { recursive: true });
    const dir = fs.mkdtempSync(path.join(parent, 'mi-output-'));
    const result = assembleFile('.prog test\nmov r1, 1\n', path.join(dir, 'test.asm'),
        'mi', 'normal', dir, { fileFormat: 'Bin', addressDepth: 2, dataWidth: 32 });
    assert.equal(result.outputFile, path.join(dir, 'test.mi'));
    const expected = '#File_format=Bin\n#Address_depth=2\n#Data_width=32\n00000000000000010000000100000000\n00000000000000000000000000000000\n';
    assert.equal(fs.readFileSync(result.outputFile, 'utf8'), expected);
    assert.throws(() => assembleFile('.prog test\nmov r1, 1\n', path.join(dir, 'test.asm'),
        'mi', 'normal', dir, { dataWidth: 8 }), /Data_width/);
    assert.equal(fs.readFileSync(result.outputFile, 'utf8'), expected);
});
