// 中断功能测试
// R1 - 中断控制寄存器
//   bit 2-1: 中断触发类型
//   bit 0: 中断使能
// R2 - 中断向量寄存器
//   bit 31-16: 中断跳转地址
//   bit 15-0: 中断返回地址

MOV R1, 1           // 中断使能，上升沿触发，清除标志位
MOV R3, interrupt   // 保存中断跳转地址
MOV R2, R3 << 16    // 写入高 16 位

main: // 主循环
MOV R4, R4 + 1
JMP main, R15 // 无限循环

interrupt:
MOV R1, R1 & 0xFFFE // 关闭中断使能
MOV R5, R1 // 测试语句
MOV R5, R2 // 测试语句
MOV R5, R3 // 测试语句
MOV R5, R4 // 测试语句
MOV R6, R5 // 测试语句
MOV R5, R2 & 0xFFFF // 取返回地址
MOV R1, R1 | 0x0001 // 开启中断使能
JMP R5, R15 // 返回主循环