
#include <stdio.h>

#define MAX 10

int main(void) {
    int x = 42;
    float pi = 3.14f;
    char c = 'A';
    const char *msg = "Hello, world!";

    // Basic arithmetic
    x += 5;
    x--;

    if (x >= MAX && c != '\0') {
        printf("%s x=%d pi=%.2f\n", msg, x, pi);
    } else {
        printf("Something went wrong!\n");
    }

    /* Bitwise operations */
    int flags = 0xFF & 0x0F;
    flags |= 0x10;

    for (int i = 0; i < 3; i++) {
        printf("i = %d\n", i);
    }

    return 0;
}
