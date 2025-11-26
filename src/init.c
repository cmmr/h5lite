#include <R_ext/Rdynload.h>
#include "h5lite.h"

/*
 * This structure defines the mapping between the C function names and the
 * character strings that will be used to call them from R's .Call() interface.
 * The format is: {"r_name", (DL_FUNC) &c_function_name, number_of_arguments}.
 */
static const R_CallMethodDef CallEntries[] = {
  
  /* read.c */
  {"C_h5_read_dataset",   (DL_FUNC) &C_h5_read_dataset, 2},
  {"C_h5_read_attribute", (DL_FUNC) &C_h5_read_attribute, 3},
  
  /* write.c */
  {"C_h5_write_dataset",   (DL_FUNC) &C_h5_write_dataset, 6},
  {"C_h5_write_attribute", (DL_FUNC) &C_h5_write_attribute, 6},
  {"C_h5_create_group",    (DL_FUNC) &C_h5_create_group, 2},
  {"C_h5_move",            (DL_FUNC) &C_h5_move, 3},
  
  /* dataframe.c */
  {"C_h5_write_dataframe", (DL_FUNC) &C_h5_write_dataframe, 5},
  
  /* ls.c */
  {"C_h5_str",     (DL_FUNC) &C_h5_str, 2},
  {"C_h5_ls",      (DL_FUNC) &C_h5_ls, 4},
  {"C_h5_ls_attr", (DL_FUNC) &C_h5_ls_attr, 2},
  
  /* info.c */
  {"C_h5_typeof",      (DL_FUNC) &C_h5_typeof, 2},
  {"C_h5_typeof_attr", (DL_FUNC) &C_h5_typeof_attr, 3},
  {"C_h5_dim",         (DL_FUNC) &C_h5_dim, 2},
  {"C_h5_dim_attr",    (DL_FUNC) &C_h5_dim_attr, 3},
  {"C_h5_exists",      (DL_FUNC) &C_h5_exists, 2},
  {"C_h5_exists_attr", (DL_FUNC) &C_h5_exists_attr, 3},
  {"C_h5_is_group",    (DL_FUNC) &C_h5_is_group, 2},
  {"C_h5_is_dataset",  (DL_FUNC) &C_h5_is_dataset, 2},
  
  /* delete.c */
  {"C_h5_delete", (DL_FUNC) &C_h5_delete, 2},
  {"C_h5_delete_attr", (DL_FUNC) &C_h5_delete_attr, 3},
  
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
