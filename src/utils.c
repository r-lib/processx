#include <Rinternals.h>
#include "processx.h"

// Need to jump out of the `R_UnwindProtect()` context
#include <setjmp.h>

r_no_return
void r_unwind(SEXP x) {
  if (inherits(x, "error")) {
    SEXP call = PROTECT(lang2(install("stop"), x));
    eval(call, R_BaseEnv);
  } else {
    R_ContinueUnwind(x);
  }
  error("Unreachable");
}

static
void unwind_cleanup(void *payload, Rboolean jump) {
  if (jump) {
    jmp_buf *env = (jmp_buf *) payload;
    longjmp(*env, 1);
  }
}

// Conversion of SEXP-returning callback to a void-returning one
struct callback_compat {
  void (*fn)(void *data);
  void *data;
};

static
SEXP callback_compat(void *payload) {
  struct callback_compat *data = (struct callback_compat *) payload;
  data->fn(data->data);
  return R_NilValue;
}

SEXP r_unwind_protect(void (*fn)(void *data), void *data) {
  SEXP cont = PROTECT(R_MakeUnwindCont());
  jmp_buf env;

  struct callback_compat compat_data = {
    .fn = fn,
    .data = data
  };

  if (setjmp(env)) {
    UNPROTECT(1);
    return cont;
  }

  R_UnwindProtect(&callback_compat, &compat_data, &unwind_cleanup, &env, cont);

  UNPROTECT(1);
  return NULL;
}

struct safe_eval {
  SEXP expr;
  SEXP env;
  SEXP *out;
};

static
void safe_eval_callback(void *payload) {
  struct safe_eval *data = (struct safe_eval *) payload;
  SEXP out = eval(data->expr, data->env);

  if (data->out) {
    *data->out = out;
  }
}

SEXP r_safe_eval(SEXP expr, SEXP env, SEXP *out) {
  struct safe_eval data = { .expr = expr, .env = env, .out = out };
  return r_unwind_protect(&safe_eval_callback, &data);
}
