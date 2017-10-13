
#include <testthat.h>

#include "processx.h"

#include <fcntl.h>
#include <cstring>
#include <unistd.h>
#include <errno.h>

int make_temp_file(char **filename) {
  char *wd = getcwd(NULL, 0);
  char *tmpdir = (char*) malloc(snprintf(NULL, 0, "%s/fixtures", wd) + 1);
  sprintf(tmpdir, "%s/fixtures", wd);
  *filename = R_tmpnam2(0, tmpdir, ".test");
  free(tmpdir);
  free(wd);

  int fd = open(*filename, O_WRONLY | O_CREAT | O_TRUNC, S_IRWXU);
  return fd;
}

int open_temp_file(char **filename, size_t bytes, const char *pattern) {
  int fd = make_temp_file(filename);
  int abytes = 0;
  const char *default_pattern = "Nem csak a gyemant es arany\n";
  const char *mypattern = pattern ? pattern : default_pattern;
  size_t pattern_size = strlen(mypattern);

  for (abytes = 0; abytes < bytes; abytes += pattern_size) {
    write(fd, mypattern, pattern_size);
  }

  close(fd);

  fd = open(*filename, O_RDONLY);
  return fd;
}

context("Basics") {

  test_that("can create a connection from os handle") {
    int fd = open("fixtures/simple.txt", O_RDONLY);
    processx_connection_t *ccon =
      processx_c_connection_create(fd, "UTF-8", 0);
    expect_true(ccon != 0);
    processx_c_connection_close(ccon);
  }
}

context("Reading characters") {

  test_that("can read characters and set EOF") {
    int fd = open("fixtures/simple.txt", O_RDONLY);
    expect_true(fd >= 0);
    processx_connection_t *ccon =
      processx_c_connection_create(fd, "UTF-8", 0);

    expect_false(processx_c_connection_is_eof(ccon));

    char buffer[10];
    size_t ret = processx_c_connection_read_chars(ccon, buffer, 10);
    expect_true(ret == 10);
    expect_true(! strncmp(buffer, "simple tex", 10));

    expect_false(processx_c_connection_is_eof(ccon));

    ret = processx_c_connection_read_chars(ccon, buffer, 10);
    expect_true(ret == 7);
    expect_true(! strncmp(buffer, "t file\n", 7));

    expect_false(processx_c_connection_is_eof(ccon));

    ret = processx_c_connection_read_chars(ccon, buffer, 10);
    expect_true(ret == 0);

    expect_true(processx_c_connection_is_eof(ccon));

    processx_c_connection_close(ccon);
  }

  test_that("EOF edge case") {
    int fd = open("fixtures/simple.txt", O_RDONLY);
    expect_true(fd >= 0);
    processx_connection_t *ccon =
      processx_c_connection_create(fd, "UTF-8", 0);

    // Read all contents of the file, it is still not EOF
    char buffer[17];
    size_t ret = processx_c_connection_read_chars(ccon, buffer, 17);
    expect_true(ret == 17);
    expect_true(! strncmp(buffer, "simple text file\n", 17));
    expect_false(processx_c_connection_is_eof(ccon));

    // But if we read again, EOF is set
    ret = processx_c_connection_read_chars(ccon, buffer, 17);
    expect_true(ret == 0);
    expect_true(processx_c_connection_is_eof(ccon));

    processx_c_connection_close(ccon);
  }

  test_that("A larger file that needs buffering") {
    char *filename;
    int fd = open_temp_file(&filename, 100000, 0);
    expect_true(fd >= 0);
    processx_connection_t *ccon =
      processx_c_connection_create(fd, "UTF-8", 0);

    expect_false(processx_c_connection_is_eof(ccon));

    char buffer[1024];
    while (! processx_c_connection_is_eof(ccon)) {
      size_t ret = processx_c_connection_read_chars(ccon, buffer, 1024);
      if (ret == 0) expect_true(processx_c_connection_is_eof(ccon));
    }

    processx_c_connection_close(ccon);
    unlink(filename);
    free(filename);
  }

  test_that("Reading UTF-8 file") {
    char *filename;
    // A 2-byte character, then a 3-byte character, then a 4-byte one
    int fd = open_temp_file(&filename, 1,
			    "\xc2\xa0\xe2\x86\x92\xf0\x90\x84\x82");
    processx_connection_t *ccon =
      processx_c_connection_create(fd, "UTF-8", 0);

    expect_false(processx_c_connection_is_eof(ccon));

    char buffer[4];
    ssize_t ret = processx_c_connection_read_chars(ccon, buffer, 4);
    expect_true(ret == 2);
    expect_true(buffer[0] == '\xc2');
    expect_true(buffer[1] == '\xa0');

    ret = processx_c_connection_read_chars(ccon, buffer, 4);
    expect_true(ret == 3);
    expect_true(buffer[0] == '\xe2');
    expect_true(buffer[1] == '\x86');
    expect_true(buffer[2] == '\x92');

    ret = processx_c_connection_read_chars(ccon, buffer, 4);
    expect_true(ret == 4);
    expect_true(buffer[0] == '\xf0');
    expect_true(buffer[1] == '\x90');
    expect_true(buffer[2] == '\x84');
    expect_true(buffer[3] == '\x82');

    expect_false(processx_c_connection_is_eof(ccon));
    ret = processx_c_connection_read_chars(ccon, buffer, 4);
    expect_true(ret == 0);
    expect_true(processx_c_connection_is_eof(ccon));

    processx_c_connection_close(ccon);
    unlink(filename);
    free(filename);
  }

  test_that("Conversion to UTF-8") {
    char *filename;
    const char *latin1 = "\xe1\xe9\xed";
    const char *utf8 = "\xc3\xa1\xc3\xa9\xc3\xad";
    int fd = open_temp_file(&filename, 1, latin1);

    processx_connection_t *ccon =
      processx_c_connection_create(fd, "latin1", 0);

    expect_false(processx_c_connection_is_eof(ccon));

    char buffer[10];
    ssize_t ret = processx_c_connection_read_chars(ccon, buffer, 10);
    expect_true(ret == 6);
    buffer[6] = '\0';
    expect_true(!strcmp(buffer, utf8));

    expect_false(processx_c_connection_is_eof(ccon));
    ret = processx_c_connection_read_chars(ccon, buffer, 4);
    expect_true(ret == 0);
    expect_true(processx_c_connection_is_eof(ccon));

    processx_c_connection_close(ccon);
    unlink(filename);
    free(filename);
  }

}

context("Reading lines") {

  test_that("Reading a line") {
    char *filename;
    int fd = open_temp_file(&filename, 50, "hello\n");
    expect_true(fd >= 0);
    processx_connection_t *ccon =
      processx_c_connection_create(fd, "UTF-8", 0);

    char *linep = 0;
    size_t linecapp = 0;
    ssize_t read = processx_c_connection_read_line(ccon, &linep, &linecapp);
    expect_true(read == 5);
    expect_true(!strcmp(linep, "hello"));
    expect_true(linecapp == 6);

    processx_c_connection_close(ccon);
    unlink(filename);
    free(filename);
  }

  test_that("Reading the last incomplete line") {
    char *filename;
    int fd = open_temp_file(&filename, 1, "hello\nhello\nagain");
    expect_true(fd >= 0);
    processx_connection_t *ccon =
      processx_c_connection_create(fd, "UTF-8", 0);

    char *linep = 0;
    size_t linecapp = 0;
    ssize_t read;

    for (int i = 0; i < 2; i++) {
      read = processx_c_connection_read_line(ccon, &linep, &linecapp);
      expect_true(linep[5] == '\0');
      expect_true(read == 5);
      expect_true(!strcmp(linep, "hello"));
      expect_true(linecapp == 6);
      expect_false(processx_c_connection_is_eof(ccon));
    }

    read = processx_c_connection_read_line(ccon, &linep, &linecapp);
    expect_true(linep[5] == '\0');
    expect_true(read == 5);
    expect_true(!strcmp(linep, "again"));
    expect_true(linecapp == 6);
    expect_false(processx_c_connection_is_eof(ccon));

    read = processx_c_connection_read_chars(ccon, linep, 4);
    expect_true(read == 0);
    expect_true(processx_c_connection_is_eof(ccon));

    processx_c_connection_close(ccon);
    unlink(filename);
    free(filename);
  }
}
