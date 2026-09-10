#include "cpu_test.h"
#include <stddef.h>
#include <string.h>

typedef struct { uint8_t tag; int16_t delta; uint32_t value; } Record;
static Record initial = { .value = 0x12345678u, .tag = 0xa5, .delta = -300 };
static volatile uint32_t zeroed[8];
static volatile uint32_t lanes = 0x11223344u;
static volatile int8_t signed_byte = -7;
static volatile int16_t signed_half = -301;

int main(void) {
    volatile uint8_t *bytes = (volatile uint8_t *)&lanes;
    volatile uint16_t halves[3] = { 0x1234u, 0xabcd, 0x5678u };
    Record local = initial;
    Record records[2] = { { .tag = 1, .delta = -2, .value = 3 }, { 4, 5, 6 } };
    unsigned char buffer[48] = { 1, 2, 3 };
    char text[] = "MERC32";

    CHECK(sizeof(Record) == 8 && offsetof(Record, value) == 4, 0x201);
    CHECK(local.tag == 0xa5 && local.delta == -300 && local.value == 0x12345678u, 0x202);
    for (unsigned i = 0; i < 8; ++i) CHECK(zeroed[i] == 0, 0x203);
    CHECK(signed_byte == -7 && signed_half == -301, 0x204);
    CHECK((uint8_t)signed_byte == 249u && (uint16_t)signed_half == 65235u, 0x205);
    /* MERC32 DLB words use little-endian byte lanes. Check every strobe. */
    CHECK(bytes[0] == 0x44 && bytes[1] == 0x33 && bytes[2] == 0x22 && bytes[3] == 0x11, 0x206);
    bytes[0] = 0xaa; bytes[1] = 0xbb; bytes[2] = 0xcc; bytes[3] = 0xdd;
    CHECK(lanes == 0xddccbbaau, 0x207);
    halves[1] = 0xff01u;
    CHECK(halves[0] == 0x1234u && halves[1] == 0xff01u && halves[2] == 0x5678u, 0x208);
    CHECK(&records[1] - records == 1 && records[1].value == 6, 0x209);
    records[1] = (Record){ .tag = 9, .delta = -10, .value = 11 };
    CHECK(records[1].tag == 9 && records[1].delta == -10 && records[1].value == 11, 0x20a);
    CHECK(buffer[0] == 1 && buffer[2] == 3 && buffer[47] == 0, 0x20b);
    memset(buffer, 0x5a, sizeof(buffer));
    memcpy(buffer + 8, text, sizeof(text));
    memmove(buffer + 9, buffer + 8, sizeof(text));
    CHECK(buffer[0] == 0x5a && buffer[47] == 0x5a && buffer[8] == 'M', 0x20c);
    CHECK(strcmp((char *)buffer + 9, "MERC32") == 0 && strlen((char *)buffer + 9) == 6, 0x20d);
    return cpu_pass();
}
