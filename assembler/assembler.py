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
    """指令类型 - 对应16个功能码"""
    SET = 0x0   # MOV Rd, #imm / MOV Rd, Rs
    ADD = 0x1   # MOV Rd, Rs2 + Rs1 / MOV Rd, Rs + #imm
    SUB = 0x2   # MOV Rd, Rs2 - Rs1 / MOV Rd, Rs - #imm
    AND = 0x3   # MOV Rd, Rs2 & Rs1 / MOV Rd, Rs & #imm
    OR = 0x4    # MOV Rd, Rs2 | Rs1 / MOV Rd, Rs | #imm
    XOR = 0x5   # MOV Rd, Rs2 ^ Rs1 / MOV Rd, Rs ^ #imm
    SLL = 0x6   # MOV Rd, Rs2 << Rs1 / MOV Rd, Rs << #imm
    SRL = 0x7   # MOV Rd, Rs2 >> Rs1 / MOV Rd, Rs >> #imm
    SRA = 0x8   # MOV Rd, Rs2 >>> Rs1 / MOV Rd, Rs >>> #imm (算术右移)
    MWR = 0x9   # MOV [Rs1 + Rs2], Rd / MOV [Rs + #imm], Rd (内存写)
    MRD = 0xA   # MOV Rd, [Rs1 + Rs2] / MOV Rd, [Rs + #imm] (内存读)
    JAL = 0xB   # JMP #imm/label, Rd / JMP Rs, Rd
    BEQ = 0xC   # BRC #imm/Rs, Rd2 == Rd1
    BNE = 0xD   # BRC #imm/Rs, Rd2 != Rd1
    BLT = 0xE   # BRC #imm/Rs, Rd2 < Rd1 (有符号)
    BGE = 0xF   # BRC #imm/Rs, Rd2 >= Rd1 (有符号)


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
    def __init__(self, label: Optional[str] = None, 
                 instruction: Optional[Instruction] = None, 
                 line_content: str = ""):
        self.label = label
        self.instruction = instruction
        self.line_content = line_content  # 原始行内容（用于调试）


class SimpleCPUAssembler:
    """Simple CPU 汇编器"""

    def __init__(self):
        self.symbols: Dict[str, int] = {}      # 符号表（标签 -> 地址）
        self.instructions: List[Instruction] = []  # 指令列表
        self.errors: List[str] = []            # 错误列表

    def remove_comments(self, line: str) -> str:
        """移除注释（只支持 // 格式）"""
        # 查找 // 注释
        if '//' in line:
            line = line[:line.index('//')]
        return line.strip()

    def extract_label(self, line: str) -> Tuple[Optional[str], str]:
        """提取标签，返回 (标签名, 剩余代码)"""
        # 标签格式: label: 或 label：
        match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*)[:：]\s*(.*)', line)
        if match:
            return match.group(1), match.group(2).strip()
        return None, line

    def is_valid_register(self, reg_str: str) -> bool:
        """检查字符串是否是有效的寄存器名 (R0-R15)"""
        reg_str = reg_str.strip().upper()
        if not reg_str.startswith('R'):
            return False
        try:
            reg_num = int(reg_str[1:])
            return 0 <= reg_num <= 15
        except ValueError:
            return False

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

    def parse_immediate(self, imm_str: str, bits: int = 16) -> int:
        """解析立即数字符串，返回整数值
        
        十六进制(0x)和二进制(0b)按无符号数处理，范围 0x0000-0xFFFF
        十进制按有符号数处理，范围 -32768 到 32767
        """
        imm_str = imm_str.strip()

        # 检查是否为 # 开头的立即数
        if imm_str.startswith('#'):
            imm_str = imm_str[1:]

        try:
            # 支持不同进制
            is_hex = imm_str.lower().startswith('0x')
            is_bin = imm_str.lower().startswith('0b')
            
            if is_hex:
                value = int(imm_str, 16)
            elif is_bin:
                value = int(imm_str, 2)
            else:
                value = int(imm_str)

            # 检查范围
            if is_hex or is_bin:
                # 十六进制和二进制按无符号数处理: 0 到 65535 (0x0000-0xFFFF)
                max_val = (1 << bits) - 1  # 65535
                min_val = 0
                if not (min_val <= value <= max_val):
                    raise ValueError(f"立即数越界: {value} (应在 0x0000 到 0x{max_val:04X} 之间)")
            else:
                # 十进制按有符号数处理: -32768 到 32767
                max_val = (1 << (bits - 1)) - 1  # 32767
                min_val = -(1 << (bits - 1))     # -32768
                if not (min_val <= value <= max_val):
                    raise ValueError(f"立即数越界: {value} (应在 {min_val} 到 {max_val} 之间)")

            # 转换为无符号表示（用于编码）- 16位补码表示
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
            # 检查移位运算符 << >> >>>
            if c in '<' and i + 1 < len(operand_str) and operand_str[i+1] == '<':
                if current.strip():
                    tokens.append(current.strip())
                tokens.append('<<')
                current = ""
                i += 2
                continue
            if c in '>' and i + 2 < len(operand_str) and operand_str[i+1] == '>' and operand_str[i+2] == '>':
                # 算术右移 >>>
                if current.strip():
                    tokens.append(current.strip())
                tokens.append('>>>')
                current = ""
                i += 3
                continue
            if c in '>' and i + 1 < len(operand_str) and operand_str[i+1] == '>':
                # 逻辑右移 >>
                if current.strip():
                    tokens.append(current.strip())
                tokens.append('>>')
                current = ""
                i += 2
                continue
            # 处理立即数（带符号）#-123 或 #+123
            if c == '#' and i + 1 < len(operand_str) and operand_str[i+1] in '+-':
                # 这是一个带符号的立即数开始，收集完整的立即数
                if current.strip():
                    tokens.append(current.strip())
                    current = ""
                current += c  # 添加 #
                i += 1
                current += operand_str[i]  # 添加 + 或 -
                i += 1
                # 继续收集数字
                while i < len(operand_str) and (operand_str[i].isalnum() or operand_str[i] in 'xXbB'):
                    current += operand_str[i]
                    i += 1
                tokens.append(current)
                current = ""
                continue
            # 单字符分隔符（但跳过立即数中的+-）
            if c in '[]()&|^':
                if current.strip():
                    tokens.append(current.strip())
                tokens.append(c)
                current = ""
                i += 1
                continue
            # 处理加减运算符（需要区分是运算符还是立即数符号）
            if c in '+-':
                # 如果current为空或current以操作符结尾，这可能是立即数的一部分
                # 否则这是一个运算符
                if current.strip():
                    tokens.append(current.strip())
                    current = ""
                tokens.append(c)
                i += 1
                continue
            current += c
            i += 1
        if current.strip():
            tokens.append(current.strip())
        return tokens

    def parse_mov(self, operands: List[str], line_num: int, line_content: str) -> Instruction:
        """解析MOV指令 - 完整支持I-Type和R-Type

        I-Type (立即数操作):
        MOV Rd, #imm              -> SET
        MOV Rd, Rs + #imm         -> ADD
        MOV Rd, Rs - #imm         -> SUB
        MOV Rd, Rs & #imm         -> AND
        MOV Rd, Rs | #imm         -> OR
        MOV Rd, Rs ^ #imm         -> XOR
        MOV Rd, Rs << #imm        -> SLL
        MOV Rd, Rs >> #imm        -> SRL
        MOV Rd, Rs >>> #imm       -> SRA
        MOV Rd, [Rs + #imm]       -> MRD
        MOV [Rs + #imm], Rd       -> MWR

        R-Type (寄存器操作):
        MOV Rd, Rs                -> SET (简写: MOV Rd, Rs + R0)
        MOV Rd, Rs2 + Rs1         -> ADD
        MOV Rd, Rs2 - Rs1         -> SUB
        MOV Rd, Rs2 & Rs1         -> AND
        MOV Rd, Rs2 | Rs1         -> OR
        MOV Rd, Rs2 ^ Rs1         -> XOR
        MOV Rd, Rs2 << Rs1        -> SLL
        MOV Rd, Rs2 >> Rs1        -> SRL
        MOV Rd, Rs2 >>> Rs1       -> SRA
        MOV Rd, [Rs]              -> MRD (偏移为0，即 [Rs + R0])
        MOV Rd, [Rs1 + Rs2]       -> MRD
        MOV [Rs], Rd              -> MWR (偏移为0，即 [Rs + R0])
        MOV [Rs1 + Rs2], Rd       -> MWR
        """
        if len(operands) < 1:
            raise ValueError("MOV指令需要操作数")

        # 检查是否为内存写操作: MOV [addr], Rd
        first_op = operands[0].strip()
        if first_op.startswith('['):
            # 解析内存地址
            addr_str = first_op
            data_reg = operands[1].strip() if len(operands) > 1 else None
            if not data_reg:
                raise ValueError("MOV内存写需要数据寄存器: MOV [addr], Rd")
            
            # 解析地址表达式 [base + offset]
            addr_tokens = self.tokenize_operands(addr_str)
            # 去掉 '[' 和 ']'
            if addr_tokens[0] == '[':
                addr_tokens = addr_tokens[1:]
            if addr_tokens[-1] == ']':
                addr_tokens = addr_tokens[:-1]
            
            # 格式: [Rs] 或 [Rs + #imm] 或 [Rs + Rt]
            if len(addr_tokens) == 1:
                # [Rs] - 偏移为0，使用R0
                base_reg = addr_tokens[0]
                return Instruction(InstructionType.MWR, [f"[{base_reg}]", data_reg, 'R0'], line_num, line_content)
            elif len(addr_tokens) == 3 and addr_tokens[1] == '+':
                # [Rs + offset]
                base_reg = addr_tokens[0]
                offset = addr_tokens[2]
                return Instruction(InstructionType.MWR, [f"[{base_reg}]", data_reg, offset], line_num, line_content)
            else:
                raise ValueError(f"无效的内存地址格式: {addr_str}")

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
            return Instruction(InstructionType.ADD, [dest_reg, tokens[0], '#0'], line_num, line_content)

        # 检查是否为内存读: MOV Rd, [addr]
        if len(tokens) >= 3 and tokens[0] == '[':
            # 去掉 '[' 和 ']'
            if tokens[-1] == ']':
                tokens = tokens[1:-1]
            else:
                tokens = tokens[1:]
            
            # 格式: [Rs] 或 [Rs + #imm] 或 [Rs + Rt]
            if len(tokens) == 1:
                # [Rs] - 偏移为0
                base_reg = tokens[0]
                return Instruction(InstructionType.MRD, [dest_reg, base_reg, '#0'], line_num, line_content)
            elif len(tokens) == 3 and tokens[1] == '+':
                # [Rs + offset]
                base_reg = tokens[0]
                offset = tokens[2]
                return Instruction(InstructionType.MRD, [dest_reg, base_reg, offset], line_num, line_content)
            else:
                raise ValueError(f"无效的内存地址格式: {src_str}")

        # 检查算术/逻辑运算 - 支持寄存器和立即数两种形式
        # 格式: Rs2 op Rs1 或 Rs op #imm
        if len(tokens) == 3:
            rs2, op, rs1_or_imm = tokens
            
            # 判断是R-Type还是I-Type
            if rs1_or_imm.startswith('#'):
                # I-Type: Rs op #imm
                op_map_i = {
                    '+': InstructionType.ADD,
                    '-': InstructionType.SUB,
                    '&': InstructionType.AND,
                    '|': InstructionType.OR,
                    '^': InstructionType.XOR,
                    '<<': InstructionType.SLL,
                    '>>': InstructionType.SRL,
                    '>>>': InstructionType.SRA,
                }
                if op in op_map_i:
                    return Instruction(op_map_i[op], [dest_reg, rs2, rs1_or_imm], line_num, line_content)
            else:
                # R-Type: Rs2 op Rs1
                op_map_r = {
                    '+': InstructionType.ADD,
                    '-': InstructionType.SUB,
                    '&': InstructionType.AND,
                    '|': InstructionType.OR,
                    '^': InstructionType.XOR,
                    '<<': InstructionType.SLL,
                    '>>': InstructionType.SRL,
                    '>>>': InstructionType.SRA,
                }
                if op in op_map_r:
                    return Instruction(op_map_r[op], [dest_reg, rs2, rs1_or_imm], line_num, line_content)

        raise ValueError(f"无法识别的MOV格式: {src_str}")

    def parse_jmp(self, operands: List[str], line_num: int, line_content: str) -> Instruction:
        """解析JMP指令 - 支持I-Type和R-Type
        
        语法: JMP target, Rd    (与BRC指令结构保持一致)
        
        JMP #imm, Rd          -> JAL (I-Type): Rd = PC+1, PC = imm
        JMP label, Rd         -> JAL (I-Type): Rd = PC+1, PC = label
        JMP Rs, Rd            -> JAL (R-Type): Rd = PC+1, PC = Rs
        """
        if len(operands) != 2:
            raise ValueError("JMP指令需要2个操作数: JMP target, Rd")

        target = operands[0]
        dest_reg = operands[1]

        # JAL 指令支持立即数、标签和寄存器三种形式
        # 编码时根据操作数类型决定是I-Type还是R-Type
        return Instruction(InstructionType.JAL, [target, dest_reg], line_num, line_content)

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

        return ParsedLine(label=label, instruction=inst, line_content=line)

    def _is_brc_with_label(self, inst: Instruction) -> bool:
        """检查BRC指令是否使用标签作为跳转目标
        
        BRC指令现在支持立即数跳转，使用标签时直接汇编为立即数分支
        """
        if inst.inst_type not in [InstructionType.BEQ, InstructionType.BNE,
                                  InstructionType.BLT, InstructionType.BGE]:
            return False
        
        target = inst.operands[0]
        # 检查目标是否为寄存器格式 (R+数字)
        is_register = bool(re.match(r'^[Rr]\d+$', target))
        # 检查目标是否为立即数
        is_immediate = target.startswith('#')
        
        # 如果不是寄存器也不是立即数，则认为是标签
        return not is_register and not is_immediate

    def encode_instruction(self, inst: Instruction, current_addr: int) -> int:
        """将指令编码为32位机器码
        
        指令格式 (32位):
        [31:16] immediate/src_1 (16位)
        [15:12] src_2 (4位)
        [11:8]  dest (4位)
        [7:4]   opcode (4位) - 0001=I-Type, 0010=R-Type
        [3:0]   funct (4位)
        """
        inst_type = inst.inst_type
        ops = inst.operands
        
        # opcode 和 funct 组合
        # I-Type (立即数): opcode = 0001 = 0x1
        # R-Type (寄存器): opcode = 0010 = 0x2
        OPCODE_I = 0x1
        OPCODE_R = 0x2

        # SET: MOV Rd, #imm (I-Type)
        if inst_type == InstructionType.SET:
            rd = self.parse_register(ops[0])
            imm = self.parse_immediate(ops[1], 16)  # 16位有符号立即数
            # 格式: imm[15:0] | 0000 | rd[3:0] | 0001 | funct
            return (imm << 16) | (rd << 8) | (OPCODE_I << 4) | inst_type.value

        # ADD, SUB, AND, OR, XOR, SLL, SRL, SRA: 支持I-Type和R-Type
        elif inst_type in [InstructionType.ADD, InstructionType.SUB, InstructionType.AND,
                          InstructionType.OR, InstructionType.XOR, InstructionType.SLL,
                          InstructionType.SRL, InstructionType.SRA]:
            rd = self.parse_register(ops[0])
            rs2 = self.parse_register(ops[1])
            third_op = ops[2]
            
            # 判断是I-Type还是R-Type
            if third_op.startswith('#'):
                # I-Type: Rs op #imm
                imm = self.parse_immediate(third_op, 16)
                # 格式: imm[15:0] | rs2[3:0] | rd[3:0] | 0001 | funct
                return (imm << 16) | (rs2 << 12) | (rd << 8) | (OPCODE_I << 4) | inst_type.value
            else:
                # R-Type: Rs2 op Rs1
                rs1 = self.parse_register(third_op)
                # 格式: rs1[3:0] | rs2[3:0] | rd[3:0] | 0010 | funct
                return (rs1 << 16) | (rs2 << 12) | (rd << 8) | (OPCODE_R << 4) | inst_type.value

        # MWR: 内存写 - 支持 [Rs + #imm] (I-Type) 和 [Rs1 + Rs2] (R-Type)
        # ops: [base_reg_str], data_reg, offset
        elif inst_type == InstructionType.MWR:
            # 从 "[Rs]" 中提取基址寄存器
            base_str = ops[0].strip()
            if base_str.startswith('[') and base_str.endswith(']'):
                base_str = base_str[1:-1]
            rs_base = self.parse_register(base_str)
            
            # 数据寄存器
            data_reg_str = ops[1]
            rd = self.parse_register(data_reg_str)
            
            # 偏移
            offset_str = ops[2] if len(ops) > 2 else '#0'
            
            if offset_str.startswith('#'):
                # I-Type: [Rs + #imm]
                imm = self.parse_immediate(offset_str, 16)
                # 格式: imm[15:0] | rs_base[3:0] | rd[3:0] | 0001 | funct
                return (imm << 16) | (rs_base << 12) | (rd << 8) | (OPCODE_I << 4) | inst_type.value
            else:
                # R-Type: [Rs1 + Rs2]
                rs_offset = self.parse_register(offset_str)
                # 格式: rs_offset[3:0] | rs_base[3:0] | rd[3:0] | 0010 | funct
                return (rs_offset << 16) | (rs_base << 12) | (rd << 8) | (OPCODE_R << 4) | inst_type.value

        # MRD: 内存读 - 支持 [Rs + #imm] (I-Type) 和 [Rs1 + Rs2] (R-Type)
        # ops: dest_reg, base_reg, offset
        elif inst_type == InstructionType.MRD:
            rd = self.parse_register(ops[0])
            rs_base = self.parse_register(ops[1])
            
            # 偏移
            offset_str = ops[2] if len(ops) > 2 else '#0'
            
            if offset_str.startswith('#'):
                # I-Type: [Rs + #imm]
                imm = self.parse_immediate(offset_str, 16)
                # 格式: imm[15:0] | rs_base[3:0] | rd[3:0] | 0001 | funct
                return (imm << 16) | (rs_base << 12) | (rd << 8) | (OPCODE_I << 4) | inst_type.value
            else:
                # R-Type: [Rs1 + Rs2]
                rs_offset = self.parse_register(offset_str)
                # 格式: rs_offset[3:0] | rs_base[3:0] | rd[3:0] | 0010 | funct
                return (rs_offset << 16) | (rs_base << 12) | (rd << 8) | (OPCODE_R << 4) | inst_type.value

        # JAL: JMP target, Rd (I-Type或R-Type)
        # ops[0] = target (#imm, label, 或 Rs)
        # ops[1] = Rd (链接寄存器)
        elif inst_type == InstructionType.JAL:
            target = ops[0]
            rd = self.parse_register(ops[1])

            # 判断是I-Type还是R-Type（标签已预处理为立即数）
            if target.startswith('#'):
                # I-Type: 立即数跳转
                imm = self.parse_immediate(target, 16)  # 16位有符号立即数
                # 格式: imm[15:0] | 0000 | rd[3:0] | 0001 | funct
                return (imm << 16) | (rd << 8) | (OPCODE_I << 4) | inst_type.value
            elif self.is_valid_register(target):
                # R-Type: 寄存器跳转
                rs1 = self.parse_register(target)
                # 格式: rs1[3:0] | 0000 | rd[3:0] | 0010 | funct
                return (rs1 << 16) | (rd << 8) | (OPCODE_R << 4) | inst_type.value
            else:
                raise ValueError(f"无效的跳转目标: {target} (应为#立即数或寄存器)")

        # BEQ, BNE, BLT, BGE: BRC target, Rd2 op Rd1
        # 支持两种模式:
        # - I-Type: BRC #imm/label, cond (立即数跳转)
        # - R-Type: BRC Rs, cond (寄存器跳转)
        elif inst_type in [InstructionType.BEQ, InstructionType.BNE,
                          InstructionType.BLT, InstructionType.BGE]:
            target = ops[0]
            rs2 = self.parse_register(ops[1])
            rd = self.parse_register(ops[2])

            # 判断是立即数跳转(I-Type)还是寄存器跳转(R-Type)（标签已预处理为立即数）
            if target.startswith('#'):
                # I-Type: 立即数跳转
                imm = self.parse_immediate(target, 16)
                # 格式: imm[15:0] | rs2[3:0] | rd[3:0] | 0001 | funct
                return (imm << 16) | (rs2 << 12) | (rd << 8) | (OPCODE_I << 4) | inst_type.value
            elif self.is_valid_register(target):
                # R-Type: 寄存器跳转
                rs1 = self.parse_register(target)
                # 格式: rs1[3:0] | rs2[3:0] | rd[3:0] | 0010 | funct
                return (rs1 << 16) | (rs2 << 12) | (rd << 8) | (OPCODE_R << 4) | inst_type.value
            else:
                raise ValueError(f"无效的分支目标: {target} (应为#立即数或寄存器)")

        else:
            raise ValueError(f"未实现的指令类型: {inst_type}")

    def replace_labels(self, line: str) -> str:
        """将行中的标签替换为 #立即数"""
        # 去注释
        line_no_comment = self.remove_comments(line)
        if not line_no_comment:
            return line
        
        # 提取标签部分
        label_match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*)[:：]\s*(.*)', line_no_comment)
        if label_match:
            label_part = label_match.group(1) + ':'
            code_part = label_match.group(2)
        else:
            label_part = ""
            code_part = line_no_comment
        
        if not code_part.strip():
            return line_no_comment
        
        # 提取指令和操作数
        parts = code_part.split(None, 1)
        if len(parts) == 0:
            return line_no_comment
        
        mnemonic = parts[0].upper()
        operands_str = parts[1] if len(parts) > 1 else ""
        
        # 替换操作数中的标签
        new_operands = []
        # 按逗号分割操作数
        raw_operands = [op.strip() for op in operands_str.split(',')]
        
        for op in raw_operands:
            if not op:
                continue
            
            # 检查是否是标签（不是立即数，不是寄存器，但在符号表中）
            if op.startswith('#'):
                # 立即数，保持不变
                new_operands.append(op)
            elif self.is_valid_register(op):
                # 寄存器，保持不变
                new_operands.append(op)
            elif op in self.symbols:
                # 标签，替换为 #立即数
                addr = self.symbols[op]
                new_operands.append(f"#{addr}")
            else:
                # 不是标签，保持不变（可能是错误，后续语法分析会报）
                new_operands.append(op)
        
        # 重组指令
        new_line = label_part + " " + mnemonic + " " + ", ".join(new_operands)
        return new_line.strip()

    def assemble(self, source_code: str) -> tuple[List[int], str, str, str]:
        """汇编源代码，返回机器码列表及调试信息
        
        处理流程：
        1. 第一遍：收集所有标签，建立符号表
        2. 第二遍：替换所有标签为立即数 (#addr)
        3. 第三遍：解析指令并生成机器码
        
        返回: (机器码列表, 去注释带行号的代码, 标签表文本, 替换标签后的代码带PC)
        """
        lines = source_code.split('\n')
        self.symbols = {}
        self.errors = []
        
        # ==================== 第一遍：收集标签 ====================
        instruction_count = 0
        for line_num, line in enumerate(lines, 1):
            # 去注释
            clean_line = self.remove_comments(line)
            if not clean_line:
                continue
            
            # 提取标签
            label, code = self.extract_label(clean_line)
            
            if label:
                # 检查标签名是否使用了寄存器名
                if self.is_valid_register(label):
                    self.errors.append(f"第 {line_num} 行错误: 标签名不能作为寄存器名: {label}")
                    continue
                # 检查重复标签
                if label in self.symbols:
                    self.errors.append(f"第 {line_num} 行错误: 重复的标签: {label}")
                    continue
                # 记录标签地址
                self.symbols[label] = instruction_count
            
            # 统计指令数（非空代码行）
            if code.strip():
                instruction_count += 1
        
        if self.errors:
            raise ValueError("\n".join(self.errors))
        
        # ==================== 第二遍：替换标签为立即数 ====================
        processed_lines = []
        for line_num, line in enumerate(lines, 1):
            try:
                new_line = self.replace_labels(line)
                processed_lines.append((line_num, new_line, line))
            except ValueError as e:
                self.errors.append(f"第 {line_num} 行错误: {e}")
        
        if self.errors:
            raise ValueError("\n".join(self.errors))
        
        # 生成替换标签后的代码（带PC地址）- 用于调试
        replaced_code_lines = []
        pc = 0
        for line_num, processed_line, original_line in processed_lines:
            # 去注释
            clean_line = self.remove_comments(processed_line)
            if not clean_line:
                continue
            
            # 提取标签
            label, code = self.extract_label(clean_line)
            
            # 如果有标签，单独显示标签行
            if label:
                replaced_code_lines.append(f"// --- {label} ---")
            
            # 如果有代码，显示带PC地址的代码
            if code.strip():
                replaced_code_lines.append(f"[{pc:3d}\\0x{pc:04X}] {code.strip()}")
                pc += 1
        
        replaced_code = '\n'.join(replaced_code_lines)
        
        # ==================== 第三遍：解析指令并生成机器码 ====================
        self.instructions = []
        parsed_lines = []
        
        for line_num, processed_line, original_line in processed_lines:
            try:
                parsed = self.parse_line(processed_line, line_num)
                # 保留原始行内容用于调试显示
                parsed.line_content = original_line
                parsed_lines.append(parsed)
                if parsed.instruction:
                    self.instructions.append(parsed.instruction)
            except ValueError as e:
                self.errors.append(f"第 {line_num} 行错误: {e}")
        
        if self.errors:
            raise ValueError("\n".join(self.errors))
        
        # 生成调试文件: 去注释带PC地址的原始代码
        debug_code_lines = []
        debug_code_lines.append("// 调试文件: 去除注释后的汇编代码")
        debug_code_lines.append("// 格式: [PC地址] 代码 (十进制/十六进制)")
        debug_code_lines.append("")
        
        pc = 0
        for parsed in parsed_lines:
            if parsed.label:
                debug_code_lines.append(f"// --- {parsed.label} ---")
            
            if parsed.instruction:
                clean_line = self.remove_comments(parsed.line_content)
                if clean_line:
                    debug_code_lines.append(f"[{pc:3d}/0x{pc:04X}] {clean_line}")
                    pc += 1
        
        debug_code = '\n'.join(debug_code_lines)
        
        # 生成调试文件: 标签表
        debug_symbols_lines = []
        debug_symbols_lines.append("// 标签地址表")
        debug_symbols_lines.append("// 格式: 标签名 = 地址(十进制) / 地址(十六进制)")
        debug_symbols_lines.append("")
        
        for label, addr in sorted(self.symbols.items(), key=lambda x: x[1]):
            debug_symbols_lines.append(f"{label:20s} = {addr:3d} (0x{addr:04X})")
        
        debug_symbols = '\n'.join(debug_symbols_lines)
        
        # 第四遍：生成机器码
        machine_codes = []
        
        for i, inst in enumerate(self.instructions):
            try:
                code = self.encode_instruction(inst, i)
                machine_codes.append(code)
            except ValueError as e:
                self.errors.append(f"第 {inst.line_num} 行错误 ({inst.line_content}): {e}")
        
        if self.errors:
            raise ValueError("\n".join(self.errors))
        
        return machine_codes, debug_code, debug_symbols, replaced_code

    def format_verilog(self, codes: List[int], module_name: str = "prog_rom") -> str:
        """格式化为Verilog初始化代码"""
        lines = [
            '// Simple CPU Program Memory Initialization', 
            f'module {module_name}(',
            '    input wire [7:0] prog_addr,',
            '    output reg [31:0] prog_data',
            ');',
            'always @(*) begin',
            '    case (prog_addr)'
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
    return """// Simple CPU 示例程序 - 完整指令集演示
// 计算 1 + 2 + 3 + 4 = 10，演示各种指令

start:
    // 立即数加载 (I-Type SET)
    MOV R0, #0              // R0 = 0
    MOV R1, #1              // R1 = 1
    MOV R2, #2              // R2 = 2
    MOV R3, #3              // R3 = 3
    MOV R4, #4              // R4 = 4

    // ALU I-Type 运算
    MOV R5, R1 + #0         // R5 = 1
    MOV R5, R5 + R2         // R5 = 3 (R-Type ADD)
    MOV R5, R5 + #3         // R5 = 6 (I-Type ADD)
    MOV R5, R5 + R4         // R5 = 10 (R-Type ADD)

    // 内存访问 - I-Type (立即数偏移)
    MOV [R0 + #0], R5       // Mem[0] = 10
    MOV R6, [R0 + #0]       // R6 = Mem[0] = 10

    // 内存访问 - R-Type (寄存器偏移)
    MOV [R0 + R1], R5       // Mem[1] = 10
    MOV R7, [R0 + R1]       // R7 = Mem[1] = 10

    // 逻辑运算
    MOV R8, R5 & #0xFF      // R8 = 10 & 0xFF = 10
    MOV R9, R5 | #0xF0      // R9 = 10 | 0xF0 = 0xFA
    MOV R10, R5 ^ R1        // R10 = 10 ^ 1 = 11

    // 移位运算
    MOV R11, R5 << #1       // R11 = 10 << 1 = 20
    MOV R12, R11 >> #2      // R12 = 20 >> 2 = 5
    MOV R13, #0x80 >>> #1   // R13 = 0x80 >>> 1 = 0xC0 (算术右移)

    // 分支指令
    BRC loop, R5 == R6      // if (10 == 10) goto loop

loop:
    JMP loop, R14           // 无限循环 (JMP target, Rd)
"""


def main():
    parser = argparse.ArgumentParser(
        description='Simple CPU 汇编器 v2.0 - 支持 MOV/JMP/BRC 语法',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  sass program.asm                    # 默认输出Verilog格式
  sass program.asm -f coe             # 输出Xilinx COE格式
  sass program.asm -f mif             # 输出Altera MIF格式
  sass program.asm -f hex -p          # 打印十六进制到控制台
  sass program.asm -d                 # 同时生成调试文件
  sass --sample > sample.asm          # 生成示例程序

支持的语法:
  操作数类型:
    Rd, Rs, Rn          - 寄存器 (R0-R15)
    #imm                - 立即数 (16位有符号: -32768~32767)
    label               - 标签

  运算符:
    + - & | ^           - 算术/逻辑运算
    << >> >>>           - 移位 (>>>为算术右移)
    == != < >=          - 比较运算

  指令格式:
    MOV Rd, #imm                    - 立即数加载
    MOV Rd, Rs2 op Rs1              - 寄存器运算 (R-Type)
    MOV Rd, Rs op #imm              - 立即数运算 (I-Type)
    MOV Rd, [Rs + offset]           - 内存读 (offset: #imm 或 Rs)
    MOV [Rs + offset], Rd           - 内存写
    JMP target, Rd                  - 跳转 (target: #imm, label, 或 Rs; Rd为链接寄存器)
    BRC target, Rd2 cond Rd1        - 条件分支 (cond: == != < >=)
        """
    )

    parser.add_argument('input', nargs='?', help='输入汇编文件 (.asm)')
    parser.add_argument('-o', '--output', help='输出文件 (默认根据格式自动生成)')
    parser.add_argument('-f', '--format', choices=['verilog', 'coe', 'mif', 'hex', 'bin'],
                        default='verilog', help='输出格式 (默认: verilog)')
    parser.add_argument('--sample', action='store_true', help='输出生成的示例程序')
    parser.add_argument('--depth', type=int, default=256, help='MIF文件深度 (默认: 256)')
    parser.add_argument('-p', '--print', action='store_true', help='仅打印到命令行，不保存文件')
    parser.add_argument('-d', '--debug', action='store_true', help='生成调试文件(标签表和去注释代码)')

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

    # 组装代码
    assembler = SimpleCPUAssembler()
    try:
        machine_codes, debug_code, debug_symbols, replaced_code = assembler.assemble(source_code)
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
    
    # 确定调试文件名（基于源文件名）
    source_base = os.path.splitext(args.input)[0]
    label_table_file = source_base + "_label_table.txt"
    replaced_asm_file = source_base + "_replaced.asm"

    # 格式化和输出
    is_binary = False
    if args.format == 'verilog':
        # 使用输入文件的基础名作为 module 名
        module_name = os.path.splitext(os.path.basename(args.input))[0]
        output = assembler.format_verilog(machine_codes, module_name)
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
            
            # 保存调试文件(仅在--debug模式下)
            if args.debug:
                try:
                    with open(label_table_file, 'w', encoding='utf-8') as f:
                        f.write(debug_symbols)
                    with open(replaced_asm_file, 'w', encoding='utf-8') as f:
                        f.write(replaced_code)
                    print(f"调试: 已生成 {label_table_file} 和 {replaced_asm_file}")
                except Exception as e:
                    print(f"警告: 调试文件写入失败: {e}", file=sys.stderr)
                
        except Exception as e:
            print(f"错误: 写入文件失败: {e}", file=sys.stderr)
            sys.exit(1)

    return 0


if __name__ == '__main__':
    sys.exit(main())
