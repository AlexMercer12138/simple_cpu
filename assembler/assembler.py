#!/usr/bin/env python3
"""
Simple CPU 汇编器 v2.0
支持 MOV/JMP/BRC 三种关键字语法
支持标签、多格式输出
"""

import sys
import os
import re
import argparse
from typing import List, Tuple, Optional, Dict, Union
from dataclasses import dataclass, field
from enum import Enum, auto


class InstructionType(Enum):
    """指令类型"""
    SET = 0x0   # MOV Rd, #imm
    ADD = 0x1   # MOV Rd, Rs2 + Rs1
    SUB = 0x2   # MOV Rd, Rs2 - Rs1
    AND = 0x3   # MOV Rd, Rs2 & Rs1
    OR = 0x4    # MOV Rd, Rs2 | Rs1
    XOR = 0x5   # MOV Rd, Rs2 ^ Rs1
    SLL = 0x6   # MOV Rd, Rs2 << Rs1
    SRL = 0x7   # MOV Rd, Rs2 >> Rs1
    MWR = 0x8   # MOV [Rs1], Rs2
    MRD = 0x9   # MOV Rd, [Rs1]
    JAL = 0xA   # JMP Rd, #imm
    JALR = 0xB  # JMP Rd, Rs1
    BEQ = 0xC   # BRC Rs1, Rs2 == Rd
    BNE = 0xD   # BRC Rs1, Rs2 != Rd
    BLT = 0xE   # BRC Rs1, Rs2 < Rd
    BGE = 0xF   # BRC Rs1, Rs2 >= Rd


@dataclass
class Instruction:
    """汇编指令类"""
    inst_type: InstructionType  # 指令类型
    operands: List[str]         # 操作数列表
    line_num: int               # 行号
    line_content: str           # 原始行内容


@dataclass
class ParsedLine:
    """解析后的行"""
    label: Optional[str] = None
    instruction: Optional[Instruction] = None


class SimpleCPUAssembler:
    """Simple CPU 汇编器"""

    def __init__(self):
        self.symbols: Dict[str, int] = {}      # 符号表（标签 -> 地址）
        self.instructions: List[Instruction] = []  # 指令列表
        self.errors: List[str] = []            # 错误列表

    def remove_comments(self, line: str) -> str:
        """移除注释（支持 # 和 ;）
        注意：#号在字符串中或作为立即数前缀时不是注释
        """
        # 先处理 ; 注释
        if ';' in line:
            line = line[:line.index(';')]

        # 处理 # 注释，但需要排除立即数 #xxx
        # 立即数格式: #数字 或 #0x 或 #0b
        result = []
        i = 0
        while i < len(line):
            c = line[i]
            if c == '#':
                # 检查是否是立即数
                if i + 1 < len(line) and (line[i+1].isdigit() or line[i+1] in 'xXbB'):
                    result.append(c)
                else:
                    # 这是注释
                    break
            else:
                result.append(c)
            i += 1

        return ''.join(result).strip()

    def extract_label(self, line: str) -> Tuple[Optional[str], str]:
        """提取标签，返回 (标签名, 剩余代码)"""
        # 标签格式: label: 或 label：
        match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*)[:：]\s*(.*)', line)
        if match:
            return match.group(1), match.group(2).strip()
        return None, line

    def parse_register(self, reg_str: str) -> int:
        """解析寄存器字符串，返回寄存器编号 (0-15)"""
        reg_str = reg_str.strip().upper()
        if reg_str.startswith('R'):
            try:
                reg_num = int(reg_str[1:])
                if 0 <= reg_num <= 15:
                    return reg_num
                raise ValueError(f"寄存器编号越界: {reg_str} (应为 R0-R15)")
            except ValueError as e:
                if "越界" in str(e):
                    raise
                raise ValueError(f"无效的寄存器: {reg_str}")
        raise ValueError(f"无效的寄存器格式: {reg_str} (应为 Rx)")

    def parse_immediate(self, imm_str: str, bits: int = 20) -> int:
        """解析立即数字符串，返回整数值"""
        imm_str = imm_str.strip()

        # 检查是否为 # 开头的立即数
        if imm_str.startswith('#'):
            imm_str = imm_str[1:]

        try:
            # 支持不同进制
            if imm_str.lower().startswith('0x'):
                value = int(imm_str, 16)
            elif imm_str.lower().startswith('0b'):
                value = int(imm_str, 2)
            else:
                value = int(imm_str)

            # 检查范围（20位有符号数: -524288 到 524287）
            max_val = (1 << (bits - 1)) - 1
            min_val = -(1 << (bits - 1))
            if not (min_val <= value <= max_val):
                raise ValueError(f"立即数越界: {value} (应在 {min_val} 到 {max_val} 之间)")

            # 转换为无符号表示（用于编码）
            if value < 0:
                value = value & ((1 << bits) - 1)

            return value
        except ValueError as e:
            if "越界" in str(e):
                raise
            raise ValueError(f"无效的立即数: {imm_str}")

    def tokenize_operands(self, operand_str: str) -> List[str]:
        """将操作数字符串分割为token列表"""
        # 保留方括号、运算符作为独立token，但不包括逗号（逗号用于分隔操作数）
        tokens = []
        current = ""
        i = 0
        while i < len(operand_str):
            c = operand_str[i]
            # 跳过空白字符
            if c.isspace():
                if current.strip():
                    tokens.append(current.strip())
                    current = ""
                i += 1
                continue
            # 检查双字符运算符
            if i + 1 < len(operand_str):
                two_char = operand_str[i:i+2]
                if two_char in ['==', '!=', '>=', '<=']:
                    if current.strip():
                        tokens.append(current.strip())
                    tokens.append(two_char)
                    current = ""
                    i += 2
                    continue
            # 检查移位运算符 << >>
            if c in '<' and i + 1 < len(operand_str) and operand_str[i+1] == '<':
                if current.strip():
                    tokens.append(current.strip())
                tokens.append('<<')
                current = ""
                i += 2
                continue
            if c in '>' and i + 1 < len(operand_str) and operand_str[i+1] == '>':
                if current.strip():
                    tokens.append(current.strip())
                tokens.append('>>')
                current = ""
                i += 2
                continue
            # 单字符分隔符
            if c in '[]()+-&|^':
                if current.strip():
                    tokens.append(current.strip())
                tokens.append(c)
                current = ""
                i += 1
                continue
            current += c
            i += 1
        if current.strip():
            tokens.append(current.strip())
        return tokens

    def parse_mov(self, operands: List[str], line_num: int, line_content: str) -> Instruction:
        """解析MOV指令

        MOV Rd, #imm          -> SET
        MOV Rd, Rs            -> 简写: MOV Rd, Rs + R0
        MOV Rd, Rs2 + Rs1     -> ADD
        MOV Rd, Rs2 - Rs1     -> SUB
        MOV Rd, Rs2 & Rs1     -> AND
        MOV Rd, Rs2 | Rs1     -> OR
        MOV Rd, Rs2 ^ Rs1     -> XOR
        MOV Rd, Rs2 << Rs1    -> SLL
        MOV Rd, Rs2 >> Rs1    -> SRL
        MOV Rd, [Rs]          -> MRD
        MOV [Rs1], Rs2        -> MWR
        """
        if len(operands) < 1:
            raise ValueError("MOV指令需要操作数")

        # 检查是否为内存写操作: MOV [Rs1], Rs2
        first_op = operands[0].strip()
        if first_op.startswith('['):
            # 内存写 - operands[0] = "[Rs1]", operands[1] = "Rs2"
            if len(operands) != 2:
                raise ValueError("MOV内存写格式错误，应为: MOV [Rs1], Rs2")
            return Instruction(InstructionType.MWR, [operands[0], operands[1]], line_num, line_content)

        # 检查是否有至少2个操作数 (dest, src)
        if len(operands) < 2:
            raise ValueError("MOV指令需要至少2个操作数: MOV Rd, src")

        dest_reg = operands[0]
        src_str = operands[1]

        # 解析源操作数
        tokens = self.tokenize_operands(src_str)

        # 检查是否为立即数: MOV Rd, #imm
        if len(tokens) == 1 and tokens[0].startswith('#'):
            return Instruction(InstructionType.SET, [dest_reg, tokens[0]], line_num, line_content)

        # 检查是否为单寄存器: MOV Rd, Rs (简化为 ADD Rd, Rs, R0)
        if len(tokens) == 1 and tokens[0].upper().startswith('R'):
            return Instruction(InstructionType.ADD, [dest_reg, tokens[0], 'R0'], line_num, line_content)

        # 检查是否为内存读: MOV Rd, [Rs]
        if len(tokens) == 3 and tokens[0] == '[' and tokens[2] == ']':
            return Instruction(InstructionType.MRD, [dest_reg, tokens[1]], line_num, line_content)

        # 检查算术/逻辑运算
        if len(tokens) == 3:
            rs2, op, rs1 = tokens
            op_map = {
                '+': InstructionType.ADD,
                '-': InstructionType.SUB,
                '&': InstructionType.AND,
                '|': InstructionType.OR,
                '^': InstructionType.XOR,
                '<<': InstructionType.SLL,
                '>>': InstructionType.SRL,
            }
            if op in op_map:
                return Instruction(op_map[op], [dest_reg, rs2, rs1], line_num, line_content)

        raise ValueError(f"无法识别的MOV格式: {src_str}")

    def parse_jmp(self, operands: List[str], line_num: int, line_content: str) -> Instruction:
        """解析JMP指令

        JMP Rd, #imm          -> JAL
        JMP Rd, label         -> JAL (标签)
        JMP Rd, Rs            -> JALR
        """
        if len(operands) != 2:
            raise ValueError("JMP指令需要2个操作数: JMP Rd, target")

        dest_reg = operands[0]
        target = operands[1]

        # 检查是否为立即数
        if target.startswith('#'):
            return Instruction(InstructionType.JAL, [dest_reg, target], line_num, line_content)

        # 检查是否为寄存器
        if target.upper().startswith('R'):
            return Instruction(InstructionType.JALR, [dest_reg, target], line_num, line_content)

        # 否则认为是标签
        return Instruction(InstructionType.JAL, [dest_reg, target], line_num, line_content)

    def parse_brc(self, operands: List[str], line_num: int, line_content: str) -> Instruction:
        """解析BRC指令

        BRC target, Rs2 == Rs1    -> BEQ
        BRC target, Rs2 != Rs1    -> BNE
        BRC target, Rs2 < Rs1     -> BLT
        BRC target, Rs2 >= Rs1    -> BGE

        target可以是寄存器、立即数或标签
        """
        if len(operands) < 2:
            raise ValueError("BRC指令格式错误，应为: BRC target, Rs2 op Rs1")

        target = operands[0]

        # 合并剩余操作数（条件表达式）
        condition_str = ' '.join(operands[1:])
        tokens = self.tokenize_operands(condition_str)

        if len(tokens) < 3:
            raise ValueError("BRC指令条件表达式格式错误")

        # 查找比较运算符位置
        op_idx = -1
        for i, tok in enumerate(tokens):
            if tok in ['==', '!=', '<', '>', '<=', '>=']:
                op_idx = i
                break

        if op_idx == -1 or op_idx == 0 or op_idx + 1 >= len(tokens):
            raise ValueError("BRC指令缺少比较运算符或操作数")

        rs2 = tokens[op_idx - 1]
        op = tokens[op_idx]
        rd = tokens[op_idx + 1]

        # 转换操作符（简化处理）
        # > 转换为 < (交换操作数)
        # <= 转换为 >= (交换操作数)
        if op == '>':
            op = '<'
            rs2, rd = rd, rs2
        elif op == '<=':
            op = '>='
            rs2, rd = rd, rs2

        op_map = {
            '==': InstructionType.BEQ,
            '!=': InstructionType.BNE,
            '<': InstructionType.BLT,
            '>=': InstructionType.BGE,
        }

        if op not in op_map:
            raise ValueError(f"不支持的条件运算符: {op}")

        return Instruction(op_map[op], [target, rs2, rd], line_num, line_content)

    def parse_line(self, line: str, line_num: int) -> ParsedLine:
        """解析单行汇编代码"""
        line = self.remove_comments(line)
        if not line:
            return ParsedLine()

        # 提取标签
        label, code = self.extract_label(line)

        if not code:
            return ParsedLine(label=label)

        # 解析指令
        # 分割指令助记符和操作数
        parts = re.split(r'[\s]+', code, maxsplit=1)
        mnemonic = parts[0].upper()
        operand_str = parts[1] if len(parts) > 1 else ""

        # 分割操作数（按逗号分隔，但保留原始字符串用于进一步解析）
        operands = [op.strip() for op in operand_str.split(',') if op.strip()]

        if mnemonic == 'MOV':
            inst = self.parse_mov(operands, line_num, line)
        elif mnemonic == 'JMP':
            inst = self.parse_jmp(operands, line_num, line)
        elif mnemonic == 'BRC':
            inst = self.parse_brc(operands, line_num, line)
        else:
            raise ValueError(f"未知指令: {mnemonic} (只支持 MOV, JMP, BRC)")

        return ParsedLine(label=label, instruction=inst)

    def encode_instruction(self, inst: Instruction, current_addr: int) -> int:
        """将指令编码为32位机器码"""
        inst_type = inst.inst_type
        ops = inst.operands

        # SET: MOV Rd, #imm
        if inst_type == InstructionType.SET:
            rd = self.parse_register(ops[0])
            imm = self.parse_immediate(ops[1], 20)
            return (imm << 12) | (rd << 4) | inst_type.value

        # ADD, SUB, AND, OR, XOR, SLL, SRL: MOV Rd, Rs2 op Rs1
        elif inst_type in [InstructionType.ADD, InstructionType.SUB, InstructionType.AND,
                          InstructionType.OR, InstructionType.XOR, InstructionType.SLL,
                          InstructionType.SRL]:
            rd = self.parse_register(ops[0])
            rs2 = self.parse_register(ops[1])
            rs1 = self.parse_register(ops[2])
            return (rs1 << 12) | (rs2 << 8) | (rd << 4) | inst_type.value

        # MWR: MOV [Rs1], Rs2
        # ops[0] = "[Rs1]", ops[1] = "Rs2"
        elif inst_type == InstructionType.MWR:
            # 从 "[Rs1]" 中提取 Rs1
            rs1_str = ops[0].strip()
            if rs1_str.startswith('[') and rs1_str.endswith(']'):
                rs1_str = rs1_str[1:-1]
            rs1 = self.parse_register(rs1_str)
            rs2 = self.parse_register(ops[1])
            return (rs1 << 12) | (rs2 << 8) | (0 << 4) | inst_type.value

        # MRD: MOV Rd, [Rs1]
        # ops[0] = "Rd", ops[1] = "Rs1" (已经去掉方括号)
        elif inst_type == InstructionType.MRD:
            rd = self.parse_register(ops[0])
            rs1 = self.parse_register(ops[1])
            return (rs1 << 12) | (0 << 8) | (rd << 4) | inst_type.value

        # JAL: JMP Rd, #imm 或 JMP Rd, label
        elif inst_type == InstructionType.JAL:
            rd = self.parse_register(ops[0])
            target = ops[1]

            # 处理标签
            if target.startswith('#'):
                imm = self.parse_immediate(target, 20)
            elif target.upper().startswith('R'):
                raise ValueError("JAL需要立即数或标签，但得到寄存器")
            else:
                # 标签
                if target not in self.symbols:
                    raise ValueError(f"未定义的标签: {target}")
                imm = self.symbols[target]
            return (imm << 12) | (rd << 4) | inst_type.value

        # JALR: JMP Rd, Rs1
        elif inst_type == InstructionType.JALR:
            rd = self.parse_register(ops[0])
            rs1 = self.parse_register(ops[1])
            return (rs1 << 12) | (0 << 8) | (rd << 4) | inst_type.value

        # BEQ, BNE, BLT, BGE: BRC target, Rs2 op Rs1
        elif inst_type in [InstructionType.BEQ, InstructionType.BNE,
                          InstructionType.BLT, InstructionType.BGE]:
            target = ops[0]
            rs2 = self.parse_register(ops[1])
            rd = self.parse_register(ops[2])

            # 处理跳转目标
            if target.upper().startswith('R'):
                # 目标在寄存器中
                rs1 = self.parse_register(target)
            elif target.startswith('#'):
                # 立即数地址
                imm = self.parse_immediate(target, 20)
                raise ValueError("分支指令目标必须是寄存器或标签，不支持立即数")
            else:
                # 标签 - 需要加载到寄存器，这里简化处理
                # 实际上需要将标签地址先加载到寄存器
                if target not in self.symbols:
                    raise ValueError(f"未定义的标签: {target}")
                raise ValueError("分支指令目标为标签时，需要先将标签地址加载到寄存器")

            return (rs1 << 12) | (rs2 << 8) | (rd << 4) | inst_type.value

        else:
            raise ValueError(f"未实现的指令类型: {inst_type}")

    def assemble(self, source_code: str) -> List[int]:
        """汇编源代码，返回机器码列表"""
        lines = source_code.split('\n')
        self.instructions = []
        self.symbols = {}
        self.errors = []
        parsed_lines = []

        # 第一遍：解析所有行，收集标签和指令
        for line_num, line in enumerate(lines, 1):
            try:
                parsed = self.parse_line(line, line_num)
                parsed_lines.append(parsed)
                if parsed.label:
                    self.symbols[parsed.label] = len(self.instructions)
                if parsed.instruction:
                    self.instructions.append(parsed.instruction)
            except ValueError as e:
                self.errors.append(f"第 {line_num} 行错误: {e}")

        if self.errors:
            raise ValueError("\n".join(self.errors))

        # 第二遍：生成机器码
        machine_codes = []
        for i, inst in enumerate(self.instructions):
            try:
                code = self.encode_instruction(inst, i)
                machine_codes.append(code)
            except ValueError as e:
                self.errors.append(f"第 {inst.line_num} 行错误 ({inst.line_content}): {e}")

        if self.errors:
            raise ValueError("\n".join(self.errors))

        return machine_codes

    def format_verilog(self, codes: List[int]) -> str:
        """格式化为Verilog初始化代码"""
        lines = [
            '// Simple CPU Program Memory Initialization', 
            'module prog_rom(',
            '    input wire [7:0] prog_addr,',
            '    output reg [31:0] prog_data',
            ');',
            'always @(*) begin',
            '    case (prog_addr)',
            '        default: prog_data = 0;'
        ]
        for i, code in enumerate(codes):
            lines.append(f"        {i} : prog_data = 32'h{code:08X};")
        lines.append(f"        default: prog_data = 0;")
        lines.append(f"    endcase")
        lines.append(f"end")
        lines.append(f"endmodule")
        return '\n'.join(lines)

    def format_coe(self, codes: List[int]) -> str:
        """格式化为Xilinx COE文件"""
        lines = [
            '; Simple CPU Program Memory COE File',
            'memory_initialization_radix=16;',
            'memory_initialization_vector=',
        ]
        for i, code in enumerate(codes):
            if i == len(codes) - 1:
                lines.append(f"{code:08X};")
            else:
                lines.append(f"{code:08X},")
        return '\n'.join(lines)

    def format_mif(self, codes: List[int], depth: int = 256, width: int = 32) -> str:
        """格式化为Altera MIF文件"""
        lines = [
            '-- Simple CPU Program Memory MIF File',
            f'WIDTH={width};',
            f'DEPTH={depth};',
            '',
            'ADDRESS_RADIX=HEX;',
            'DATA_RADIX=HEX;',
            '',
            'CONTENT BEGIN',
        ]
        for i, code in enumerate(codes):
            lines.append(f"    {i:04X} : {code:08X};")
        if len(codes) < depth:
            lines.append(f"    [{len(codes):04X}..{depth-1:04X}] : 00000000;")
        lines.append('END;')
        return '\n'.join(lines)

    def format_intel_hex(self, codes: List[int]) -> str:
        """格式化为Intel HEX格式（文本格式，但符合标准）"""
        lines = []
        # 数据记录
        for i, code in enumerate(codes):
            # Intel HEX格式: :BBAAAATTDD...CC
            # BB=字节数, AAAA=地址, TT=记录类型(00=数据), DD=数据, CC=校验和
            addr = i * 4  # 每个指令4字节
            # 将32位数据拆分为4字节，大端序
            byte_data = [
                (code >> 24) & 0xFF,
                (code >> 16) & 0xFF,
                (code >> 8) & 0xFF,
                code & 0xFF
            ]
            # 计算校验和
            checksum = 4 + ((addr >> 8) & 0xFF) + (addr & 0xFF) + 0
            for b in byte_data:
                checksum += b
            checksum = ((-checksum) & 0xFF)

            data_str = ''.join([f"{b:02X}" for b in byte_data])
            lines.append(f":04{addr:04X}00{data_str}{checksum:02X}")

        # 结束记录
        lines.append(":00000001FF")
        return '\n'.join(lines)

    def format_bin_bytes(self, codes: List[int]) -> bytes:
        """格式化为原始二进制字节（大端序，每个指令4字节）"""
        byte_array = bytearray()
        for code in codes:
            # 大端序写入32位数据
            byte_array.append((code >> 24) & 0xFF)
            byte_array.append((code >> 16) & 0xFF)
            byte_array.append((code >> 8) & 0xFF)
            byte_array.append(code & 0xFF)
        return bytes(byte_array)


def create_sample_asm():
    """创建示例汇编代码"""
    return """; Simple CPU 示例程序
; 计算 1 + 2 + 3 + 4 = 10

start:
    MOV R0, #0          ; R0 = 0 (累加器)
    MOV R1, #1          ; R1 = 1
    MOV R2, #2          ; R2 = 2
    MOV R3, #3          ; R3 = 3
    MOV R4, #4          ; R4 = 4

    MOV R5, R1          ; R5 = R1 + R0 = 1
    MOV R5, R5 + R2     ; R5 = R5 + R2 = 3
    MOV R5, R5 + R3     ; R5 = R5 + R3 = 6
    MOV R5, R5 + R4     ; R5 = R5 + R4 = 10

    MOV [R0], R5        ; 存储结果到内存地址0
    MOV R6, [R0]        ; 从内存读取到R6

loop:
    JMP R7, loop        ; 无限循环
"""


def main():
    parser = argparse.ArgumentParser(
        description='Simple CPU 汇编器 v2.0 - 支持 MOV/JMP/BRC 语法',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  simple-asm program.asm                    # 默认Verilog格式输出
  simple-asm program.asm -o output.v -f verilog
  simple-asm program.asm -o output.coe -f coe    # Xilinx COE格式
  simple-asm program.asm -o output.mif -f mif    # Altera MIF格式
  simple-asm program.asm -f hex               # 纯十六进制
  simple-asm --sample > sample.asm            # 生成示例程序

支持的指令语法:
  MOV 指令:
    MOV Rd, #imm              ; 加载立即数: Rd = imm
    MOV Rd, Rs                ; 寄存器复制: Rd = Rs
    MOV Rd, Rs2 + Rs1         ; 加法: Rd = Rs2 + Rs1
    MOV Rd, Rs2 - Rs1         ; 减法: Rd = Rs2 - Rs1
    MOV Rd, Rs2 & Rs1         ; 按位与: Rd = Rs2 & Rs1
    MOV Rd, Rs2 | Rs1         ; 按位或: Rd = Rs2 | Rs1
    MOV Rd, Rs2 ^ Rs1         ; 按位异或: Rd = Rs2 ^ Rs1
    MOV Rd, Rs2 << Rs1        ; 逻辑左移: Rd = Rs2 << Rs1
    MOV Rd, Rs2 >> Rs1        ; 逻辑右移: Rd = Rs2 >> Rs1
    MOV Rd, [Rs]              ; 内存读: Rd = Mem[Rs]
    MOV [Rs1], Rs2            ; 内存写: Mem[Rs1] = Rs2

  JMP 指令:
    JMP Rd, #imm              ; 跳转到立即数地址: Rd = PC+1, PC = imm
    JMP Rd, label             ; 跳转到标签: Rd = PC+1, PC = label
    JMP Rd, Rs                ; 寄存器跳转: Rd = PC+1, PC = Rs

  BRC 指令 (分支):
    BRC Rs, Rd2 == Rd1        ; 相等分支: if (Rd2 == Rd1) PC = Rs
    BRC Rs, Rd2 != Rd1        ; 不等分支: if (Rd2 != Rd1) PC = Rs
    BRC Rs, Rd2 < Rd1         ; 小于分支: if (Rd2 < Rd1) PC = Rs
    BRC Rs, Rd2 >= Rd1        ; 大于等于分支: if (Rd2 >= Rd1) PC = Rs
    BRC Rs, Rd2 > Rd1         ; 大于分支: if (Rd1 < Rd2) PC = Rs
    BRC Rs, Rd2 <= Rd1        ; 小于等于分支: if (Rd1 >= Rd2) PC = Rs
        """
    )

    parser.add_argument('input', nargs='?', help='输入汇编文件 (.asm)')
    parser.add_argument('-o', '--output', help='输出文件 (默认根据格式自动生成)')
    parser.add_argument('-f', '--format', choices=['verilog', 'coe', 'mif', 'hex', 'bin'],
                        default='verilog', help='输出格式 (默认: verilog)')
    parser.add_argument('--sample', action='store_true', help='输出生成的示例程序')
    parser.add_argument('--depth', type=int, default=256, help='MIF文件深度 (默认: 256)')
    parser.add_argument('-p', '--print', action='store_true', help='仅打印到命令行，不保存文件')

    args = parser.parse_args()

    # 生成示例程序
    if args.sample:
        print(create_sample_asm())
        return 0

    # 检查输入文件
    if not args.input:
        parser.error("需要提供输入文件或使用 --sample 生成示例")

    # 读取输入文件
    try:
        with open(args.input, 'r', encoding='utf-8') as f:
            source_code = f.read()
    except FileNotFoundError:
        print(f"错误: 找不到文件 '{args.input}'", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"错误: 读取文件失败: {e}", file=sys.stderr)
        sys.exit(1)

    # 汇编
    assembler = SimpleCPUAssembler()
    try:
        machine_codes = assembler.assemble(source_code)
    except ValueError as e:
        print(f"汇编错误:\n{e}", file=sys.stderr)
        sys.exit(1)

    # 确定输出文件名
    if args.output:
        output_file = args.output
    else:
        # 根据输入文件名和格式自动生成输出文件名
        base_name = os.path.splitext(args.input)[0]
        ext_map = {
            'verilog': '.v',
            'coe': '.coe',
            'mif': '.mif',
            'hex': '.hex',
            'bin': '.bin'
        }
        output_file = base_name + ext_map[args.format]

    # 格式化和输出
    is_binary = False
    if args.format == 'verilog':
        output = assembler.format_verilog(machine_codes)
    elif args.format == 'coe':
        output = assembler.format_coe(machine_codes)
    elif args.format == 'mif':
        output = assembler.format_mif(machine_codes, args.depth)
    elif args.format == 'hex':
        if args.print:
            output = assembler.format_intel_hex(machine_codes)
        else:
            output = assembler.format_intel_hex(machine_codes)
    elif args.format == 'bin':
        is_binary = True
        output = assembler.format_bin_bytes(machine_codes)
    else:
        print(f"错误: 未知的输出格式: {args.format}", file=sys.stderr)
        sys.exit(1)

    # 输出结果
    if args.print:
        if is_binary:
            # 二进制格式打印十六进制表示
            print(' '.join([f"{b:02X}" for b in output]))
        else:
            print(output)
    else:
        try:
            if is_binary:
                # 二进制文件使用'wb'模式写入
                with open(output_file, 'wb') as f:
                    f.write(output)
            else:
                # 文本文件使用'w'模式写入
                with open(output_file, 'w', encoding='utf-8') as f:
                    f.write(output)
            print(f"成功: 已生成 {output_file} ({len(machine_codes)} 条指令)")
        except Exception as e:
            print(f"错误: 写入文件失败: {e}", file=sys.stderr)
            sys.exit(1)

    return 0


if __name__ == '__main__':
    sys.exit(main())
