#include "h5lite.h"

/*
 * C implementation of h5_create_group().
 * Recursively creates groups to ensure the full path exists.
 */
SEXP C_h5_create_group(SEXP filename, SEXP group_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *gname = CHAR(STRING_ELT(group_name, 0));
  
  /* 1. Root Group Optimization
   * The root group "/" always exists in a valid HDF5 file. 
   * We just need to ensure the file exists.
   */
  if (strcmp(gname, "/") == 0) {
    hid_t file_id = open_or_create_file(fname);
    if (file_id >= 0) H5Fclose(file_id);
    return R_NilValue;
  }
  
  hid_t file_id = open_or_create_file(fname);
  
  /* Create Link Creation Property List */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  
  /* Enable creating intermediate groups (mkdir -p behavior) */
  H5Pset_create_intermediate_group(lcpl_id, 1);
  
  /* 2. Error Suppression
   * We expect H5Gcreate2 to fail if the group already exists.
   * We must turn off HDF5's auto-error printing so the user doesn't see the
   * "name already exists" traceback in the console.
   */
  H5E_auto2_t old_func;
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  /* Try to create the group */
  hid_t group_id = H5Gcreate2(file_id, gname, lcpl_id, H5P_DEFAULT, H5P_DEFAULT);
  
  /* Restore original error handler immediately */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  H5Pclose(lcpl_id);
  
  if (group_id < 0) {
    /* Creation failed. Now we check: did it fail because it already exists? */
    
    /* Suppress errors for the check as well */
    H5Eset_auto(H5E_DEFAULT, NULL, NULL);
    hid_t check_id = H5Gopen2(file_id, gname, H5P_DEFAULT);
    H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
    
    if (check_id >= 0) {
      H5Gclose(check_id); /* It exists and is a group. Success. */
    } else {
      H5Fclose(file_id);
      /* Now we allow the error to be raised to R */
      error("Failed to create group (or object exists and is not a group): %s", gname);
    }
  }
  else {
    H5Gclose(group_id);
  }
  
  H5Fclose(file_id);
  return R_NilValue;
}


/*
 * C implementation of h5_move().
 * Wraps H5Lmove to rename/move objects.
 */
SEXP C_h5_move(SEXP filename, SEXP from_name, SEXP to_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *src   = CHAR(STRING_ELT(from_name, 0));
  const char *dest  = CHAR(STRING_ELT(to_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  /* Create Link Creation Property List to auto-create parent groups for destination */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_create_intermediate_group(lcpl_id, 1);
  
  herr_t status = H5Lmove(file_id, src, file_id, dest, lcpl_id, H5P_DEFAULT);
  
  H5Pclose(lcpl_id);
  H5Fclose(file_id);
  
  if (status < 0) error("Failed to move/rename object from '%s' to '%s'", src, dest);
  
  return R_NilValue;
}

/*
 * C implementation of h5_delete().
 * Deletes a link (Group or Dataset) using H5Ldelete.
 */
SEXP C_h5_delete(SEXP filename, SEXP name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *obj   = CHAR(STRING_ELT(name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  herr_t status = H5Ldelete(file_id, obj, H5P_DEFAULT);
  
  H5Fclose(file_id);
  
  if (status < 0) error("Failed to delete object: %s", obj);
  
  return R_NilValue;
}

/*
 * C implementation of h5_delete_attr().
 * Deletes an attribute using H5Adelete.
 */
SEXP C_h5_delete_attr(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t obj_id = H5Oopen(file_id, oname, H5P_DEFAULT);
  if (obj_id < 0) { H5Fclose(file_id); error("Failed to open object: %s", oname); }
  
  herr_t status = H5Adelete(obj_id, aname);
  
  H5Oclose(obj_id);
  H5Fclose(file_id);
  
  if (status < 0) error("Failed to delete attribute '%s' from '%s'", aname, oname);
  
  return R_NilValue;
}
