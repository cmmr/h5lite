#include "h5lite.h"
#include <hdf5.h>
#include <stdlib.h> // for malloc

/* --- HELPER: Map H5T to String --- */
static SEXP h5_type_to_rstr(hid_t type_id) {
  
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
    return mkString("INTEGER"); 
  }
  
  if (class_id == H5T_FLOAT) {
    
    /* Check for standard float types first (LE and BE) */
    if (H5Tequal(type_id, H5T_IEEE_F16LE) > 0 || H5Tequal(type_id, H5T_IEEE_F16BE) > 0) return mkString("float16");
    if (H5Tequal(type_id, H5T_IEEE_F32LE) > 0 || H5Tequal(type_id, H5T_IEEE_F32BE) > 0) return mkString("float32");
    if (H5Tequal(type_id, H5T_IEEE_F64LE) > 0 || H5Tequal(type_id, H5T_IEEE_F64BE) > 0) return mkString("float64");

    /* Generic fallback */
    return mkString("FLOAT");
  }
  
  /* Handle other classes */
  const char *s = "UNKNOWN";
  switch(class_id) {
    case H5T_STRING:    s = "STRING";    break;
    case H5T_BITFIELD:  s = "BITFIELD";  break;
    case H5T_OPAQUE:    s = "OPAQUE";    break;
    case H5T_COMPOUND:  s = "COMPOUND";  break;
    case H5T_REFERENCE: s = "REFERENCE"; break;
    case H5T_ENUM:      s = "ENUM";      break;
    case H5T_VLEN:      s = "VLEN";      break; 
    case H5T_ARRAY:     s = "ARRAY";     break;
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
