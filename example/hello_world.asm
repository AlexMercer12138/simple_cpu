// helloworld 滑动窗口循环写入程序
// 每间隔1秒，循环写入4字节滑动窗口到0x44000000地址
// 窗口序列: "hell" -> "ello" -> "llow" -> "lowo" -> "owor" -> "worl" -> "orld" -> "rldh" -> "ldhe" -> "dhel" -> "hell"...
// 使用策略：每次左移8位并添加新字符
//
// 寄存器分配：
// R1  = 窗口起始索引 (0-9)
// R2  = 目标地址 (0x44000000)
// R3  = 计数器最大值
// R4  = 常数8（用于左移位）
// R5  = 常数16（用于左移位）
// R6  = 存储当前字符
// R7  = 存储完整字符
// R8  = 分支临时寄存器
// R9  = 常数1（用于递增）
// R10 = 常数9（用于比较）
// R11 = 延时循环计数器
// R12 = JMP链接寄存器
// R13 = 待定
// R14 = 待定
// R15 = 待定

start:
    // 初始化索引和常数
    MOV R1, #0          // R1 = 窗口起始索引 (0-9)
    MOV R2, #0x4400     // R2 = 0x4400
    MOV R3, #763      // R3 = 763 (50000000的65536分之1)
    // MOV R3, #1          // R3 = 1 (用于快速仿真)
    MOV R4, #8          // R4 = 常数8
    MOV R5, #16         // R5 = 常数16
    MOV R9, #1          // R9 = 常数1
    MOV R10, #9         // R10 = 常数9
    MOV R11, #0         // R11 = 常数0
    MOV R12, #0         // R12 = 0 (JMP链接寄存器初始值)
    
    // 目标地址 0x44000000
    MOV R2, R2 << R5    // R2 = 0x4400 << 16 = 0x44000000
    // 计数器计满1秒（约等于49999999）
    MOV R3, R3 << R5    // R3 = 763 << 16 = 49,938,432

main_loop:
    // ============================================================
    // 字符序列: h(0), e(1), l(2), l(3), o(4), w(5), o(6), r(7), l(8), d(9)
    // ============================================================
    
    // ----- 加载当前字符 (索引 = R1) -----
    MOV R8, #0
    BRC char_eq0, R1 == R8      // R1==0 -> 'h'(0x68)
    MOV R8, #1
    BRC char_eq1, R1 == R8      // R1==1 -> 'e'(0x65)
    MOV R8, #2
    BRC char_eq2, R1 == R8      // R1==2 -> 'l'(0x6C)
    MOV R8, #3
    BRC char_eq3, R1 == R8      // R1==3 -> 'l'(0x6C)
    MOV R8, #4
    BRC char_eq4, R1 == R8      // R1==4 -> 'o'(0x6F)
    MOV R8, #5
    BRC char_eq5, R1 == R8      // R1==5 -> 'w'(0x77)
    MOV R8, #6
    BRC char_eq6, R1 == R8      // R1==6 -> 'o'(0x6F)
    MOV R8, #7
    BRC char_eq7, R1 == R8      // R1==7 -> 'r'(0x72)
    MOV R8, #8
    BRC char_eq8, R1 == R8      // R1==8 -> 'l'(0x6C)
    JMP char_eq9, R12           // R1==9 -> 'd'(0x64)，使用R12作为链接寄存器

char_eq0:
    MOV R6, #0x68       // 'h'
    JMP load_char, R12
char_eq1:
    MOV R6, #0x65       // 'e'
    JMP load_char, R12
char_eq2:
    MOV R6, #0x6C       // 'l'
    JMP load_char, R12
char_eq3:
    MOV R6, #0x6C       // 'l'
    JMP load_char, R12
char_eq4:
    MOV R6, #0x6F       // 'o'
    JMP load_char, R12
char_eq5:
    MOV R6, #0x77       // 'w'
    JMP load_char, R12
char_eq6:
    MOV R6, #0x6F       // 'o'
    JMP load_char, R12
char_eq7:
    MOV R6, #0x72       // 'r'
    JMP load_char, R12
char_eq8:
    MOV R6, #0x6C       // 'l'
    JMP load_char, R12
char_eq9:
    MOV R6, #0x64       // 'd'

load_char:
    // ----- 加载字符到队列并递增 -----
    MOV R7, R7 << R4    // R7 = R7 << 8(队列左移)
    MOV R7, R7 + R6     // R7 = R7 + R6(添加字符到队列)
    MOV R11, #0         // R11 = 0(计数器清零)
    BRC index_clear, R1 == R10    // 如果 R1 == 9，清零索引
    JMP index_incr, R12 // 否则索引递增，使用R12

index_clear:
    // 清空窗口索引
    MOV R1, #0          // R1 = 0
    JMP store, R12      // 去写入内存，使用R12

index_incr:
    // 窗口索引递增
    MOV R1, R1 + R9     // R1 = R1 + 1
    JMP store, R12      // 去写入内存，使用R12

store:
    // 保存字符队列到目标地址 0x44000000
    MOV [R2], R7        // MEM[R2] = R7

delay:
    // 循环计数延时
    MOV R11, R11 + R9   // R11 = R11 + 1
    BRC delay, R11 < R3 // 如果计数器值小于最大值，继续递增
    JMP main_loop, R12  // 否则回到主循环，使用R12
