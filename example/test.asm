; Simple CPU 测试程序
; 测试各种指令

start:
    ; 测试SET指令
    MOV R0, #0          ; R0 = 0
    MOV R1, #1          ; R1 = 1
    MOV R2, #0xFF       ; R2 = 255

    ; 测试算术运算
    MOV R3, R1 + R2     ; R3 = R1 + R2 = 256
    MOV R4, R2 - R1     ; R4 = R2 - R1 = 254

    ; 测试逻辑运算
    MOV R5, R1 & R2     ; R5 = R1 & R2 = 1
    MOV R6, R1 | R2     ; R6 = R1 | R2 = 255
    MOV R7, R1 ^ R2     ; R7 = R1 ^ R2 = 254

    ; 测试移位运算
    MOV R8, R2 << R1    ; R8 = R2 << 1 = 510
    MOV R9, R2 >> R1    ; R9 = R2 >> 1 = 127

    ; 测试内存操作
    MOV [R10], R3       ; Mem[R10] = R3
    MOV R11, [R4]       ; R11 = Mem[R4]

    ; 测试跳转
    JMP R12, #13        ; 跳转到地址13
    MOV R15, #15        ; R15 = 15;
    JMP R13, R15        ; 跳转到地址15

    ; 测试分支
    MOV R15, #17        ; R15 = 17
    BRC R15, R1 == R1   ; if (R1 == R1) PC = R15
    MOV R15, #19        ; R15 = 19
    BRC R15, R1 != R2   ; if (R1 != R2) PC = R15
    MOV R15, #21        ; R15 = 21
    BRC R15, R1 <  R2   ; if (R1 <  R2) PC = R15
    MOV R15, #23        ; R15 = 23
    BRC R15, R2 >= R1   ; if (R2 >= R1) PC = R15

loop:
    JMP R13, loop       ; 无限循环
