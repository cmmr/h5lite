#include "h5lite.h"

/*
 * High-level function to write an R data.frame as a compound HDF5 object.
 * This function orchestrates the entire process, from creating compound types
 * and serializing R data to creating and writing the final HDF5 object.
 */
void write_dataframe_as_compound(hid_t file_id, hid_t loc_id, const char *obj_name, SEXP data, SEXP dtypes, int compress_level, int is_attribute) {
  
  /* --- 1. Get data.frame properties --- */
  R_xlen_t n_cols = XLENGTH(data);
  if (n_cols == 0) return; // Success, but do nothing
  
  R_xlen_t n_rows    = XLENGTH(VECTOR_ELT(data, 0));
  SEXP col_names = PROTECT(getAttrib(data, R_NamesSymbol));
  
  /* --- 2. Create File and Memory Compound Types --- */
  hid_t *ft_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
  hid_t *mt_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
  
  /* Create a re-usable memory type for variable-length strings. */
  hid_t vl_string_mem_type = H5Tcopy(H5T_C_S1);
  H5Tset_size(vl_string_mem_type, H5T_VARIABLE);
  H5Tset_cset(vl_string_mem_type, H5T_CSET_UTF8);
  
  size_t total_file_size = 0;
  size_t total_mem_size = 0;
  /* For each column, determine its file and memory HDF5 type. */
  for (R_xlen_t c = 0; c < n_cols; c++) {
    SEXP r_column = VECTOR_ELT(data, c);
    const char *dtype_str = CHAR(STRING_ELT(dtypes, c));
    ft_members[c] = get_file_type(dtype_str, r_column);
    if (TYPEOF(r_column) == STRSXP) {
      mt_members[c] = H5Tcopy(vl_string_mem_type);
    } else {
      if (strcmp(dtype_str, "factor") == 0) mt_members[c] = H5Tcopy(ft_members[c]);
      else mt_members[c] = get_mem_type(r_column);
    }
    total_file_size += H5Tget_size(ft_members[c]);
    total_mem_size += H5Tget_size(mt_members[c]);
  }
  
  /* Create the compound types for file and memory. */
  hid_t file_type_id = H5Tcreate(H5T_COMPOUND, total_file_size);
  hid_t mem_type_id  = H5Tcreate(H5T_COMPOUND, total_mem_size);
  size_t file_offset = 0;
  size_t mem_offset  = 0;
  
  /* Insert each column as a member into the compound types. */
  for (R_xlen_t c = 0; c < n_cols; c++) {
    const char *name = CHAR(STRING_ELT(col_names, c));
    H5Tinsert(file_type_id, name, file_offset, ft_members[c]);
    H5Tinsert(mem_type_id,  name, mem_offset,  mt_members[c]);
    file_offset += H5Tget_size(ft_members[c]);
    mem_offset  += H5Tget_size(mt_members[c]);
  }
  
  /* --- 3. Create C Buffer and Serialize Data --- */
  /* Allocate a single buffer to hold all rows of the serialized data. */
  char *buffer = (char *) malloc(n_rows * total_mem_size);
  if (!buffer) {
    // Clean up before erroring
    for(int c=0; c<n_cols; c++) { H5Tclose(ft_members[c]); H5Tclose(mt_members[c]); }
    H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Tclose(vl_string_mem_type);
    UNPROTECT(1);
    error("Memory allocation failed for data.frame buffer");
  }
  
  /* Iterate through each row and column, copying data into the C buffer. */
  for (hsize_t r = 0; r < n_rows; r++) {
    char *row_ptr = buffer + (r * total_mem_size);
    for (R_xlen_t c = 0; c < n_cols; c++) {
      size_t col_offset = H5Tget_member_offset(mem_type_id, c);
      char *dest = row_ptr + col_offset;
      SEXP r_col = VECTOR_ELT(data, c);
      switch (TYPEOF(r_col)) {
        case REALSXP: {
          double val = REAL(r_col)[r];
          memcpy(dest, &val, sizeof(double));
          break;
        }
        case INTSXP: {
          int val = INTEGER(r_col)[r];
          memcpy(dest, &val, sizeof(int));
          break;
        }
        case LGLSXP: {
          int val = LOGICAL(r_col)[r];
          memcpy(dest, &val, sizeof(int));
          break;
        }
        case RAWSXP: {
          unsigned char val = RAW(r_col)[r];
          memcpy(dest, &val, sizeof(unsigned char));
          break;
        }
        case STRSXP: {
          SEXP s = STRING_ELT(r_col, r);
          const char *ptr = (s == NA_STRING) ? NULL : CHAR(s);
          memcpy(dest, &ptr, sizeof(const char *));
          break;
        }
        default:
          free(buffer);
          for(int i=0; i<n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
          H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Tclose(vl_string_mem_type);
          UNPROTECT(1);
          error("Unsupported R column type in data.frame");
      }
    }
  }
  
  /* --- 4. Create Dataspace and Object (Dataset or Attribute) --- */
  hsize_t h5_dims = (hsize_t) n_rows;
  hid_t space_id = H5Screate_simple(1, &h5_dims, NULL);
  hid_t obj_id = -1;
  
  /* Create either an attribute or a dataset, depending on the context. */
  if (is_attribute) {
    obj_id = H5Acreate2(loc_id, obj_name, file_type_id, space_id, H5P_DEFAULT, H5P_DEFAULT);
  } else {
    hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
    H5Pset_create_intermediate_group(lcpl_id, 1);
    hid_t dcpl_id = H5Pcreate(H5P_DATASET_CREATE);
    /* If compression is enabled, set up chunking and filters. */
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
  if (obj_id < 0) { // Object creation failed
    free(buffer);
    for(int i=0; i<n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
    H5Tclose(vl_string_mem_type);
    H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Sclose(space_id);
    if (is_attribute) {
      H5Oclose(loc_id); // This is obj_id from the caller
      H5Fclose(file_id);
      UNPROTECT(1);
      error("Failed to create compound attribute '%s'", obj_name);
    } else {
      H5Fclose(file_id); // This is loc_id from the caller
      UNPROTECT(1);
      error("Failed to create compound dataset '%s'", obj_name);
    }
  }
  
  if (obj_id >= 0) {
    /* Write the entire buffer to the HDF5 object. */
    write_status = write_buffer_to_object(obj_id, mem_type_id, buffer);
    if (is_attribute) H5Aclose(obj_id); else H5Dclose(obj_id);
  }
  
  free(buffer);
  /* Clean up all the HDF5 type handles created. */
  for(int i=0; i<n_cols; i++) { 
    H5Tclose(ft_members[i]);
    if (TYPEOF(VECTOR_ELT(data, i)) == STRSXP || isFactor(VECTOR_ELT(data, i))) {
      H5Tclose(mt_members[i]);
    }
  }
  H5Tclose(vl_string_mem_type);
  H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Sclose(space_id);
  
  if (write_status < 0) {
    if (is_attribute) {
      H5Oclose(loc_id);
      H5Fclose(file_id);
      UNPROTECT(1);
      error("Failed to write compound attribute '%s'", obj_name);
    } else {
      H5Fclose(file_id);
      UNPROTECT(1);
      error("Failed to write compound dataset '%s'", obj_name);
    }
  }
  
  UNPROTECT(1);
  return; // Success
}