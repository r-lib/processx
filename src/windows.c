
void processx_win_dummy() { }

#ifdef WIN32

#include <windows.h>

#include "utils.h"
#include "windows-stdio.h"

int uv_utf8_to_utf16_alloc(const char* s, WCHAR** ws_ptr) {
  int ws_len, r;
  WCHAR* ws;

  ws_len = MultiByteToWideChar(
    /* CodePage =       */ CP_UTF8,
    /* dwFlags =        */ 0,
    /* lpMultiByteStr = */ s,
    /* cbMultiByte =    */ -1,
    /* lpWideCharStr =  */ NULL,
    /* cchWideChar =    */ 0);

  if (ws_len <= 0) { return GetLastError(); }

  ws = (WCHAR*) R_alloc(ws_len,  sizeof(WCHAR));
  if (ws == NULL) { return ERROR_OUTOFMEMORY; }

  r = MultiByteToWideChar(
    /* CodePage =       */ CP_UTF8,
    /* dwFlags =        */ 0,
    /* lpMultiByteStr = */ s,
    /* cbMultiBytes =   */ -1,
    /* lpWideCharStr =  */ ws,
    /* cchWideChar =    */ ws_len);

  if (r != ws_len) {
    error("processx error interpreting UTF8 command or arguments");
  }

  *ws_ptr = ws;
  return 0;
}

WCHAR* processx__quote_cmd_arg(const WCHAR *source, WCHAR *target) {
  size_t len = wcslen(source);
  size_t i;
  int quote_hit;
  WCHAR* start;

  if (len == 0) {
    /* Need double quotation for empty argument */
    *(target++) = L'"';
    *(target++) = L'"';
    return target;
  }

  if (NULL == wcspbrk(source, L" \t\"")) {
    /* No quotation needed */
    wcsncpy(target, source, len);
    target += len;
    return target;
  }

  if (NULL == wcspbrk(source, L"\"\\")) {
    /*
     * No embedded double quotes or backlashes, so I can just wrap
     * quote marks around the whole thing.
     */
    *(target++) = L'"';
    wcsncpy(target, source, len);
    target += len;
    *(target++) = L'"';
    return target;
  }

  /*
   * Expected input/output:
   *   input : hello"world
   *   output: "hello\"world"
   *   input : hello""world
   *   output: "hello\"\"world"
   *   input : hello\world
   *   output: hello\world
   *   input : hello\\world
   *   output: hello\\world
   *   input : hello\"world
   *   output: "hello\\\"world"
   *   input : hello\\"world
   *   output: "hello\\\\\"world"
   *   input : hello world\
   *   output: "hello world\\"
   */

  *(target++) = L'"';
  start = target;
  quote_hit = 1;

  for (i = len; i > 0; --i) {
    *(target++) = source[i - 1];

    if (quote_hit && source[i - 1] == L'\\') {
      *(target++) = L'\\';
    } else if(source[i - 1] == L'"') {
      quote_hit = 1;
      *(target++) = L'\\';
    } else {
      quote_hit = 0;
    }
  }
  target[0] = L'\0';
  wcsrev(start);
  *(target++) = L'"';
  return target;
}

static int processx__make_program_args(SEXP args, int verbatim_arguments,
				       WCHAR **dst_ptr) {
  const char* arg;
  WCHAR* dst = NULL;
  WCHAR* temp_buffer = NULL;
  size_t dst_len = 0;
  size_t temp_buffer_len = 0;
  WCHAR* pos;
  int arg_count = LENGTH(args);
  int err = 0;
  int i;

  /* Count the required size. */
  for (i = 0; i < arg_count; i++) {
    DWORD arg_len;
    arg = CHAR(STRING_ELT(args, i));

    arg_len = MultiByteToWideChar(
    /* CodePage =       */ CP_UTF8,
    /* dwFlags =        */ 0,
    /* lpMultiByteStr = */ arg,
    /* cbMultiBytes =   */ -1,
    /* lpWideCharStr =  */ NULL,
    /* cchWideChar =    */ 0);

    if (arg_len == 0) { return GetLastError(); }

    dst_len += arg_len;

    if (arg_len > temp_buffer_len) { temp_buffer_len = arg_len; }
  }

  /* Adjust for potential quotes. Also assume the worst-case scenario */
  /* that every character needs escaping, so we need twice as much space. */
  dst_len = dst_len * 2 + arg_count * 2;

  /* Allocate buffer for the final command line. */
  dst = (WCHAR*) R_alloc(dst_len, sizeof(WCHAR));

  /* Allocate temporary working buffer. */
  temp_buffer = (WCHAR*) R_alloc(temp_buffer_len, sizeof(WCHAR));

  pos = dst;
  for (i = 0; i < arg_count; i++) {
    DWORD arg_len;
    arg = CHAR(STRING_ELT(args, i));

    /* Convert argument to wide char. */
    arg_len = MultiByteToWideChar(
    /* CodePage =       */ CP_UTF8,
    /* dwFlags =        */ 0,
    /* lpMultiByteStr = */ arg,
    /* cbMultiBytes =   */ -1,
    /* lpWideCharStr =  */ temp_buffer,
    /* cchWideChar =    */ (int) (dst + dst_len - pos));

    if (arg_len == 0) {
      err = GetLastError();
      goto error;
    }

    if (verbatim_arguments) {
      /* Copy verbatim. */
      wcscpy(pos, temp_buffer);
      pos += arg_len - 1;
    } else {
      /* Quote/escape, if needed. */
      pos = processx__quote_cmd_arg(temp_buffer, pos);
    }

    *pos++ = i < arg_count - 1 ? L' ' : L'\0';
  }

  *dst_ptr = dst;
  return 0;

error:
  return err;
}

static WCHAR* processx__search_path_join_test(const WCHAR* dir,
					      size_t dir_len,
					      const WCHAR* name,
					      size_t name_len,
					      const WCHAR* ext,
					      size_t ext_len,
					      const WCHAR* cwd,
					      size_t cwd_len) {
  WCHAR *result, *result_pos;
  DWORD attrs;
  if (dir_len > 2 && dir[0] == L'\\' && dir[1] == L'\\') {
    /* It's a UNC path so ignore cwd */
    cwd_len = 0;
  } else if (dir_len >= 1 && (dir[0] == L'/' || dir[0] == L'\\')) {
    /* It's a full path without drive letter, use cwd's drive letter only */
    cwd_len = 2;
  } else if (dir_len >= 2 && dir[1] == L':' &&
      (dir_len < 3 || (dir[2] != L'/' && dir[2] != L'\\'))) {
    /* It's a relative path with drive letter (ext.g. D:../some/file)
     * Replace drive letter in dir by full cwd if it points to the same drive,
     * otherwise use the dir only.
     */
    if (cwd_len < 2 || _wcsnicmp(cwd, dir, 2) != 0) {
      cwd_len = 0;
    } else {
      dir += 2;
      dir_len -= 2;
    }
  } else if (dir_len > 2 && dir[1] == L':') {
    /* It's an absolute path with drive letter
     * Don't use the cwd at all
     */
    cwd_len = 0;
  }

  /* Allocate buffer for output */
  result = result_pos = (WCHAR*) R_alloc(
    (cwd_len + 1 + dir_len + 1 + name_len + 1 + ext_len + 1),
    sizeof(WCHAR));

  /* Copy cwd */
  wcsncpy(result_pos, cwd, cwd_len);
  result_pos += cwd_len;

  /* Add a path separator if cwd didn't end with one */
  if (cwd_len && wcsrchr(L"\\/:", result_pos[-1]) == NULL) {
    result_pos[0] = L'\\';
    result_pos++;
  }

  /* Copy dir */
  wcsncpy(result_pos, dir, dir_len);
  result_pos += dir_len;

  /* Add a separator if the dir didn't end with one */
  if (dir_len && wcsrchr(L"\\/:", result_pos[-1]) == NULL) {
    result_pos[0] = L'\\';
    result_pos++;
  }

  /* Copy filename */
  wcsncpy(result_pos, name, name_len);
  result_pos += name_len;

  if (ext_len) {
    /* Add a dot if the filename didn't end with one */
    if (name_len && result_pos[-1] != '.') {
      result_pos[0] = L'.';
      result_pos++;
    }

    /* Copy extension */
    wcsncpy(result_pos, ext, ext_len);
    result_pos += ext_len;
  }

  /* Null terminator */
  result_pos[0] = L'\0';

  attrs = GetFileAttributesW(result);

  if (attrs != INVALID_FILE_ATTRIBUTES &&
      !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
    return result;
  }

  return NULL;
}


/*
 * Helper function for search_path
 */
static WCHAR* processx__path_search_walk_ext(const WCHAR *dir,
					     size_t dir_len,
					     const WCHAR *name,
					     size_t name_len,
					     WCHAR *cwd,
					     size_t cwd_len,
					     int name_has_ext) {
  WCHAR* result;

  /* If the name itself has a nonempty extension, try this extension first */
  if (name_has_ext) {
    result = processx__search_path_join_test(dir, dir_len,
					     name, name_len,
					     L"", 0,
					     cwd, cwd_len);
    if (result != NULL) {
      return result;
    }
  }

  /* Try .com extension */
  result = processx__search_path_join_test(dir, dir_len,
					   name, name_len,
					   L"com", 3,
					   cwd, cwd_len);
  if (result != NULL) {
    return result;
  }

  /* Try .exe extension */
  result = processx__search_path_join_test(dir, dir_len,
					   name, name_len,
					   L"exe", 3,
					   cwd, cwd_len);
  if (result != NULL) {
    return result;
  }

  return NULL;
}


/*
 * search_path searches the system path for an executable filename -
 * the windows API doesn't provide this as a standalone function nor as an
 * option to CreateProcess.
 *
 * It tries to return an absolute filename.
 *
 * Furthermore, it tries to follow the semantics that cmd.exe, with this
 * exception that PATHEXT environment variable isn't used. Since CreateProcess
 * can start only .com and .exe files, only those extensions are tried. This
 * behavior equals that of msvcrt's spawn functions.
 *
 * - Do not search the path if the filename already contains a path (either
 *   relative or absolute).
 *
 * - If there's really only a filename, check the current directory for file,
 *   then search all path directories.
 *
 * - If filename specified has *any* extension, search for the file with the
 *   specified extension first.
 *
 * - If the literal filename is not found in a directory, try *appending*
 *   (not replacing) .com first and then .exe.
 *
 * - The path variable may contain relative paths; relative paths are relative
 *   to the cwd.
 *
 * - Directories in path may or may not end with a trailing backslash.
 *
 * - CMD does not trim leading/trailing whitespace from path/pathex entries
 *   nor from the environment variables as a whole.
 *
 * - When cmd.exe cannot read a directory, it will just skip it and go on
 *   searching. However, unlike posix-y systems, it will happily try to run a
 *   file that is not readable/executable; if the spawn fails it will not
 *   continue searching.
 *
 * UNC path support: we are dealing with UNC paths in both the path and the
 * filename. This is a deviation from what cmd.exe does (it does not let you
 * start a program by specifying an UNC path on the command line) but this is
 * really a pointless restriction.
 *
 */
static WCHAR* processx__search_path(const WCHAR *file,
				    WCHAR *cwd,
				    const WCHAR *path) {
  int file_has_dir;
  WCHAR* result = NULL;
  WCHAR *file_name_start;
  WCHAR *dot;
  const WCHAR *dir_start, *dir_end, *dir_path;
  size_t dir_len;
  int name_has_ext;

  size_t file_len = wcslen(file);
  size_t cwd_len = wcslen(cwd);

  /* If the caller supplies an empty filename,
   * we're not gonna return c:\windows\.exe -- GFY!
   */
  if (file_len == 0
      || (file_len == 1 && file[0] == L'.')) {
    return NULL;
  }

  /* Find the start of the filename so we can split the directory from the */
  /* name. */
  for (file_name_start = (WCHAR*)file + file_len;
       file_name_start > file
           && file_name_start[-1] != L'\\'
           && file_name_start[-1] != L'/'
           && file_name_start[-1] != L':';
       file_name_start--);

  file_has_dir = file_name_start != file;

  /* Check if the filename includes an extension */
  dot = wcschr(file_name_start, L'.');
  name_has_ext = (dot != NULL && dot[1] != L'\0');

  if (file_has_dir) {
    /* The file has a path inside, don't use path */
    result = processx__path_search_walk_ext(
        file, file_name_start - file,
        file_name_start, file_len - (file_name_start - file),
        cwd, cwd_len,
        name_has_ext);

  } else {
    dir_end = path;

    /* The file is really only a name; look in cwd first, then scan path */
    result = processx__path_search_walk_ext(L"", 0,
					    file, file_len,
					    cwd, cwd_len,
					    name_has_ext);

    while (result == NULL) {
      if (*dir_end == L'\0') {
        break;
      }

      /* Skip the separator that dir_end now points to */
      if (dir_end != path || *path == L';') {
        dir_end++;
      }

      /* Next slice starts just after where the previous one ended */
      dir_start = dir_end;

      /* Slice until the next ; or \0 is found */
      dir_end = wcschr(dir_start, L';');
      if (dir_end == NULL) {
        dir_end = wcschr(dir_start, L'\0');
      }

      /* If the slice is zero-length, don't bother */
      if (dir_end - dir_start == 0) {
        continue;
      }

      dir_path = dir_start;
      dir_len = dir_end - dir_start;

      /* Adjust if the path is quoted. */
      if (dir_path[0] == '"' || dir_path[0] == '\'') {
        ++dir_path;
        --dir_len;
      }

      if (dir_path[dir_len - 1] == '"' || dir_path[dir_len - 1] == '\'') {
        --dir_len;
      }

      result = processx__path_search_walk_ext(dir_path, dir_len,
					      file, file_len,
					      cwd, cwd_len,
					      name_has_ext);
    }
  }

  return result;
}

void processx__error(DWORD errorcode) {
  LPVOID lpMsgBuf;
  char *msg;

  FormatMessage(
    FORMAT_MESSAGE_ALLOCATE_BUFFER |
    FORMAT_MESSAGE_FROM_SYSTEM |
    FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL,
    errorcode,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    (LPTSTR) &lpMsgBuf,
    0, NULL );

  msg = R_alloc(1, strlen(lpMsgBuf) + 1);
  strcpy(msg, lpMsgBuf);
  LocalFree(lpMsgBuf);

  error("processx error: %s", msg);
}

void processx__collect_exit_status(SEXP status, DWORD exitcode);

void processx__finalizer(SEXP status) {
  processx_handle_t *handle = (processx_handle_t*) R_ExternalPtrAddr(status);
  SEXP private;
  DWORD err;

  if (!handle) return;

  /* Just in case it is running */
  err = TerminateProcess(handle->hProcess, 1);
  if (err) processx__collect_exit_status(status, 1);
  WaitForSingleObject(handle->hProcess, INFINITE);

  /* Copy over pid and exit status */
  private = R_ExternalPtrTag(status);
  defineVar(install("exited"), ScalarLogical(1), private);
  defineVar(install("pid"), ScalarInteger(handle->dwProcessId), private);
  defineVar(install("exitcode"), ScalarInteger(handle->exitcode), private);

  if (handle->child_stdio_buffer) {
    CloseHandle(processx__stdio_handle(handle->child_stdio_buffer, 0));
    CloseHandle(processx__stdio_handle(handle->child_stdio_buffer, 1));
    CloseHandle(processx__stdio_handle(handle->child_stdio_buffer, 2));
  }
  if (handle->hProcess) CloseHandle(handle->hProcess);
  processx__handle_destroy(handle);
  R_ClearExternalPtr(status);
}

/* This is not strictly necessary, but we might as well do it.... */

static void CALLBACK processx__exit_callback(void* data, BOOLEAN didTimeout) {
  processx_handle_t *handle = (processx_handle_t *) data;
  DWORD err, exitcode;
  
  /* Still need to wait a bit, otherwise we might crash.... */
  WaitForSingleObject(handle->hProcess, INFINITE);
  err = GetExitCodeProcess(handle->hProcess, &exitcode);
  if (!err) return;

  if (handle->collected) return;
  handle->exitcode = exitcode;
  handle->collected = 1;
}

SEXP processx__make_handle(SEXP private) {
  processx_handle_t * handle;
  SEXP result;

  handle = (processx_handle_t*) malloc(sizeof(processx_handle_t));
  if (!handle) { error("Out of memory"); }
  memset(handle, 0, sizeof(processx_handle_t));

  result = PROTECT(R_MakeExternalPtr(handle, private, R_NilValue));
  R_RegisterCFinalizerEx(result, processx__finalizer, 1);

  UNPROTECT(1);
  return result;
}

SEXP processx_exec(SEXP command, SEXP args, SEXP std_out, SEXP std_err,
		   SEXP detached, SEXP windows_verbatim_args, SEXP windows_hide,
		   SEXP private) {

  const char *cstd_out = isNull(std_out) ? 0 : CHAR(STRING_ELT(std_out, 0));
  const char *cstd_err = isNull(std_err) ? 0 : CHAR(STRING_ELT(std_err, 0));

  int err = 0;
  WCHAR *path;
  WCHAR *application_path = NULL, *application = NULL, *arguments = NULL,
    *cwd = NULL;
  processx_options_t options;
  STARTUPINFOW startup;
  PROCESS_INFORMATION info;
  DWORD process_flags;

  processx_handle_t *handle;
  SEXP result;
  BOOL regerr;

  options.detached = LOGICAL(detached)[0];
  options.windows_verbatim_args = LOGICAL(windows_verbatim_args)[0];
  options.windows_hide = LOGICAL(windows_hide)[0];

  err = uv_utf8_to_utf16_alloc(CHAR(STRING_ELT(command, 0)), &application);
  if (err) { processx__error(err); }

  err = processx__make_program_args(
      args,
      options.windows_verbatim_args,
      &arguments);
  if (err) { processx__error(err); }

  /* Inherit cwd */
  {
    DWORD cwd_len, r;

    cwd_len = GetCurrentDirectoryW(0, NULL);
    if (!cwd_len) { processx__error(GetLastError()); }

    cwd = (WCHAR*) R_alloc(cwd_len, sizeof(WCHAR));

    r = GetCurrentDirectoryW(cwd_len, cwd);
    if (r == 0 || r >= cwd_len) { processx__error(GetLastError()); }
  }

  /* Get PATH environment variable */
  {
    DWORD path_len, r;

    path_len = GetEnvironmentVariableW(L"PATH", NULL, 0);
    if (!path_len) { processx__error(GetLastError()); }

    path = (WCHAR*) R_alloc(path_len, sizeof(WCHAR));

    r = GetEnvironmentVariableW(L"PATH", path, path_len);
    if (r == 0 || r >= path_len) { processx__error(GetLastError()); }
  }

  result = PROTECT(processx__make_handle(private));
  handle = R_ExternalPtrAddr(result);

  err = processx__stdio_create(cstd_out, cstd_err, &handle->child_stdio_buffer);
  if (err) { processx__error(err); }

  application_path = processx__search_path(application, cwd, path);
  if (!application_path) { free(handle); error("Command not found"); }

  startup.cb = sizeof(startup);
  startup.lpReserved = NULL;
  startup.lpDesktop = NULL;
  startup.lpTitle = NULL;
  startup.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;

  startup.cbReserved2 = processx__stdio_size(handle->child_stdio_buffer);
  startup.lpReserved2 = (BYTE*) handle->child_stdio_buffer;

  startup.hStdInput = processx__stdio_handle(handle->child_stdio_buffer, 0);
  startup.hStdOutput = processx__stdio_handle(handle->child_stdio_buffer, 1);
  startup.hStdError = processx__stdio_handle(handle->child_stdio_buffer, 2);
  startup.wShowWindow = options.windows_hide ? SW_HIDE : SW_SHOWDEFAULT;

  process_flags = CREATE_UNICODE_ENVIRONMENT;

  if (options.detached) {
    /* Note that we're not setting the CREATE_BREAKAWAY_FROM_JOB flag. That
     * means that libuv might not let you create a fully daemonized process
     * when run under job control. However the type of job control that libuv
     * itself creates doesn't trickle down to subprocesses so they can still
     * daemonize.
     *
     * A reason to not do this is that CREATE_BREAKAWAY_FROM_JOB makes the
     * CreateProcess call fail if we're under job control that doesn't allow
     * breakaway.
     */
    process_flags |= DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP;
  }

  err = CreateProcessW(
    /* lpApplicationName =    */ application_path,
    /* lpCommandLine =        */ arguments,
    /* lpProcessAttributes =  */ NULL,
    /* lpThreadAttributes =   */ NULL,
    /* bInheritHandles =      */ 1,
    /* dwCreationFlags =      */ process_flags,
    /* lpEnvironment =        */ NULL,
    /* lpCurrentDirectory =   */ cwd,
    /* lpStartupInfo =        */ &startup,
    /* lpProcessInformation = */ &info);

  if (!err) { processx__error(err); }

  handle->hProcess = info.hProcess;
  handle->dwProcessId = info.dwProcessId;

  CloseHandle(info.hThread);

  regerr = RegisterWaitForSingleObject(
    &handle->waitObject,
    handle->hProcess,
    processx__exit_callback,
    (void*) handle,
    /* dwMilliseconds = */ INFINITE,
    WT_EXECUTEINWAITTHREAD | WT_EXECUTEONLYONCE);

  if (!regerr) {
    /* This also kills the process, in the finalizer */
    processx__error(GetLastError());
  }

  UNPROTECT(1);
  return result;
}

/* Process status and related functions.

 * `process_wait`:
    1. If we already have its exit status, return immediately.
    2. Othewise do a blocking WaitForSingleObject.
    3. Then collect exit status.

 * `process_is_alive`:
    1. If we already have its exit status, then return `FALSE`.
    2. Otherwise do a GetExitCodeProcess.
    3. If it is running return `TRUE`, otherwise `FALSE`.

 * `process_get_exit_status`:
    1. If we already have the exit status, then return that.
    2. Otherwise do a GetExitCodeProcess.
    3. If the process has finished, then collect the exit status, and return it.
    4. Otherwise return `NULL`, the process is still running.

 * `process_signal`:
    1. If we already have its exit status, return with `FALSE`.
    2. Otherwise deliver the signal. If successful, return `TRUE`, otherwise
       `FALSE`. Only a limited set of signals are supported.

 * `process_kill`:
    1. If we already have its exit status, return with `FALSE`.
    2. Otherwise call GetExitCodeProcess.
    3. If the process is not running, collect the exit status, and
       return `FALSE`.
    4. Otherwise kill the process, and collect the exit status.
    5. If the killing was successful, return `TRUE`, otherwise `FALSE`.

    The return value of `process_kill()` is `TRUE` if the process was
    indeed killed by the signal. It is `FALSE` otherwise, i.e. if the
    process finished.

 * Finalizers (`processx__finalizer`):

   Finalizers are called on the handle only, so we do not know if the
   process has already finished or not.

   1. Run `GetExitCodeProcess` to see if it has finished already.
   2. If yes, then free memory.
   3. Otherwise terminate it.
   4. Free memory.

 */

void processx__collect_exit_status(SEXP status, DWORD exitcode) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  handle->exitcode = exitcode;
  handle->collected = 1;
}

SEXP processx_wait(SEXP status) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  DWORD err, err2, exitcode;

  if (handle->collected) return R_NilValue;

  /* Othewise do a blocking wait */
  err2 = WaitForSingleObject(handle->hProcess, INFINITE);
  if (err2 == WAIT_FAILED) { processx__error(GetLastError()); }

  /* Collect  */
  err = GetExitCodeProcess(handle->hProcess, &exitcode);
  if (!err) { processx__error(GetLastError()); }

  processx__collect_exit_status(status, exitcode);

  return R_NilValue;
}

SEXP processx_is_alive(SEXP status) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  DWORD err, exitcode;

  if (handle->collected) return ScalarLogical(0);

  /* Otherwise try to get exit code */
  err = GetExitCodeProcess(handle->hProcess, &exitcode);
  if (!err) { processx__error(GetLastError()); }

  if (exitcode == STILL_ACTIVE) {
    return ScalarLogical(1);
  } else {
    processx__collect_exit_status(status, exitcode);
    return ScalarLogical(0);
  }
}

SEXP processx_get_exit_status(SEXP status) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  DWORD err, exitcode;

  if (handle->collected) return ScalarInteger(handle->exitcode);

  /* Otherwise try to get exit code */
  err = GetExitCodeProcess(handle->hProcess, &exitcode);
  if (!err) {processx__error(GetLastError()); }

  if (exitcode == STILL_ACTIVE) {
    return R_NilValue;
  } else {
    processx__collect_exit_status(status, exitcode);
    return ScalarInteger(handle->exitcode);
  }
}

SEXP processx_signal(SEXP status, SEXP signal) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  DWORD err, exitcode = STILL_ACTIVE;

  if (handle->collected) return ScalarLogical(0);

  switch (INTEGER(signal)[0]) {

  case 15:   /* SIGTERM */
  case 9:    /* SIGKILL */
  case 2: {  /* SIGINT */
    /* Call GetExitCodeProcess to see if it is done */
    /* TODO: there is a race condition here, might finish right before
       we are terminating it... */
    err = GetExitCodeProcess(handle->hProcess, &exitcode);
    if (!err) { processx__error(GetLastError()); }

    if (exitcode == STILL_ACTIVE) {
      err = TerminateProcess(handle->hProcess, 1);
      if (err) {
	processx__collect_exit_status(status, 1);
	return ScalarLogical(0);
      } else {
	return ScalarLogical(1);
      }

    } else {
      processx__collect_exit_status(status, exitcode);
      return ScalarLogical(0);
    }
  }

  case 0: {
    /* Health check: is the process still alive? */
    err = GetExitCodeProcess(handle->hProcess, &exitcode);
    if (!err) { processx__error(GetLastError()); }

    if (exitcode == STILL_ACTIVE) {
      return ScalarLogical(1);
    } else {
      return ScalarLogical(0);
    }
  }

  default:
    error("Unsupported signal on this platform");
    return R_NilValue;
  }
}

SEXP processx_kill(SEXP status, SEXP grace) {
  return processx_signal(status, ScalarInteger(9));
}

SEXP processx_get_pid(SEXP status) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);

  if (!handle) { error("Internal processx error, handle already removed"); }

  return ScalarInteger(handle->dwProcessId);
}

#endif
