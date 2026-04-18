; 测试标签跳转功能
; 使用BRC指令跳转到标签

start:
    MOV R0, #0          ; R0 = 0
    MOV R1, #1          ; R1 = 1
    MOV R2, #5          ; R2 = 循环计数器 (5次)

loop_start:
    ; 检查计数器是否为0
    MOV R3, #0
    BRC exit_loop, R2 == R3    ; 如果R2==0，跳转到exit_loop
    
    ; R0 = R0 + R1
    MOV R0, R0 + R1
    
    ; 计数器减1
    MOV R2, R2 - R1
    
    ; 跳回循环开始
    JMP R4, loop_start

exit_loop:
    ; 循环结束，存储结果
    MOV R5, #0x10
    MOV [R5], R0          ; 将结果存入地址0x10
    
done:
    JMP R6, done          ; 无限循环
