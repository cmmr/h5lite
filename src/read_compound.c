#include "h5lite.h"

/*
 * Generic helper to read compound data from either a dataset or an attribute.
 */
static SEXP read_compound_data(hid_t obj_id, hid_t file_type_id, hid_t space_id, int is_attribute) {
  
  int ndims = H5Sget_simple_extent_ndims(space_id);
  hsize_t n_rows = (ndims > 0) ? H5Sget_simple_extent_npoints(space_id) : 1;
  
  int n_cols = H5Tget_nmembers(file_type_id);
  
  H5T_class_t *member_classes = (H5T_class_t *)R_alloc(n_cols, sizeof(H5T_class_t));
  
  hid_t vl_string_mem_type = H5Tcopy(H5T_C_S1);
  H5Tset_size(vl_string_mem_type, H5T_VARIABLE);
  H5Tset_cset(vl_string_mem_type, H5T_CSET_UTF8);
  
  size_t total_mem_size = 0;
  hid_t *mem_member_types = (hid_t *)R_alloc(n_cols, sizeof(hid_t));
  
  for (int i = 0; i < n_cols; i++) {
    hid_t file_member_type = H5Tget_member_type(file_type_id, i);
    H5T_class_t file_class = H5Tget_class(file_member_type);
    
    member_classes[i] = file_class;
    
    if (file_class == H5T_INTEGER || file_class == H5T_FLOAT) {
      mem_member_types[i] = H5T_NATIVE_DOUBLE;
    } else if (file_class == H5T_ENUM) {
      mem_member_types[i] = H5Tcopy(file_member_type);
    } else if (file_class == H5T_STRING) {
      mem_member_types[i] = vl_string_mem_type;
    } else if (file_class == H5T_OPAQUE) {
      mem_member_types[i] = H5Tcopy(file_member_type);
    } 
    /* NEW: Support for HDF5 2.0.0 Complex types */
    #if H5_VERSION_GE(2, 0, 0)
    else if (file_class == H5T_COMPLEX) {
      /* Create a native complex type (struct of 2 doubles) to match R's CPLXSXP */
      mem_member_types[i] = H5Tcomplex_create(H5T_NATIVE_DOUBLE);
    }
    #endif
    else {
      // Unsupported type
      H5Tclose(file_member_type); // # nocov
      H5Tclose(vl_string_mem_type); // # nocov
      error("Unsupported member type in compound dataset."); // # nocov
    }
    
    total_mem_size += H5Tget_size(mem_member_types[i]);
    H5Tclose(file_member_type);
  }
  
  hid_t mem_type_id = H5Tcreate(H5T_COMPOUND, total_mem_size);
  hid_t *extra_types_to_close = (hid_t *)R_alloc(n_cols, sizeof(hid_t));
  int n_extra_types = 0;

  size_t mem_offset = 0;
  for (int i = 0; i < n_cols; i++) {
    char *member_name = H5Tget_member_name(file_type_id, i);
    H5Tinsert(mem_type_id, member_name, mem_offset, mem_member_types[i]);
    mem_offset += H5Tget_size(mem_member_types[i]);
    H5free_memory(member_name);
  }

  /* Track types that need explicit closing (enums and complex) */
  for (int i = 0; i < n_cols; i++) {
    #if H5_VERSION_GE(2, 0, 0)
    if (member_classes[i] == H5T_ENUM || member_classes[i] == H5T_COMPLEX)
       extra_types_to_close[n_extra_types++] = mem_member_types[i];
    #else
    if (member_classes[i] == H5T_ENUM)
       extra_types_to_close[n_extra_types++] = mem_member_types[i];
    #endif
  }
  
  char *buffer = (char *)malloc(n_rows * total_mem_size);
  if (!buffer) {
    H5Tclose(vl_string_mem_type); // # nocov
    H5Tclose(mem_type_id); // # nocov
    error("Memory allocation failed for compound read buffer"); // # nocov
  }
  
  herr_t status;
  if (is_attribute) {
    status = H5Aread(obj_id, mem_type_id, buffer);
  } else {
    status = H5Dread(obj_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
  }
  
  if (status < 0) {
    free(buffer); // # nocov
    H5Tclose(vl_string_mem_type); // # nocov
    H5Tclose(mem_type_id); // # nocov
    error("Failed to read compound dataset."); // # nocov
  }
  
  /* --- 5. Unpack C Buffer into R data.frame (VECSXP) --- */
  SEXP result;
  PROTECT(result = allocVector(VECSXP, n_cols));
  SEXP col_names_sexp;
  PROTECT(col_names_sexp = allocVector(STRSXP, n_cols));
  
  for (int c = 0; c < n_cols; c++) {
    char *member_name = H5Tget_member_name(mem_type_id, c);
    SET_STRING_ELT(col_names_sexp, c, mkChar(member_name));
    size_t member_offset = H5Tget_member_offset(mem_type_id, c);
    
    SEXP r_column;
    H5T_class_t mclass = member_classes[c];
    
    if (mclass == H5T_INTEGER || mclass == H5T_FLOAT) {
      PROTECT(r_column = allocVector(REALSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        double val;
        memcpy(&val, src, sizeof(double));
        REAL(r_column)[r] = val;
      }
    } 
    /* NEW: Unpack Complex Data */
    #if H5_VERSION_GE(2, 0, 0)
    else if (mclass == H5T_COMPLEX) {
      PROTECT(r_column = allocVector(CPLXSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        Rcomplex val;
        memcpy(&val, src, sizeof(Rcomplex));
        COMPLEX(r_column)[r] = val;
      }
    }
    #endif
    else if (mclass == H5T_ENUM) {
      PROTECT(r_column = allocVector(INTSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        int val;
        memcpy(&val, src, sizeof(int));
        INTEGER(r_column)[r] = val;
      }
      
      hid_t file_member_type = H5Tget_member_type(file_type_id, c);
      int n_levels = H5Tget_nmembers(file_member_type);
      SEXP levels;
      PROTECT(levels = allocVector(STRSXP, n_levels));
      for (int i = 0; i < n_levels; i++) {
        char *lname = H5Tget_member_name(file_member_type, i);
        SET_STRING_ELT(levels, i, mkChar(lname));
        H5free_memory(lname);
      }
      setAttrib(r_column, R_LevelsSymbol, levels);
      UNPROTECT(1); 
      
      SEXP class_attr;
      PROTECT(class_attr = allocVector(STRSXP, 1));
      SET_STRING_ELT(class_attr, 0, mkChar("factor"));
      setAttrib(r_column, R_ClassSymbol, class_attr);
      UNPROTECT(1); 
      H5Tclose(file_member_type);
      
    } else if (mclass == H5T_STRING) {
      PROTECT(r_column = allocVector(STRSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        char *str_ptr;
        memcpy(&str_ptr, src, sizeof(char *)); 
        if (str_ptr) {
          SET_STRING_ELT(r_column, r, mkChar(str_ptr));
        } else {
          SET_STRING_ELT(r_column, r, NA_STRING);
        }
      }
    } else if (mclass == H5T_OPAQUE) {
      PROTECT(r_column = allocVector(RAWSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        unsigned char val;
        memcpy(&val, src, sizeof(unsigned char));
        RAW(r_column)[r] = val;
      }
    } else {
      PROTECT(r_column = allocVector(LGLSXP, 0)); // # nocov
    }
    
    SET_VECTOR_ELT(result, c, r_column);
    UNPROTECT(1); 
    H5free_memory(member_name);
  }
  
  setAttrib(result, R_NamesSymbol, col_names_sexp);
  UNPROTECT(1); 
  
  SEXP class_attr;
  PROTECT(class_attr = allocVector(STRSXP, 1));
  SET_STRING_ELT(class_attr, 0, mkChar("data.frame"));
  setAttrib(result, R_ClassSymbol, class_attr);
  UNPROTECT(1); 
  
  SEXP row_names_attr;
  PROTECT(row_names_attr = allocVector(INTSXP, 2));
  INTEGER(row_names_attr)[0] = NA_INTEGER;
  INTEGER(row_names_attr)[1] = -n_rows; 
  setAttrib(result, R_RowNamesSymbol, row_names_attr);
  UNPROTECT(1); 
  
  if (is_attribute) {
    H5Treclaim(mem_type_id, space_id, H5P_DEFAULT, buffer);
  } else {
    H5Dvlen_reclaim(mem_type_id, space_id, H5P_DEFAULT, buffer);
  }
  free(buffer);
  
  H5Tclose(vl_string_mem_type);
  for (int i = 0; i < n_extra_types; i++) {
    H5Tclose(extra_types_to_close[i]);
  }
  H5Tclose(mem_type_id);
  
  UNPROTECT(1); 
  return result;
}

SEXP read_compound(hid_t dset_id, hid_t file_type_id, hid_t space_id) {
  return read_compound_data(dset_id, file_type_id, space_id, 0); 
}

SEXP read_compound_attribute(hid_t attr_id, hid_t file_type_id, hid_t space_id) {
  return read_compound_data(attr_id, file_type_id, space_id, 1); 
}
