// This file is intentionally pulled in by full_test.asm with .include.
// The preprocessor appends include contents after the main file, so the main
// program calls pseudo_include_test as a normal subroutine.

.equ INCLUDED_FLAG

.macro inc_once(reg)
mov reg, reg + 1
.endm

pseudo_include_test:
mov r3, 0
.ifdef INCLUDED_FLAG
.rept 3
inc_once(r3)
.endr
.else
mov r3, 99
.endif

assert_eqi(r3, 3, 80)

mov r4, 8
mov r14, 81
cmp r4, r0
brc pseudo_include_gt_ok, ">"
jmp fail

pseudo_include_gt_ok:
mov r14, 82
cmp r0, r4
brc pseudo_include_le_ok, "<="
jmp fail

pseudo_include_le_ok:
jmp r12
