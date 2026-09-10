import { MiOutputOptions, OutputFormat } from './types';

export const OUTPUT_EXTENSIONS: Record<OutputFormat, string> = {
    verilog: '.v',
    coe: '.coe',
    mif: '.mif',
    hex: '.hex',
    bin: '.bin',
    mem: '.mem',
    mi: '.mi',
};

export function formatAssemblyOutput(codes: number[], format: OutputFormat, moduleName: string,
    miOptions: MiOutputOptions = {}): string | Buffer {
    switch (format) {
        case 'verilog':
            return formatVerilog(codes, moduleName);
        case 'coe':
            return formatCoe(codes);
        case 'mif':
            return formatMif(codes);
        case 'hex':
            return formatIntelHex(codes);
        case 'bin':
            return formatBinBytes(codes);
        case 'mem':
            return formatReadmemh(codes);
        case 'mi':
            return formatMi(codes, miOptions);
    }
}

function formatMi(codes: number[], options: MiOutputOptions): string {
    const { fileFormat = 'Hex', addressDepth = 0, dataWidth = 32 } = options;
    if (fileFormat !== 'Bin' && fileFormat !== 'Hex') {
        throw new Error('MI File_format must be Bin or Hex');
    }
    if (!Number.isInteger(addressDepth) || addressDepth < 0 || addressDepth > 2 ** 25) {
        throw new Error('MI Address_depth must be an integer in 0..33554432 (0 = automatic)');
    }
    if (!Number.isInteger(dataWidth) || dataWidth < 1 || dataWidth > 32) {
        throw new Error('MI Data_width must be an integer in 1..32');
    }
    const depth = addressDepth || Math.max(1, codes.length);
    if (codes.length > depth) {
        throw new Error(`MI Address_depth ${depth} is smaller than the ${codes.length} output words`);
    }
    const radix = fileFormat === 'Bin' ? 2 : 16;
    const digits = fileFormat === 'Bin' ? dataWidth : Math.ceil(dataWidth / 4);
    const lines = [`#File_format=${fileFormat}`, `#Address_depth=${depth}`, `#Data_width=${dataWidth}`];
    for (let index = 0; index < depth; index++) {
        const code = codes[index] ?? 0;
        if (!Number.isInteger(code) || code < -0x80000000 || code > 0xffffffff) {
            throw new Error(`MI word ${index} is not a 32-bit integer`);
        }
        const word = code >>> 0;
        if (word >= 2 ** dataWidth) {
            throw new Error(`MI word ${index} does not fit Data_width=${dataWidth}`);
        }
        lines.push(word.toString(radix).toUpperCase().padStart(digits, '0'));
    }
    return `${lines.join('\n')}\n`;
}

export function formatPrintOutput(output: string | Buffer, format: OutputFormat): string {
    if (format !== 'bin') {
        return output.toString();
    }

    return Array.from(output as Buffer)
        .map((byte) => byte.toString(16).toUpperCase().padStart(2, '0'))
        .join(' ');
}

function formatVerilog(codes: number[], moduleName = 'prog_rom'): string {
    const lines = [
        '// Simple CPU Program Memory Initialization',
        `module ${moduleName}(`,
        '    input wire [15:0] prog_addr,',
        '    output reg [31:0] prog_data',
        ');',
        'always @(*) begin',
        '    case (prog_addr)',
    ];
    for (let i = 0; i < codes.length; i++) {
        const byteAddress = i * 4;
        const romAddress = byteAddress >>> 2;
        lines.push(`        ${romAddress} : prog_data = 32'h${toWordHex(codes[i])};`);
    }
    lines.push('        default: prog_data = 0;');
    lines.push('    endcase');
    lines.push('end');
    lines.push('endmodule');
    return lines.join('\n');
}

function formatCoe(codes: number[]): string {
    const lines = [
        '; Simple CPU Program Memory COE File',
        'memory_initialization_radix=16;',
        'memory_initialization_vector=',
    ];
    for (let i = 0; i < codes.length; i++) {
        const suffix = i === codes.length - 1 ? ';' : ',';
        lines.push(`${toWordHex(codes[i])}${suffix}`);
    }
    return lines.join('\n');
}

function formatMif(codes: number[], depth = 256, width = 32): string {
    const lines = [
        '-- Simple CPU Program Memory MIF File',
        `WIDTH=${width};`,
        `DEPTH=${depth};`,
        '',
        'ADDRESS_RADIX=HEX;',
        'DATA_RADIX=HEX;',
        '',
        'CONTENT BEGIN',
    ];
    for (let i = 0; i < codes.length; i++) {
        lines.push(`    ${toAddressHex(i)} : ${toWordHex(codes[i])};`);
    }
    if (codes.length < depth) {
        lines.push(`    [${toAddressHex(codes.length)}..${toAddressHex(depth - 1)}] : 00000000;`);
    }
    lines.push('END;');
    return lines.join('\n');
}

function formatIntelHex(codes: number[]): string {
    const lines: string[] = [];
    for (let i = 0; i < codes.length; i++) {
        const addr = i * 4;
        const byteData = wordToBytes(codes[i]);
        let checksum = 4 + ((addr >> 8) & 0xFF) + (addr & 0xFF);
        for (const byte of byteData) {
            checksum += byte;
        }
        checksum = (-checksum) & 0xFF;
        const dataStr = byteData.map(toByteHex).join('');
        lines.push(`:04${toAddressHex(addr)}00${dataStr}${toByteHex(checksum)}`);
    }
    lines.push(':00000001FF');
    return lines.join('\n');
}

function formatReadmemh(codes: number[]): string {
    return codes.map(toWordHex).join('\n');
}

function formatBinBytes(codes: number[]): Buffer {
    return Buffer.from(codes.flatMap(wordToBytes));
}

function wordToBytes(code: number): number[] {
    return [
        (code >>> 24) & 0xFF,
        (code >>> 16) & 0xFF,
        (code >>> 8) & 0xFF,
        code & 0xFF,
    ];
}

function toWordHex(value: number): string {
    return (value >>> 0).toString(16).toUpperCase().padStart(8, '0');
}

function toAddressHex(value: number): string {
    return value.toString(16).toUpperCase().padStart(4, '0');
}

function toByteHex(value: number): string {
    return value.toString(16).toUpperCase().padStart(2, '0');
}
