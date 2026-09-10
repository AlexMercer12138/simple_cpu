#include "cpu_test.h"
#include <merc32_irq.h>

/* Held-high external interrupt: the CPU bench checks two entries, vector,
 * return PC and r4-r14 restoration around this real C handler. */
volatile unsigned int irq_count = 0;
volatile unsigned int irq_mix = 0;
static volatile unsigned int guard_seed = 0x13579bdfu;

unsigned int status_addr = 0x080003C0;
unsigned int ready_code = 0x1234;
unsigned int pass_code = 0x600D;

void __irq_handler(void) {
    volatile unsigned int *status = (volatile unsigned int *)status_addr;
    unsigned int values[4] = { irq_count, 3, 5, 7 };

    for (unsigned int i = 0; i < 4; ++i)
        irq_mix += values[i];
    ++irq_count;
    *status = pass_code + irq_count;
}

int main(void) {
    volatile unsigned int *status = (volatile unsigned int *)status_addr;
    unsigned int guard = guard_seed;

    __irq_enable_level();
    *status = ready_code;

    while (irq_count < 2) {
    }

    __irq_disable();
    CHECK(irq_count == 2 && irq_mix == 31, 0x401);
    CHECK(guard == 0x13579bdfu, 0x402);
    return cpu_pass();
}
