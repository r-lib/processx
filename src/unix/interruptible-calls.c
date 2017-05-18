
#include <R.h>

#include <sys/wait.h>
#include <poll.h>
#include <errno.h>

#include "processx-unix.h"

int processx__interruptible_poll(struct pollfd fds[],
                          nfds_t nfds, int timeout) {
  int ret = 0;
  int timeleft = timeout;

  while (timeout < 0 || timeleft > PROCESSX_INTERRUPT_INTERVAL) {
    do {
      ret = poll(fds, nfds, PROCESSX_INTERRUPT_INTERVAL);
    } while (ret == -1 && errno == EINTR);

    /* If not a timeout, then return */
    if (ret != 0) return ret;

    R_CheckUserInterrupt();
    timeleft -= PROCESSX_INTERRUPT_INTERVAL;
  }

  /* Maybe we are not done, and there is a little left from the timeout */
  if (timeleft >= 0) {
    do {
      ret = poll(fds, nfds, timeleft);
    } while (ret == -1 && errno == EINTR);
  }

  return ret;
}
