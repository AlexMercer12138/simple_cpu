# SASS Assembly for VSCode

[![Version](https://img.shields.io/badge/Version-2.0.0-blue.svg)](https://github.com/simple-cpu/sass-vscode)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Simple CPU 的 VSCode 扩展，集成汇编器、语法高亮、代码片段，支持一键编译输出 Verilog、COE、MIF、HEX、BIN 等多种格式。

## 功能特性

- ▶️ **一键编译** - 打开 `.asm` 文件，点击右上角播放按钮直接编译
- 🎨 **语法高亮** - MOV/JMP/BRC 指令、寄存器、立即数、标签、注释
- ✂️ **代码片段** - 输入 `movi`、`movr`、`jmpl`、`brceq` 等快速生成代码
- 📝 **注释支持** - `//` 格式注释，支持 `Ctrl+/` 快捷键
- 🔤 **括号匹配** - 内存访问括号 `[]` 自动匹配
- 🔄 **多种输出格式** - Verilog、COE、MIF、Intel HEX、Binary
- 🐛 **调试模式** - 生成标签表和替换后的汇编代码

## 安装

### 从 VSIX 安装

```bash
code --install-extension sass-asm-syntax-2.0.0.vsix
```

### 从市场安装（待发布）

在 VSCode 扩展面板搜索 `SASS Assembly` 并安装。

## 使用方法

### 编译汇编文件

1. 打开任意 `.asm` 文件
2. 点击编辑器右上角的 ▶ **Compile** 按钮
3. 编译结果自动输出到同目录（或配置的路径）

### 切换编译模式

点击 ▶ 右侧的 ▼ 下拉按钮，选择：

| 模式 | 说明 |
|------|------|
| 正常模式 | 编译并输出文件（默认） |
| 打印模式 | 编译结果输出到输出面板，不保存文件 |
| 调试模式 | 编译并额外生成标签表和替换后的汇编代码 |

### 配置输出格式

在 VSCode 设置中搜索 `SASS Assembler`：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `sass-asm.outputFormat` | 输出格式：verilog / coe / mif / hex / bin | `verilog` |
| `sass-asm.outputPath` | 自定义输出目录（空则同源文件目录） | `""` |

### 支持的指令语法

#### MOV 指令

```asm
// 加载立即数 (I-Type)
MOV Rd, #imm              // Rd = imm

// 寄存器复制 (R-Type)
MOV Rd, Rs                // Rd = Rs
```

#### ALU 运算指令

支持 I-Type（立即数）和 R-Type（寄存器）两种形式：

```asm
// I-Type: Rs op #imm
MOV Rd, Rs + #imm         // Rd = Rs + imm
MOV Rd, Rs - #imm         // Rd = Rs - imm
MOV Rd, Rs & #imm         // Rd = Rs & imm
MOV Rd, Rs | #imm         // Rd = Rs | imm
MOV Rd, Rs ^ #imm         // Rd = Rs ^ imm
MOV Rd, Rs << #imm        // Rd = Rs << imm (逻辑左移)
MOV Rd, Rs >> #imm        // Rd = Rs >> imm (逻辑右移)
MOV Rd, Rs >>> #imm       // Rd = Rs >>> imm (算术右移)

// R-Type: Rs2 op Rs1
MOV Rd, Rs2 + Rs1         // Rd = Rs2 + Rs1
MOV Rd, Rs2 - Rs1         // Rd = Rs2 - Rs1
MOV Rd, Rs2 & Rs1         // Rd = Rs2 & Rs1
MOV Rd, Rs2 | Rs1         // Rd = Rs2 | Rs1
MOV Rd, Rs2 ^ Rs1         // Rd = Rs2 ^ Rs1
MOV Rd, Rs2 << Rs1        // Rd = Rs2 << Rs1 (逻辑左移)
MOV Rd, Rs2 >> Rs1        // Rd = Rs2 >> Rs1 (逻辑右移)
MOV Rd, Rs2 >>> Rs1       // Rd = Rs2 >>> Rs1 (算术右移)
```

#### 内存访问指令

```asm
// I-Type: [Rs + #imm]
MOV Rd, [Rs + #imm]       // Rd = Mem[Rs + imm]
MOV [Rs + #imm], Rd       // Mem[Rs + imm] = Rd

// R-Type: [Rs1 + Rs2]
MOV Rd, [Rs1 + Rs2]       // Rd = Mem[Rs1 + Rs2]
MOV [Rs1 + Rs2], Rd       // Mem[Rs1 + Rs2] = Rd

// 偏移为0的简写形式
MOV Rd, [Rs]              // Rd = Mem[Rs]
MOV [Rs], Rd              // Mem[Rs] = Rd
```

#### JMP 指令

```asm
JMP #imm, Rd              // Rd = PC+1, PC = imm
JMP label, Rd             // Rd = PC+1, PC = label
JMP Rs, Rd                // Rd = PC+1, PC = Rs
```

#### BRC 指令（分支）

```asm
BRC #imm, Rd2 == Rd1      // if (Rd2 == Rd1) PC = #imm
BRC #imm, Rd2 != Rd1      // if (Rd2 != Rd1) PC = #imm
BRC #imm, Rd2 <  Rd1      // if (Rd2 <  Rd1) PC = #imm
BRC #imm, Rd2 >= Rd1      // if (Rd2 >= Rd1) PC = #imm

BRC label, Rd2 == Rd1     // if (Rd2 == Rd1) PC = label
BRC label, Rd2 != Rd1     // if (Rd2 != Rd1) PC = label

BRC Rs, Rd2 == Rd1        // if (Rd2 == Rd1) PC = Rs
BRC Rs, Rd2 != Rd1        // if (Rd2 != Rd1) PC = Rs
BRC Rs, Rd2 <  Rd1        // if (Rd2 <  Rd1) PC = Rs
BRC Rs, Rd2 >= Rd1        // if (Rd2 >= Rd1) PC = Rs
```

### 标签支持

```asm
start:
    MOV R0, #0
    MOV R1, #10

loop:
    MOV R0, R0 + R1
    JMP loop, R2
```

### 有符号立即数

立即数为 **16位有符号数**，范围 `-32768 ~ 32767`。

```asm
MOV R1, #100              // R1 = 100
MOV R2, #-1               // R2 = 0xFFFF
MOV R3, #-32768           // R3 = 0x8000
MOV R4, #0xFFFF           // R4 = 65535
```

### 注释

只支持 `//` 格式的注释：

```asm
// 这是注释
MOV R0, #1          // 这也是注释
```

## 输出格式说明

### Verilog 格式

生成完整的 Verilog ROM 模块，可直接例化使用：

```verilog
module prog_rom(
    input wire [31:0] prog_addr,
    output reg [31:0] prog_data
);
always @(*) begin
    case (prog_addr)
        0 : prog_data = 32'h00000000;
        ...
        default: prog_data = 0;
    endcase
end
endmodule
```

### COE 格式（Xilinx）

```
memory_initialization_radix=16;
memory_initialization_vector=
00000000,
00001001,
...,
FFFFFFFF;
```

### MIF 格式（Altera/Intel）

```
WIDTH=32;
DEPTH=256;
ADDRESS_RADIX=HEX;
DATA_RADIX=HEX;
CONTENT BEGIN
    0000 : 00000000;
    ...
END;
```

### HEX 格式（Intel HEX）

```
:0400000000000010EC
:0400040000010110E6
:00000001FF
```

## 技术规格

| 特性 | 参数 |
|------|------|
| 架构 | 32位 RISC |
| 寄存器数量 | 16个有符号通用寄存器 |
| 指令宽度 | 32位 |
| 指令数量 | 32条（16种功能 x 2种寻址方式） |
| 数据通路 | 单周期执行 |
| 程序存储 | 256条指令（8位地址） |
| 有符号数支持 | 原生支持 |

## 许可证

MIT License
