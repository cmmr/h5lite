#include "h5lite.h"

/* Generic helper to write compound data to a dataset OR attribute */
herr_t write_compound_data(hid_t obj_id, hid_t mem_type_id, void *buffer) {
  herr_t status = -1;
  
  // Check if obj_id is a dataset or an attribute
  H5I_type_t obj_type = H5Iget_type(obj_id);
  
  if (obj_type == H5I_DATASET) {
    // For datasets, we need to specify memory and file space, which are the same here.
    status = H5Dwrite(obj_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
  } else if (obj_type == H5I_ATTR) {
    // For attributes, the dataspace is defined on creation, so we only need the memory type.
    status = H5Awrite(obj_id, mem_type_id, buffer);
  }
  
  return status;
}

/* --- WRITER: DATA.FRAME (COMPOUND) --- */
SEXP C_h5_write_dataframe(SEXP filename, SEXP dset_name, SEXP data, SEXP dtypes, SEXP compress_level) {
  
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dset_name, 0));
  int compress = asInteger(compress_level);
  
  /* --- 1. Get data.frame properties --- */
  R_xlen_t n_cols = XLENGTH(data);
  if (n_cols == 0) return R_NilValue; // Do nothing for a 0-column data.frame
  
  R_xlen_t n_rows    = XLENGTH(VECTOR_ELT(data, 0));
  SEXP     col_names = getAttrib(data, R_NamesSymbol);
  if (n_rows == 0) return R_NilValue; // Do nothing for a 0-row data.frame
  
  /* --- 2. Create File and Memory Compound Types --- */
  /* R_alloc: auto-freed by R */
  hid_t *ft_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
  hid_t *mt_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
  
  /* Create one variable-length string type to copy for memory */
  hid_t vl_string_mem_type = H5Tcopy(H5T_C_S1);
  H5Tset_size(vl_string_mem_type, H5T_VARIABLE);
  H5Tset_cset(vl_string_mem_type, H5T_CSET_UTF8);
  
  /* Pre-calculate total size for compound types */
  size_t total_file_size = 0;
  size_t total_mem_size = 0;
  for (R_xlen_t c = 0; c < n_cols; c++) {
    SEXP r_column = VECTOR_ELT(data, c);
    const char *dtype_str = CHAR(STRING_ELT(dtypes, c));
    ft_members[c] = get_file_type(dtype_str, r_column);
    if (TYPEOF(r_column) == STRSXP) {
      mt_members[c] = H5Tcopy(vl_string_mem_type);
    } else {
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
    
    // Insert into compound types
    H5Tinsert(file_type_id, name, file_offset, ft_members[c]);
    H5Tinsert(mem_type_id,  name, mem_offset,  mt_members[c]);
    
    file_offset += H5Tget_size(ft_members[c]);
    mem_offset  += H5Tget_size(mt_members[c]);
  }
  
  /* --- 3. Create Row-Major C Buffer and Trans-serialize Data --- */
  char *buffer = (char *) malloc(n_rows * total_mem_size);
  if (!buffer) {
    // Clean up member types before erroring
    for(int c=0; c<n_cols; c++) { H5Tclose(ft_members[c]); H5Tclose(mt_members[c]); }
    H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Tclose(vl_string_mem_type);
    error("Memory allocation failed for data.frame buffer");
  }
  
  for (hsize_t r = 0; r < n_rows; r++) {
    char *row_ptr = buffer + (r * total_mem_size);
    for (R_xlen_t c = 0; c < n_cols; c++) {
      size_t col_offset = H5Tget_member_offset(mem_type_id, c);
      char *dest = row_ptr + col_offset;
      SEXP r_col = VECTOR_ELT(data, c);
      
      switch (TYPEOF(r_col)) {
        case REALSXP:
          *((double*)dest) = REAL(r_col)[r];
          break;
        case INTSXP: // Handles integers and factors
          *((int*)dest) = INTEGER(r_col)[r];
          break;
        case LGLSXP:
          *((int*)dest) = LOGICAL(r_col)[r];
          break;
        case RAWSXP:
          *((unsigned char*)dest) = RAW(r_col)[r];
          break;
        case STRSXP:
          *((const char**)dest) = CHAR(STRING_ELT(r_col, r));
          break;
        default:
          free(buffer);
          // Clean up member types
          for(int i=0; i<n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
          H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Tclose(vl_string_mem_type);
          error("Unsupported R column type in data.frame");
      }
    }
  }
  
  /* --- 4. Open File and Create Dataspace (1D array of rows) --- */
  hid_t   file_id  = open_or_create_file(fname);
  hsize_t h5_dims  = (hsize_t) n_rows;
  hid_t   space_id = H5Screate_simple(1, &h5_dims, NULL);
  
  /* --- 5. Create Property Lists (Compression & Groups) --- */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_create_intermediate_group(lcpl_id, 1);
  
  hid_t dcpl_id = H5Pcreate(H5P_DATASET_CREATE);
  if (compress > 0 && n_rows > 0) {
    hsize_t chunk_dims = 0; // 1D chunk
    calculate_chunk_dims(1, &h5_dims, total_mem_size, &chunk_dims);
    H5Pset_chunk(dcpl_id, 1, &chunk_dims);
    H5Pset_shuffle(dcpl_id);
    H5Pset_deflate(dcpl_id, (unsigned int) compress);
  }
  
  /* --- 6. Overwrite Logic --- */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  htri_t link_exists = H5Lexists(file_id, dname, H5P_DEFAULT);
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  if (link_exists > 0) {
    H5Ldelete(file_id, dname, H5P_DEFAULT);
  }
  
  /* --- 7. Create and Write Dataset --- */
  hid_t dset_id = H5Dcreate2(file_id, dname, file_type_id, space_id, lcpl_id, dcpl_id, H5P_DEFAULT);
  if (dset_id < 0) {
    // Error, must clean up everything
    free(buffer);
    for(int i=0; i<n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
    H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Tclose(vl_string_mem_type);
    H5Sclose(space_id); H5Pclose(lcpl_id); H5Pclose(dcpl_id); H5Fclose(file_id);
    error("Failed to create compound dataset");
  }
  
  herr_t write_status = write_compound_data(dset_id, mem_type_id, buffer);
  if (write_status < 0) {
    warning("Failed to write data to compound dataset: %s", dname);
  }
  
  /* --- 8. Clean Up --- */
  free(buffer);
  for(int i=0; i<n_cols; i++) { 
    H5Tclose(ft_members[i]);
    // Only close mem types we copied (strings), not immutable native types
    if (TYPEOF(VECTOR_ELT(data, i)) == STRSXP) {
      H5Tclose(mt_members[i]);
    }
  }
  H5Tclose(vl_string_mem_type);
  H5Tclose(file_type_id);
  H5Tclose(mem_type_id);
  H5Sclose(space_id);
  H5Pclose(lcpl_id);
  H5Pclose(dcpl_id);
  H5Dclose(dset_id);
  H5Fclose(file_id);
  
  return R_NilValue;
}
