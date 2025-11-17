#include "h5lite.h"

/* Generic helper to read compound data from a dataset OR attribute */
static SEXP read_compound_data(hid_t obj_id, hid_t file_type_id, hid_t space_id, int is_attribute) {
  
  // --- 1. Get Dataspace (Number of Rows) ---
  int ndims = H5Sget_simple_extent_ndims(space_id);
  hsize_t n_rows = (ndims > 0) ? H5Sget_simple_extent_npoints(space_id) : 1;
  
  // --- 2. Get File Member Info ---
  int n_cols = H5Tget_nmembers(file_type_id);
  
  // --- 3. Create Memory Datatype (based on h5lite conversion rules) ---
  // R_alloc: memory is garbage-collected by R, no need to free
  H5T_class_t *member_classes = (H5T_class_t *)R_alloc(n_cols, sizeof(H5T_class_t));
  
  // Create the C-style variable-length string type (re-used from C_h5_read_dataset)
  hid_t vl_string_mem_type = H5Tcopy(H5T_C_S1);
  H5Tset_size(vl_string_mem_type, H5T_VARIABLE);
  H5Tset_cset(vl_string_mem_type, H5T_CSET_UTF8);
  
  // Pre-calculate total size for the memory compound type
  size_t total_mem_size = 0;
  hid_t *mem_member_types = (hid_t *)R_alloc(n_cols, sizeof(hid_t));
  
  for (int i = 0; i < n_cols; i++) {
    hid_t file_member_type = H5Tget_member_type(file_type_id, i);
    H5T_class_t file_class = H5Tget_class(file_member_type);
    
    member_classes[i] = file_class; // Save for unpacking loop
    
    if (file_class == H5T_INTEGER || file_class == H5T_FLOAT) {
      // Coerce all numeric types to double
      mem_member_types[i] = H5T_NATIVE_DOUBLE;
    } else if (file_class == H5T_ENUM) {
      // Coerce enums to their base integer type (for factor creation)
      mem_member_types[i] = H5T_NATIVE_INT;
    } else if (file_class == H5T_STRING) {
      // Use our variable-length string type
      mem_member_types[i] = vl_string_mem_type;
    } else {
      // Unsupported type
      H5Tclose(file_member_type);
      H5Tclose(vl_string_mem_type);
      error("Unsupported member type in compound dataset.");
    }
    
    total_mem_size += H5Tget_size(mem_member_types[i]);
    H5Tclose(file_member_type);
  }
  
  // Now create the memory type with the correct total size
  hid_t mem_type_id = H5Tcreate(H5T_COMPOUND, total_mem_size);
  size_t mem_offset = 0;
  for (int i = 0; i < n_cols; i++) {
    char *member_name = H5Tget_member_name(file_type_id, i);
    H5Tinsert(mem_type_id, member_name, mem_offset, mem_member_types[i]);
    mem_offset += H5Tget_size(mem_member_types[i]);
    H5free_memory(member_name);
  }
  
  // --- 4. Read Data ---
  // Allocate a C buffer to hold all rows of the in-memory struct
  char *buffer = (char *)malloc(n_rows * total_mem_size);
  if (!buffer) {
    H5Tclose(vl_string_mem_type);
    H5Tclose(mem_type_id);
    error("Memory allocation failed for compound read buffer");
  }
  
  // H5Dread handles all conversions from file_type_id to mem_type_id
  herr_t status;
  if (is_attribute) {
    status = H5Aread(obj_id, mem_type_id, buffer);
  } else {
    status = H5Dread(obj_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
  }
  
  if (status < 0) {
    free(buffer);
    H5Tclose(vl_string_mem_type);
    H5Tclose(mem_type_id);
    error("Failed to read compound dataset.");
  }
  
  // --- 5. Unpack C Buffer into R data.frame (VECSXP) ---
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
        REAL(r_column)[r] = *((double*)src);
      }
    } else if (mclass == H5T_ENUM) {
      // Get levels from the *file* type
      hid_t file_member_type = H5Tget_member_type(file_type_id, c);
      int n_levels = H5Tget_nmembers(file_member_type);
      SEXP levels;
      PROTECT(levels = allocVector(STRSXP, n_levels));
      for (int i = 0; i < n_levels; i++) {
        char *level_name = H5Tget_member_name(file_member_type, i);
        SET_STRING_ELT(levels, i, mkChar(level_name));
        H5free_memory(level_name);
      }
      
      // Get integer data from the buffer
      SEXP int_data;
      PROTECT(int_data = allocVector(INTSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        INTEGER(int_data)[r] = *((int*)src);
      }
      
      // Create the special factor list (like in C_h5_read_dataset)
      PROTECT(r_column = allocVector(VECSXP, 3));
      SEXP factor_list_names;
      PROTECT(factor_list_names = allocVector(STRSXP, 3));
      SET_STRING_ELT(factor_list_names, 0, mkChar(".h5_factor"));
      SET_STRING_ELT(factor_list_names, 1, mkChar("data"));
      SET_STRING_ELT(factor_list_names, 2, mkChar("levels"));
      
      SET_VECTOR_ELT(r_column, 0, ScalarLogical(1));
      SET_VECTOR_ELT(r_column, 1, int_data);
      SET_VECTOR_ELT(r_column, 2, levels);
      setAttrib(r_column, R_NamesSymbol, factor_list_names);
      
      UNPROTECT(4); // levels, int_data, r_column, factor_list_names
      H5Tclose(file_member_type);
      
    } else if (mclass == H5T_STRING) {
      PROTECT(r_column = allocVector(STRSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        char *str_ptr = *((char**)src); // Get the pointer
        if (str_ptr) {
          SET_STRING_ELT(r_column, r, mkChar(str_ptr));
        } else {
          SET_STRING_ELT(r_column, r, NA_STRING);
        }
      }
    } else {
      // Should be unreachable due to error check above
      PROTECT(r_column = allocVector(LGLSXP, 0));
    }
    
    SET_VECTOR_ELT(result, c, r_column);
    UNPROTECT(1); // r_column
    H5free_memory(member_name);
  }
  
  setAttrib(result, R_NamesSymbol, col_names_sexp);
  UNPROTECT(1); // col_names_sexp
  
  // --- 6. Set data.frame Attributes ---
  SEXP class_attr;
  PROTECT(class_attr = allocVector(STRSXP, 1));
  SET_STRING_ELT(class_attr, 0, mkChar("data.frame"));
  setAttrib(result, R_ClassSymbol, class_attr);
  UNPROTECT(1); // class_attr
  
  SEXP row_names_attr;
  PROTECT(row_names_attr = allocVector(INTSXP, 2));
  INTEGER(row_names_attr)[0] = NA_INTEGER;
  INTEGER(row_names_attr)[1] = -n_rows; // Compact 1:n_rows
  setAttrib(result, R_RowNamesSymbol, row_names_attr);
  UNPROTECT(1); // row_names_attr
  
  // --- 7. Clean Up ---
  // Reclaim memory allocated by H5Dread for variable-length strings
  if (is_attribute) {
    H5Treclaim(mem_type_id, space_id, H5P_DEFAULT, buffer);
  } else {
    H5Dvlen_reclaim(mem_type_id, space_id, H5P_DEFAULT, buffer);
  }
  free(buffer);
  
  H5Tclose(vl_string_mem_type);
  H5Tclose(mem_type_id);
  
  UNPROTECT(1); // result
  return result;
}

/* --- Read a compound dataset into an R data.frame --- */
SEXP read_dataframe(hid_t dset_id, hid_t file_type_id, hid_t space_id) {
  return read_compound_data(dset_id, file_type_id, space_id, 0); // 0 = is not attribute
}

/* --- Read a compound attribute into an R data.frame --- */
SEXP read_compound_attribute(hid_t attr_id, hid_t file_type_id, hid_t space_id) {
  return read_compound_data(attr_id, file_type_id, space_id, 1); // 1 = is attribute
}
