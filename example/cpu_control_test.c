#include "cpu_test.h"

typedef struct { int x, y; } Pair;
static volatile int seed = 5;
static int side_effects;

static int touch(void) { ++side_effects; return 1; }
static int factorial(int n) { return n < 2 ? 1 : n * factorial(n - 1); }
static int sum8(int a, int b, int c, int d, int e, int f, int g, int h) {
    return a + b + c + d + e + f + g + h;
}
static int add(int a, int b) { return a + b; }
static int (*volatile callback)(int, int) = add;
static Pair translate(Pair p, int delta) { return (Pair){ p.x + delta, p.y - delta }; }
static int next(void) { static int count = 3; return ++count; }

int main(void) {
    int sum = 0, rounds = 0;
    int n = seed;
    for (int i = 0; i < 10; ++i) {
        if (i == 2) continue;
        if (i == 7) break;
        sum += i;
    }
    CHECK(sum == 19, 0x301);
    do { ++rounds; } while (rounds < n);
    CHECK(rounds == 5, 0x302);
    switch (n) {
    case 5: sum += 3; /* intentional fallthrough */
    case 6: sum += 7; break;
    default: sum = -1;
    }
    CHECK(sum == 29, 0x303);
    CHECK((n == 0 && touch()) == 0 && side_effects == 0, 0x304);
    CHECK((n != 0 || touch()) == 1 && side_effects == 0, 0x305);
    CHECK((n ? touch() : 99) == 1 && side_effects == 1, 0x306);
    CHECK(factorial(n) == 120, 0x307);
    CHECK(sum8(n, 2, 3, 4, 5, 6, 7, 8) == 40, 0x308);
    CHECK(callback(n, factorial(3)) == 11, 0x309);
    Pair result = translate((Pair){ 12, -7 }, n);
    CHECK(result.x == 17 && result.y == -12, 0x30a);
    CHECK(next() == 4, 0x30b);
    CHECK(next() == 5, 0x30c);
    while (sum > 0) {
        sum -= 3;
        if (sum == 2) goto finished;
    }
    CHECK(0, 0x30d);
finished:
    CHECK(sum == 2, 0x30e);
    return cpu_pass();
}
