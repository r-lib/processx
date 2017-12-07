
#include <unistd.h>
#include <stdio.h>
#include <string.h>

void usage() {
  fprintf(stderr, "Usage: px [command arg] [command arg] ...\n\n");
  fprintf(stderr, "Commands:   sleep  <seconds>  -- "
	  "sleep for a number os seconds\n");
  fprintf(stderr, "            out    <string>   -- "
	  "print string to stdout\n");
  fprintf(stderr, "            err    <string>   -- "
	  "print string to stderr\n");
  fprintf(stderr, "            outln  <string>   -- "
	  "print string to stdout, add newline\n");
  fprintf(stderr, "            errln  <string>   -- "
	  "print string to stderr, add newline\n");
  fprintf(stderr, "            return <exitcode> -- "
	  "return with exitcode\n");
}

int main(int argc, const char **argv) {

  int num, idx, ret;

  if (argc == 2 && !strcmp("--help", argv[1])) { usage(); return 0; }

  for (idx = 1; idx < argc; idx++) {
    const char *cmd = argv[idx];
    if (!strcmp("sleep", cmd)) {
      ret = sscanf(argv[++idx], "%d", &num);
      if (ret != 1) {
	fprintf(stderr, "Invalid seconds for px sleep: '%s'\n", argv[idx]);
	return 3;
      }
      sleep(num);

    } else if (!strcmp("out", cmd)) {
      printf("%s", argv[++idx]);
      fflush(stdout);

    } else if (!strcmp("err", cmd)) {
      fprintf(stderr, "%s", argv[++idx]);

    } else if (!strcmp("outln", cmd)) {
      printf("%s\n", argv[++idx]);
      fflush(stdout);

    } else if (!strcmp("errln", cmd)) {
      fprintf(stderr, "%s\n", argv[++idx]);

    } else if (!strcmp("return", cmd)) {
      ret = sscanf(argv[++idx], "%d", &num);
      if (ret != 1) {
	fprintf(stderr, "Invalid seconds for px return: '%s'\n", argv[idx]);
	return 4;
      }
      return num;

    } else {
      fprintf(stderr, "Unknown px command: '%s'\n", cmd);
      return 2;
    }
  }

  return 0;
}
