# Tasks

- [x] Task 1: 确认参考风格与模块边界
  - [x] SubTask 1.1: 对齐 `rtl/uart/apb_uart.v` 的 APB 握手、寄存器译码、软复位、中断输出和文件头格式。
  - [x] SubTask 1.2: 对齐 `rtl/uart/uart_top.v` 的顶层端口风格、FIFO 缓冲思想和内部功能分区方式。
  - [x] SubTask 1.3: 确认 CAN 第一版范围为 Classic CAN 2.0A/B、DLC 0-8、数字 `can_tx/can_rx` 管脚、独立外设目录。

- [x] Task 2: 设计 `rtl/can/` 文件结构
  - [x] SubTask 2.1: 创建 `apb_can.v`，作为 APB 包装层和寄存器文件。
  - [x] SubTask 2.2: 创建 `can_top.v`，作为 CAN 协议核心顶层，仅做核心子模块连接和统一接口管理。
  - [x] SubTask 2.3: 根据实现复杂度创建最小必要子模块，建议候选包括 `can_bit_timing.v`、`can_tx.v`、`can_rx.v`、`can_crc.v`、`can_fifo.v`。
  - [x] SubTask 2.4: 创建 `apb_can_manual.md`，记录寄存器和编程流程，格式参考 UART 手册。

- [x] Task 3: 设计 APB 寄存器映射
  - [x] SubTask 3.1: 定义 `CTRL`：使能、监听/普通模式、环回模式、软复位、TX 请求、RX 释放等控制位。
  - [x] SubTask 3.2: 定义 `BITTIMING`：BRP、SJW、TSEG1、TSEG2、采样点相关配置。
  - [x] SubTask 3.3: 定义 `TX_ID`、`TX_CTRL`、`TX_DATA0`、`TX_DATA1`：发送 ID、IDE/RTR、DLC、8 字节数据。
  - [x] SubTask 3.4: 定义 `RX_ID`、`RX_CTRL`、`RX_DATA0`、`RX_DATA1`：接收 ID、IDE/RTR、DLC、8 字节数据。
  - [x] SubTask 3.5: 定义 `STATUS`：TX ready/busy/done、RX valid/count、bus idle、error passive/bus off 预留状态。
  - [x] SubTask 3.6: 定义 `INTERRUPT`：中断使能、触发源、状态标志、写 1 清除或读清除策略。
  - [x] SubTask 3.7: 定义 `ERROR`：CRC、stuff、form、ack、bit error 计数或标志。

- [x] Task 4: 设计 CAN 位时序模块
  - [x] SubTask 4.1: 根据 APB 时钟和 `BITTIMING` 生成时间量子 tick、bit tick、sample point 和 sync point。
  - [x] SubTask 4.2: 支持硬同步和重同步，使用 SJW 限制相位调整。
  - [x] SubTask 4.3: 输出 RX 采样使能、TX 位推进使能、总线空闲检测辅助信号。

- [x] Task 5: 设计 CAN CRC 模块
  - [x] SubTask 5.1: 实现 Classic CAN CRC-15 多项式计算。
  - [x] SubTask 5.2: 提供发送路径 CRC 累加和接收路径 CRC 校验接口。
  - [x] SubTask 5.3: 用独立 Testbench 验证至少一组已知帧 CRC。

- [x] Task 6: 设计 CAN 发送路径
  - [x] SubTask 6.1: 从 TX 寄存器/FIFO 锁存完整帧。
  - [x] SubTask 6.2: 按 SOF、仲裁场、控制场、数据场、CRC 场、ACK 场、EOF、IFS 顺序发送。
  - [x] SubTask 6.3: 实现位填充，连续 5 个相同位后插入反相填充位。
  - [x] SubTask 6.4: 检测 ACK slot、位错误和发送完成状态。

- [x] Task 7: 设计 CAN 接收路径
  - [x] SubTask 7.1: 检测 SOF 并按配置采样点接收位流。
  - [x] SubTask 7.2: 实现去位填充和 stuff error 检测。
  - [x] SubTask 7.3: 解码标准帧与扩展帧的 ID、IDE、RTR、DLC、payload。
  - [x] SubTask 7.4: 校验 CRC、EOF/form，并将有效帧写入 RX FIFO。

- [x] Task 8: 设计 FIFO 与 APB 包装联动
  - [x] SubTask 8.1: 实现 TX/RX FIFO 或单帧缓冲的最小可用版本；若使用 FIFO，深度参数默认 4 或 8。
  - [x] SubTask 8.2: 将 TX ready、RX valid、RX count、错误标志映射到 APB `STATUS/ERROR/INTERRUPT`。
  - [x] SubTask 8.3: 实现软件读 RX、释放 RX、写 TX、启动 TX 的副作用。

- [x] Task 9: 编写 CAN 外设手册
  - [x] SubTask 9.1: 记录模块概述、参数、端口、寄存器表和位定义。
  - [x] SubTask 9.2: 记录初始化、发送帧、接收帧、中断模式、环回模式和软复位流程。
  - [x] SubTask 9.3: 记录第一版不支持 CAN FD、不包含外部收发器模拟、不做 SoC 地址接入的边界。

- [x] Task 10: 编写并运行仿真验证
  - [x] SubTask 10.1: 为 CRC、位时序、TX、RX 等关键子模块编写独立 Testbench。
  - [x] SubTask 10.2: 为 `apb_can` 编写 APB 级集成 Testbench，风格参考 `rtl/sim/tb_apb_uart.v`。
  - [x] SubTask 10.3: 覆盖 APB 读写、复位默认值、标准帧环回、扩展帧环回、RX 中断、TX 完成中断、CRC/stuff 错误丢帧。
  - [x] SubTask 10.4: 使用 `iverilog` 编译、`vvp` 运行，并清理仿真输出临时文件。

# Task Dependencies
- Task 2 depends on Task 1.
- Task 3 depends on Task 1.
- Task 4, Task 5, Task 6, Task 7 depend on Task 2 and Task 3.
- Task 8 depends on Task 4, Task 5, Task 6, Task 7.
- Task 9 depends on Task 3 and Task 8.
- Task 10 depends on Task 4, Task 5, Task 6, Task 7, Task 8.

# Parallelizable Work
- Task 3 register-map drafting can proceed in parallel with Task 2 file-structure setup after Task 1.
- Task 4 bit timing and Task 5 CRC can proceed in parallel after module interfaces are fixed.
- Task 6 TX and Task 7 RX can proceed in parallel after bit timing and CRC interfaces are available.
- Task 9 manual drafting can proceed while Task 10 testbench work is prepared, once register behavior is stable.

- [x] Task 11: 补齐系统验证发现的错误丢帧仿真覆盖
  - [x] SubTask 11.1: 在现有 CAN Testbench 中加入最小错误帧/CRC 或 stuff 错误注入场景，验证错误帧不会写入 RX FIFO。
  - [x] SubTask 11.2: 使用 `iverilog -g2005` 和 `vvp` 重新运行 CRC 与 APB CAN 集成仿真，并在通过后更新 checklist 中对应仿真 checkpoint。
