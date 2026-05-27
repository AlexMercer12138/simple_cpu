# MERC32

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Verilog](https://img.shields.io/badge/Language-Verilog-blue.svg)](https://en.wikipedia.org/wiki/Verilog)

一个轻量级32位RISC CPU核心，采用Verilog HDL实现，面向嵌入式系统和SoC应用。

<p align="center">
  <img src="https://img.shields.io/badge/Architecture-32bit%20RISC-green.svg" alt="Architecture">
  <img src="https://img.shields.io/badge/Registers-16-green.svg" alt="Registers">
  <img src="https://img.shields.io/badge/Instructions-30-green.svg" alt="Instructions">
  <img src="https://img.shields.io/badge/Bus-AXI4--Lite-orange.svg" alt="Bus">
</p>

---

## ✨ 特性

- 🚀 **单周期执行** - 大多数指令在一个指令周期完成
- 📦 **资源占用少** - 适合FPGA实现，逻辑资源消耗低
- 🔌 **AXI4-Lite接口** - 标准总线接口，便于集成到ARM/SoC系统
- 📝 **灵活指令集** - 16种功能 × 2种寻址方式 = 32条指令
- 🔄 **三级流水线** - 取指、执行和跳转阶段串行处理
- 🔢 **有符号数支持** - 原生支持有符号数运算和比较
- 🎨 **VSCode 汇编器扩展** - 集成汇编、语法高亮、代码片段、编译按钮和多格式输出

---

## 🚀 快速开始

### 文件结构

```
CPU/
├── rtl/                          # RTL源代码
│   ├── core.v                    # CPU核心代码 - 32位RISC处理器实现
│   ├── MERC32_top.v              # 顶层封装 - 多种总线接口支持
│   ├── s_axi_lite.v              # AXI4-Lite从机接口模块 - 用于外设寄存器访问
│   ├── hello_world.v             # Hello World程序存储器初始化模块
│   ├── inst_test.v               # 指令测试程序存储器初始化模块
│   └── core_tb.v                # CPU测试平台 - 带指令追踪功能
├── sass-vscode/                  # VSCode 汇编器扩展
│   ├── src/                      # TypeScript 源码
│   │   ├── assembler.ts          # 内置汇编器实现
│   │   └── extension.ts          # VSCode 扩展入口
│   ├── syntaxes/                 # 语法高亮定义
│   ├── snippets/                 # 代码片段
│   ├── language-configuration/   # 语言配置
│   ├── package.json              # 扩展配置
│   ├── tsconfig.json             # TypeScript 编译配置
│   └── README.md                 # 扩展市场页说明
├── example/                      # 示例汇编程序
│   ├── hello_world.asm           # Hello World滑动窗口演示程序
│   └── inst_test.asm             # 全指令集测试程序
├── ISA.md                        # 指令集参考文档
├── LICENSE                       # MIT许可证
├── .gitignore                    # Git忽略规则
└── README.md                     # 项目介绍
```

### 端口说明

| 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|
| `clk` | Input | 1 | 系统时钟 |
| `rst_n` | Input | 1 | 低电平有效复位 |
| `prog_addr` | Output | 16 | 程序地址（65536条指令） |
| `prog_data` | Input | 32 | 程序数据（指令） |

**AXI4-Lite主接口**

| 通道 | 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|------|
| 写地址 | `m_axi_awvalid/awready/awaddr` | master | 1/1/32 | 写地址通道 |
| 写数据 | `m_axi_wvalid/wready/wdata/wstrb` | master | 1/1/32/4 | 写数据通道 |
| 写响应 | `m_axi_bvalid/bready/bresp` | master | 1/1/2 | 写响应通道 |
| 读地址 | `m_axi_arvalid/arready/araddr` | master | 1/1/32 | 读地址通道 |
| 读数据 | `m_axi_rvalid/rready/rresp/rdata` | master | 1/1/2/32 | 读数据通道 |

---

## 🧩 指令集

### 指令格式

所有指令均为 **32位定长** 格式，采用分层编码：

```
31                 16  15  12  11   8  7    4  3    0
├─────────────────────┼───────┼───────┼───────┼───────┤
│   immediate/src_1   │ src_2 │ dest  │ opcode│ funct │
│       [15:0]        │ [3:0] │ [3:0] │ [3:0] │ [3:0] │
└─────────────────────┴───────┴───────┴───────┴───────┘
```

| 字段 | 位宽 | 描述 |
|------|------|------|
| `immediate` | 16位 [31:16] | 立即数/地址偏移 |
| `reg_src_1` | 4位 [19:16] | 源寄存器1索引 |
| `reg_src_2` | 4位 [15:12] | 源寄存器2索引 |
| `reg_dest` | 4位 [11:8] | 目标寄存器索引 |
| `opcode` | 4位 [7:4] | 操作类型码 |
| `funct` | 4位 [3:0] | 功能码 |

### 操作类型码 (Opcode)

| Opcode | 类型 | 说明 |
|--------|------|------|
| `0001` | I-Type | 立即数操作 - 使用16位立即数作为操作数 |
| `0010` | R-Type | 寄存器操作 - 使用寄存器值作为操作数 |

### 功能码 (Funct)

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

## 🛠️ VSCode 汇编器扩展

项目现在使用 `sass-vscode` 作为唯一汇编器入口，汇编逻辑已集成在 VSCode 扩展中，无需额外解释器环境。扩展会在打开 `.asm` 文件时提供语法支持和右上角编译按钮。

### 扩展功能

- **内置 TypeScript 汇编器** - 扩展自行完成 `.asm` 到机器码/初始化文件的转换
- **一键编译按钮** - 打开 `.asm` 文件后，编辑器右上角显示编译按钮
- **编译模式切换** - 支持正常模式、打印模式、调试模式
- **输出格式配置** - 支持 Verilog、COE、MIF、Intel HEX、Binary
- **输出路径配置** - 可输出到源文件目录或用户指定目录
- **语法高亮与片段** - 支持 MOV/JMP/BRC、寄存器、立即数、标签、注释等高亮和代码片段

### 安装与开发

```bash
cd sass-vscode
npm install
npx tsc
```

本地开发调试可在 VSCode 中打开 `sass-vscode` 目录，并以扩展开发模式启动。

如需生成 VSIX 安装包：

```bash
cd sass-vscode
vsce package
```

安装 VSIX：

```bash
code --install-extension merc32-asm-2.0.0.vsix
```

### 使用方式

1. 在 VSCode 中打开 `.asm` 文件
2. 点击编辑器右上角的 ▶ `Compile` 按钮
3. 默认生成同名 `.v` 文件到源文件所在目录
4. 点击旁边的下拉按钮可切换打印模式或调试模式

### 扩展设置

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| `merc32-asm.outputFormat` | `verilog` | 输出格式，可选 `verilog`、`coe`、`mif`、`hex`、`bin` |
| `merc32-asm.outputPath` | 空 | 自定义输出目录；为空时输出到 `.asm` 同目录 |

### 汇编示例

```asm
// 计算 1+2+3+4 = 10
start:
    MOV R0, 0
    MOV R1, 1
    MOV R2, 2
    MOV R3, R1 + R2      // R3 = 3
    MOV [R0], R3         // Mem[0] = R3
loop:
    JMP loop, R4         // 无限循环
```

### 支持的输出格式

| 格式 | 扩展名 | 说明 |
|------|--------|------|
| Verilog | `.v` | 完整的ROM模块 |
| COE | `.coe` | Xilinx FPGA 内存初始化 |
| MIF | `.mif` | Altera/Intel FPGA 内存初始化 |
| HEX | `.hex` | Intel HEX文件 |
| BIN | `.bin` | 二进制文件 |

详细扩展说明见 [sass-vscode/README.md](sass-vscode/README.md)。

---

## 🏗️ 架构

### 微架构

```
    取指阶段            执行阶段             跳转阶段
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  prog_load  │ --> │  prog_exec  │ --> │  prog_step  │
└─────────────┘     └─────────────┘     └─────────────┘
```

### 寄存器文件

- **16个32位有符号寄存器** (`regi_int[0:15]`)
- 复位后，16个寄存器初始化为值 `0`

#### 寄存器使用约定

| 寄存器 | 用途 | 说明 |
|--------|------|------|
| `R0` | 零寄存器 | 固定为0，**不可写入** |
| `R1-R15` | 通用寄存器 | 可自由使用，包括作为JMP链接寄存器 |

---

## 📊 技术规格

| 特性 | 参数 |
|------|------|
| 架构 | 32位 RISC |
| 寄存器数量 | 16个有符号通用寄存器 |
| 指令宽度 | 32位 |
| 指令数量 | 32条（16种功能 × 2种寻址方式） |
| 数据通路 | 单周期执行 |
| 内存接口 | AXI4-Lite |
| 程序存储 | 65536条指令（16位地址） |
| 时间刻度 | 1ns / 1ps |
| 有符号数支持 | 原生支持 |

---

## ⚠️ 已知限制

- 程序存储有限 - 16位地址仅支持65536条指令
- 无硬件乘法/除法 - 需软件实现复杂运算
- 无中断支持 - 需要外部中断控制器
- 无调试接口 - 需要时序仿真验证程序正确性

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 许可证。

---

## 👤 作者

- **Mercer**
- WeChat: zxw895674551
- Email: alexmercer@outlook.com

---

## 📚 相关文档

- [指令集参考](ISA.md) - 完整的指令集说明
- [VSCode 汇编器扩展](sass-vscode/README.md) - 扩展安装、使用和市场页说明

---

<p align="center">
  Made with ❤️ for FPGA enthusiasts
</p>
