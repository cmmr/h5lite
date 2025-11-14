#include <R_ext/Rdynload.h>
#include "h5lite.h"

static const R_CallMethodDef CallEntries[] = {
  /* read.c */
  {"C_h5_read_dataset",   (DL_FUNC) &C_h5_read_dataset, 2},
  {"C_h5_read_attribute", (DL_FUNC) &C_h5_read_attribute, 3},
  
  /* write.c */
  {"C_h5_write_dataset",   (DL_FUNC) &C_h5_write_dataset, 6},
  {"C_h5_write_attribute", (DL_FUNC) &C_h5_write_attribute, 6},
  {"C_h5_create_group", (DL_FUNC) &C_h5_create_group, 2},
  
  /* ls.c */
  {"C_h5_ls",      (DL_FUNC) &C_h5_ls, 3},
  {"C_h5_ls_attr", (DL_FUNC) &C_h5_ls_attr, 2},
  
  /* info.c */
  {"C_h5_typeof",      (DL_FUNC) &C_h5_typeof, 2},
  {"C_h5_typeof_attr", (DL_FUNC) &C_h5_typeof_attr, 3},
  {"C_h5_dim",         (DL_FUNC) &C_h5_dim, 2},
  {"C_h5_dim_attr",    (DL_FUNC) &C_h5_dim_attr, 3},
  
  /* delete.c */
  {"C_h5_delete_link", (DL_FUNC) &C_h5_delete_link, 2},
  {"C_h5_delete_attr", (DL_FUNC) &C_h5_delete_attr, 3},
  
  {NULL, NULL, 0}
};

void R_init_h5lite(DllInfo *dll) {
  R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
}
