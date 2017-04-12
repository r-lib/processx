
#include "processx-unix.h"

void processx__sigchld_callback(int sig, siginfo_t *info, void *ctx) {
  if (sig != SIGCHLD) return;
  pid_t pid = info->si_pid;
  processx__child_list_t *child = processx__child_find(pid);

  if (child) {
    /* We deliberately do not call the finalizer here, because that
       moves the exit code and pid to R, and we might have just checked
       that these are not in R, before calling C. So finalizing here
       would be a race condition.

       OTOH, we need to check if the handle is null, because a finalizer
       might actually run before the SIGCHLD handler. Or the finalizer
       might even trigger the SIGCHLD handler...
    */
    int wp, wstat;
    processx_handle_t *handle = R_ExternalPtrAddr(child->status);

    /* This might not be necessary, if the handle was finalized,
       but it does not hurt... */
    do {
      wp = waitpid(pid, &wstat, 0);
    } while (wp == -1 && errno == EINTR);

    /* If handle is NULL, then the exit status was collected already */
    if (handle) processx__collect_exit_status(child->status, wstat);

    processx__child_remove(pid);

    /* If no more children, then we could remove the SIGCHLD handler,
       but that leads to strange interactions with system(), at least
       on macOS. So we don't do that. */

    /* If there is an active wait() with a timeout, then stop it */
    if (handle && handle->waitpipe[1] >= 0) {
      close(handle->waitpipe[1]);
      handle->waitpipe[1] = -1;
    }
  }
}

/* TODO: use oldact */

void processx__setup_sigchld() {
  struct sigaction action;
  action.sa_sigaction = processx__sigchld_callback;
  action.sa_flags = SA_SIGINFO | SA_RESTART | SA_NOCLDSTOP;
  sigaction(SIGCHLD, &action, /* oldact= */ NULL);
}

void processx__remove_sigchld() {
  struct sigaction action;
  action.sa_handler = SIG_DFL;
  sigaction(SIGCHLD, &action, /* oldact= */ NULL);
}

void processx__block_sigchld() {
  sigset_t blockMask;
  sigemptyset(&blockMask);
  sigaddset(&blockMask, SIGCHLD);
  if (sigprocmask(SIG_BLOCK, &blockMask, NULL) == -1) {
    error("processx error setting up signal handlers");
  }
}

void processx__unblock_sigchld() {
  sigset_t unblockMask;
  sigemptyset(&unblockMask);
  sigaddset(&unblockMask, SIGCHLD);
  if (sigprocmask(SIG_UNBLOCK, &unblockMask, NULL) == -1) {
    error("processx error setting up signal handlers");
  }
}
