#include "h5lite.h"

/*
 * Writes an R data.frame as a compound HDF5 object (dataset or attribute).
 *
 * This function handles the complexities of mapping R's column types to HDF5
 * compound members. It uses a "duplicate-and-coerce" strategy to safely handle
 * type promotions (e.g., integer to double for NA values) without altering the
 * user's original R object.
 *
 * 1. A shallow copy of the input data.frame SEXP is created using `duplicate()`
 *    and is `PROTECT`ed. This allows us to modify the list of column pointers.
 * 2. It iterates through each column, and if a type promotion is needed (e.g.,
 *    an integer column with NAs being written as a float), it calls `coerceVector`.
 * 3. The new, coerced column vector is then placed into the duplicated data.frame
 *    SEXP. Because `coerceVector` allocates a new SEXP, the original column in the
 *    user's data.frame remains untouched.
 * 4. The rest of the function proceeds to build the HDF5 compound type and serialize
 *    the data from this (potentially modified) duplicated data.frame.
 */
void write_dataframe_as_compound(hid_t file_id, hid_t loc_id, const char *obj_name, SEXP data, SEXP dtypes, int compress_level, int is_attribute) {

  /* --- 1. Get data.frame properties --- */
  R_xlen_t n_cols = XLENGTH(data);
  if (n_cols == 0) return;
  R_xlen_t n_rows = (n_cols > 0) ? XLENGTH(VECTOR_ELT(data, 0)) : 0;
  
  /* Create and protect a shallow copy of `data` so we can modify it without affecting the original R object. */
  data = PROTECT(duplicate(data));
  
  SEXP col_names = PROTECT(getAttrib(data, R_NamesSymbol));
  
  /* --- 2. Prepare Columns, Types, and Coercion --- */
  /* We use col_ptrs to store the columns we will actually write. 
     If type promotion is needed (int -> float), we coerce here and store the result in col_ptrs. */
  SEXP *col_ptrs = (SEXP *) R_alloc(n_cols, sizeof(SEXP));

  hid_t *ft_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
  hid_t *mt_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
  
  hid_t vl_string_mem_type = H5Tcopy(H5T_C_S1);
  H5Tset_size(vl_string_mem_type, H5T_VARIABLE);
  H5Tset_cset(vl_string_mem_type, H5T_CSET_UTF8);
  
  size_t total_file_size = 0;
  size_t total_mem_size = 0;

  for (R_xlen_t c = 0; c < n_cols; c++) {
    SEXP r_column = VECTOR_ELT(data, c);
    const char *dtype_str = CHAR(STRING_ELT(dtypes, c));
    
    /* Check if we need to promote Integer/Logical to Double to handle NAs correctly. */
    if (TYPEOF(r_column) == INTSXP || TYPEOF(r_column) == LGLSXP) {
      if (strcmp(dtype_str, "float64") == 0 ||
          strcmp(dtype_str, "float32") == 0 ||
          strcmp(dtype_str, "float16") == 0) {
        /* Coerce to REAL. This handles NA_INTEGER -> NA_REAL conversion automatically. */
        r_column = coerceVector(r_column, REALSXP);
        SET_VECTOR_ELT(data, c, r_column); // Update the data copy with the coerced column
      }
    }
    
    col_ptrs[c] = r_column;

    /* Now determine HDF5 types based on the (possibly coerced) column */
    ft_members[c] = get_file_type(dtype_str, r_column);

    if (TYPEOF(r_column) == STRSXP) {
      mt_members[c] = H5Tcopy(vl_string_mem_type);
    }
    else if (strcmp(dtype_str, "factor") == 0) {
      mt_members[c] = H5Tcopy(ft_members[c]);
    }
    else if (TYPEOF(r_column) == RAWSXP) {
      mt_members[c] = H5Tcreate(H5T_OPAQUE, 1);
    }
    else {
      /* This returns H5T_NATIVE_DOUBLE if r_column is REALSXP (including coerced ones) */
      mt_members[c] = get_mem_type(r_column);
    }
    
    total_file_size += H5Tget_size(ft_members[c]);
    total_mem_size += H5Tget_size(mt_members[c]);
  }
  
  hid_t file_type_id = H5Tcreate(H5T_COMPOUND, total_file_size);
  hid_t mem_type_id  = H5Tcreate(H5T_COMPOUND, total_mem_size);
  size_t file_offset = 0;
  size_t mem_offset  = 0;
  
  for (R_xlen_t c = 0; c < n_cols; c++) {
    const char *name = CHAR(STRING_ELT(col_names, c));
    H5Tinsert(file_type_id, name, file_offset, ft_members[c]);
    H5Tinsert(mem_type_id,  name, mem_offset,  mt_members[c]);
    file_offset += H5Tget_size(ft_members[c]);
    mem_offset  += H5Tget_size(mt_members[c]);
  }
  
  /* --- 3. Create C Buffer and Serialize Data --- */
  char *buffer = (char *) malloc(n_rows * total_mem_size);
  if (!buffer) {
    // Clean up before erroring
    // # nocov start
    for(int c=0; c<n_cols; c++) { H5Tclose(ft_members[c]); H5Tclose(mt_members[c]); }
    H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Tclose(vl_string_mem_type);
    UNPROTECT(2); // data, col_names
    error("Memory allocation failed for data.frame buffer");  // # nocov end
  }
  
  for (hsize_t r = 0; r < n_rows; r++) {
    char *row_ptr = buffer + (r * total_mem_size);
    for (R_xlen_t c = 0; c < n_cols; c++) {
      size_t col_offset = H5Tget_member_offset(mem_type_id, c);
      char *dest = row_ptr + col_offset;
      
      /* Use the pointer from col_ptrs, which may be a coerced SEXP */
      SEXP r_col = col_ptrs[c];
      
      switch (TYPEOF(r_col)) {
        case REALSXP: {
          /* Handles standard doubles AND promoted integers/logicals */
          double val = REAL(r_col)[r];
          memcpy(dest, &val, sizeof(double));
          break;
        }
        case INTSXP: {
          int int_val = INTEGER(r_col)[r];
          memcpy(dest, &int_val, sizeof(int));
          break;
        }
        case LGLSXP: {
          int lgl_val = LOGICAL(r_col)[r];
          memcpy(dest, &lgl_val, sizeof(int));
          break;
        }
        case RAWSXP: {
          unsigned char val = RAW(r_col)[r];
          memcpy(dest, &val, sizeof(unsigned char));
          break;
        }
        case CPLXSXP: {
          Rcomplex val = COMPLEX(r_col)[r];
          memcpy(dest, &val, sizeof(Rcomplex));
          break;
        }
        case STRSXP: {
          SEXP s = STRING_ELT(r_col, r);
          const char *ptr = (s == NA_STRING) ? NULL : CHAR(s);
          memcpy(dest, &ptr, sizeof(const char *));
          break;
        }
        default: // # nocov start
          free(buffer);
          for(int i=0; i<n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
          H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Tclose(vl_string_mem_type);
          UNPROTECT(2); // data, col_names
          error("Unsupported R column type in data.frame"); // # nocov end
      }
    }
  }
  
  /* --- 4. Create Dataspace and Object --- */
  hsize_t h5_dims = (hsize_t) n_rows;
  hid_t space_id = H5Screate_simple(1, &h5_dims, NULL);
  hid_t obj_id = -1;
  
  if (is_attribute) {
    obj_id = H5Acreate2(loc_id, obj_name, file_type_id, space_id, H5P_DEFAULT, H5P_DEFAULT);
  } else {
    hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
    H5Pset_create_intermediate_group(lcpl_id, 1);
    hid_t dcpl_id = H5Pcreate(H5P_DATASET_CREATE);
    if (compress_level > 0 && n_rows > 0) {
      hsize_t chunk_dims = 0;
      calculate_chunk_dims(1, &h5_dims, total_mem_size, &chunk_dims);
      H5Pset_chunk(dcpl_id, 1, &chunk_dims);
      H5Pset_shuffle(dcpl_id);
      H5Pset_deflate(dcpl_id, (unsigned int) compress_level);
    }
    obj_id = H5Dcreate2(loc_id, obj_name, file_type_id, space_id, lcpl_id, dcpl_id, H5P_DEFAULT);
    H5Pclose(lcpl_id); H5Pclose(dcpl_id);
  }
  
  /* --- 5. Write Data and Clean Up --- */
  herr_t write_status = -1;
  if (obj_id < 0) {
    free(buffer); // # nocov start
    for(int i=0; i<n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
    H5Tclose(vl_string_mem_type);
    H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Sclose(space_id);
    if (is_attribute) {
      H5Oclose(loc_id); H5Fclose(file_id);
      UNPROTECT(2); // data, col_names
      error("Failed to create compound attribute '%s'", obj_name);
    } else {
      H5Fclose(file_id);
      UNPROTECT(2); // data, col_names
      error("Failed to create compound dataset '%s'", obj_name);
    } // # nocov end
  }
  
  if (obj_id >= 0) {
    write_status = write_buffer_to_object(obj_id, mem_type_id, buffer);
    if (is_attribute) H5Aclose(obj_id); else H5Dclose(obj_id);
  }
  
  free(buffer);
  
  for(int i=0; i<n_cols; i++) { 
    H5Tclose(ft_members[i]);
    
    /* Close the memory type if it was created specifically for this column. */
    SEXP col = col_ptrs[i];
    if (TYPEOF(col) == STRSXP || 
        isFactor(col) || 
        TYPEOF(col) == RAWSXP ||
        TYPEOF(col) == CPLXSXP) {
      H5Tclose(mt_members[i]);
    }
  }
  H5Tclose(vl_string_mem_type);
  H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Sclose(space_id);
  
  if (write_status < 0) {
    if (is_attribute) { // # nocov start
      H5Oclose(loc_id); H5Fclose(file_id);
      UNPROTECT(2); // data, col_names
      error("Failed to write compound attribute '%s'", obj_name);
    } else {
      H5Fclose(file_id);
      UNPROTECT(2); // data, col_names
      error("Failed to write compound dataset '%s'", obj_name);
    } // # nocov end
  }
  
  UNPROTECT(2); // data, col_names
}
