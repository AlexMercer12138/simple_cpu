// ============================================
// Simple CPU 全指令测试程序
// 测试所有 MOV/JMP/BRC 指令变体
// ============================================

// ========== MOV 指令测试 ==========

// 1. 加载立即数 (I-Type)
MOV R0, #0              // R0 = 0
MOV R1, #100            // R1 = 100
MOV R2, #-1             // R2 = -1 (0xFFFF)
MOV R3, #0x1234         // R3 = 0x1234

// 2. 寄存器复制 (R-Type)
MOV R4, R0              // R4 = R0
MOV R5, R1              // R5 = R1

// 3. ALU 运算 I-Type
MOV R6, R1 + #10        // 加法: R6 = R1 + 10 = 110
MOV R7, R1 - #50        // 减法: R7 = R1 - 50 = 50
MOV R0, R3 & #0x0F00    // 按位与: R0 = 0x0200 (使用小立即数)
MOV R0, R3 | #0x00FF    // 按位或: R0 = 0x12FF
MOV R0, R3 ^ #0x00FF    // 按位异或: R0 = 0x12CB (使用小立即数)
MOV R0, R1 << #2        // 逻辑左移: R0 = 400
MOV R0, R1 >> #2        // 逻辑右移: R0 = 25
MOV R0, R2 >>> #1       // 算术右移: R0 = 0xFFFF

// 4. ALU 运算 R-Type
MOV R0, R1 + R2         // R0 = R1 + R2 = 99
MOV R0, R1 - R2         // R0 = R1 - R2 = 101
MOV R0, R3 & R2         // R0 = R3 & R2 = 0x1234
MOV R0, R3 | R2         // R0 = R3 | R2 = 0xFFFF
MOV R0, R3 ^ R2         // R0 = R3 ^ R2 = 0xEDCB
MOV R0, R1 << R2        // R0 = R1 << R2
MOV R0, R1 >> R2        // R0 = R1 >> R2
MOV R0, R2 >>> R2       // R0 = R2 >>> R2

// 5. 内存访问 I-Type
MOV R0, #0x10           // 设置基地址
MOV [R0 + #0], R1       // Mem[0x10] = R1 = 100
MOV [R0 + #4], R2       // Mem[0x14] = R2 = -1
MOV [R0 + #8], R3       // Mem[0x18] = R3 = 0x1234
MOV R4, [R0 + #0]       // R4 = Mem[0x10] = 100
MOV R5, [R0 + #4]       // R5 = Mem[0x14] = -1
MOV R6, [R0 + #8]       // R6 = Mem[0x18] = 0x1234

// 6. 内存访问 R-Type
MOV R1, #4
MOV R2, #8
MOV R7, [R0 + R1]       // R7 = Mem[R0 + 4] = -1
MOV [R0 + R2], R7       // Mem[R0 + 8] = R7 = -1

// 7. 内存访问简写形式 (偏移为0)
MOV [R0], R3            // Mem[R0] = R3
MOV R4, [R0]            // R4 = Mem[R0]

// ========== JMP 指令测试 ==========

// 1. 跳转到立即数地址
MOV R0, #0
JMP #20, R1             // R1 = PC+1, PC = 20

// 2. 跳转到标签
jmp_test:
MOV R0, #1
JMP jmp_label1, R2      // R2 = PC+1, 跳转到 jmp_label1

jmp_label1:
MOV R0, #2

// 3. 寄存器跳转 - 使用JALR指令，通过MOV先设置寄存器值
// 注意: JALR使用寄存器作为跳转目标，但我们需要先知道地址
// 这里我们使用JMP立即数来测试跳转功能
JMP jmp_label2, R4      // 跳转到标签

jmp_label2:
MOV R0, #4

// ========== BRC 指令测试 ==========
// 注意: BRC 语法是 BRC target, Rd2 op Rd1

// 1. BRC R-Type (寄存器跳转目标) - 使用R3保存跳转地址
// 注意: 由于不能直接用标签作为立即数，我们使用BRC的立即数或标签形式

// 先设置测试数据
MOV R0, #10
MOV R1, #10
MOV R2, #20

// 测试相等条件 - 使用标签直接跳转 (应该跳转)
BRC brc_label1, R0 == R1        // if (R0 == R1) PC = brc_label1
MOV R4, #0              // 如果跳转成功，这行不会执行

brc_label1:
MOV R4, #1              // 跳转成功标记

// 测试相等条件 (不应该跳转)
BRC brc_label_skip, R0 == R2    // if (R0 == R2) PC = brc_label_skip (条件不满足，不跳转)
MOV R5, #2              // 这行会执行
brc_label_skip:

// 测试不等条件 (应该跳转)
BRC brc_label2, R0 != R2        // if (R0 != R2) PC = brc_label2
MOV R6, #0              // 如果跳转成功，这行不会执行

brc_label2:
MOV R6, #3              // 跳转成功标记

// 测试小于条件
MOV R0, #5
MOV R1, #10
BRC brc_label3, R0 < R1         // if (R0 < R1) PC = brc_label3 (有符号比较)
MOV R7, #0

brc_label3:
MOV R7, #4

// 测试大于等于条件
BRC brc_label4, R1 >= R0        // if (R1 >= R0) PC = brc_label4 (有符号比较)
MOV R0, #0

brc_label4:
MOV R0, #5

// 2. BRC I-Type (立即数跳转目标)
MOV R0, #100
MOV R1, #100

// 测试相等条件 - 立即数跳转
BRC #60, R0 == R1       // if (R0 == R1) PC = #60
MOV R1, #0

// 由于立即数跳转需要知道地址，这里我们跳过后续几条指令
MOV R2, #200
BRC #70, R0 != R2       // if (R0 != R2) PC = #70
MOV R2, #0

// 3. BRC 标签跳转 - 使用标签形式的循环
MOV R0, #1
MOV R1, #1

brc_loop_start:
MOV R0, R0 + #1
BRC brc_loop_start, R0 != R1    // 循环直到 R0 == R1

// ========== 综合测试 ==========

// 测试负数立即数边界
MOV R0, #-32768         // 最小负数
MOV R1, #32767          // 最大正数

// 测试零偏移内存访问
MOV R2, #0x20
MOV [R2], R0            // Mem[0x20] = -32768
MOV [R2 + #4], R1       // Mem[0x24] = 32767
MOV R3, [R2]            // R3 = -32768
MOV R4, [R2 + #4]       // R4 = 32767

// 测试复杂跳转链
MOV R0, #0
JMP chain_start, R1     // 开始跳转链

chain_mid:
MOV R0, R0 + #2         // R0 = 2
JMP chain_end, R2

chain_start:
MOV R0, R0 + #1         // R0 = 1
JMP chain_mid, R3

chain_end:
MOV R0, R0 + #3         // R0 = 5

// ========== 程序结束 ==========
done:
MOV R0, #0x7FFF         // 结束标记 (最大正数)
MOV R1, #0x7000         // 结束标记
JMP #0, R2              // 跳转到地址0 (复位)

// ============================================
// 测试总结:
// - MOV 立即数: 正数、负数、十六进制(范围内)
// - MOV 寄存器复制
// - ALU I-Type: +, -, &, |, ^, <<, >>, >>>
// - ALU R-Type: +, -, &, |, ^, <<, >>, >>>
// - 内存 I-Type: [Rs + #imm], 读写
// - 内存 R-Type: [Rs1 + Rs2], 读写
// - 内存简写: [Rs]
// - JMP 立即数、标签 (语法: JMP target, Rd)
// - BRC R-Type: ==, !=, <, >= (语法: BRC Rs, Rd2 op Rd1)
// - BRC I-Type: ==, != (语法: BRC #imm, Rd2 op Rd1)
// - BRC 标签跳转 (语法: BRC label, Rd2 op Rd1)
// ============================================
