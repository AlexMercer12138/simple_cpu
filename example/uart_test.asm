// ============================================================================
// 串口测试程序 - 周期打印 "hello world!" 并通过中断回显输入数据
// ----------------------------------------------------------------------------
// 外设地址映射 (APB UART base = 0x10000000):
//  0   uart_ctrl       [0]=rx_en [2:1]=rx_cnt_max [4]=tx_en [6:5]=tx_cnt_max [31]=soft_rst
//  4   uart_config     [23:0]=baud_div [30:29]=parity [31]=stop_bit
//  8   uart_rx_buf     RX 4字节缓存（读后自动清 ptr）
//  12  uart_rx_status  [8]=rx_ready [5:2]=fifo_cnt [1:0]=ptr
//  16  uart_tx_buf     TX 4字节缓存（写入后自动清 ptr）
//  20  uart_tx_status  [8]=tx_valid [7:6]=tx_cnt [5:2]=fifo_cnt [1:0]=ptr
//  24  uart_interrupt  [0]=int_en [2:1]=int_type (0:rx_valid 1:tx_ready 2:rx_cnt 3:tx_cnt)
//
// 波特率: 115200
// CTRL : rx_en=1, rx_cnt_max=3(4字节), tx_en=1(后续单独触发), tx_cnt_max=3 → 0x7B/0x6B
//
// 寄存器分配:
//   r0  : 硬件归零
//   r1  : 中断控制 (使能 + 触发方式)
//   r2  : 中断向量 (高16位=ISR地址, 低16位=硬件自动写返回地址)
//   r3  : UART 基址 0x10000000
//   r4  : 字符串字数据 / 通用临时
//   r5  : ISR 临时 / 通用临时
//   r6  : ISR 中读回的接收数据
//   r7  : 延时计数最大值
//   r8  : 延时计数器
//   r9  : TX 启动时写入的 ctrl 值 (0x7B)
//   r10 : TX 等待空闲读回的 status
//   r11 : 当前字索引 (0..2)
//   r12 : 字符串总字数 (3)
//   r15 : JAL 链接寄存器占位
// ============================================================================

.equ UART_BASE        0x1000
.equ UART_BAUD_RATE   0xE100      // 115200 >> 1 = 57600
.equ UART_INT_RX      0x0001      // int_en=1, type=0 (rx_valid)
.equ DELAY_HIGH       0x00FF      // 延时高16位; (0xFF<<16)*3周期 ≈ 1s @50MHz

.macro interrupt_enable()
    mov r1, r1 | 0x0001 // 开启中断使能
.endm

.macro interrupt_disable()
    mov r1, r1 & 0xFFFE // 关闭中断使能
.endm

.macro return_main(ra)
    mov ra, r2 & 0xFFFF // 取返回地址
    jmp ra, r15         // 返回主循环
.endm

.macro UartSendByte(Rbase, Rbyte, value)
    mov Rbyte, value
    mov Rbyte, Rbyte << 24
    mov [Rbase + 16], Rbyte
    mov Rbyte, 0x0010
    mov [Rbase], Rbyte
.endm

.macro UartSendInt(Rbase, Rint, valhi, vallo)
    mov Rint, valhi
    mov Rint, Rint << 16
    mov Rint, Rint + vallo
    mov [Rbase + 16], Rint
    mov Rint, 0x0070
    mov [Rbase], Rint
.endm

.macro UartRecvByte(Rbase, Rbyte)
    mov Rbyte, 0x0001
    mov [Rbase], Rbyte
    mov Rbyte, [Rbase + 8]
    mov Rbyte, Rbyte >> 24
.endm

// .equ sim

// ---------------------------- 初始化 ----------------------------------------
start:
    // 构造 UART 基地址 0x10000000
    mov r3, UART_BASE       // r3 = 0x1000
    mov r3, r3 << 16        // r3 = 0x10000000

    // 配置波特率寄存器 (offset 0x04)
    mov r4, UART_BAUD_RATE  // r4 = 57600
    mov r4, r4 << 1         // r4 = 115200
    mov [r3 + 4], r4        // write 0x10000004 = r4

    // 配置 UART 中断源: rx_valid 触发
    mov r4, UART_INT_RX     // r4 = 1
    mov [r3 + 24], r4       // offset 0x18

    // 配置 CPU 中断: 上升沿触发, 跳转到 isr
    
    mov r4, isr             // 保存中断跳转地址
    mov r2, r4 << 16        // 写入高 16 位
    mov r1, 1               // 中断使能，上升沿触发

    // 延时常量
    mov r5, DELAY_HIGH
.ifdef sim
    mov r5, r5 << 6         // r5 = 0x00000FF0
.else
    mov r5, r5 << 16        // r5 = 0x00FF0000
.endif

// ----------------------------- 主循环 ---------------------------------------
main_loop:

wait_trans_ready:
    mov r4, [r3 + 20]               // Read Tx status
    mov r4, r4 >> 9                 // Shift Tx busy bit to LSB
    mov r7, 0x1
    brc wait_trans_ready, r4 == r7  // Keep LSB only

    UartSendInt(r3, r4, 0x4865, 0x6c6c) // "Hell"
wait_trans0:
    mov r4, [r3 + 20]           // Read Tx status
    mov r4, r4 >> 9             // Shift Tx busy bit to LSB
    mov r7, 0x1
    brc wait_trans0, r4 == r7   // Keep LSB only

    UartSendInt(r3, r4, 0x6f20, 0x776f) // "o wo"
wait_trans1:
    mov r4, [r3 + 20]           // Read Tx status
    mov r4, r4 >> 9             // Shift Tx busy bit to LSB
    mov r7, 0x1
    brc wait_trans1, r4 == r7   // Keep LSB only

    UartSendInt(r3, r4, 0x726c, 0x6421) // "rld!"
wait_trans2:
    mov r4, [r3 + 20]           // Read Tx status
    mov r4, r4 >> 9             // Shift Tx busy bit to LSB
    mov r7, 0x1
    brc wait_trans2, r4 == r7   // Keep LSB only

    UartSendByte(r3, r4, 0x0a) // "\n"
wait_trans3:
    mov r4, [r3 + 20]           // Read Tx status
    mov r4, r4 >> 9             // Shift Tx busy bit to LSB
    mov r7, 0x1
    brc wait_trans3, r4 == r7   // Keep LSB only

    UartSendByte(r3, r4, 0x0d) // "\r"

delay:
    mov r6, r6 + 1
    brc delay, r6 != r5
    mov r6, 0
    jmp main_loop, r15


// ---------------------------- 中断服务程序 ----------------------------------
// 触发条件: rx_valid 上升沿 (接收 FIFO 有数据)
// 行为 : 发送 "?"
isr:
    interrupt_disable()     // 关闭中断使能
    UartRecvByte(r3, r4)    // Read byte from fifo

wait_isr:
    mov r4, [r3 + 20]           // Read Tx status
    mov r4, r4 >> 9             // Shift Tx busy bit to LSB
    mov r7, 0x1
    brc wait_isr, r4 == r7      // Keep LSB only
    UartSendByte(r3, r4, 0x3f)  // "?"

    interrupt_enable()      // 开启中断使能
    return_main(r14)        // 返回主循环
