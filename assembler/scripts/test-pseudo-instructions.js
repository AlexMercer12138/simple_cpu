const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');
const { SimpleCPUAssembler } = require('../out/assembler');
const { assembleFile } = require('../out/assemblyService');

function assemble(source, fileName = 'main.asm') {
    return new SimpleCPUAssembler().assemble(source, { sourceFileName: fileName });
}

function hex(codes) {
    return codes.map((code) => `0x${(code >>> 0).toString(16).padStart(8, '0')}`);
}

function mustThrow(label, fn, pattern) {
    try {
        fn();
    } catch (error) {
        const message = String(error && error.message ? error.message : error);
        if (pattern && !pattern.test(message)) {
            throw new Error(`${label}: unexpected error: ${message}`);
        }
        return;
    }

    throw new Error(`${label}: expected an error`);
}

let result = assemble(`
.equ base 0b1000
.equ plus base + 2
.equ alias plus * 3
.equ reg r2
mov r1, alias
mov r3, reg
`);
assert.deepStrictEqual(hex(result.machineCodes), ['0x001e0110', '0x00002311']);
assert.match(result.preprocessedCode, /mov r1, 30/);
assert.match(result.preprocessedCode, /mov r3, r2/);

result = assemble(`
.equ defined_only
.ifdef missing
mov r1, 1
.elsif defined_only
mov r1, 2
.else
mov r1, 3
.endif
`);
assert.deepStrictEqual(hex(result.machineCodes), ['0x00020110']);

result = assemble(`
.macro load(rd, v)
mov rd, v
.endm
.macro wrapper(dst, value)
load(dst, value)
.endm
.ifdef wrapper
wrapper(r4, 6)
.else
mov r4, 0
.endif
`);
assert.deepStrictEqual(hex(result.machineCodes), ['0x00060410']);
assert.match(result.preprocessedCode, /mov r4, 6/);

result = assemble(`
.equ count 1 + 2
.macro emit(x)
mov r5, x
.endm
.rept count
emit(9)
.endr
`);
assert.deepStrictEqual(hex(result.machineCodes), ['0x00090510', '0x00090510', '0x00090510']);

result = assemble(`
.equ flag
.macro pair(v)
.rept 2
.ifdef flag
mov r6, v
.endif
.endr
.endm
pair(4)
`);
assert.deepStrictEqual(hex(result.machineCodes), ['0x00040610', '0x00040610']);

result = assemble(`
target:
jmp 12, r5
jmp r4, r6
jmp r2 + 7, r8
jmp r2 - 3, r9
jmp r1 + r3, r10
jmp 15
jmp r7
jmp r14 + 2
`);
assert.deepStrictEqual(hex(result.machineCodes), [
    '0x000c051b',
    '0x0004062b',
    '0x0007281b',
    '0xfffd291b',
    '0x00031a2b',
    '0x000f001b',
    '0x0007002b',
    '0x0002e01b',
]);

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'merc32-pre-'));
const main = path.join(tmp, 'source.asm');
fs.writeFileSync(main, '.prog demo_prog\nmov r1, 1\n', 'utf8');
const serviceResult = assembleFile(fs.readFileSync(main, 'utf8'), main, 'verilog', 'file');
assert.strictEqual(path.basename(serviceResult.outputFile), 'demo_prog.v');
assert.match(fs.readFileSync(serviceResult.outputFile, 'utf8'), /module demo_prog\(/);

const inc1 = path.join(tmp, 'inc1.asm');
const inc2 = path.join(tmp, 'inc2.asm');
const inactive = path.join(tmp, 'inactive.asm');
fs.writeFileSync(inc1, 'inc1:\nmov r2, 2\n', 'utf8');
fs.writeFileSync(inc2, 'inc2:\nmov r3, 3\n', 'utf8');
fs.writeFileSync(inactive, 'inactive:\nmov r9, 9\n', 'utf8');
fs.writeFileSync(
    main,
    [
        '.ifdef never',
        '.include "inactive.asm"',
        '.endif',
        '.include "inc1.asm"',
        'main:',
        'mov r1, inc1',
        '.include "inc2.asm"',
        'mov r4, inc2',
        '',
    ].join('\n'),
    'utf8',
);

result = assemble(fs.readFileSync(main, 'utf8'), main);
assert.deepStrictEqual(hex(result.machineCodes), ['0x00020110', '0x00030410', '0x00020210', '0x00030310']);
assert.ok(!result.debugSymbols.includes('inactive'));
assert.ok(result.debugSymbols.indexOf('main') < result.debugSymbols.indexOf('inc1'));
assert.ok(result.debugSymbols.indexOf('inc1') < result.debugSymbols.indexOf('inc2'));

mustThrow('register in equ expression', () => assemble('.equ bad r1 + 1\nmov r1, bad\n'), /register|equ|rept/i);
mustThrow('register in rept expression', () => assemble('.equ reg r1\n.rept reg\nmov r1, 1\n.endr\n'), /register|equ|rept/i);
mustThrow('macro recursion', () => assemble('.macro again()\nagain()\n.endm\nagain()\n'), /macro|recursive/i);
mustThrow('macro arg count', () => assemble('.macro one(a)\nmov r1, a\n.endm\none(1, 2)\n'), /macro|argument/i);
mustThrow('unclosed conditional', () => assemble('.ifdef x\nmov r1, 1\n'), /endif|conditional/i);
mustThrow('uppercase instruction still invalid', () => assemble('MOV r1, 1\n'), /MOV|mov/i);

console.log('pseudo-instruction tests passed');
