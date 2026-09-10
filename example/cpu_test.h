#ifndef CPU_TEST_H
#define CPU_TEST_H

#include <stdint.h>

/* Testbench mailboxes in DLB RAM; no peripheral IP is required. */
#define CPU_STATUS (*(volatile uint32_t *)0x080003c0u)
#define CPU_DETAIL (*(volatile uint32_t *)0x080003c4u)
#define CPU_READY 0x1234u
#define CPU_PASS  0x600du
#define CPU_FAIL  0x0badu

#define CHECK(condition, code) do { \
    if (!(condition)) { \
        CPU_DETAIL = (code); \
        CPU_STATUS = CPU_FAIL; \
        return (code); \
    } \
} while (0)

static int cpu_pass(void) {
    CPU_DETAIL = 0;
    CPU_STATUS = CPU_PASS;
    return 0;
}

#endif
