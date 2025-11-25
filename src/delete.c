#include "h5lite.h"

/* Deletes a Dataset or Group by removing its link */
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

/* Deletes an Attribute from an object */
SEXP C_h5_delete_attr(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t obj_id = H5Oopen(file_id, oname, H5P_DEFAULT);
  if (obj_id < 0) {
    H5Fclose(file_id);
    error("Failed to open object: %s", oname);
  }
  
  herr_t status = H5Adelete(obj_id, aname);
  
  H5Oclose(obj_id);
  H5Fclose(file_id);
  
  if (status < 0) error("Failed to delete attribute: %s", aname);
  
  return R_NilValue;
}
