
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

typedef struct {
    char       *name;
    DL_FUNC     fun;
    int         numArgs;

    R_NativePrimitiveArgType *types;
} Rf_DotCSymbol;

typedef Rf_DotCSymbol Rf_DotFortranSymbol;

typedef struct {
    char       *name;
    DL_FUNC     fun;
    int         numArgs;
} Rf_DotCallSymbol;

typedef Rf_DotCallSymbol Rf_DotExternalSymbol;

struct Rf_RegisteredNativeSymbol {
    NativeSymbolType type;
    union {
	Rf_DotCSymbol        *c;
	Rf_DotCallSymbol     *call;
	Rf_DotFortranSymbol  *fortran;
	Rf_DotExternalSymbol *external;
    } symbol;
    DllInfo *dll;
};

/* --------------------------------------------------------------------- */

struct cleanup_record {
  void (*func)(void*);
  void *data;
};

struct cleanup_data {
  struct cleanup_record *recs;
  int size;
  int next;
};

static struct cleanup_data *active_cleanup_data = NULL;

void r_on_exit_reg(void (*func)(void*), void *data) {
  static struct cleanup_data *acd;
  int size;
  int next;

  acd = active_cleanup_data;
  if (acd == NULL) {
    /* Need to clean this up..... */
    func(data);
    error("r_on_exit must be called from within `safecall()`");
  }
  size = acd->size;
  next = acd->next;

  if (next == size) {
    /* Need to clean this up. The rest is in the stack, so it is cleaned
       up automatically. */
    func(data);
    error("Cleanup stack full");
  }

  acd->recs[next].func = func;
  acd->recs[next].data = data;
  acd->next ++;
}

/* -------------------------------------------------------------------- */

struct argdata {
  DL_FUNC fun;
  SEXP numpar;
  SEXP args;
};

SEXP wrap_unpack(void *data);
void cleanup(void *data);

SEXP safecall(SEXP addr, SEXP numpar, SEXP args) {
  struct Rf_RegisteredNativeSymbol *tmp = R_ExternalPtrAddr(addr);
  DL_FUNC fun = tmp->symbol.call->fun;
  SEXP result = R_NilValue;

  struct argdata argd = { fun, numpar, args };
  struct cleanup_data *old = active_cleanup_data;
  struct cleanup_record recs[100];
  struct cleanup_data new = { recs, 100, 0 };

  active_cleanup_data = &new;

  result = R_ExecWithCleanup(wrap_unpack, &argd, cleanup, old);

  active_cleanup_data = old;

  return result;
}

SEXP wrap_unpack(void *data) {
  struct argdata *argd = data;
  DL_FUNC fun = argd->fun;
  int num = INTEGER(argd->numpar)[0];
  SEXP args = argd->args;
  SEXP r = R_NilValue;

#define X(i) VECTOR_ELT(args, i)

  if (num > 30) error("Too many arguments, max 30 is handled currently");

  switch (num) {
  case 0:
    r = fun();
    break;
  case 1:
    r = fun(X(0));
    break;
  case 2:
    r = fun(X(0),X(1));
    break;
  case 3:
    r = fun(X(0),X(1),X(2));
    break;
  case 4:
    r = fun(X(0),X(1),X(2),X(3));
    break;
  case 5:
    r = fun(X(0),X(1),X(2),X(3),X(4));
    break;
  case 6:
    r = fun(X(0),X(1),X(2),X(3),X(4),X(5));
    break;
  case 7:
    r = fun(X(0),X(1),X(2),X(3),X(4),X(5),X(6));
    break;
  case 8:
    r = fun(X(0),X(1),X(2),X(3),X(4),X(5),X(6),X(7));
    break;
  case 9:
    r = fun(X(0),X(1),X(2),X(3),X(4),X(5),X(6),X(7),X(8));
    break;
  case 10:
    r = fun(X(0),X(1),X(2),X(3),X(4),X(5),X(6),X(7),X(8),X(9));
    break;
  case 11:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10));
    break;
  case 12:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11));
    break;
  case 13:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12));
    break;
  case 14:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13));
    break;
  case 15:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14));
    break;
  case 16:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15));
    break;
  case 17:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16));
    break;
  case 18:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17));
    break;
  case 19:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18));
    break;
  case 20:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19));
    break;
  case 21:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20));
    break;
  case 22:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20),X(21));
    break;
  case 23:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20),X(21),X(22));
    break;
  case 24:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20),X(21),X(22),X(23));
    break;
  case 25:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20),X(21),X(22),X(23),X(24));
    break;
  case 26:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20),X(21),X(22),X(23),X(24),X(25));
    break;
  case 27:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20),X(21),X(22),X(23),X(24),X(25),X(26));
    break;
  case 28:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20),X(21),X(22),X(23),X(24),X(25),X(26),X(27));
    break;
  case 29:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20),X(21),X(22),X(23),X(24),X(25),X(26),X(27),X(28));
    break;
  case 30:
    r = fun(X( 0),X( 1),X( 2),X( 3),X( 4),X( 5),X( 6),X( 7),X( 8),X( 9),
	    X(10),X(11),X(12),X(13),X(14),X(15),X(16),X(17),X(18),X(19),
	    X(20),X(21),X(22),X(23),X(24),X(25),X(26),X(27),X(28),X(29));
    break;
  }

#undef X

  return r;
}

void cleanup(void *old) {
  static struct cleanup_data *acd;
  int size;
  int next;

  acd = active_cleanup_data;
  size = acd->size;
  next = acd->next;

  while (next > 0) {
    next--;
    acd->recs[next].func(acd->recs[next].data);
  }

  active_cleanup_data = old;
}
