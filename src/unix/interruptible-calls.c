
#include <R.h>

#include <sys/wait.h>
#include <poll.h>
#include <errno.h>

#include "processx-unix.h"

int processx__interruptible_poll(struct pollfd fds[],
                          nfds_t nfds, int timeout) {
  int ret;

  while (timeout > PROCESSX_INTERRUPT_INTERVAL) {
    do {
      ret = poll(fds, nfds, PROCESSX_INTERRUPT_INTERVAL);
    } while (ret == -1 && errno == EINTR);

    /* If not a timeout, then return */
    if (ret != 0) return ret;

    R_CheckUserInterrupt();
    timeout -= PROCESSX_INTERRUPT_INTERVAL;
  }

  if (timeout < 0) timeout = 0;
  do {
    ret = poll(fds, nfds, timeout);
  } while (ret == -1 && errno == EINTR);

  return ret;
}
