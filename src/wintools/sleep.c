
#include <unistd.h>
#include <stdio.h>

void usage() {
  fprintf(stderr, "Usage: sleep seconds\n");
}

int main(int argc, const char **argv) {

  int ret, secs;

  if (argc != 2) { usage(); return 1; }

  ret = sscanf(argv[1], "%d", &secs);
  if (ret != 1) { usage(); return 1; }

  return sleep(secs);
}
