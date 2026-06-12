# Simple CPU 指令集参考

## 目录

- [指令集概述](#指令集概述)
  - [字段说明](#字段说明)
- [指令列表](#指令列表)
  - [1. 伪指令](#1-伪指令)
    - [.equ - 常量宏定义](#equ---常量宏定义)
    - [.prog - 输出文件名定义](#prog---输出文件名定义)
    - [.ifdef/.elsif/.else/.endif - 条件编译](#ifdefelsifelseendif---条件编译)
    - [.macro/.endm - 代码片段宏定义](#macroendm---代码片段宏定义)
    - [.include - 文件引用](#include---文件引用)
    - [.rept/.endr - 重复展开](#reptendr---重复展开)
  - [2. 数据传送指令](#2-数据传送指令)
    - [SETI - 设置立即数 (I-Type)](#seti---设置立即数-i-type)
    - [SETR - 寄存器移动 (R-Type)](#setr---寄存器移动-r-type)
  - [3. 算术运算指令](#3-算术运算指令)
    - [ADDI - 立即数加法 (I-Type)](#addi---立即数加法-i-type)
    - [ADDR - 寄存器加法 (R-Type)](#addr---寄存器加法-r-type)
    - [SUBI - 立即数减法 (I-Type)](#subi---立即数减法-i-type)
    - [SUBR - 寄存器减法 (R-Type)](#subr---寄存器减法-r-type)
  - [4. 逻辑运算指令](#4-逻辑运算指令)
    - [ANDI - 立即数按位与 (I-Type)](#andi---立即数按位与-i-type)
    - [ANDR - 寄存器按位与 (R-Type)](#andr---寄存器按位与-r-type)
    - [ORI - 立即数按位或 (I-Type)](#ori---立即数按位或-i-type)
    - [ORR - 寄存器按位或 (R-Type)](#orr---寄存器按位或-r-type)
    - [XORI - 立即数按位异或 (I-Type)](#xori---立即数按位异或-i-type)
    - [XORR - 寄存器按位异或 (R-Type)](#xorr---寄存器按位异或-r-type)
  - [5. 移位运算指令](#5-移位运算指令)
    - [SLLI - 立即数逻辑左移 (I-Type)](#slli---立即数逻辑左移-i-type)
    - [SLLR - 寄存器逻辑左移 (R-Type)](#sllr---寄存器逻辑左移-r-type)
    - [SRLI - 立即数逻辑右移 (I-Type)](#srli---立即数逻辑右移-i-type)
    - [SRLR - 寄存器逻辑右移 (R-Type)](#srlr---寄存器逻辑右移-r-type)
    - [SRAI - 立即数算术右移 (I-Type)](#srai---立即数算术右移-i-type)
    - [SRAR - 寄存器算术右移 (R-Type)](#srar---寄存器算术右移-r-type)
  - [6. 内存访问指令](#6-内存访问指令)
    - [MWRI - 立即数偏移内存写 (I-Type)](#mwri---立即数偏移内存写-i-type)
    - [MWRR - 寄存器偏移内存写 (R-Type)](#mwrr---寄存器偏移内存写-r-type)
    - [MRDI - 立即数偏移内存读 (I-Type)](#mrdi---立即数偏移内存读-i-type)
    - [MRDR - 寄存器偏移内存读 (R-Type)](#mrdr---寄存器偏移内存读-r-type)
  - [7. 跳转指令](#7-跳转指令)
    - [JALI - 基址加立即数跳转并链接 (I-Type)](#jali---基址加立即数跳转并链接-i-type)
    - [JALR - 基址加寄存器跳转并链接 (R-Type)](#jalr---基址加寄存器跳转并链接-r-type)
  - [8. 分支指令](#8-分支指令)
    - [BEQI - 立即数相等分支 (I-Type)](#beqi---立即数相等分支-i-type)
    - [BEQR - 寄存器相等分支 (R-Type)](#beqr---寄存器相等分支-r-type)
    - [BNEI - 立即数不等分支 (I-Type)](#bnei---立即数不等分支-i-type)
    - [BNER - 寄存器不等分支 (R-Type)](#bner---寄存器不等分支-r-type)
    - [BLTI - 立即数小于分支 (I-Type)](#blti---立即数小于分支-i-type)
    - [BLTR - 寄存器小于分支 (R-Type)](#bltr---寄存器小于分支-r-type)
    - [BGEI - 立即数大于等于分支 (I-Type)](#bgei---立即数大于等于分支-i-type)
    - [BGER - 寄存器大于等于分支 (R-Type)](#bger---寄存器大于等于分支-r-type)
- [相关文档](#相关文档)

---

## 指令集概述

Simple CPU 采用精简指令集（RISC）架构，共支持 **32条指令**（16种功能 × 2种寻址方式），每条指令为 **32位** 定长格式。

- **I-Type（立即数类型）**：使用16位立即数作为操作数
- **R-Type（寄存器类型）**：使用寄存器值作为操作数

```
指令格式:
31                 16  15  12  11   8  7    4  3    0
├─────────────────────┼───────┼───────┼───────┼───────┤
│   immediate/src_1   │ src_2 │ dest  │ opcode│ funct │
│       [15:0]        │ [3:0] │ [3:0] │ [3:0] │ [3:0] │
└─────────────────────┴───────┴───────┴───────┴───────┘
```

### 字段说明

| 字段 | 位宽 | 描述 |
|------|------|------|
| `imm` | 16位 [31:16] | 立即数 |
| `rs1` | 4位 [19:16] | 源寄存器1索引 |
| `rs2` | 4位 [15:12] | 源寄存器2索引 |
| `rd`  | 4位 [11:8] | 目标寄存器索引 |
| `opc` | 4位 [7:4] | 操作类型码 |
| `fun` | 4位 [3:0] | 功能码 |

### 寄存器约定

| 寄存器 | 说明 |
|------|------|
| `r0` | 零寄存器，读出恒为0，写入无效 |
| `r15` | PC寄存器，读出当前指令地址，写入无效 |

---

## 指令列表

### 1. 伪指令

汇编器在预编译阶段支持以下伪指令：

#### .equ - 常量宏定义

说明：编译阶段文本替换

**汇编示例：**
```
.equ uart_base 0x10000000       // uart_base -> 0x10000000
.equ uart_cfg (uart_base + 4)   // uart_cfg -> 0x10000004
.equ simulation                 // simulation defined
```

#### .prog - 输出文件名定义

说明：定义输出文件名，Verilog 输出时也作为 module 名

**汇编示例：**
```
.prog HelloWorld    // HelloWorld.v
```

#### .ifdef/.elsif/.else/.endif - 条件编译

说明：按宏是否已定义进行条件编译

**汇编示例：**
```
.ifdef UART
    mov r3, 0x1000
    mov r3, r3 << 16
.elsif ETH
    mov r3, 0x2000
    mov r3, r3 << 16
.else
    mov r3, 0x3000
    mov r3, r3 << 16
.endif
```

#### .macro/.endm - 代码片段宏定义

说明：定义带参数的代码片段，编译阶段文本替换

**汇编示例：**
```
.macro SetInt32(rd, hi, lo)
    mov rd, hi
    mov rd, rd << 16
    mov rd, rd + lo
.endm
```

#### .include - 文件引用

说明：将引用文件按声明顺序追加到主文件后一起汇编

**汇编示例：**
```
.include "macro.asm"
```

#### .rept/.endr - 重复展开

说明：将内部代码块重复声明多次

**汇编示例：**
```
.rept 10
    mov r8, r8 + 1
.endr
```

### 2. 数据传送指令

#### SETI - 设置立即数 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0000` |
| 操作 | `R[dest] = immediate` |
| 说明 | 将16位立即数符号扩展后存入目标寄存器 |

**汇编示例：**
```
mov r5, 100       // r5 = 100
```

#### SETR - 寄存器移动 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0000` |
| 操作 | `R[dest] = R[src_1]` |
| 说明 | 将源寄存器1的值复制到目标寄存器 |

**汇编示例：**
```
mov r5, r3         // r5 = r3
```

---

### 3. 算术运算指令

#### ADDI - 立即数加法 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0001` |
| 操作 | `R[dest] = R[src_2] + immediate` |
| 说明 | 源寄存器2的值与16位立即数相加 |

**汇编示例：**
```
mov r3, r1 + 10    // r3 = r1 + 10
```

#### ADDR - 寄存器加法 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0001` |
| 操作 | `R[dest] = R[src_2] + R[src_1]` |
| 说明 | 两个源寄存器值相加 |

**汇编示例：**
```
mov r3, r1 + r2     // r3 = r1 + r2
```

#### SUBI - 立即数减法 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0010` |
| 操作 | `R[dest] = R[src_2] - immediate` |
| 说明 | 源寄存器2的值减去16位立即数 |

**汇编示例：**
```
mov r3, r5 - 5     // r3 = r5 - 5
```

#### SUBR - 寄存器减法 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0010` |
| 操作 | `R[dest] = R[src_2] - R[src_1]` |
| 说明 | 源寄存器2的值减去源寄存器1的值 |

**汇编示例：**
```
mov r3, r5 - r2     // r3 = r5 - r2
```

---

### 4. 逻辑运算指令

#### ANDI - 立即数按位与 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0011` |
| 操作 | `R[dest] = R[src_2] & immediate` |

**汇编示例：**
```
mov r4, r7 & 0xFF  // r4 = r7 & 0xFF
```

#### ANDR - 寄存器按位与 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0011` |
| 操作 | `R[dest] = R[src_2] & R[src_1]` |

**汇编示例：**
```
mov r4, r7 & r3     // r4 = r7 & r3
```

#### ORI - 立即数按位或 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0100` |
| 操作 | `R[dest] = R[src_2] \| immediate` |

**汇编示例：**
```
mov r4, r7 | 0xFF   // r4 = r7 | 0xFF
```

#### ORR - 寄存器按位或 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0100` |
| 操作 | `R[dest] = R[src_2] \| R[src_1]` |

**汇编示例：**
```
mov r4, r7 | r3     // r4 = r7 | r3
```

#### XORI - 立即数按位异或 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0101` |
| 操作 | `R[dest] = R[src_2] ^ immediate` |

**汇编示例：**
```
mov r4, r7 ^ 0xFF  // r4 = r7 ^ 0xFF
```

#### XORR - 寄存器按位异或 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0101` |
| 操作 | `R[dest] = R[src_2] ^ R[src_1]` |

**汇编示例：**
```
mov r4, r7 ^ r3     // r4 = r7 ^ r3
```

---

### 5. 移位运算指令

#### SLLI - 立即数逻辑左移 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0110` |
| 操作 | `R[dest] = R[src_2] << immediate` |
| 说明 | 将 src_2 寄存器的值左移 immediate 位，低位补0 |

**汇编示例：**
```
mov r3, r4 << 4     // r3 = r4 << 4
```

#### SLLR - 寄存器逻辑左移 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0110` |
| 操作 | `R[dest] = R[src_2] << R[src_1]` |
| 说明 | 将 src_2 寄存器的值左移 src_1 位 |

**汇编示例：**
```
mov r3, r4 << r1     // r3 = r4 << r1
```

#### SRLI - 立即数逻辑右移 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0111` |
| 操作 | `R[dest] = R[src_2] >> immediate` |
| 说明 | 将 src_2 寄存器的值逻辑右移 immediate 位，高位补0 |

**汇编示例：**
```
mov r3, r4 >> 4     // r3 = r4 >> 4
```

#### SRLR - 寄存器逻辑右移 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0111` |
| 操作 | `R[dest] = R[src_2] >> R[src_1]` |
| 说明 | 将 src_2 寄存器的值逻辑右移 src_1 位 |

**汇编示例：**
```
mov r3, r4 >> r1     // r3 = r4 >> r1
```

#### SRAI - 立即数算术右移 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1000` |
| 操作 | `R[dest] = R[src_2] >>> immediate` |
| 说明 | 将 src_2 寄存器的值算术右移 immediate 位，高位补符号位 |

**汇编示例：**
```
mov r3, r4 >>> 4     // r3 = r4 >>> 4 (有符号右移)
```

#### SRAR - 寄存器算术右移 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1000` |
| 操作 | `R[dest] = R[src_2] >>> R[src_1]` |
| 说明 | 将 src_2 寄存器的值算术右移 src_1 位，高位补符号位 |

**汇编示例：**
```
mov r3, r4 >>> r1     // r3 = r4 >>> r1 (有符号右移)
```

---

### 6. 内存访问指令

#### MWRI - 立即数偏移内存写 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1001` |
| 操作 | `Mem[R[src_2] + immediate] = R[dest]` |
| 说明 | 将 dest 寄存器的值写入 (src_2 + immediate) 地址的内存 |

**汇编示例：**
```
mov [r1 + 4], r5   // Mem[r1 + 4] = r5
```

#### MWRR - 寄存器偏移内存写 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1001` |
| 操作 | `Mem[R[src_2] + R[src_1]] = R[dest]` |
| 说明 | 将 dest 寄存器的值写入 (src_2 + src_1) 地址的内存 |

**汇编示例：**
```
mov [r1 + r2], r5   // Mem[r1 + r2] = r5
```

#### MRDI - 立即数偏移内存读 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1010` |
| 操作 | `R[dest] = Mem[R[src_2] + immediate]` |
| 说明 | 从 (src_2 + immediate) 地址读取数据到 dest 寄存器 |

**汇编示例：**
```
mov r3, [r7 + 8]   // r3 = Mem[r7 + 8]
```

#### MRDR - 寄存器偏移内存读 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1010` |
| 操作 | `R[dest] = Mem[R[src_2] + R[src_1]]` |
| 说明 | 从 (src_2 + src_1) 地址读取数据到 dest 寄存器 |

**汇编示例：**
```
mov r3, [r7 + r2]   // r3 = Mem[r7 + r2]
```

---

### 7. 跳转指令

#### JALI - 基址加立即数跳转并链接 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1011` |
| 操作 | `R[dest] = PC + 1; PC = R[src_2] + immediate` |
| 说明 | 将基址寄存器 `src_2` 与16位立即数相加作为跳转地址，并将返回地址存入目标寄存器；若 `dest=r0` 则不保存链接 |

**汇编示例：**
```
jmp 100, r6        // r6 = PC + 1, PC = r0 + 100
jmp r15 + 2       // 不保存链接，PC = 当前PC + 2
jmp r3 - 4, r6     // r6 = PC + 1, PC = r3 + (-4)
```

#### JALR - 基址加寄存器跳转并链接 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1011` |
| 操作 | `R[dest] = PC + 1; PC = R[src_2] + R[src_1]` |
| 说明 | 将两个源寄存器相加作为跳转地址，并将返回地址存入目标寄存器；若 `dest=r0` 则不保存链接 |

**汇编示例：**
```
jmp r10, r6         // r6 = PC + 1, PC = r0 + r10
jmp r1 + r2, r6     // r6 = PC + 1, PC = r1 + r2
jmp r15 + r3        // 不保存链接，PC = 当前PC + r3
```

---

### 8. 分支指令

**注意：BLT和BGE使用有符号数比较**

#### BEQI - 立即数相等分支 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1100` |
| 操作 | `PC = (R[src_2] == R[dest]) ? immediate : PC + 1` |
| 说明 | 如果 src_2 和 dest 寄存器的值相等，则跳转到 immediate 地址 |

**汇编示例：**
```
brc loop, r5 == r3     // if (r5 == r3) PC = loop else PC = PC + 1
```

#### BEQR - 寄存器相等分支 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1100` |
| 操作 | `PC = (R[src_2] == R[dest]) ? R[src_1] : PC + 1` |
| 说明 | 如果 src_2 和 dest 寄存器的值相等，则跳转到 src_1 寄存器指向的地址 |

**汇编示例：**
```
brc r10, r5 == r3   // if (r5 == r3) PC = r10 else PC = PC + 1
```

#### BNEI - 立即数不等分支 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1101` |
| 操作 | `PC = (R[src_2] != R[dest]) ? immediate : PC + 1` |

**汇编示例：**
```
brc loop, r5 != r3  // if (r5 != r3) PC = loop else PC = PC + 1
```

#### BNER - 寄存器不等分支 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1101` |
| 操作 | `PC = (R[src_2] != R[dest]) ? R[src_1] : PC + 1` |

**汇编示例：**
```
brc r10, r5 != r3   // if (r5 != r3) PC = r10 else PC = PC + 1
```

#### BLTI - 立即数小于分支 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1110` |
| 操作 | `PC = ($signed(R[src_2]) < $signed(R[dest])) ? immediate : PC + 1` |
| 说明 | **有符号比较**：如果 src_2 < dest，则跳转到 immediate 地址 |

**汇编示例：**
```
brc loop, r5 < r3   // if ($signed(r5) < $signed(r3)) PC = loop else PC = PC + 1
```

#### BLTR - 寄存器小于分支 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1110` |
| 操作 | `PC = ($signed(R[src_2]) < $signed(R[dest])) ? R[src_1] : PC + 1` |
| 说明 | **有符号比较**：如果 src_2 < dest，则跳转到 src_1 寄存器指向的地址 |

**汇编示例：**
```
brc r10, r5 < r3    // if ($signed(r5) < $signed(r3)) PC = r10 else PC = PC + 1
```

#### BGEI - 立即数大于等于分支 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1111` |
| 操作 | `PC = ($signed(R[src_2]) >= $signed(R[dest])) ? immediate : PC + 1` |
| 说明 | **有符号比较**：如果 src_2 >= dest，则跳转到 immediate 地址 |

**汇编示例：**
```
brc loop, r5 >= r3  // if ($signed(r5) >= $signed(r3)) PC = loop else PC = PC + 1
```

#### BGER - 寄存器大于等于分支 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1111` |
| 操作 | `PC = ($signed(R[src_2]) >= $signed(R[dest])) ? R[src_1] : PC + 1` |
| 说明 | **有符号比较**：如果 src_2 >= dest，则跳转到 src_1 寄存器指向的地址 |

**汇编示例：**
```
brc r10, r5 >= r3   // if ($signed(r5) >= $signed(r3)) PC = r10 else PC = PC + 1
```

---

## 相关文档

- [CPU设计说明](README.md) - 详细的CPU设计文档
