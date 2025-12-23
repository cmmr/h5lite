#include "h5lite.h"


/* --- WRITER: GROUP --- */
SEXP C_h5_create_group(SEXP filename, SEXP group_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *gname = CHAR(STRING_ELT(group_name, 0));
  
  hid_t file_id = open_or_create_file(fname);
  
  /* Use Link Creation Property List to create intermediate groups */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_create_intermediate_group(lcpl_id, 1);
  
  /* --- Suppress H5Lexists error --- */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  htri_t group_exists = H5Lexists(file_id, gname, H5P_DEFAULT);
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (group_exists > 0) {
    /* Group already exists, this is not an error */
    H5Pclose(lcpl_id);
    H5Fclose(file_id);
    return R_NilValue;
  }
  
  hid_t group_id = H5Gcreate2(file_id, gname, lcpl_id, H5P_DEFAULT, H5P_DEFAULT);
  
  H5Pclose(lcpl_id);
  
  if (group_id < 0) { H5Fclose(file_id); error("Failed to create group"); }
  
  H5Gclose(group_id);
  H5Fclose(file_id);
  
  return R_NilValue;
}


/*
 * Moves or renames an HDF5 link (dataset, group, etc.)
 * This is an efficient metadata operation; no data is read or rewritten.
 */
SEXP C_h5_move(SEXP filename, SEXP from_name, SEXP to_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *from = CHAR(STRING_ELT(from_name, 0));
  const char *to = CHAR(STRING_ELT(to_name, 0));
  
  /* Open file with Read-Write access */
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file (read-write access required): %s", fname);
  
  /* Create Link Creation Property List */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  if (lcpl_id < 0) { // # nocov start
    H5Fclose(file_id);
    error("Failed to create link creation property list.");
  } // # nocov end
  
  /* Set HDF5 to create intermediate groups (like mkdir -p) */
  herr_t prop_status = H5Pset_create_intermediate_group(lcpl_id, 1);
  if (prop_status < 0) { // # nocov start
    H5Pclose(lcpl_id); H5Fclose(file_id);
    error("Failed to set intermediate group creation property.");
  } // # nocov end
  
  /* --- Suppress HDF5's automatic error printing --- */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  /*
   * H5Lmove
   * We move from/to paths relative to the file root (file_id).
   * We pass our new lcpl_id to the 'to' path. H5P_DEFAULT is fine for 'from'.
   */
  herr_t status = H5Lmove(file_id, from, file_id, to, lcpl_id, H5P_DEFAULT);
  
  /* --- Restore HDF5's automatic error printing --- */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  /* Close property list and file before checking status */
  H5Pclose(lcpl_id);
  H5Fclose(file_id);
  
  if (status < 0)
    error("Failed to move object from '%s' to '%s'.", from, to); // # nocov
  
  return R_NilValue;
}


/*
 * C implementation of h5_delete().
 * Deletes a dataset or group by removing its link from the file structure.
 */
SEXP C_h5_delete(SEXP filename, SEXP name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  herr_t status = H5Ldelete(file_id, oname, H5P_DEFAULT);
  
  H5Fclose(file_id);
  if (status < 0) error("Failed to delete object: %s", oname);
  
  return R_NilValue;
}


/*
 * C implementation of h5_delete(..., attr = ...).
 * Deletes an attribute from a specified object.
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
  
  if (status < 0) error("Failed to delete attribute: %s", aname);
  
  return R_NilValue;
}
