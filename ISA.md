# Simple CPU 指令集参考

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
| `immediate` | 16位 [31:16] | 立即数/地址偏移 |
| `reg_src_1` | 4位 [19:16] | 源寄存器1索引 |
| `reg_src_2` | 4位 [15:12] | 源寄存器2索引 |
| `reg_dest` | 4位 [11:8] | 目标寄存器索引 |
| `opcode` | 4位 [7:4] | 操作类型码 |
| `funct` | 4位 [3:0] | 功能码 |

---

## 指令分类

| 类别 | 指令数 | 说明 |
|------|--------|------|
| 数据传送 | 2条 | 立即数加载、寄存器移动 |
| 算术运算 | 4条 | 立即数/寄存器加法、减法 |
| 逻辑运算 | 6条 | 立即数/寄存器与、或、异或 |
| 移位运算 | 6条 | 立即数/寄存器逻辑左移、逻辑右移、算术右移 |
| 内存访问 | 4条 | 立即数偏移/寄存器偏移的内存读写 |
| 跳转指令 | 2条 | 立即数地址/寄存器地址的跳转并链接 |
| 分支指令 | 8条 | 立即数地址/寄存器地址的各种条件分支 |

---

## 操作类型码 (Opcode)

| Opcode | 类型 | 说明 |
|--------|------|------|
| `0001` | I-Type | 立即数操作 - immediate字段作为操作数 |
| `0010` | R-Type | 寄存器操作 - reg_src_1指向的寄存器作为操作数 |

---

## 功能码 (Funct)

| Funct | 助记符 | 描述 |
|-------|--------|------|
| `0000` | `SET` | 设置/移动 |
| `0001` | `ADD` | 加法 |
| `0010` | `SUB` | 减法 |
| `0011` | `AND` | 按位与 |
| `0100` | `OR`  | 按位或 |
| `0101` | `XOR` | 按位异或 |
| `0110` | `SLL` | 逻辑左移 |
| `0111` | `SRL` | 逻辑右移 |
| `1000` | `SRA` | 算术右移 |
| `1001` | `MWR` | 内存写 |
| `1010` | `MRD` | 内存读 |
| `1011` | `JAL` | 跳转并链接 |
| `1100` | `BEQ` | 相等分支 |
| `1101` | `BNE` | 不等分支 |
| `1110` | `BLT` | 小于分支（有符号比较） |
| `1111` | `BGE` | 大于等于分支（有符号比较） |

---

## 指令列表

### 1. 数据传送指令

#### SETI - 设置立即数 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0000` |
| 操作 | `R[dest] = immediate` |
| 说明 | 将16位立即数符号扩展后存入目标寄存器 |

**汇编示例：**
```
MOV R5, #100       // R5 = 100
```

#### SETR - 寄存器移动 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0000` |
| 操作 | `R[dest] = R[src_1]` |
| 说明 | 将源寄存器1的值复制到目标寄存器 |

**汇编示例：**
```
MOV R5, R3         // R5 = R3
```

---

### 2. 算术运算指令

#### ADDI - 立即数加法 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0001` |
| 操作 | `R[dest] = R[src_2] + immediate` |
| 说明 | 源寄存器2的值与16位立即数相加 |

**汇编示例：**
```
MOV R3, R1, #10    // R3 = R1 + 10
```

#### ADDR - 寄存器加法 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0001` |
| 操作 | `R[dest] = R[src_2] + R[src_1]` |
| 说明 | 两个源寄存器值相加 |

**汇编示例：**
```
MOV R3, R1, R2     // R3 = R1 + R2
```

#### SUBI - 立即数减法 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0010` |
| 操作 | `R[dest] = R[src_2] - immediate` |
| 说明 | 源寄存器2的值减去16位立即数 |

**汇编示例：**
```
MOV R3, R5, #5     // R3 = R5 - 5
```

#### SUBR - 寄存器减法 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0010` |
| 操作 | `R[dest] = R[src_2] - R[src_1]` |
| 说明 | 源寄存器2的值减去源寄存器1的值 |

**汇编示例：**
```
MOV R3, R5, R2     // R3 = R5 - R2
```

---

### 3. 逻辑运算指令

#### ANDI - 立即数按位与 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0011` |
| 操作 | `R[dest] = R[src_2] & immediate` |

**汇编示例：**
```
MOV R4, R7, #0xFF  // R4 = R7 & 0xFF
```

#### ANDR - 寄存器按位与 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0011` |
| 操作 | `R[dest] = R[src_2] & R[src_1]` |

**汇编示例：**
```
MOV R4, R7, R3     // R4 = R7 & R3
```

#### ORI - 立即数按位或 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0100` |
| 操作 | `R[dest] = R[src_2] \| immediate` |

**汇编示例：**
```
MOV R4, R7, #0xFF   // R4 = R7 | 0xFF
```

#### ORR - 寄存器按位或 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0100` |
| 操作 | `R[dest] = R[src_2] \| R[src_1]` |

**汇编示例：**
```
MOV R4, R7, R3      // R4 = R7 | R3
```

#### XORI - 立即数按位异或 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0101` |
| 操作 | `R[dest] = R[src_2] ^ immediate` |

**汇编示例：**
```
MOV R4, R7, #0xFF  // R4 = R7 ^ 0xFF
```

#### XORR - 寄存器按位异或 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0101` |
| 操作 | `R[dest] = R[src_2] ^ R[src_1]` |

**汇编示例：**
```
MOV R4, R7, R3     // R4 = R7 ^ R3
```

---

### 4. 移位运算指令

#### SLLI - 立即数逻辑左移 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0110` |
| 操作 | `R[dest] = R[src_2] << immediate` |
| 说明 | 将 src_2 寄存器的值左移 immediate 位，低位补0 |

**汇编示例：**
```
MOV R3, R4, #4     // R3 = R4 << 4
```

#### SLLR - 寄存器逻辑左移 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0110` |
| 操作 | `R[dest] = R[src_2] << R[src_1]` |
| 说明 | 将 src_2 寄存器的值左移 src_1 位 |

**汇编示例：**
```
MOV R3, R4, R1     // R3 = R4 << R1
```

#### SRLI - 立即数逻辑右移 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=0111` |
| 操作 | `R[dest] = R[src_2] >> immediate` |
| 说明 | 将 src_2 寄存器的值逻辑右移 immediate 位，高位补0 |

**汇编示例：**
```
MOV R3, R4, #4     // R3 = R4 >> 4
```

#### SRLR - 寄存器逻辑右移 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=0111` |
| 操作 | `R[dest] = R[src_2] >> R[src_1]` |
| 说明 | 将 src_2 寄存器的值逻辑右移 src_1 位 |

**汇编示例：**
```
MOV R3, R4, R1     // R3 = R4 >> R1
```

#### SRAI - 立即数算术右移 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1000` |
| 操作 | `R[dest] = R[src_2] >>> immediate` |
| 说明 | 将 src_2 寄存器的值算术右移 immediate 位，高位补符号位 |

**汇编示例：**
```
MOV R3, R4, #4     // R3 = R4 >>> 4 (有符号右移)
```

#### SRAR - 寄存器算术右移 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1000` |
| 操作 | `R[dest] = R[src_2] >>> R[src_1]` |
| 说明 | 将 src_2 寄存器的值算术右移 src_1 位，高位补符号位 |

**汇编示例：**
```
MOV R3, R4, R1     // R3 = R4 >>> R1
```

---

### 5. 内存访问指令

#### MWRI - 立即数偏移内存写 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1001` |
| 操作 | `Mem[R[src_2] + immediate] = R[dest]` |
| 说明 | 将 dest 寄存器的值写入 (src_2 + immediate) 地址的内存 |

**汇编示例：**
```
MOV [R1 + #4], R5   // Mem[R1 + 4] = R5
```

#### MWRR - 寄存器偏移内存写 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1001` |
| 操作 | `Mem[R[src_2] + R[src_1]] = R[dest]` |
| 说明 | 将 dest 寄存器的值写入 (src_2 + src_1) 地址的内存 |

**汇编示例：**
```
MOV [R1 + R2], R5   // Mem[R1 + R2] = R5
```

#### MRDI - 立即数偏移内存读 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1010` |
| 操作 | `R[dest] = Mem[R[src_2] + immediate]` |
| 说明 | 从 (src_2 + immediate) 地址读取数据到 dest 寄存器 |

**汇编示例：**
```
MOV R3, [R7 + #8]   // R3 = Mem[R7 + 8]
```

#### MRDR - 寄存器偏移内存读 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1010` |
| 操作 | `R[dest] = Mem[R[src_2] + R[src_1]]` |
| 说明 | 从 (src_2 + src_1) 地址读取数据到 dest 寄存器 |

**汇编示例：**
```
MOV R3, [R7 + R2]   // R3 = Mem[R7 + R2]
```

---

### 6. 跳转指令

#### JALI - 立即数跳转并链接 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1011` |
| 操作 | `R[dest] = PC + 1; PC = immediate` |
| 说明 | 跳转到立即数指定的地址，并将返回地址存入目标寄存器 |

**汇编示例：**
```
JMP #100, R6    // R6 = PC + 1, PC = 100
```

#### JALR - 寄存器跳转并链接 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1011` |
| 操作 | `R[dest] = PC + 1; PC = R[src_1]` |
| 说明 | 跳转到 src_1 寄存器指定的地址，并将返回地址存入目标寄存器 |

**汇编示例：**
```
JMP R10, R6     // R6 = PC + 1, PC = R10
```

---

### 7. 分支指令

**注意：BLT和BGE使用有符号数比较**

#### BEQI - 立即数相等分支 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1100` |
| 操作 | `PC = (R[src_2] == R[dest]) ? immediate : PC + 1` |
| 说明 | 如果 src_2 和 dest 寄存器的值相等，则跳转到 immediate 地址 |

**汇编示例：**
```
BRC loop, R5 == R3     // if (R5 == R3) PC = loop else PC = PC + 1
```

#### BEQR - 寄存器相等分支 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1100` |
| 操作 | `PC = (R[src_2] == R[dest]) ? R[src_1] : PC + 1` |
| 说明 | 如果 src_2 和 dest 寄存器的值相等，则跳转到 src_1 寄存器指向的地址 |

**汇编示例：**
```
BRC R10, R5 == R3   // if (R5 == R3) PC = R10 else PC = PC + 1
```

#### BNEI - 立即数不等分支 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1101` |
| 操作 | `PC = (R[src_2] != R[dest]) ? immediate : PC + 1` |

**汇编示例：**
```
BRC loop, R5 != R3  // if (R5 != R3) PC = loop else PC = PC + 1
```

#### BNER - 寄存器不等分支 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1101` |
| 操作 | `PC = (R[src_2] != R[dest]) ? R[src_1] : PC + 1` |

**汇编示例：**
```
BRC R10, R5 != R3   // if (R5 != R3) PC = R10 else PC = PC + 1
```

#### BLTI - 立即数小于分支 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1110` |
| 操作 | `PC = ($signed(R[src_2]) < $signed(R[dest])) ? immediate : PC + 1` |
| 说明 | **有符号比较**：如果 src_2 < dest，则跳转到 immediate 地址 |

**汇编示例：**
```
BRC loop, R5 < R3   // if ($signed(R5) < $signed(R3)) PC = loop else PC = PC + 1
```

#### BLTR - 寄存器小于分支 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1110` |
| 操作 | `PC = ($signed(R[src_2]) < $signed(R[dest])) ? R[src_1] : PC + 1` |
| 说明 | **有符号比较**：如果 src_2 < dest，则跳转到 src_1 寄存器指向的地址 |

**汇编示例：**
```
BRC R10, R5 < R3    // if ($signed(R5) < $signed(R3)) PC = R10 else PC = PC + 1
```

#### BGEI - 立即数大于等于分支 (I-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0001, funct=1111` |
| 操作 | `PC = ($signed(R[src_2]) >= $signed(R[dest])) ? immediate : PC + 1` |
| 说明 | **有符号比较**：如果 src_2 >= dest，则跳转到 immediate 地址 |

**汇编示例：**
```
BRC loop, R5 >= R3  // if ($signed(R5) >= $signed(R3)) PC = loop else PC = PC + 1
```

#### BGER - 寄存器大于等于分支 (R-Type)

| 字段 | 值 |
|------|-----|
| 操作码 | `opcode=0010, funct=1111` |
| 操作 | `PC = ($signed(R[src_2]) >= $signed(R[dest])) ? R[src_1] : PC + 1` |
| 说明 | **有符号比较**：如果 src_2 >= dest，则跳转到 src_1 寄存器指向的地址 |

**汇编示例：**
```
BRC R10, R5 >= R3   // if ($signed(R5) >= $signed(R3)) PC = R10 else PC = PC + 1
```

---

## 指令编码速查表

### I-Type 指令 (Opcode = 0001)

| Funct | 助记符 | 功能描述 |
|-------|--------|----------|
| `0000` | SETI | `R[dest] = immediate` |
| `0001` | ADDI | `R[dest] = R[src_2] + immediate` |
| `0010` | SUBI | `R[dest] = R[src_2] - immediate` |
| `0011` | ANDI | `R[dest] = R[src_2] & immediate` |
| `0100` | ORI | `R[dest] = R[src_2] \| immediate` |
| `0101` | XORI | `R[dest] = R[src_2] ^ immediate` |
| `0110` | SLLI | `R[dest] = R[src_2] << immediate` |
| `0111` | SRLI | `R[dest] = R[src_2] >> immediate` |
| `1000` | SRAI | `R[dest] = R[src_2] >>> immediate` |
| `1001` | MWRI | `Mem[R[src_2] + immediate] = R[dest]` |
| `1010` | MRDI | `R[dest] = Mem[R[src_2] + immediate]` |
| `1011` | JALI | `R[dest] = PC+1; PC = immediate` |
| `1100` | BEQI | `PC = (R[src_2]==R[dest]) ? immediate : PC+1` |
| `1101` | BNEI | `PC = (R[src_2]!=R[dest]) ? immediate : PC+1` |
| `1110` | BLTI | `PC = ($signed(R[src_2])<$signed(R[dest])) ? immediate : PC+1` |
| `1111` | BGEI | `PC = ($signed(R[src_2])>=$signed(R[dest])) ? immediate : PC+1` |

### R-Type 指令 (Opcode = 0010)

| Funct | 助记符 | 功能描述 |
|-------|--------|----------|
| `0000` | SETR | `R[dest] = R[src_1]` |
| `0001` | ADDR | `R[dest] = R[src_2] + R[src_1]` |
| `0010` | SUBR | `R[dest] = R[src_2] - R[src_1]` |
| `0011` | ANDR | `R[dest] = R[src_2] & R[src_1]` |
| `0100` | ORR | `R[dest] = R[src_2] \| R[src_1]` |
| `0101` | XORR | `R[dest] = R[src_2] ^ R[src_1]` |
| `0110` | SLLR | `R[dest] = R[src_2] << R[src_1]` |
| `0111` | SRLR | `R[dest] = R[src_2] >> R[src_1]` |
| `1000` | SRAR | `R[dest] = R[src_2] >>> R[src_1]` |
| `1001` | MWRR | `Mem[R[src_2] + R[src_1]] = R[dest]` |
| `1010` | MRDR | `R[dest] = Mem[R[src_2] + R[src_1]]` |
| `1011` | JALR | `R[dest] = PC+1; PC = R[src_1]` |
| `1100` | BEQR | `PC = (R[src_2]==R[dest]) ? R[src_1] : PC+1` |
| `1101` | BNER | `PC = (R[src_2]!=R[dest]) ? R[src_1] : PC+1` |
| `1110` | BLTR | `PC = ($signed(R[src_2])<$signed(R[dest])) ? R[src_1] : PC+1` |
| `1111` | BGER | `PC = ($signed(R[src_2])>=$signed(R[dest])) ? R[src_1] : PC+1` |

---

## 有符号数支持说明

### 寄存器声明

所有寄存器被声明为有符号数类型：
```verilog
reg signed [31:0] regi_int [0:15];
```

### 有符号比较

BLT 和 BGE 指令使用 `$signed()` 系统函数进行有符号比较：

```verilog
// BLT 指令
prog_next <= prog_exec ? ($signed(regi_int[reg_src_2]) < $signed(regi_int[reg_dest]) ? immediate : prog_addr + 1) : prog_next;

// BGE 指令
prog_next <= prog_exec ? ($signed(regi_int[reg_src_2]) >= $signed(regi_int[reg_dest]) ? immediate : prog_addr + 1) : prog_next;
```

### 算术右移 (SRA)

SRA 指令使用 Verilog 的算术右移运算符 `>>>`，自动进行符号位扩展：

```verilog
// SRAI (I-Type)
regi_int[reg_dest] <= prog_exec ? regi_int[reg_src_2] >>> immediate : regi_int[reg_dest];

// SRAR (R-Type)
regi_int[reg_dest] <= prog_exec ? regi_int[reg_src_2] >>> regi_int[reg_src_1] : regi_int[reg_dest];
```

---

## 相关文档

- [CPU设计说明](README.md) - 详细的CPU设计文档
