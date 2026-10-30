#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include "hdf5lib.h"
#include "h5lite.h"


SEXP C_register_hdf5_filters(void) {
  hdf5lib_register_all_filters();

  /* h5lite reports every failure as an R error with its own message, so
   * HDF5's automatic error-stack dumps would only be noise in the console. */
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);

  return R_NilValue;
}

/* The number of threads for everything in h5lite that runs in parallel
 * (currently the Blosc and Blosc2 filters).  0 means none was set. */
#define H5LITE_MAX_THREADS 256
static int nthreads_setting = 0;

/* h5_threads() takes precedence.  Without it, the default is the
 * H5LITE_NTHREADS environment variable, then one thread. */
static int h5lite_nthreads(void) {
  if (nthreads_setting > 0) return nthreads_setting;
  const char *env = getenv("H5LITE_NTHREADS");
  if (env != NULL) {
    char *end;
    long n = strtol(env, &end, 10);
    if (end != env && n > 0)
      return (n > H5LITE_MAX_THREADS) ? H5LITE_MAX_THREADS : (int)n;
  }
  return 1;
}

/* Hands the thread count to each threaded feature.  Called at the start of
 * every dataset read and write, so a change to H5LITE_NTHREADS made with
 * Sys.setenv() applies to the next call. */
void apply_nthreads(void) {
#ifdef HDF5LIB_BLOSC2_BITSHUFFLE
  hdf5lib_set_blosc_nthreads(h5lite_nthreads());
#else
  /* hdf5lib 2.2.0.0 has no thread setting (nor the Blosc2 constants that
   * hdf5lib.h gained with it), so Blosc runs on one thread there. */
#endif
}

/* Gets (n = NULL) or sets the number of threads h5lite uses.
 * Setting returns the previous setting; 0 means none (use the default). */
SEXP C_h5_threads(SEXP n) {
  if (n == R_NilValue) return ScalarInteger(h5lite_nthreads());
  int previous = nthreads_setting;
  nthreads_setting = asInteger(n);
  return ScalarInteger(previous);
}

// # nocov start
SEXP C_destroy_hdf5_filters(void) {
  hdf5lib_destroy_all_filters();
  return R_NilValue;
}
// # nocov end


/*
 * This structure defines the mapping between the C function names and the
 * character strings that will be used to call them from R's .Call() interface.
 * The format is: {"r_name", (DL_FUNC) &c_function_name, number_of_arguments}.
 */
static const R_CallMethodDef CallEntries[] = {
  
  /* init.c */
  {"C_register_hdf5_filters", (DL_FUNC) &C_register_hdf5_filters, 0},
  {"C_destroy_hdf5_filters",  (DL_FUNC) &C_destroy_hdf5_filters,  0},
  {"C_h5_threads",            (DL_FUNC) &C_h5_threads,            1},
  
  /* info.c */
  {"C_h5_typeof",      (DL_FUNC) &C_h5_typeof, 2},
  {"C_h5_typeof_attr", (DL_FUNC) &C_h5_typeof_attr, 3},
  {"C_h5_dim",         (DL_FUNC) &C_h5_dim, 2},
  {"C_h5_dim_attr",    (DL_FUNC) &C_h5_dim_attr, 3},
  {"C_h5_exists",      (DL_FUNC) &C_h5_exists, 3},
  {"C_h5_is_group",    (DL_FUNC) &C_h5_is_group, 2},
  {"C_h5_is_dataset",  (DL_FUNC) &C_h5_is_dataset, 2},
  {"C_h5_names",       (DL_FUNC) &C_h5_names, 3},
  {"C_h5_attr_names",  (DL_FUNC) &C_h5_attr_names, 2},
  
  /* inspect.c */
  {"C_h5_inspect",     (DL_FUNC) &C_h5_inspect, 2},
  
  /* ls.c */
  {"C_h5_str", (DL_FUNC) &C_h5_str, 5},
  {"C_h5_ls",  (DL_FUNC) &C_h5_ls, 6},
  
  /* organize.c */
  {"C_h5_create_group", (DL_FUNC) &C_h5_create_group, 2},
  {"C_h5_move",         (DL_FUNC) &C_h5_move, 3},
  {"C_h5_delete",       (DL_FUNC) &C_h5_delete, 2},
  {"C_h5_delete_attr",  (DL_FUNC) &C_h5_delete_attr, 3},
  
  /* read.c */
  {"C_h5_read_dataset",   (DL_FUNC) &C_h5_read_dataset, 6},
  {"C_h5_read_attribute", (DL_FUNC) &C_h5_read_attribute, 4},
  
  /* write.c */
  {"C_h5_write_dataset",   (DL_FUNC) &C_h5_write_dataset, 6},
  {"C_h5_write_attribute", (DL_FUNC) &C_h5_write_attribute, 6},

  /* util.c */
  {"C_h5_open_id_count", (DL_FUNC) &C_h5_open_id_count, 0},
  {"C_h5_close_all",     (DL_FUNC) &C_h5_close_all,     0},

  {NULL, NULL, 0}
};

/*
 * This function is called by R when the package is loaded.
 * It registers the C functions defined in CallEntries with R's dynamic loading system.
 * R_useDynamicSymbols(dll, FALSE) tells R that we are providing an explicit registration list.
 */
void R_init_h5lite(DllInfo *dll) {
  R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
}
