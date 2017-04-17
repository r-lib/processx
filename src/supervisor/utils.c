
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include "utils.h"


bool verbose_mode = false;


void verbose_printf(const char *format, ...) {
    va_list args;
    va_start(args, format);

    if (verbose_mode) {
        vprintf(format, args);
        fflush(stdout);
    }

    va_end(args);
}


// Remove an element from an array and shift all items down. The last item
// gets a 0. Returns new length of array.
int remove_element(int* ar, int len, int idx) {
    for (int i=idx; i<len-1; i++) {
        ar[i] = ar[i+1];
    }
    ar[len-1] = 0;
    return len-1;
}


bool array_contains(int* ar, int len, int value) {
    for (int i=0; i<len; i++) {
        if (ar[i] == value)
            return true;
    }

    return false;
}
