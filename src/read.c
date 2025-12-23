#include "h5lite.h"

/* Internal helper to dispatch H5Dread or H5Aread based on the object type. */
static herr_t h5_read_impl(hid_t loc_id, hid_t mem_type_id, void *buf, int is_dataset) {
  if (is_dataset) { return H5Dread(loc_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, buf); }
  else            { return H5Aread(loc_id, mem_type_id, buf); }
}


/* --- READERS FOR ATOMIC TYPES --- */

static SEXP read_numeric(hid_t loc_id, int is_dataset, hid_t file_type_id, H5T_class_t class_id, 
                         int ndims, hsize_t *dims, hsize_t total_elements, R_TYPE rtype) {
  
  SEXP result = PROTECT(allocVector(REALSXP, (R_xlen_t)total_elements));
  
  herr_t status;
  char   as_bit64 = (rtype == R_TYPE_BIT64);
  if (as_bit64) { status = h5_read_impl(loc_id, H5T_NATIVE_INT64,  REAL(result), is_dataset); }
  else          { status = h5_read_impl(loc_id, H5T_NATIVE_DOUBLE, REAL(result), is_dataset); }
  if (status < 0) { UNPROTECT(1); return mkChar("Failed to read numeric data"); }
  
  UNPROTECT(1);
  result = PROTECT(coerce_to_rtype(result, rtype, file_type_id));
  
  if (ndims > 1) {
    SEXP   dup_result = PROTECT(duplicate(result));
    size_t el_size    = (TYPEOF(result) == REALSXP) ? sizeof(double) : sizeof(int);
    h5_transpose(get_R_data_ptr(dup_result), get_R_data_ptr(result), ndims, dims, el_size, 1);
    set_r_dimensions(result, ndims, dims);
    UNPROTECT(1); 
  }
  
  UNPROTECT(1);
  return result; 
}

static SEXP read_complex(hid_t loc_id, int is_dataset, int ndims, hsize_t *dims, hsize_t total_elements) {
  SEXP result = PROTECT(allocVector(CPLXSXP, (R_xlen_t)total_elements));
  hid_t mem_type_id = H5Tcomplex_create(H5T_NATIVE_DOUBLE);
  herr_t status     = h5_read_impl(loc_id, mem_type_id, COMPLEX(result), is_dataset);
  H5Tclose(mem_type_id);
  
  if (status < 0) { UNPROTECT(1); return mkChar("Failed to read complex data"); }
  
  if (ndims > 1) {
    SEXP dup_result = PROTECT(duplicate(result));
    h5_transpose(COMPLEX(dup_result), COMPLEX(result), ndims, dims, sizeof(Rcomplex), 1);
    set_r_dimensions(result, ndims, dims);
    UNPROTECT(1); 
  }
  
  UNPROTECT(1);
  return result;
}

SEXP read_character(hid_t loc_id, int is_dataset, hid_t file_type_id, hid_t space_id, 
                           int ndims, hsize_t *dims, hsize_t total_elements) {
  SEXP result = R_NilValue;
  
  if (H5Tis_variable_str(file_type_id)) {
    char **c_buffer = (char **)malloc(total_elements * sizeof(char *));
    char **f_buffer = (char **)malloc(total_elements * sizeof(char *));
    if (!c_buffer || !f_buffer) { // # nocov start
      free(c_buffer); free(f_buffer);
      return mkChar("Memory allocation failed for variable-length strings");
    } // # nocov end
    
    hid_t mem_type = H5Tcopy(H5T_C_S1);
    H5Tset_size(mem_type, H5T_VARIABLE); 
    H5Tset_cset(mem_type, H5T_CSET_UTF8);
    
    if (h5_read_impl(loc_id, mem_type, c_buffer, is_dataset) < 0) {
      result = PROTECT(mkChar("Failed to read variable-length strings")); // # nocov
    } else {
      result = PROTECT(allocVector(STRSXP, (R_xlen_t)total_elements));
      h5_transpose(c_buffer, f_buffer, ndims, dims, sizeof(char*), 1);
      for (hsize_t i = 0; i < total_elements; i++) {
        if (f_buffer[i]) { SET_STRING_ELT(result, i, mkChar(f_buffer[i])); }
        else             { SET_STRING_ELT(result, i, NA_STRING); } // # nocov
      }
    }
    H5Dvlen_reclaim(mem_type, space_id, H5P_DEFAULT, c_buffer);
    free(c_buffer); free(f_buffer); H5Tclose(mem_type);
  }
  else {
    size_t type_size = H5Tget_size(file_type_id);
    char *c_buffer = (char *)malloc(total_elements * type_size);
    char *f_buffer = (char *)malloc(total_elements * type_size);
    if (!c_buffer || !f_buffer) { // # nocov start
      free(c_buffer); free(f_buffer);
      return mkChar("Memory allocation failed for fixed-length strings");
    } // # nocov end
    
    hid_t mem_type = H5Tcopy(H5T_C_S1);
    H5Tset_size(mem_type, type_size);
    
    if (h5_read_impl(loc_id, mem_type, c_buffer, is_dataset) < 0) {
      result = PROTECT(mkChar("Failed to read fixed-length strings")); // # nocov
    }else {
      result = PROTECT(allocVector(STRSXP, (R_xlen_t)total_elements));
      h5_transpose(c_buffer, f_buffer, ndims, dims, type_size, 1);
      char *single_str = (char *)R_alloc(type_size + 1, sizeof(char));
      for (hsize_t i = 0; i < total_elements; i++) {
        memcpy(single_str, f_buffer + (i * type_size), type_size);
        single_str[type_size] = '\0';
        SET_STRING_ELT(result, i, mkChar(single_str));
      }
    }
    free(c_buffer); free(f_buffer); H5Tclose(mem_type);
  }
  
  if (TYPEOF(result) != CHARSXP)
    set_r_dimensions(result, ndims, dims);
  
  UNPROTECT(1);
  return result;
}

static SEXP read_raw(hid_t loc_id, int is_dataset, hid_t file_type_id, 
                     int ndims, hsize_t *dims, hsize_t total_elements) {
  size_t type_size = H5Tget_size(file_type_id);
  if (type_size != 1) return mkChar("h5lite only supports reading 1-byte opaque types as raw vectors");
  
  hid_t  mem_type = H5Tcreate(H5T_OPAQUE, type_size);
  SEXP   result   = PROTECT(allocVector(RAWSXP, (R_xlen_t)total_elements));
  herr_t status   = h5_read_impl(loc_id, mem_type, RAW(result), is_dataset);
  
  if (status < 0) {
    result = PROTECT(mkChar("Failed to read raw data")); // # nocov
  }
  else if (ndims > 1) {
    SEXP dup_result = PROTECT(duplicate(result));
    h5_transpose(RAW(dup_result), RAW(result), ndims, dims, type_size, 1);
    set_r_dimensions(result, ndims, dims);
    UNPROTECT(1); 
  }
  
  H5Tclose(mem_type);
  UNPROTECT(1);
  return result;
}

static SEXP read_factor(hid_t loc_id, int is_dataset, hid_t file_type_id, 
                        int ndims, hsize_t *dims, hsize_t total_elements) {
  int n_members = H5Tget_nmembers(file_type_id);
  if (n_members <= 0) return mkChar("enum type has no members");
  
  SEXP   result = PROTECT(allocVector(INTSXP, (R_xlen_t)total_elements));
  herr_t status = h5_read_impl(loc_id, H5T_NATIVE_INT, INTEGER(result), is_dataset);
  if (status < 0) { UNPROTECT(1); return mkChar("Failed to read enum values"); }
  
  if (ndims > 1) {
    SEXP dup_result = PROTECT(duplicate(result));
    h5_transpose(INTEGER(dup_result), INTEGER(result), ndims, dims, sizeof(int), 1);
    set_r_dimensions(result, ndims, dims);
    UNPROTECT(1); 
  }
  
  SEXP levels = allocVector(STRSXP, n_members);
  setAttrib(result, R_LevelsSymbol, levels);
  for (int i = 0; i < n_members; i++) {
    char *level_name = H5Tget_member_name(file_type_id, i);
    if (level_name) { SET_STRING_ELT(levels, i, mkChar(level_name)); }
    else            { SET_STRING_ELT(levels, i, NA_STRING); } // # nocov
    H5free_memory(level_name);
  }
  
  SEXP class_attr = allocVector(STRSXP, 1);
  setAttrib(result, R_ClassSymbol, class_attr);
  SET_STRING_ELT(class_attr, 0, mkChar("factor"));
  
  UNPROTECT(1);
  return result;
}


/* --- DATASET READ ENTRY POINT --- */

SEXP C_h5_read_dataset(SEXP filename, SEXP dataset_name, SEXP rmap, SEXP element_name) {
  const char *fname   = CHAR(STRING_ELT(filename,     0));
  const char *dname   = CHAR(STRING_ELT(dataset_name, 0));
  const char *el_name = CHAR(STRING_ELT(element_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t dset_id = H5Dopen2(file_id, dname, H5P_DEFAULT);
  if (dset_id < 0) { H5Fclose(file_id); error("Failed to open dataset: %s", dname); }
  
  hid_t       file_type_id = H5Dget_type(dset_id);
  H5T_class_t class_id     = H5Tget_class(file_type_id);
  hid_t       space_id     = H5Dget_space(dset_id);
  R_TYPE      rtype        = rtype_from_map(file_type_id, rmap, el_name);
  
  if (H5Sget_simple_extent_type(space_id) == H5S_NULL || rtype == R_TYPE_NULL) {
    H5Sclose(space_id); H5Tclose(file_type_id); H5Dclose(dset_id); H5Fclose(file_id);
    return R_NilValue;
  }
  
  int ndims = H5Sget_simple_extent_ndims(space_id);
  hsize_t total_elements = 1;
  hsize_t *dims = NULL;
  
  if (ndims > 0) {
    dims = (hsize_t *)R_alloc(ndims, sizeof(hsize_t));
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    for (int i = 0; i < ndims; i++) total_elements *= dims[i];
  }
  
  SEXP result;
  
  if (class_id == H5T_INTEGER || class_id == H5T_FLOAT) {
    result = read_numeric(dset_id, 1, file_type_id, class_id, ndims, dims, total_elements, rtype);
  }
  else if (class_id == H5T_COMPLEX) {
    result = read_complex(dset_id, 1, ndims, dims, total_elements);
  }
  else if (class_id == H5T_STRING) {
    result = read_character(dset_id, 1, file_type_id, space_id, ndims, dims, total_elements);
  }
  else if (class_id == H5T_OPAQUE) {
    result = read_raw(dset_id, 1, file_type_id, ndims, dims, total_elements);
  }
  else if (class_id == H5T_ENUM) {
    result = read_factor(dset_id, 1, file_type_id, ndims, dims, total_elements);
  }
  else if (class_id == H5T_COMPOUND) {
    /* Compound logic includes its own Dimension Scale check for row.names */
    result = read_data_frame(dset_id, 1, file_type_id, space_id, rmap);
  }
  else {
    result = mkChar("Unsupported HDF5 type"); // # nocov
  }
  
  /* For Atomic types, check for attached Dimension Scales and restore names/dimnames */
  if (class_id != H5T_COMPOUND && TYPEOF(result) != CHARSXP) {
    read_r_dimscales(dset_id, ndims, result);
  }
  
  H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
  
  if (TYPEOF(result) == CHARSXP)
    error("Error reading dataset '%s'\n%s", dname, CHAR(result)); // # nocov
  
  return result;
}


/* --- ATTRIBUTE READ ENTRY POINT --- */

SEXP C_h5_read_attribute(SEXP filename, SEXP obj_name, SEXP attr_name, SEXP rmap) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t attr_id = H5Aopen_by_name(file_id, oname, aname, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) { H5Fclose(file_id); error("Failed to open attribute: %s", aname); }
  
  hid_t       file_type_id = H5Aget_type(attr_id);
  H5T_class_t class_id     = H5Tget_class(file_type_id);
  hid_t       space_id     = H5Aget_space(attr_id);
  R_TYPE      rtype        = rtype_from_map(file_type_id, rmap, aname);
  
  if (H5Sget_simple_extent_type(space_id) == H5S_NULL || rtype == R_TYPE_NULL) { // # nocov start
    H5Sclose(space_id); H5Tclose(file_type_id); H5Aclose(attr_id); H5Fclose(file_id);
    return R_NilValue;
  } // # nocov end
  
  int ndims = H5Sget_simple_extent_ndims(space_id);
  hsize_t total_elements = 1;
  hsize_t *dims = NULL;
  
  if (ndims > 0) {
    dims = (hsize_t *)R_alloc(ndims, sizeof(hsize_t));
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    for (int i = 0; i < ndims; i++) total_elements *= dims[i];
  }
  
  SEXP result;
  
  if (class_id == H5T_INTEGER || class_id == H5T_FLOAT) {
    result = read_numeric(attr_id, 0, file_type_id, class_id, ndims, dims, total_elements, rtype);
  }
  else if (class_id == H5T_COMPLEX) {
    result = read_complex(attr_id, 0, ndims, dims, total_elements);
  }
  else if (class_id == H5T_STRING) {
    result = read_character(attr_id, 0, file_type_id, space_id, ndims, dims, total_elements);
  }
  else if (class_id == H5T_OPAQUE) {
    result = read_raw(attr_id, 0, file_type_id, ndims, dims, total_elements);
  }
  else if (class_id == H5T_ENUM) {
    result = read_factor(attr_id, 0, file_type_id, ndims, dims, total_elements);
  }
  else if (class_id == H5T_COMPOUND) {
    result = read_data_frame(attr_id, 0, file_type_id, space_id, rmap);
  }
  else {
    result = mkChar("Unsupported HDF5 type"); // # nocov
  }
  
  H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
  
  if (TYPEOF(result) == CHARSXP)
    error("Error reading attribute '%s': %s", aname, CHAR(result)); // # nocov
  
  return result;
}
