
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#include <windows.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <stdlib.h>
#include <errno.h>
#include <stdlib.h>

#include <io.h>

void usage() {
  fwprintf(stderr, L"Usage: px [command arg] [command arg] ...\n\n");
  fwprintf(stderr, L"Commands:\n");
  fwprintf(stderr, L"  sleep  <seconds>           -- "
	  L"sleep for a number os seconds\n");
  fwprintf(stderr, L"  out    <string>            -- "
	  L"print string to stdout\n");
  fwprintf(stderr, L"  err    <string>            -- "
	  L"print string to stderr\n");
  fwprintf(stderr, L"  outln  <string>            -- "
	  L"print string to stdout, add newline\n");
  fwprintf(stderr, L"  errln  <string>            -- "
	  L"print string to stderr, add newline\n");
  fwprintf(stderr, L"  errflush                   -- "
	  L"flush stderr stream\n");
  fwprintf(stderr, L"  cat    <filename>          -- "
	  L"print file to stdout\n");
  fwprintf(stderr, L"  return <exitcode>          -- "
	  L"return with exitcode\n");
  fwprintf(stderr, L"  writefile <path> <string>  -- "
    L"write to file\n");
  fwprintf(stderr, L"  write <fd> <string>        -- "
	  L"write to file descriptor\n");
  fwprintf(stderr, L"  echo <fd1> <fd2> <nbytes>  -- "
	  L"echo from fd to another fd\n");
  fwprintf(stderr, L"  getenv <var>               -- "
	  L"environment variable to stdout\n");
}

void cat2(int f, const wchar_t *s) {
  char buf[8192];
  long n;

  while ((n = read(f, buf, (long) sizeof buf)) > 0) {
    if (write(1, buf, n) != n){
      fwprintf(stderr, L"write error copying %ls", s);
      exit(6);
    }
  }

  if (n < 0) fwprintf(stderr, L"error reading %ls", s);
}

void cat(const wchar_t* filename) {
  int f;
  if (!wcscmp(L"<stdin>", filename)) {
    f = STDIN_FILENO;
  } else {
    f = _wopen(filename, O_RDONLY);
  }

  if (f < 0) {
    fwprintf(stderr, L"can't open %ls", filename);
    exit(6);
  }

  cat2(f, filename);
  close(f);
}

int write_to_fd(int fd, const wchar_t *s) {
  size_t len = wcslen(s);
  ssize_t ret = write(fd, s, len * sizeof(wchar_t));
  if (ret != len * sizeof(wchar_t)) {
    fwprintf(stderr, L"Cannot write to fd '%d'\n", fd);
    return 1;
  }
  return 0;
}

int write_to_fd_simple(int fd, const char *s) {
  size_t len = strlen(s);
  ssize_t ret = write(fd, s, len);
  if (ret != len) {
    fwprintf(stderr, L"Cannot write to fd '%d'\n", fd);
    return 1;
  }
  return 0;
}

int echo_from_fd(int fd1, int fd2, int nbytes) {
  char buffer[nbytes + 1];
  ssize_t ret;
  buffer[nbytes] = '\0';
  ret = read(fd1, buffer, nbytes);
  if (ret == -1) {
    fwprintf(stderr, L"Cannot read from fd '%d', %s\n", fd1, strerror(errno));
    return 1;
  }
  if (ret != nbytes) {
    fwprintf(stderr, L"Cannot read from fd '%d' (%d bytes)\n", fd1, (int) ret);
    return 1;
  }
  if (write_to_fd_simple(fd2, buffer)) return 1;
  fflush(stdout);
  fflush(stderr);
  return 0;
}

int wmain(int argc, const wchar_t **argv) {

  int num, idx, ret, fd, fd2, nbytes;
  double fnum;

  _setmode(_fileno(stdout), _O_U16TEXT);

  if (argc == 2 && !wcscmp(L"--help", argv[1])) { usage(); return 0; }

  for (idx = 1; idx < argc; idx++) {
    const wchar_t *cmd = argv[idx];

    if (idx + 1 == argc) {
      fwprintf(stderr, L"Missing argument for '%ls'\n", argv[idx]);
      return 5;
    }

    if (!wcscmp(L"sleep", cmd)) {
      ret = swscanf(argv[++idx], L"%lf", &fnum);
      if (ret != 1) {
	      fwprintf(stderr, L"Invalid seconds for px sleep: '%ls'\n", argv[idx]);
	      return 3;
      }
      num = (int) fnum;
      sleep(num);
      fnum = fnum - num;
      if (fnum > 0) usleep((useconds_t) (fnum * 1000.0 * 1000.0));

    } else if (!wcscmp(L"out", cmd)) {
      wprintf(L"%ls", argv[++idx]);
      fflush(stdout);

    } else if (!wcscmp(L"err", cmd)) {
      fwprintf(stderr, L"%ls", argv[++idx]);

    } else if (!wcscmp(L"outln", cmd)) {
      wprintf(L"%ls\n", argv[++idx]);
      fflush(stdout);

    } else if (!wcscmp(L"errln", cmd)) {
      fwprintf(stderr, L"%ls\n", argv[++idx]);

    } else if (!wcscmp(L"errflush", cmd)) {
      fflush(stderr);

    } else if (!wcscmp(L"cat", cmd)) {
      cat(argv[++idx]);

    } else if (!wcscmp(L"return", cmd)) {
      ret = swscanf(argv[++idx], L"%d", &num);
      if (ret != 1) {
	      fwprintf(stderr, L"Invalid exit code for px return: '%ls'\n", argv[idx]);
	      return 4;
      }
      return num;

    } else if (!wcscmp(L"writefile", cmd)) {
      if (idx + 2 >= argc) {
        fwprintf(stderr, L"Missing argument(s) for 'writefile'\n");
        return 5;
      }
      int fd = _wopen(argv[++idx], _O_WRONLY | _O_CREAT | _O_BINARY);
      if (fd == -1) return 5;
      if (write_to_fd(fd, argv[++idx])) { close(fd); return 5; }
      close(fd);

    } else if (!wcscmp(L"write", cmd)) {
      if (idx + 2 >= argc) {
	      fwprintf(stderr, L"Missing argument(s) for 'write'\n");
	      return 6;
      }
      ret = swscanf(argv[++idx], L"%d", &fd);
      if (ret != 1) {
	      fwprintf(stderr, L"Invalid fd for write: '%ls'\n", argv[idx]);
	      return 7;
      }
      if (write_to_fd(fd, argv[++idx])) return 7;

    } else if (!wcscmp(L"echo", cmd)) {
      if (idx + 3 >= argc) {
	      fwprintf(stderr, L"Missing argument(s) for 'read'\n");
	      return 8;
      }
      ret = swscanf(argv[++idx], L"%d", &fd);
      ret = ret + swscanf(argv[++idx], L"%d", &fd2);
      ret = ret + swscanf(argv[++idx], L"%d", &nbytes);
      if (ret != 3) {
	      fwprintf(stderr, L"Invalid fd1, fd2 or nbytes for read: '%ls', '%ls', '%ls'\n",
		            argv[idx-2], argv[idx-1], argv[idx]);
      	return 9;
      }
      if (echo_from_fd(fd, fd2, nbytes)) return 10;

    } else if (!wcscmp(L"getenv", cmd)) {
      wprintf(L"%ls\n", _wgetenv(argv[++idx]));
      fflush(stdout);

    } else {
      fwprintf(stderr, L"Unknown px command: '%ls'\n", cmd);
      return 2;
    }
  }

  return 0;
}
