
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#include "processx.h"

#ifdef _WIN32

/* These functions are not appropriate for general use, because they
   return 0.0 on error. They are invoked asynchronously, so they cannot
   fail. */

double processx__current_time() {
  double t = 0;
  struct timeval tv;
  int res = gettimeofday(&tv, NULL);
  if (res) return t;

  t = (double) tv.tv_sec + 1e-6 * (double) tv.tv_usec;
  return t;
}

#else

#ifdef __MACH__

#include <mach/clock.h>
#include <mach/mach.h>

double processx__current_time() {
  double t = 0;

  clock_serv_t cclock;
  mach_timespec_t mts;
  int ret;
  ret = host_get_clock_service(mach_host_self(), CALENDAR_CLOCK, &cclock);
  if (ret) return t;

  ret = clock_get_time(cclock, &mts);
  if (ret) return t;

  ret = mach_port_deallocate(mach_task_self(), cclock);
  if (ret) return t;

  t = (double) mts.tv_sec + 1e-9 * (double) mts.tv_nsec;

#else
  struct timespec *ts;
  int ret = clock_gettime(CLOCK_REALTIME, ts);
  if (ret) return t;

  t = (double) ts.tv_sec + 1e-9 * (double) ts.tv_nsec;
#endif

  return t;
}

#endif
