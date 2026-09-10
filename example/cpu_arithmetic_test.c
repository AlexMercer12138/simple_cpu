#include "cpu_test.h"

/* Volatile operands keep the ALU work in the CPU even with optimization. */
static volatile int32_t negative = -12345;
static volatile int32_t positive = 67;
static volatile uint32_t high_bit = 0x80000000u;
static volatile uint32_t all_bits = 0xffffffffu;
static volatile unsigned shift = 4;

int main(void) {
    int32_t a = negative, b = positive;
    uint32_t high = high_bit, ones = all_bits;
    CHECK(a + b == -12278, 0x101);
    CHECK(a - b == -12412, 0x102);
    CHECK(a * b == -827115, 0x103);
    CHECK(a / b == -184 && a % b == -17, 0x104);
    CHECK((-a) / (-b) == -184 && (-a) % (-b) == 17, 0x105);
    CHECK(ones + 1u == 0u && high - 1u == 0x7fffffffu, 0x106);
    CHECK(ones * 3u == 0xfffffffdu, 0x107);
    CHECK(ones / 67u == 64103989u && ones % 67u == 32u, 0x108);
    CHECK(a < b && b > a && a <= negative && b >= positive, 0x109);
    CHECK(high > (uint32_t)b && ones >= high, 0x10a);
    CHECK((int32_t)high < 0 && (uint32_t)a > (uint32_t)b, 0x10b);
    CHECK((high >> shift) == 0x08000000u, 0x10c);
    CHECK(((uint32_t)b << shift) == 1072u, 0x10d);
    CHECK((a >> shift) == -772, 0x10e); /* MERC32 arithmetic shift */
    CHECK((high | (uint32_t)b) == 0x80000043u, 0x10f);
    CHECK((ones ^ high) == 0x7fffffffu && (high & ones) == high, 0x110);
    CHECK(~high == 0x7fffffffu && !a == 0 && !!b == 1, 0x111);
    return cpu_pass();
}
