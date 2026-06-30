# Checklist

- [x] 已确认并记录 CAN 第一版范围：Classic CAN 2.0A/B、DLC 0-8、标准帧和扩展帧、数字 `can_tx/can_rx`。
- [x] `rtl/can/` 目录下新增文件继承 UART 外设的文件头、命名、APB 接口和手册风格。
- [x] `apb_can` 提供 32-bit APB 从接口、低有效复位、软复位、中断输出和确定的寄存器映射。
- [x] CAN 位时序支持 BRP、SJW、TSEG1、TSEG2 配置，并产生采样点和发送位推进信号。
- [x] CAN TX 路径可发送标准数据帧和扩展数据帧，支持 DLC 0-8、位填充、CRC、ACK 检测和发送完成状态。
- [x] CAN RX 路径可接收标准数据帧和扩展数据帧，支持去位填充、CRC 校验、错误丢帧和 RX FIFO/缓冲写入。
- [x] APB 寄存器可完成 TX 帧装载、TX 请求、RX 帧读取、RX 释放、状态查询和中断清除。
- [x] 中断覆盖 RX frame available、TX complete、error detected，且软件可清除中断标志。
- [x] `apb_can_manual.md` 记录参数、端口、寄存器、编程流程、寄存器副作用和第一版限制。
- [x] 所有新增 RTL 使用 Verilog-2005 `.v` 文件，避免 SystemVerilog 专用语法。
- [x] 已为关键子模块和 `apb_can` 集成路径编写最小 Testbench。
- [x] 已使用 `iverilog` 和 `vvp` 运行仿真，标准帧/扩展帧环回、APB 读写、中断、错误丢帧测试均通过。
- [x] 仿真临时输出文件已清理，源文件、Testbench 和手册保留。
