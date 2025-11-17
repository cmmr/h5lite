#include "h5lite.h"
#include <stdlib.h> // for malloc

/* --- HELPER: Map H5T to String --- */
SEXP h5_type_to_rstr(hid_t type_id) {
  
  H5T_class_t class_id = H5Tget_class(type_id);
  
  if (class_id == H5T_INTEGER) {
    
    /* Check for standard integer types first (LE and BE) */
    if (H5Tequal(type_id, H5T_STD_I8LE)  > 0 || H5Tequal(type_id, H5T_STD_I8BE)  > 0) return mkString("int8");
    if (H5Tequal(type_id, H5T_STD_I16LE) > 0 || H5Tequal(type_id, H5T_STD_I16BE) > 0) return mkString("int16");
    if (H5Tequal(type_id, H5T_STD_I32LE) > 0 || H5Tequal(type_id, H5T_STD_I32BE) > 0) return mkString("int32");
    if (H5Tequal(type_id, H5T_STD_I64LE) > 0 || H5Tequal(type_id, H5T_STD_I64BE) > 0) return mkString("int64");
    
    if (H5Tequal(type_id, H5T_STD_U8LE)  > 0 || H5Tequal(type_id, H5T_STD_U8BE)  > 0) return mkString("uint8");
    if (H5Tequal(type_id, H5T_STD_U16LE) > 0 || H5Tequal(type_id, H5T_STD_U16BE) > 0) return mkString("uint16");
    if (H5Tequal(type_id, H5T_STD_U32LE) > 0 || H5Tequal(type_id, H5T_STD_U32BE) > 0) return mkString("uint32");
    if (H5Tequal(type_id, H5T_STD_U64LE) > 0 || H5Tequal(type_id, H5T_STD_U64BE) > 0) return mkString("uint64");
    
    /* Generic fallback */
    return mkString("int"); 
  }
  
  if (class_id == H5T_FLOAT) {
    
    /* Check for standard float types first (LE and BE) */
    if (H5Tequal(type_id, H5T_IEEE_F16LE) > 0 || H5Tequal(type_id, H5T_IEEE_F16BE) > 0) return mkString("float16");
    if (H5Tequal(type_id, H5T_IEEE_F32LE) > 0 || H5Tequal(type_id, H5T_IEEE_F32BE) > 0) return mkString("float32");
    if (H5Tequal(type_id, H5T_IEEE_F64LE) > 0 || H5Tequal(type_id, H5T_IEEE_F64BE) > 0) return mkString("float64");
    
    /* Generic fallback */
    return mkString("float");
  }
  
  /* Handle other classes */
  const char *s = "unknown";
  switch(class_id) {
  case H5T_STRING:    s = "string";    break;
  case H5T_BITFIELD:  s = "bitfield";  break;
  case H5T_OPAQUE:    s = "opaque";    break;
  case H5T_COMPOUND:  s = "compound";  break;
  case H5T_REFERENCE: s = "reference"; break;
  case H5T_ENUM:      s = "enum";      break;
  case H5T_VLEN:      s = "vlen";      break; 
  case H5T_ARRAY:     s = "array";     break;
  default: break;
  }
  return mkString(s);
}

/* --- TYPEOF DATASET --- */
SEXP C_h5_typeof(SEXP filename, SEXP dset_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dset_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t dset_id = H5Dopen2(file_id, dname, H5P_DEFAULT);
  if (dset_id < 0) { H5Fclose(file_id); error("Failed to open dataset: %s", dname); }
  
  hid_t type_id = H5Dget_type(dset_id);
  SEXP res = h5_type_to_rstr(type_id);
  
  H5Tclose(type_id); H5Dclose(dset_id); H5Fclose(file_id);
  return res;
}

/* --- TYPEOF ATTRIBUTE --- */
SEXP C_h5_typeof_attr(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t attr_id = H5Aopen_by_name(file_id, oname, aname, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) { H5Fclose(file_id); error("Failed to open attribute: %s", aname); }
  
  hid_t type_id = H5Aget_type(attr_id);
  SEXP res = h5_type_to_rstr(type_id);
  
  H5Tclose(type_id); H5Aclose(attr_id); H5Fclose(file_id);
  return res;
}

/* --- DIM DATASET --- */
SEXP C_h5_dim(SEXP filename, SEXP dset_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dset_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t dset_id = H5Dopen2(file_id, dname, H5P_DEFAULT);
  if (dset_id < 0) { H5Fclose(file_id); error("Failed to open dataset: %s", dname); }
  
  hid_t space_id = H5Dget_space(dset_id);
  int ndims = H5Sget_simple_extent_ndims(space_id);
  SEXP result = R_NilValue;
  
  if (ndims > 0) {
    hsize_t *dims = (hsize_t *)malloc(ndims * sizeof(hsize_t));
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    
    PROTECT(result = allocVector(INTSXP, ndims));
    for (int i = 0; i < ndims; i++) {
      /* Return dims exactly as HDF5 reports them (no transpose) */
      INTEGER(result)[i] = (int)dims[i];
    }
    free(dims);
    UNPROTECT(1);
  } else {
    /* Scalar */
    result = allocVector(INTSXP, 0); 
  }
  
  H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
  return result;
}

/* --- DIM ATTRIBUTE --- */
SEXP C_h5_dim_attr(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t attr_id = H5Aopen_by_name(file_id, oname, aname, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) { H5Fclose(file_id); error("Failed to open attribute: %s", aname); }
  
  hid_t space_id = H5Aget_space(attr_id);
  int ndims = H5Sget_simple_extent_ndims(space_id);
  SEXP result = R_NilValue;
  
  if (ndims > 0) {
    hsize_t *dims = (hsize_t *)malloc(ndims * sizeof(hsize_t));
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    
    PROTECT(result = allocVector(INTSXP, ndims));
    for (int i = 0; i < ndims; i++) {
      INTEGER(result)[i] = (int)dims[i];
    }
    free(dims);
    UNPROTECT(1);
  } else {
    result = allocVector(INTSXP, 0);
  }
  
  H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
  return result;
}

/* --- EXISTS --- */
SEXP C_h5_exists(SEXP filename, SEXP name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(name, 0));
  
  /* Suppress all HDF5 errors for this function */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  htri_t result = 0; // Default to FALSE
  
  /*
   * Try to open the file. 
   * If H5Fopen fails (e.g., text file, corrupt, no permission),
   * file_id will be < 0 and we will return FALSE.
   */
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  
  if (file_id >= 0) {
    /* File is valid HDF5, now check if the link exists */
    /* This works for "/" (root group) or any other path */
    result = H5Lexists(file_id, oname, H5P_DEFAULT);
    H5Fclose(file_id);
  }
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  return ScalarLogical(result > 0);
}

/* --- EXISTS ATTR --- */
SEXP C_h5_exists_attr(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) return ScalarLogical(0);
  
  // Suppress errors for H5Oopen and H5Aexists
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  htri_t attr_exists = H5Aexists_by_name(file_id, oname, aname, H5P_DEFAULT);
  
  // Restore error handler
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  H5Fclose(file_id);
  
  return ScalarLogical(attr_exists > 0);
}

/* --- HELPER: Check object type --- */
static int check_obj_type(const char *fname, const char *oname, H5O_type_t check_type) {
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) return 0;
  
  int result = 0;
  
  // Suppress errors for H5Oget_info_by_name
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  H5O_info_t oinfo;
  /* HDF5 1.12.0 API: Added H5O_INFO_BASIC */
  herr_t status = H5Oget_info_by_name(file_id, oname, &oinfo, H5O_INFO_BASIC, H5P_DEFAULT);
  
  // Restore error handler
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (status >= 0) {
    if (oinfo.type == check_type) {
      result = 1;
    }
  }
  
  H5Fclose(file_id);
  return result;
}

/* --- IS GROUP --- */
SEXP C_h5_is_group(SEXP filename, SEXP name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(name, 0));
  
  int is_group = check_obj_type(fname, oname, H5O_TYPE_GROUP);
  
  return ScalarLogical(is_group);
}

/* --- IS DATASET --- */
SEXP C_h5_is_dataset(SEXP filename, SEXP name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(name, 0));
  
  int is_dataset = check_obj_type(fname, oname, H5O_TYPE_DATASET);
  
  return ScalarLogical(is_dataset);
}
