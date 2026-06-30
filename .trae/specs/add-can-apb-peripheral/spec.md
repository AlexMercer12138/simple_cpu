# CAN 总线 APB 外设 Spec

## Why
当前工程已有 UART APB 外设作为低速串行通信参考，但缺少 CAN 总线控制器。新增 CAN 外设可让 CPU 通过 APB 寄存器配置 CAN 位时序、收发标准/扩展帧，并通过中断处理收发事件。

## What Changes
- 在 `rtl/can/` 下新增 CAN 外设 RTL，风格参考 `rtl/uart/` 的文件头、APB 从设备接口、寄存器映射、中断和软复位组织方式。
- 新增 APB 包装模块 `apb_can`，提供 32-bit APB 寄存器访问、中断输出、TX/RX 数据窗口、状态寄存器和软复位。
- 新增 CAN 协议核心顶层 `can_top`，负责 CAN 2.0A/B 经典帧的发送、接收、位时序采样、位填充/去填充、CRC、ACK、错误检测和 FIFO 缓冲。
- 新增必要的内部子模块，优先保持模块边界清晰，避免单文件过大；所有源文件使用 Verilog-2005 `.v`。
- 新增最小 Testbench，使用 `iverilog` 和 `vvp` 验证寄存器访问、TX/RX 回环、标准帧/扩展帧、CRC/ACK、FIFO 状态和中断行为。
- 新增 CAN 外设手册，记录端口、寄存器、编程流程和注意事项，格式参考 `apb_uart_manual.md`。

## Impact
- Affected specs: APB 外设、CAN 通信接口、CPU 外设集成预留。
- Affected code: `rtl/can/` 新增目录；后续如需接入 SoC 顶层，可能影响 APB 地址译码、外设中断汇聚和示例程序。
- Reference code: `rtl/uart/apb_uart.v`、`rtl/uart/uart_top.v`、`rtl/uart/apb_uart_manual.md`、`rtl/sim/tb_apb_uart.v`。

## ADDED Requirements

### Requirement: APB CAN 外设接口
The system SHALL provide an `apb_can` module with a 32-bit APB slave interface, one interrupt output, and CAN physical TX/RX pins.

#### Scenario: APB register access
- **WHEN** software accesses a valid CAN register through APB
- **THEN** the peripheral shall complete the transfer with `s_apb_pready` and return/write the expected 32-bit register value

#### Scenario: invalid address access
- **WHEN** software accesses an unimplemented register offset
- **THEN** the peripheral shall keep `s_apb_pslverr` low and ignore writes; reads shall return a deterministic value defined by the implementation manual

### Requirement: CAN classic frame transmit
The system SHALL support transmitting CAN classic data frames with 11-bit standard ID and 29-bit extended ID, DLC 0-8, and up to 8 payload bytes.

#### Scenario: standard frame transmit
- **WHEN** software writes ID, DLC, payload, and sets TX request
- **THEN** the CAN controller shall serialize a valid standard data frame on `can_tx`

#### Scenario: extended frame transmit
- **WHEN** software enables extended frame format and requests transmit
- **THEN** the CAN controller shall serialize a valid extended data frame on `can_tx`

### Requirement: CAN classic frame receive
The system SHALL receive CAN classic standard and extended data frames, check frame integrity, store accepted frames in RX FIFO, and expose them through APB registers.

#### Scenario: valid frame receive
- **WHEN** a valid CAN frame is observed on `can_rx`
- **THEN** the controller shall decode ID, IDE, RTR, DLC, payload, and set RX valid/FIFO status

#### Scenario: corrupted frame receive
- **WHEN** bit stuffing, CRC, form, or ACK-related checks fail
- **THEN** the controller shall discard the frame and update error/status counters

### Requirement: CAN bit timing configuration
The system SHALL provide programmable CAN bit timing based on APB clock, including baud prescaler, synchronization jump width, time segment 1, time segment 2, and sample point control.

#### Scenario: configured sample point
- **WHEN** software programs bit timing registers and enables the controller
- **THEN** the CAN receiver shall sample bits at the configured sample point and the transmitter shall advance bits using the configured bit period

### Requirement: FIFO and register buffering
The system SHALL provide TX and RX buffering so software can write/read one complete CAN frame through APB registers without cycle-accurate interaction.

#### Scenario: TX buffer load
- **WHEN** software writes TX frame registers and asserts TX request
- **THEN** the hardware shall latch the complete frame and update TX busy/ready status

#### Scenario: RX buffer read
- **WHEN** software reads a completed RX frame and acknowledges/advances the FIFO
- **THEN** the hardware shall expose the next pending frame or clear RX valid when FIFO becomes empty

### Requirement: interrupt support
The system SHALL provide configurable interrupt generation for RX frame available, TX complete, error detected, and FIFO threshold/status events.

#### Scenario: RX interrupt
- **WHEN** interrupt is enabled and a frame enters RX FIFO
- **THEN** `interrupt` shall assert until software clears the interrupt flag

### Requirement: reset and enable control
The system SHALL support low-active reset and software-controlled soft reset while preserving APB-compatible register behavior.

#### Scenario: soft reset
- **WHEN** software writes the soft reset control bit
- **THEN** the CAN protocol core shall reset internal state machines and FIFOs according to the documented behavior

### Requirement: verification artifacts
The system SHALL include minimum simulation coverage for APB access, CAN TX, CAN RX, loopback, interrupt, error handling, and reset behavior.

#### Scenario: simulation pass
- **WHEN** the testbench is compiled with `iverilog` and run with `vvp`
- **THEN** all checks shall pass without compile errors, runtime fatal errors, or failed assertions/check counters

## MODIFIED Requirements

### Requirement: Existing RTL style consistency
The CAN files SHALL inherit the UART peripheral style where practical: Mercer header, APB signal naming, `interrupt` output naming, low-active reset, register-manual style, and concise module instantiation templates.

## REMOVED Requirements

None.

## Open Decisions Before Implementation
- CAN protocol scope default: Classic CAN 2.0A/B only; CAN FD is out of scope unless explicitly requested.
- Bus integration default: only create standalone `rtl/can/` peripheral and simulations; SoC address-map integration is out of scope for the first implementation unless requested.
- Physical layer default: expose digital `can_tx` and `can_rx` only; external transceiver control pins such as standby/silent mode are optional and not included by default.
