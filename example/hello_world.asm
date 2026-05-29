// helloworld 滑动窗口循环写入程序
// 每间隔1秒，循环写入4字节滑动窗口到0x44000000地址
// 窗口序列: "hell" -> "ello" -> "llow" -> "lowo" -> "owor" -> "worl" -> "orld" -> "rldh" -> "ldhe" -> "dhel" -> "hell"...
// 使用策略：每次左移8位并添加新字符
//
// 寄存器分配：
// r1  = 字符索引 (0-9)
// r2  = 目标地址 (0x44000000)
// r3  = 延时循环计数器
// r4  = 计数器最大值
// r5  = 当前字符
// r6  = 完整字符串
// r7  = 索引最大值
// r8  = 分支条件临时寄存器
// r9  = 待定
// r10 = 待定
// r11 = 待定
// r12 = 待定
// r13 = 待定
// r14 = 待定
// r15 = 待定

start:
    // 寄存器初始化
    mov r1, 0          // r1 = 字符索引（0-9）
    mov r2, 0x4400     // r2 = 0x4400（目标地址高16位）
    mov r4, 255        // r4 = 255 (用于计数)
    mov r7, 9          // r7 = 9 (索引最大值)
    
    // 大数字二次计算：
    // 目标地址 0x44000000
    mov r2, r2 << 16   // r2 = 0x4400 << 16 = 0x44000000
    // 计数器计满1秒左右
    mov r4, r4 << 16   // r4 = 255 << 16 = 16,711,680（指令周期）
    // 单指令周期 = 3，总周期 = 16,711,680 * 3 = 50,135,040（50MHz时钟下约等于1秒）

   main_loop:
    // ============================================================
    // 字符序列: h(0), e(1), l(2), l(3), o(4), w(5), o(6), r(7), l(8), d(9)
    // ============================================================
    
    // ----- 加载当前字符 (索引 = r1) -----
    mov r8, 0                  // r8 = 0
    brc char_eq0, r1 == r8      // r1 == 0 -> 'h'(0x68)
    mov r8, 1                  // r8 = 1
    brc char_eq1, r1 == r8      // r1 == 1 -> 'e'(0x65)
    mov r8, 2                  // r8 = 2
    brc char_eq2, r1 == r8      // r1 == 2 -> 'l'(0x6C)
    mov r8, 3                  // r8 = 3
    brc char_eq3, r1 == r8      // r1 == 3 -> 'l'(0x6C)
    mov r8, 4                  // r8 = 4
    brc char_eq4, r1 == r8      // r1 == 4 -> 'o'(0x6F)
    mov r8, 5                  // r8 = 5
    brc char_eq5, r1 == r8      // r1 == 5 -> 'w'(0x77)
    mov r8, 6                  // r8 = 6
    brc char_eq6, r1 == r8      // r1 == 6 -> 'o'(0x6F)
    mov r8, 7                  // r8 = 7
    brc char_eq7, r1 == r8      // r1 == 7 -> 'r'(0x72)
    mov r8, 8                  // r8 = 8
    brc char_eq8, r1 == r8      // r1 == 8 -> 'l'(0x6C)
    jmp char_eq9, r12           // r1 == 9 -> 'd'(0x64)

char_eq0:
    mov r5, 0x68       // 'h'
    jmp load_char, r12
char_eq1:
    mov r5, 0x65       // 'e'
    jmp load_char, r12
char_eq2:
    mov r5, 0x6C       // 'l'
    jmp load_char, r12
char_eq3:
    mov r5, 0x6C       // 'l'
    jmp load_char, r12
char_eq4:
    mov r5, 0x6F       // 'o'
    jmp load_char, r12
char_eq5:
    mov r5, 0x77       // 'w'
    jmp load_char, r12
char_eq6:
    mov r5, 0x6F       // 'o'
    jmp load_char, r12
char_eq7:
    mov r5, 0x72       // 'r'
    jmp load_char, r12
char_eq8:
    mov r5, 0x6C       // 'l'
    jmp load_char, r12
char_eq9:
    mov r5, 0x64       // 'd'

load_char:
    // ----- 加载字符到队列并递增 -----
    mov r6, r6 << 8    // r6 = r6 << 8(队列左移)
    mov r6, r6 | r5     // r6 = r6 | r5(添加字符到队列)
    mov r3, 0          // r3 = 0(计数器清零)
    brc index_clear, r1 == r7    // 如果 r1 为最大值，清零索引
    jmp index_incr, r12 // 否则索引递增

index_clear:
    // 清空字符索引
    mov r1, 0          // r1 = 0
    jmp store, r12      // 去写入内存

index_incr:
    // 字符索引递增
    mov r1, r1 + 1     // r1 = r1 + 1
    jmp store, r12      // 去写入内存

store:
    // 保存字符队列到目标地址 0x44000000
    mov [r2], r6        // MEM[r2] = r6

delay:
    // 循环计数延时
    mov r3, r3 + 1     // r3 = r3 + 1
    brc delay, r3 < r4  // 如果计数器值小于最大值，继续递增
    jmp main_loop, r12  // 否则回到主循环
