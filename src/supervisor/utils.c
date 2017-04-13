
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
