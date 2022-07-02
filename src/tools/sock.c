
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>

#include <processx/unix-sockets.c>

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s <socket-file>", argv[0]);
  }

  processx_socket_t sock;
  int ret = processx_socket_connect(argv[1], &sock);
  if (ret == -1) {
    fprintf(
      stderr,
      "Failed to connect to socket at '%s': %s\n",
      argv[1],
      strerror(errno)
    );
    exit(1);
  }

  char buffer[1024];
  ssize_t nbytes = processx_socket_read(&sock, buffer, sizeof(buffer));
  if (nbytes == -1) {
    fprintf(
      stderr,
      "Failed to read from server socket: %s\n",
      strerror(errno)
    );
    exit(2);
  }

  buffer[nbytes] = '\0';
  printf("Message from server: %s\n", buffer);

  const char *msg = "hello there!";
  nbytes = processx_socket_write(&sock, (void*) msg, strlen(msg));
  if (nbytes == -1) {
    fprintf(
      stderr,
      "Failed to write to server socket: %s\n",
      strerror(errno)
    );
    exit(3);
  }

  ret = processx_socket_close(&sock);
  if (ret == -1) {
    fprintf(
      stderr,
      "Failed to close client socket: %s\n",
      strerror(errno)
    );
    exit(4);
  }

  return 0;
}
