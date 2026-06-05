// ============================================
// Simple CPU 全指令测试程序
// 测试所有 mov/jmp/brc 指令变体
// ============================================

// ========== mov 指令测试 ==========

// 1. 加载立即数 (I-Type)
mov r3, 0              // r3 = 0
mov r4, 100            // r4 = 100
mov r5, -1             // r5 = -1 (0xFFFF)
mov r6, 0x1234         // r6 = 0x1234

// 2. 寄存器复制 (R-Type)
mov r7, r3              // r7 = r3
mov r8, r4              // r8 = r4

// 3. ALU 运算 I-Type
mov r9, r4 + 10        // 加法: r9 = r4 + 10 = 110
mov r10, r4 - 50        // 减法: r10 = r4 - 50 = 50
mov r3, r6 & 0x0F00    // 按位与: r3 = 0x0200 (使用小立即数)
mov r3, r6 | 0x00FF    // 按位或: r3 = 0x12FF
mov r3, r6 ^ 0x00FF    // 按位异或: r3 = 0x12CB (使用小立即数)
mov r3, r4 << 2        // 逻辑左移: r3 = 400
mov r3, r4 >> 2        // 逻辑右移: r3 = 25
mov r3, r5 >>> 1       // 算术右移: r3 = 0xFFFF

// 4. ALU 运算 R-Type
mov r3, r4 + r5         // r3 = r4 + r5 = 99
mov r3, r4 - r5         // r3 = r4 - r5 = 101
mov r3, r6 & r5         // r3 = r6 & r5 = 0x1234
mov r3, r6 | r5         // r3 = r6 | r5 = 0xFFFF
mov r3, r6 ^ r5         // r3 = r6 ^ r5 = 0xEDCB
mov r3, r4 << r5        // r3 = r4 << r5
mov r3, r4 >> r5        // r3 = r4 >> r5
mov r3, r5 >>> r5       // r3 = r5 >>> r5

// 5. 内存访问 I-Type
mov r3, 0x10           // 设置基地址
mov [r3 + 0], r4       // Mem[0x10] = r4 = 100
mov [r3 + 4], r5       // Mem[0x14] = r5 = -1
mov [r3 + 8], r6       // Mem[0x18] = r6 = 0x1234
mov r7, [r3 + 0]       // r7 = Mem[0x10] = 100
mov r8, [r3 + 4]       // r8 = Mem[0x14] = -1
mov r9, [r3 + 8]       // r9 = Mem[0x18] = 0x1234

// 6. 内存访问 R-Type
mov r4, 4
mov r5, 8
mov r10, [r3 + r4]       // r10 = Mem[r3 + 4] = -1
mov [r3 + r5], r10       // Mem[r3 + 8] = r10 = -1

// 7. 内存访问简写形式 (偏移为0)
mov [r3], r6            // Mem[r3] = r6
mov r7, [r3]            // r7 = Mem[r3]

// ========== jmp 指令测试 ==========

// 1. 跳转到立即数地址
mov r3, 0
jmp 38, r4             // r4 = PC+1, PC = 38

// 2. 跳转到标签
jmp_test:
mov r3, 1
jmp jmp_label1, r5      // r5 = PC+1, 跳转到 jmp_label1

jmp_label1:
mov r3, 2

// 3. 寄存器跳转 - 使用JALR指令，通过mov先设置寄存器值
// 注意: JALR使用寄存器作为跳转目标，但我们需要先知道地址
// 这里我们使用jmp立即数来测试跳转功能
jmp jmp_label2, r7      // 跳转到标签

jmp_label2:
mov r3, 4

// ========== brc 指令测试 ==========
// 注意: brc 语法是 brc target, rd2 op rd1

// 1. brc R-Type (寄存器跳转目标) - 使用r3保存跳转地址
// 注意: 由于不能直接用标签作为立即数，我们使用brc的立即数或标签形式

// 先设置测试数据
mov r3, 10
mov r4, 10
mov r5, 20

// 测试相等条件 - 使用标签直接跳转 (应该跳转)
brc brc_label1, r3 == r4        // if (r3 == r4) PC = brc_label1
mov r7, 0              // 如果跳转成功，这行不会执行

brc_label1:
mov r7, 1              // 跳转成功标记

// 测试相等条件 (不应该跳转)
brc brc_label_skip, r3 == r5    // if (r3 == r5) PC = brc_label_skip (条件不满足，不跳转)
mov r8, 2              // 这行会执行
brc_label_skip:

// 测试不等条件 (应该跳转)
brc brc_label2, r3 != r5        // if (r3 != r5) PC = brc_label2
mov r9, 0              // 如果跳转成功，这行不会执行

brc_label2:
mov r9, 3              // 跳转成功标记

// 测试小于条件
mov r3, 5
mov r4, 10
brc brc_label3, r3 < r4         // if (r3 < r4) PC = brc_label3 (有符号比较)
mov r10, 0

brc_label3:
mov r10, 4

// 测试大于等于条件
brc brc_label4, r4 >= r3        // if (r4 >= r3) PC = brc_label4 (有符号比较)
mov r3, 0

brc_label4:
mov r3, 5

// 2. brc I-Type (立即数跳转目标)
mov r3, 100
mov r4, 100

// 测试相等条件 - 立即数跳转
brc 68, r3 == r4       // if (r3 == r4) PC = 68
mov r4, 0

// 由于立即数跳转需要知道地址，这里我们跳过后续几条指令
mov r5, 200
brc 70, r3 != r5       // if (r3 != r5) PC = 70
mov r5, 0

// 3. brc 标签跳转 - 使用标签形式的循环
mov r3, 1
mov r4, 10

brc_loop_start:
mov r3, r3 + 1
brc brc_loop_start, r3 != r4    // 循环直到 r3 == r4

// ========== 综合测试 ==========

// 测试负数立即数边界
mov r3, -32768         // 最小负数
mov r4, 32767          // 最大正数

// 测试零偏移内存访问
mov r5, 0x20
mov [r5], r3            // Mem[0x20] = -32768
mov [r5 + 4], r4       // Mem[0x24] = 32767
mov r6, [r5]            // r6 = -32768
mov r7, [r5 + 4]       // r7 = 32767

// 测试复杂跳转链
mov r3, 0
jmp chain_start, r4     // 开始跳转链

chain_mid:
mov r3, r3 + 2         // r3 = 2
jmp chain_end, r5

chain_start:
mov r3, r3 + 1         // r3 = 1
jmp chain_mid, r6

chain_end:
mov r3, r3 + 3         // r3 = 5

// ========== 程序结束 ==========
done:
mov r3, 0x7FFF         // 结束标记 (最大正数)
mov r4, 0x7000         // 结束标记
jmp 0, r5              // 跳转到地址0 (复位)

// ============================================
// 测试总结:
// - mov 立即数: 正数、负数、十六进制(范围内)
// - mov 寄存器复制
// - ALU I-Type: +, -, &, |, ^, <<, >>, >>>
// - ALU R-Type: +, -, &, |, ^, <<, >>, >>>
// - 内存 I-Type: [rs + imm], 读写
// - 内存 R-Type: [rs1 + rs2], 读写
// - 内存简写: [rs]
// - jmp 立即数、标签 (语法: jmp target, rd)
// - brc R-Type: ==, !=, <, >= (语法: brc rs, rd2 op rd1)
// - brc I-Type: ==, != (语法: brc imm, rd2 op rd1)
// - brc 标签跳转 (语法: brc label, rd2 op rd1)
// ============================================
