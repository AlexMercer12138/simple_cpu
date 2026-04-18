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
    MOV [R0], R3        ; Mem[0] = R3
    MOV R10, [R0]       ; R10 = Mem[0]

    ; 测试跳转
    JMP R11, #10        ; 跳转到地址10
    JMP R12, R0         ; 跳转到R0指向的地址

    ; 测试分支
    BRC R0, R1 == R2    ; if (R1 == R2) PC = R0
    BRC R0, R1 != R2    ; if (R1 != R2) PC = R0
    BRC R0, R1 <  R2    ; if (R1 <  R2) PC = R0
    BRC R0, R1 >= R2    ; if (R1 >= R2) PC = R0

loop:
    JMP R13, loop       ; 无限循环
