# CPU 功能测试

本目录的回归测试只验证 MERC32 CPU。GPIO、UART、I2C、Timer、INTC、
RAM 等独立 IP 的验证在 `ip-repo` 维护。仿真直接连接 CPU 核心和台架内的
Local Bus 存储器模型，不依赖外设 IP。

| 源码 | CPU 执行覆盖 |
| --- | --- |
| `cpu_arithmetic_test.c` | 有符号/无符号运算、乘除余数、比较、移位、位运算、32 位边界 |
| `cpu_memory_test.c` | 全局初始化与 BSS、字节/半字访存、符号扩展、写使能、数组、结构体、指针、内存/字符串运行库 |
| `cpu_control_test.c` | 循环、分支、短路、switch/goto、递归、8 参数调用、函数指针、结构体传参/返回、局部静态变量 |
| `cpu_interrupt_test.c` | 真实 C 中断处理、持续高电平二次进入、向量、返回 PC、r4–r14 上下文及主程序恢复 |

使用当前 C17 工具链直接编译上述源文件；测试脚本不替换源代码、不伪造中断
或外设返回值。汇编、ROM 和仿真产物在临时目录生成，运行后清理，不提交旧产物。
原 `tinyc_feature_test` 和 `full_test` 的职责由这些用例以及
`rtl/sim/merc32_core_tb.v` 中的指令级检查接替。

在 `merc32-vsce` 目录执行（需要 Node.js、npm 依赖、Icarus Verilog 的
`iverilog` 和 `vvp` 在 PATH 中）：

```sh
npm run test:cpu
```

该入口先构建工具链并准备运行库资源，运行 CPU 核心、顶层 JTAG、关闭调试的顶层、调试模块、
核心内部乘法器/除法器及非法地址宽度检查，再运行全部 C 示例，分别覆盖
`none` 和 `basic` 优化。CPU 总线验证使用台架应答模型；独立协议桥不属于此套件。

也可分别执行：

```sh
npm run test:hardware
npm run test:c:rtl
node scripts/test-c-rtl.js --basic
node scripts/test-c-rtl.js --irq-only
```

`test:c:rtl` 另外保留现有 C 前端、链接和运行路径复核。
`--irq-only` 默认仍运行两档优化；可与 `--basic` 一起使用。

`cpu_test.h` 约定 DLB RAM `0x080003c0` 为状态、`0x080003c4` 为失败编号。
成功写入 `0x600d`，失败写入 `0x0bad`，失败编号为各源码中的 `CHECK` 编号。
这些地址是台架邮箱，不是 IP 寄存器；示例全局对象应保持在邮箱地址以下。
此套件用 `+POISON_RAM` 将 RAM 初值设为非零，确保 BSS 清零由真实启动代码完成。
普通用例还必须返回到正式启动代码的 halt 点，并恢复栈顶、返回 0；中断用例
同时检查中断上下文和 C 主程序的最终返回。超时、失败标记或缺失成功标记均失败。

`nor_flash_bootloader.c` 是 SoC 启动参考程序，保留给固件开发使用；
它不属于 CPU 功能回归。其构建/镜像检查仍由 `test:bootloader` 单独运行。
