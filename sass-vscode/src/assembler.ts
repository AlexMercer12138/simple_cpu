import * as path from 'path';
import * as fs from 'fs';

export enum InstructionType {
    SET = 0x0,
    ADD = 0x1,
    SUB = 0x2,
    AND = 0x3,
    OR = 0x4,
    XOR = 0x5,
    SLL = 0x6,
    SRL = 0x7,
    SRA = 0x8,
    MWR = 0x9,
    MRD = 0xA,
    JAL = 0xB,
    BEQ = 0xC,
    BNE = 0xD,
    BLT = 0xE,
    BGE = 0xF,
}

export interface Instruction {
    instType: InstructionType;
    operands: string[];
    lineNum: number;
    lineContent: string;
}

export interface ParsedLine {
    label: string | null;
    instruction: Instruction | null;
    lineContent: string;
}

export interface AssemblyResult {
    machineCodes: number[];
    debugCode: string;
    debugSymbols: string;
    replacedCode: string;
}

export class SimpleCPUAssembler {
    private symbols: Map<string, number> = new Map();
    private instructions: Instruction[] = [];
    private errors: string[] = [];

    removeComments(line: string): string {
        // 移除行内块注释 /* ... */
        while (true) {
            const startIdx = line.indexOf('/*');
            if (startIdx === -1) break;
            const endIdx = line.indexOf('*/', startIdx + 2);
            if (endIdx === -1) {
                // 块注释未闭合，删除从 /* 开始到行尾
                line = line.substring(0, startIdx);
                break;
            }
            line = line.substring(0, startIdx) + line.substring(endIdx + 2);
        }
        // 移除行注释 //
        const idx = line.indexOf('//');
        if (idx !== -1) {
            line = line.substring(0, idx);
        }
        return line.trim();
    }

    extractLabel(line: string): [string | null, string] {
        const match = line.match(/^([a-zA-Z_][a-zA-Z0-9_]*)[:\uff1a]\s*(.*)/);
        if (match) {
            return [match[1], match[2].trim()];
        }
        return [null, line];
    }

    isValidRegister(regStr: string): boolean {
        regStr = regStr.trim().toUpperCase();
        if (!regStr.startsWith('R')) return false;
        const num = parseInt(regStr.substring(1), 10);
        return !isNaN(num) && num >= 0 && num <= 15;
    }

    parseRegister(regStr: string): number {
        regStr = regStr.trim().toUpperCase();
        if (regStr.startsWith('R')) {
            const num = parseInt(regStr.substring(1), 10);
            if (!isNaN(num) && num >= 0 && num <= 15) {
                return num;
            }
            throw new Error(`寄存器编号越界: ${regStr} (应为 R0-R15)`);
        }
        throw new Error(`无效的寄存器格式: ${regStr} (应为 Rx)`);
    }

    parseImmediate(immStr: string, bits: number = 16): number {
        immStr = immStr.trim();

        const isHex = immStr.toLowerCase().startsWith('0x');
        const isBin = immStr.toLowerCase().startsWith('0b');
        let value: number;

        if (isHex) {
            value = parseInt(immStr, 16);
        } else if (isBin) {
            value = parseInt(immStr, 2);
        } else {
            value = parseInt(immStr, 10);
        }

        if (isNaN(value)) {
            throw new Error(`无效的立即数: ${immStr}`);
        }

        if (isHex || isBin) {
            const maxVal = (1 << bits) - 1;
            if (value < 0 || value > maxVal) {
                throw new Error(`立即数越界: ${value} (应在 0x0000 到 0x${maxVal.toString(16).toUpperCase()} 之间)`);
            }
        } else {
            const maxVal = (1 << (bits - 1)) - 1;
            const minVal = -(1 << (bits - 1));
            if (value < minVal || value > maxVal) {
                throw new Error(`立即数越界: ${value} (应在 ${minVal} 到 ${maxVal} 之间)`);
            }
        }

        if (value < 0) {
            value = value & ((1 << bits) - 1);
        }
        return value;
    }

    isImmediate(token: string): boolean {
        token = token.trim();
        if (token.toLowerCase().startsWith('0x')) {
            return /^0[xX][0-9a-fA-F]+$/.test(token);
        }
        if (token.toLowerCase().startsWith('0b')) {
            return /^0[bB][01]+$/.test(token);
        }
        return /^-?\d+$/.test(token);
    }

    tokenizeOperands(operandStr: string): string[] {
        const tokens: string[] = [];
        let current = "";
        let i = 0;
        while (i < operandStr.length) {
            const c = operandStr[i];
            if (/\s/.test(c)) {
                if (current.trim()) {
                    tokens.push(current.trim());
                    current = "";
                }
                i++;
                continue;
            }
            if (i + 1 < operandStr.length) {
                const twoChar = operandStr.substring(i, i + 2);
                if (['==', '!=', '>=', '<='].includes(twoChar)) {
                    if (current.trim()) {
                        tokens.push(current.trim());
                    }
                    tokens.push(twoChar);
                    current = "";
                    i += 2;
                    continue;
                }
            }
            if (c === '<' && i + 1 < operandStr.length && operandStr[i + 1] === '<') {
                if (current.trim()) {
                    tokens.push(current.trim());
                }
                tokens.push('<<');
                current = "";
                i += 2;
                continue;
            }
            if (c === '>' && i + 2 < operandStr.length && operandStr[i + 1] === '>' && operandStr[i + 2] === '>') {
                if (current.trim()) {
                    tokens.push(current.trim());
                }
                tokens.push('>>>');
                current = "";
                i += 3;
                continue;
            }
            if (c === '>' && i + 1 < operandStr.length && operandStr[i + 1] === '>') {
                if (current.trim()) {
                    tokens.push(current.trim());
                }
                tokens.push('>>');
                current = "";
                i += 2;
                continue;
            }

            if (c === '0' && i + 1 < operandStr.length && 'xXbB'.includes(operandStr[i + 1])) {
                if (current.trim()) {
                    tokens.push(current.trim());
                    current = "";
                }
                current += c;
                i++;
                current += operandStr[i];
                i++;
                while (i < operandStr.length && (/[a-zA-Z0-9]/.test(operandStr[i]) || 'xXbB'.includes(operandStr[i]))) {
                    current += operandStr[i];
                    i++;
                }
                tokens.push(current);
                current = "";
                continue;
            }
            if (/\d/.test(c) && current === "") {
                current += c;
                i++;
                while (i < operandStr.length && /\d/.test(operandStr[i])) {
                    current += operandStr[i];
                    i++;
                }
                tokens.push(current);
                current = "";
                continue;
            }
            if ('[]()&|^'.includes(c)) {
                if (current.trim()) {
                    tokens.push(current.trim());
                }
                tokens.push(c);
                current = "";
                i++;
                continue;
            }
            if ('+-'.includes(c)) {
                if (current.trim()) {
                    tokens.push(current.trim());
                    current = "";
                }
                // 检查是否是带符号数字的一部分（如 -1, +10, -0xAB, +0b11）
                if (i + 1 < operandStr.length && (/\d/.test(operandStr[i + 1]) || operandStr[i + 1] === '0')) {
                    current += c;
                    i++;
                    current += operandStr[i];
                    i++;
                    while (i < operandStr.length && (/[a-zA-Z0-9]/.test(operandStr[i]) || 'xXbB'.includes(operandStr[i]))) {
                        current += operandStr[i];
                        i++;
                    }
                    tokens.push(current);
                    current = "";
                    continue;
                }
                tokens.push(c);
                i++;
                continue;
            }
            current += c;
            i++;
        }
        if (current.trim()) {
            tokens.push(current.trim());
        }
        return tokens;
    }

    parseMov(operands: string[], lineNum: number, lineContent: string): Instruction {
        if (operands.length < 1) {
            throw new Error("MOV指令需要操作数");
        }

        const firstOp = operands[0].trim();
        if (firstOp.startsWith('[')) {
            const addrStr = firstOp;
            const dataReg = operands[1]?.trim();
            if (!dataReg) {
                throw new Error("MOV内存写需要数据寄存器: MOV [addr], Rd");
            }
            const addrTokens = this.tokenizeOperands(addrStr);
            if (addrTokens[0] === '[') {
                addrTokens.shift();
            }
            if (addrTokens[addrTokens.length - 1] === ']') {
                addrTokens.pop();
            }
            if (addrTokens.length === 1) {
                return { instType: InstructionType.MWR, operands: [`[${addrTokens[0]}]`, dataReg, 'R0'], lineNum, lineContent };
            } else if (addrTokens.length === 3 && addrTokens[1] === '+') {
                return { instType: InstructionType.MWR, operands: [`[${addrTokens[0]}]`, dataReg, addrTokens[2]], lineNum, lineContent };
            } else {
                throw new Error(`无效的内存地址格式: ${addrStr}`);
            }
        }

        if (operands.length < 2) {
            throw new Error("MOV指令需要至少2个操作数: MOV Rd, src");
        }

        const destReg = operands[0];
        const srcStr = operands[1];
        const tokens = this.tokenizeOperands(srcStr);

        if (tokens.length === 1 && this.isImmediate(tokens[0])) {
            return { instType: InstructionType.SET, operands: [destReg, tokens[0]], lineNum, lineContent };
        }

        if (tokens.length === 1 && /^[Rr]\d+$/.test(tokens[0])) {
            return { instType: InstructionType.ADD, operands: [destReg, tokens[0], '0'], lineNum, lineContent };
        }

        if (tokens.length >= 3 && tokens[0] === '[') {
            if (tokens[tokens.length - 1] === ']') {
                tokens.pop();
            }
            tokens.shift();
            if (tokens.length === 1) {
                return { instType: InstructionType.MRD, operands: [destReg, tokens[0], '0'], lineNum, lineContent };
            } else if (tokens.length === 3 && tokens[1] === '+') {
                return { instType: InstructionType.MRD, operands: [destReg, tokens[0], tokens[2]], lineNum, lineContent };
            } else {
                throw new Error(`无效的内存地址格式: ${srcStr}`);
            }
        }

        if (tokens.length === 3) {
            const rs2 = tokens[0];
            const op = tokens[1];
            const rs1OrImm = tokens[2];

            const opMap: Record<string, InstructionType> = {
                '+': InstructionType.ADD,
                '-': InstructionType.SUB,
                '&': InstructionType.AND,
                '|': InstructionType.OR,
                '^': InstructionType.XOR,
                '<<': InstructionType.SLL,
                '>>': InstructionType.SRL,
                '>>>': InstructionType.SRA,
            };

            if (op in opMap) {
                return { instType: opMap[op], operands: [destReg, rs2, rs1OrImm], lineNum, lineContent };
            }
        }

        throw new Error(`无法识别的MOV格式: ${srcStr}`);
    }

    parseJmp(operands: string[], lineNum: number, lineContent: string): Instruction {
        if (operands.length !== 2) {
            throw new Error("JMP指令需要2个操作数: JMP target, Rd");
        }
        return { instType: InstructionType.JAL, operands: [operands[0], operands[1]], lineNum, lineContent };
    }

    parseBrc(operands: string[], lineNum: number, lineContent: string): Instruction {
        if (operands.length < 2) {
            throw new Error("BRC指令格式错误，应为: BRC target, Rs2 op Rs1");
        }
        const target = operands[0];
        const conditionStr = operands.slice(1).join(' ');
        const tokens = this.tokenizeOperands(conditionStr);

        if (tokens.length < 3) {
            throw new Error("BRC指令条件表达式格式错误");
        }

        let opIdx = -1;
        for (let i = 0; i < tokens.length; i++) {
            if (['==', '!=', '<', '>', '<=', '>='].includes(tokens[i])) {
                opIdx = i;
                break;
            }
        }

        if (opIdx === -1 || opIdx === 0 || opIdx + 1 >= tokens.length) {
            throw new Error("BRC指令缺少比较运算符或操作数");
        }

        let rs2 = tokens[opIdx - 1];
        let op = tokens[opIdx];
        let rd = tokens[opIdx + 1];

        if (op === '>') {
            op = '<';
            [rs2, rd] = [rd, rs2];
        } else if (op === '<=') {
            op = '>=';
            [rs2, rd] = [rd, rs2];
        }

        const opMap: Record<string, InstructionType> = {
            '==': InstructionType.BEQ,
            '!=': InstructionType.BNE,
            '<': InstructionType.BLT,
            '>=': InstructionType.BGE,
        };

        if (!(op in opMap)) {
            throw new Error(`不支持的条件运算符: ${op}`);
        }

        return { instType: opMap[op], operands: [target, rs2, rd], lineNum, lineContent };
    }

    parseLine(line: string, lineNum: number): ParsedLine {
        line = this.removeComments(line);
        if (!line) {
            return { label: null, instruction: null, lineContent: line };
        }

        const [label, code] = this.extractLabel(line);
        if (!code) {
            return { label, instruction: null, lineContent: line };
        }

        const parts = code.split(/\s+/);
        const mnemonic = parts[0].toUpperCase();
        const operandStr = parts.slice(1).join(' ');
        const operands = operandStr.split(',').map(s => s.trim()).filter(s => s);

        let inst: Instruction;
        if (mnemonic === 'MOV') {
            inst = this.parseMov(operands, lineNum, line);
        } else if (mnemonic === 'JMP') {
            inst = this.parseJmp(operands, lineNum, line);
        } else if (mnemonic === 'BRC') {
            inst = this.parseBrc(operands, lineNum, line);
        } else {
            throw new Error(`未知指令: ${mnemonic} (只支持 MOV, JMP, BRC)`);
        }

        return { label, instruction: inst, lineContent: line };
    }

    replaceLabels(line: string): string {
        const lineNoComment = this.removeComments(line);
        if (!lineNoComment) return lineNoComment;

        const labelMatch = lineNoComment.match(/^([a-zA-Z_][a-zA-Z0-9_]*)[:\uff1a]\s*(.*)/);
        let labelPart = "";
        let codePart = lineNoComment;
        if (labelMatch) {
            labelPart = labelMatch[1] + ':';
            codePart = labelMatch[2];
        }

        if (!codePart.trim()) return lineNoComment;

        const parts = codePart.split(/\s+/);
        if (parts.length === 0) return lineNoComment;

        const mnemonic = parts[0].toUpperCase();
        const operandsStr = parts.slice(1).join(' ');
        const rawOperands = operandsStr.split(',').map(s => s.trim()).filter(s => s);
        const newOperands: string[] = [];

        for (const op of rawOperands) {
            if (!op) continue;
            if (this.isImmediate(op)) {
                newOperands.push(op);
            } else if (this.isValidRegister(op)) {
                newOperands.push(op);
            } else if (this.symbols.has(op)) {
                const addr = this.symbols.get(op)!;
                newOperands.push(`${addr}`);
            } else {
                newOperands.push(op);
            }
        }

        return (labelPart + " " + mnemonic + " " + newOperands.join(", ")).trim();
    }

    encodeInstruction(inst: Instruction, currentAddr: number): number {
        const OPCODE_I = 0x1;
        const OPCODE_R = 0x2;

        const type = inst.instType;
        const ops = inst.operands;

        if (type === InstructionType.SET) {
            const rd = this.parseRegister(ops[0]);
            const imm = this.parseImmediate(ops[1], 16);
            return (imm << 16) | (rd << 8) | (OPCODE_I << 4) | type;
        }

        if ([InstructionType.ADD, InstructionType.SUB, InstructionType.AND,
             InstructionType.OR, InstructionType.XOR, InstructionType.SLL,
             InstructionType.SRL, InstructionType.SRA].includes(type)) {
            const rd = this.parseRegister(ops[0]);
            const rs2 = this.parseRegister(ops[1]);
            const third = ops[2];
            if (this.isImmediate(third)) {
                const imm = this.parseImmediate(third, 16);
                return (imm << 16) | (rs2 << 12) | (rd << 8) | (OPCODE_I << 4) | type;
            } else {
                const rs1 = this.parseRegister(third);
                return (rs1 << 16) | (rs2 << 12) | (rd << 8) | (OPCODE_R << 4) | type;
            }
        }

        if (type === InstructionType.MWR) {
            let baseStr = ops[0].trim();
            if (baseStr.startsWith('[') && baseStr.endsWith(']')) {
                baseStr = baseStr.substring(1, baseStr.length - 1);
            }
            const rsBase = this.parseRegister(baseStr);
            const rd = this.parseRegister(ops[1]);
            const offsetStr = ops[2] || '0';
            if (this.isImmediate(offsetStr)) {
                const imm = this.parseImmediate(offsetStr, 16);
                return (imm << 16) | (rsBase << 12) | (rd << 8) | (OPCODE_I << 4) | type;
            } else {
                const rsOffset = this.parseRegister(offsetStr);
                return (rsOffset << 16) | (rsBase << 12) | (rd << 8) | (OPCODE_R << 4) | type;
            }
        }

        if (type === InstructionType.MRD) {
            const rd = this.parseRegister(ops[0]);
            const rsBase = this.parseRegister(ops[1]);
            const offsetStr = ops[2] || '0';
            if (this.isImmediate(offsetStr)) {
                const imm = this.parseImmediate(offsetStr, 16);
                return (imm << 16) | (rsBase << 12) | (rd << 8) | (OPCODE_I << 4) | type;
            } else {
                const rsOffset = this.parseRegister(offsetStr);
                return (rsOffset << 16) | (rsBase << 12) | (rd << 8) | (OPCODE_R << 4) | type;
            }
        }

        if (type === InstructionType.JAL) {
            const target = ops[0];
            const rd = this.parseRegister(ops[1]);
            if (this.isImmediate(target)) {
                const imm = this.parseImmediate(target, 16);
                return (imm << 16) | (rd << 8) | (OPCODE_I << 4) | type;
            } else if (this.isValidRegister(target)) {
                const rs1 = this.parseRegister(target);
                return (rs1 << 16) | (rd << 8) | (OPCODE_R << 4) | type;
            } else {
                throw new Error(`无效的跳转目标: ${target} (应为立即数或寄存器)`);
            }
        }

        if ([InstructionType.BEQ, InstructionType.BNE, InstructionType.BLT, InstructionType.BGE].includes(type)) {
            const target = ops[0];
            const rs2 = this.parseRegister(ops[1]);
            const rd = this.parseRegister(ops[2]);
            if (this.isImmediate(target)) {
                const imm = this.parseImmediate(target, 16);
                return (imm << 16) | (rs2 << 12) | (rd << 8) | (OPCODE_I << 4) | type;
            } else if (this.isValidRegister(target)) {
                const rs1 = this.parseRegister(target);
                return (rs1 << 16) | (rs2 << 12) | (rd << 8) | (OPCODE_R << 4) | type;
            } else {
                throw new Error(`无效的分支目标: ${target} (应为立即数或寄存器)`);
            }
        }

        throw new Error(`未实现的指令类型: ${type}`);
    }

    assemble(sourceCode: string): AssemblyResult {
        const rawLines = sourceCode.split('\n');
        this.symbols = new Map();
        this.errors = [];

        // 第一遍：处理跨行块注释，生成清理后的行
        const lines: string[] = [];
        let inBlockComment = false;
        for (let i = 0; i < rawLines.length; i++) {
            let line = rawLines[i];
            if (inBlockComment) {
                const endIdx = line.indexOf('*/');
                if (endIdx !== -1) {
                    line = line.substring(endIdx + 2);
                    inBlockComment = false;
                } else {
                    lines.push('');
                    continue;
                }
            }
            // 处理行内块注释和开始新块注释
            while (true) {
                const startIdx = line.indexOf('/*');
                if (startIdx === -1) break;
                const endIdx = line.indexOf('*/', startIdx + 2);
                if (endIdx === -1) {
                    line = line.substring(0, startIdx);
                    inBlockComment = true;
                    break;
                }
                line = line.substring(0, startIdx) + line.substring(endIdx + 2);
            }
            // 移除行注释 //
            const lineCommentIdx = line.indexOf('//');
            if (lineCommentIdx !== -1) {
                line = line.substring(0, lineCommentIdx);
            }
            lines.push(line);
        }

        let instructionCount = 0;
        for (let lineNum = 1; lineNum <= lines.length; lineNum++) {
            const cleanLine = lines[lineNum - 1].trim();
            if (!cleanLine) continue;
            const [label, code] = this.extractLabel(cleanLine);
            if (label) {
                if (this.isValidRegister(label)) {
                    this.errors.push(`第 ${lineNum} 行错误: 标签名不能作为寄存器名: ${label}`);
                    continue;
                }
                if (this.symbols.has(label)) {
                    this.errors.push(`第 ${lineNum} 行错误: 重复的标签: ${label}`);
                    continue;
                }
                this.symbols.set(label, instructionCount);
            }
            if (code.trim()) {
                instructionCount++;
            }
        }

        if (this.errors.length) {
            throw new Error(this.errors.join('\n'));
        }

        const processedLines: Array<{ lineNum: number; processed: string; original: string }> = [];
        for (let lineNum = 1; lineNum <= lines.length; lineNum++) {
            try {
                const newLine = this.replaceLabels(lines[lineNum - 1]);
                processedLines.push({ lineNum, processed: newLine, original: rawLines[lineNum - 1] });
            } catch (e: any) {
                this.errors.push(`第 ${lineNum} 行错误: ${e.message}`);
            }
        }

        if (this.errors.length) {
            throw new Error(this.errors.join('\n'));
        }

        const replacedCodeLines: string[] = [];
        let pc = 0;
        for (const { processed } of processedLines) {
            const cleanLine = processed.trim();
            if (!cleanLine) continue;
            const [label, code] = this.extractLabel(cleanLine);
            if (label) {
                replacedCodeLines.push(`// --- ${label} ---`);
            }
            if (code.trim()) {
                replacedCodeLines.push(`[${pc.toString().padStart(3, ' ')}\\0x${pc.toString(16).toUpperCase().padStart(4, '0')}] ${code.trim()}`);
                pc++;
            }
        }
        const replacedCode = replacedCodeLines.join('\n');

        this.instructions = [];
        const parsedLines: ParsedLine[] = [];
        for (const { lineNum, processed, original } of processedLines) {
            try {
                const parsed = this.parseLine(processed, lineNum);
                parsed.lineContent = original;
                parsedLines.push(parsed);
                if (parsed.instruction) {
                    this.instructions.push(parsed.instruction);
                }
            } catch (e: any) {
                this.errors.push(`第 ${lineNum} 行错误: ${e.message}`);
            }
        }

        if (this.errors.length) {
            throw new Error(this.errors.join('\n'));
        }

        const debugCodeLines: string[] = [];
        debugCodeLines.push("// 调试文件: 去除注释后的汇编代码");
        debugCodeLines.push("// 格式: [PC地址] 代码 (十进制/十六进制)");
        debugCodeLines.push("");
        pc = 0;
        for (const parsed of parsedLines) {
            if (parsed.label) {
                debugCodeLines.push(`// --- ${parsed.label} ---`);
            }
            if (parsed.instruction) {
                const cleanLine = this.removeComments(parsed.lineContent);
                if (cleanLine) {
                    debugCodeLines.push(`[${pc.toString().padStart(3, ' ')}/0x${pc.toString(16).toUpperCase().padStart(4, '0')}] ${cleanLine}`);
                    pc++;
                }
            }
        }
        const debugCode = debugCodeLines.join('\n');

        const debugSymbolsLines: string[] = [];
        debugSymbolsLines.push("// 标签地址表");
        debugSymbolsLines.push("// 格式: 标签名 = 地址(十进制) / 地址(十六进制)");
        debugSymbolsLines.push("");
        const sortedSymbols = Array.from(this.symbols.entries()).sort((a, b) => a[1] - b[1]);
        for (const [label, addr] of sortedSymbols) {
            debugSymbolsLines.push(`${label.padEnd(20, ' ')} = ${addr.toString().padStart(3, ' ')} (0x${addr.toString(16).toUpperCase().padStart(4, '0')})`);
        }
        const debugSymbols = debugSymbolsLines.join('\n');

        const machineCodes: number[] = [];
        for (let i = 0; i < this.instructions.length; i++) {
            try {
                const code = this.encodeInstruction(this.instructions[i], i);
                machineCodes.push(code >>> 0);
            } catch (e: any) {
                const inst = this.instructions[i];
                this.errors.push(`第 ${inst.lineNum} 行错误 (${inst.lineContent}): ${e.message}`);
            }
        }

        if (this.errors.length) {
            throw new Error(this.errors.join('\n'));
        }

        return { machineCodes, debugCode, debugSymbols, replacedCode };
    }

    formatVerilog(codes: number[], moduleName: string = "prog_rom"): string {
        const lines = [
            '// Simple CPU Program Memory Initialization',
            `module ${moduleName}(`,
            '    input wire [15:0] prog_addr,',
            '    output reg [31:0] prog_data',
            ');',
            'always @(*) begin',
            '    case (prog_addr)'
        ];
        for (let i = 0; i < codes.length; i++) {
            lines.push(`        ${i} : prog_data = 32'h${(codes[i] >>> 0).toString(16).toUpperCase().padStart(8, '0')};`);
        }
        lines.push(`        default: prog_data = 0;`);
        lines.push(`    endcase`);
        lines.push(`end`);
        lines.push(`endmodule`);
        return lines.join('\n');
    }

    formatCoe(codes: number[]): string {
        const lines = [
            '; Simple CPU Program Memory COE File',
            'memory_initialization_radix=16;',
            'memory_initialization_vector='
        ];
        for (let i = 0; i < codes.length; i++) {
            if (i === codes.length - 1) {
                lines.push(`${(codes[i] >>> 0).toString(16).toUpperCase().padStart(8, '0')};`);
            } else {
                lines.push(`${(codes[i] >>> 0).toString(16).toUpperCase().padStart(8, '0')},`);
            }
        }
        return lines.join('\n');
    }

    formatMif(codes: number[], depth: number = 256, width: number = 32): string {
        const lines = [
            '-- Simple CPU Program Memory MIF File',
            `WIDTH=${width};`,
            `DEPTH=${depth};`,
            '',
            'ADDRESS_RADIX=HEX;',
            'DATA_RADIX=HEX;',
            '',
            'CONTENT BEGIN'
        ];
        for (let i = 0; i < codes.length; i++) {
            lines.push(`    ${i.toString(16).toUpperCase().padStart(4, '0')} : ${(codes[i] >>> 0).toString(16).toUpperCase().padStart(8, '0')};`);
        }
        if (codes.length < depth) {
            lines.push(`    [${codes.length.toString(16).toUpperCase().padStart(4, '0')}..${(depth - 1).toString(16).toUpperCase().padStart(4, '0')}] : 00000000;`);
        }
        lines.push('END;');
        return lines.join('\n');
    }

    formatIntelHex(codes: number[]): string {
        const lines: string[] = [];
        for (let i = 0; i < codes.length; i++) {
            const addr = i * 4;
            const byteData = [
                (codes[i] >>> 24) & 0xFF,
                (codes[i] >>> 16) & 0xFF,
                (codes[i] >>> 8) & 0xFF,
                codes[i] & 0xFF
            ];
            let checksum = 4 + ((addr >> 8) & 0xFF) + (addr & 0xFF) + 0;
            for (const b of byteData) {
                checksum += b;
            }
            checksum = ((-checksum) & 0xFF);
            const dataStr = byteData.map(b => b.toString(16).toUpperCase().padStart(2, '0')).join('');
            lines.push(`:04${addr.toString(16).toUpperCase().padStart(4, '0')}00${dataStr}${checksum.toString(16).toUpperCase().padStart(2, '0')}`);
        }
        lines.push(':00000001FF');
        return lines.join('\n');
    }

    formatBinBytes(codes: number[]): Buffer {
        const byteArray: number[] = [];
        for (const code of codes) {
            byteArray.push((code >>> 24) & 0xFF);
            byteArray.push((code >>> 16) & 0xFF);
            byteArray.push((code >>> 8) & 0xFF);
            byteArray.push(code & 0xFF);
        }
        return Buffer.from(byteArray);
    }
}

export function assembleFile(
    sourceCode: string,
    sourceFileName: string,
    format: 'verilog' | 'coe' | 'mif' | 'hex' | 'bin',
    mode: 'normal' | 'print' | 'debug',
    outputDir?: string
): { output: string | Buffer; outputFile?: string; debugInfo?: { debugCode: string; debugSymbols: string; replacedCode: string } } {
    const assembler = new SimpleCPUAssembler();
    const result = assembler.assemble(sourceCode);

    let output: string | Buffer;
    if (format === 'verilog') {
        const moduleName = path.basename(sourceFileName, path.extname(sourceFileName));
        output = assembler.formatVerilog(result.machineCodes, moduleName);
    } else if (format === 'coe') {
        output = assembler.formatCoe(result.machineCodes);
    } else if (format === 'mif') {
        output = assembler.formatMif(result.machineCodes);
    } else if (format === 'hex') {
        output = assembler.formatIntelHex(result.machineCodes);
    } else if (format === 'bin') {
        output = assembler.formatBinBytes(result.machineCodes);
    } else {
        throw new Error(`未知的输出格式: ${format}`);
    }

    const extMap: Record<string, string> = {
        verilog: '.v',
        coe: '.coe',
        mif: '.mif',
        hex: '.hex',
        bin: '.bin'
    };

    const dir = outputDir || path.dirname(sourceFileName);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    const base = path.basename(sourceFileName, path.extname(sourceFileName));
    const outputFile = path.join(dir, base + extMap[format]);

    if (mode === 'print') {
        if (format === 'bin') {
            const hexStr = Array.from(output as Buffer).map(b => b.toString(16).toUpperCase().padStart(2, '0')).join(' ');
            return { output: hexStr, debugInfo: result };
        }
        return { output: output as string, debugInfo: result };
    }

    if (format === 'bin') {
        fs.writeFileSync(outputFile, output as Buffer);
    } else {
        fs.writeFileSync(outputFile, output as string, 'utf-8');
    }

    if (mode === 'debug') {
        const sourceBase = path.join(dir, base);
        fs.writeFileSync(sourceBase + '_label_table.txt', result.debugSymbols, 'utf-8');
        fs.writeFileSync(sourceBase + '_replaced.asm', result.replacedCode, 'utf-8');
        return { output: output as string, outputFile, debugInfo: result };
    }

    return { output: output as string, outputFile };
}
