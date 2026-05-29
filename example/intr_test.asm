// 中断功能测试
// r1 - 中断控制寄存器
//   bit 2-1: 中断触发类型
//   bit 0: 中断使能
// r2 - 中断向量寄存器
//   bit 31-16: 中断跳转地址
//   bit 15-0: 中断返回地址

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

mov r1, 1           // 中断使能，上升沿触发
mov r3, interrupt   // 保存中断跳转地址
mov r2, r3 << 16    // 写入高 16 位

main: // 主循环
mov r4, r4 + 1
jmp main, r15 // 无限循环

interrupt:
interrupt_disable() // 关闭中断使能
mov r5, 1           // 测试语句
mov r5, 1           // 测试语句
mov r5, 1           // 测试语句
mov r5, 1           // 测试语句
mov r5, 1           // 测试语句
interrupt_enable()  // 开启中断使能
return_main(r5)     // 返回主循环