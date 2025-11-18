#include "h5lite.h"


/* --- WRITER: DATASET --- */
SEXP C_h5_write_dataset(SEXP filename, SEXP dset_name, SEXP data, SEXP dtype, SEXP dims, SEXP compress_level) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dset_name, 0));
  const char *dtype_str = CHAR(STRING_ELT(dtype, 0));
  int compress = asInteger(compress_level);
  
  hid_t file_id = open_or_create_file(fname);
  int rank = 0;
  hsize_t *h5_dims = NULL;
  
  hid_t space_id = create_dataspace(dims, data, &rank, &h5_dims);
  hid_t file_type_id = get_file_type(dtype_str, data);
  herr_t status = -1;
  
  /* Create Link Creation Property List to auto-create groups (like mkdir -p) */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_create_intermediate_group(lcpl_id, 1);
  
  /* Create Dataset Creation Property List for compression */
  hid_t dcpl_id = H5Pcreate(H5P_DATASET_CREATE);
  
  /* Only chunk if compression is requested or we explicitly want chunking */
  if (compress > 0 && rank > 0) {
    
    /* Get element size (e.g., 4 bytes for int, 8 for double) */
    size_t type_size = H5Tget_size(file_type_id);
    
    /* Heuristic for choosing a chunk size */
    hsize_t *chunk_dims = (hsize_t *) R_alloc(rank, sizeof(hsize_t));
    calculate_chunk_dims(rank, h5_dims, type_size, chunk_dims);
    H5Pset_chunk(dcpl_id, rank, chunk_dims);
    
    /* Enable Shuffle: Only useful if element size > 1 byte */
    if (type_size > 1) H5Pset_shuffle(dcpl_id);
    
    H5Pset_deflate(dcpl_id, (unsigned int)compress);
  }
  
  /* --- Overwrite Logic --- */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  htri_t link_exists = H5Lexists(file_id, dname, H5P_DEFAULT);
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  if (link_exists > 0) {
    H5Ldelete(file_id, dname, H5P_DEFAULT);
  }
  /* --- End Overwrite --- */
  
  hid_t dset_id = H5Dcreate2(file_id, dname, file_type_id, space_id, lcpl_id, dcpl_id, H5P_DEFAULT);
  H5Pclose(lcpl_id);
  H5Pclose(dcpl_id);
  
  if (dset_id < 0) {
    /* No free(h5_dims) needed here! R handles it. */
    H5Sclose(space_id); H5Tclose(file_type_id); H5Fclose(file_id);
    error("Failed to create dataset");
  }
  
  if (strcmp(dtype_str, "character") == 0) {
    if (TYPEOF(data) != STRSXP) error("dtype 'character' requires character data");
    
    hsize_t n = (hsize_t)XLENGTH(data);
    const char **f_buffer = (const char **)malloc(n * sizeof(const char *));
    for (hsize_t i = 0; i < n; i++) f_buffer[i] = CHAR(STRING_ELT(data, i));
    
    const char **c_buffer = (const char **)malloc(n * sizeof(const char *));
    h5_transpose((void*)f_buffer, (void*)c_buffer, rank, h5_dims, sizeof(char*), 0);
    
    hid_t mem_type_id = H5Tcopy(H5T_C_S1);
    H5Tset_size(mem_type_id, H5T_VARIABLE);
    H5Tset_cset(mem_type_id, H5T_CSET_UTF8);
    status = H5Dwrite(dset_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
    free(f_buffer); free(c_buffer); H5Tclose(mem_type_id);
    
  } else {
    /* Numeric, Logical, or Opaque */
    hsize_t total_elements = 1;
    if (rank > 0 && h5_dims) {
      for(int i=0; i<rank; i++) total_elements *= h5_dims[i];
    }
    
    void *r_data_ptr = get_R_data_ptr(data);
    if (!r_data_ptr) error("Failed to get data pointer for the given R type.");
    size_t el_size;
    hid_t mem_type_id;
    
    if (strcmp(dtype_str, "opaque") == 0 || strcmp(dtype_str, "raw") == 0) {
      /* opaque: Force mem type = file type, 1-byte elements */
      if (TYPEOF(data) != RAWSXP) error("dtype 'opaque' requires raw data input");
      mem_type_id = H5Tcopy(file_type_id);
      el_size = H5Tget_size(mem_type_id); /* Should be 1 */
    } else if (strcmp(dtype_str, "factor") == 0) {
      /* FACTOR: Memory type must also be the enum type */
      if (TYPEOF(data) != INTSXP) error("dtype 'factor' requires integer-backed factor data");
      mem_type_id = H5Tcopy(file_type_id);
      el_size = H5Tget_size(mem_type_id); /* Should be 1 */
    } else {
      /* NUMERIC/LOGICAL: Get mem type from R, el_size from R type */
      mem_type_id = get_mem_type(data);
      if (TYPEOF(data) == REALSXP) el_size = sizeof(double);
      else if (TYPEOF(data) == RAWSXP) el_size = sizeof(unsigned char);
      else el_size = sizeof(int);
    }
    
    void *c_buffer = malloc(total_elements * el_size);
    if (!c_buffer) error("Memory allocation failed");
    
    h5_transpose(r_data_ptr, c_buffer, rank, h5_dims, el_size, 0); // 0 = R->HDF5
    
    status = H5Dwrite(dset_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
    
    free(c_buffer);
    if (strcmp(dtype_str, "opaque") == 0 || strcmp(dtype_str, "raw") == 0 || strcmp(dtype_str, "factor") == 0) {
      H5Tclose(mem_type_id);
    }
  }
  
  /* No free(h5_dims) needed here! R handles it. */
  H5Dclose(dset_id); H5Tclose(file_type_id); H5Sclose(space_id); H5Fclose(file_id);
  
  if (status < 0) error("Failed to write data to dataset: %s", dname);
  return R_NilValue;
}

/* --- WRITER: ATTRIBUTE --- */
SEXP C_h5_write_attribute(SEXP filename, SEXP obj_name, SEXP attr_name, SEXP data, SEXP dtype, SEXP dims) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("File must exist to write attributes: %s", fname);
  
  hid_t obj_id = H5Oopen(file_id, oname, H5P_DEFAULT);
  if (obj_id < 0) {
    H5Fclose(file_id);
    error("Failed to open object: %s", oname);
  }
  
  /* --- Overwrite Logic --- */
  htri_t attr_exists = H5Aexists(obj_id, aname);
  if (attr_exists > 0) {
    H5Adelete(obj_id, aname);
  }
  
  if (TYPEOF(data) == VECSXP) { // This is the C-level check for is.list() / is.data.frame()
    R_xlen_t n_cols = XLENGTH(data);
    if (n_cols == 0) return R_NilValue; // Do nothing for a 0-column data.frame
    
    R_xlen_t n_rows = XLENGTH(VECTOR_ELT(data, 0));
    SEXP col_names = getAttrib(data, R_NamesSymbol);
    
    hid_t *ft_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
    hid_t *mt_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
    hid_t vl_string_mem_type = H5Tcopy(H5T_C_S1);
    H5Tset_size(vl_string_mem_type, H5T_VARIABLE);
    H5Tset_cset(vl_string_mem_type, H5T_CSET_UTF8);
    
    size_t total_file_size = 0;
    size_t total_mem_size = 0;
    for (R_xlen_t c = 0; c < n_cols; c++) {
      SEXP r_column = VECTOR_ELT(data, c);
      const char *dtype_str = CHAR(STRING_ELT(dtype, c));
      ft_members[c] = get_file_type(dtype_str, r_column);
      if (TYPEOF(r_column) == STRSXP) {
        mt_members[c] = H5Tcopy(vl_string_mem_type);
      } else {
        // For factors, the memory type must also be the enum type.
        if (strcmp(dtype_str, "factor") == 0) mt_members[c] = H5Tcopy(ft_members[c]);
        else mt_members[c] = get_mem_type(r_column);
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
    
    hsize_t h5_dims = (hsize_t) n_rows;
    hid_t space_id = H5Screate_simple(1, &h5_dims, NULL);
    
    hid_t attr_id = H5Acreate2(obj_id, aname, file_type_id, space_id, H5P_DEFAULT, H5P_DEFAULT);
    
    // This part is identical to C_h5_write_dataframe, but I've left it here for now
    // to avoid another function call with too many arguments.
    // It could be further modularized if desired.
    char *buffer = (char *) malloc(n_rows * total_mem_size);
    for (hsize_t r = 0; r < n_rows; r++) {
      char *row_ptr = buffer + (r * total_mem_size);
      for (R_xlen_t c = 0; c < n_cols; c++) {
        size_t col_offset = H5Tget_member_offset(mem_type_id, c);
        char *dest = row_ptr + col_offset;
        SEXP r_col = VECTOR_ELT(data, c);
        switch (TYPEOF(r_col)) {
          case REALSXP: *((double*)dest) = REAL(r_col)[r]; break;
          case INTSXP:  *((int*)dest) = INTEGER(r_col)[r]; break;
          case LGLSXP:  *((int*)dest) = LOGICAL(r_col)[r]; break;
          case RAWSXP:  *((unsigned char*)dest) = RAW(r_col)[r]; break;
          case STRSXP:  *((const char**)dest) = CHAR(STRING_ELT(r_col, r)); break;
          default: free(buffer); error("Unsupported R column type in data.frame attribute");
        }
      }
    }
    
    herr_t write_status = write_compound_data(attr_id, mem_type_id, buffer);
    if (write_status < 0) {
      warning("Failed to write data to compound attribute: %s", aname);
    }
    
    free(buffer);
    for(int i=0; i<n_cols; i++) { 
      H5Tclose(ft_members[i]);
      // Close copied string and factor enum types
      if (TYPEOF(VECTOR_ELT(data, i)) == STRSXP || isFactor(VECTOR_ELT(data, i))) {
        H5Tclose(mt_members[i]);
      }
    }
    H5Tclose(vl_string_mem_type);
    H5Tclose(file_type_id);
    H5Tclose(mem_type_id);
    H5Sclose(space_id);
    H5Aclose(attr_id);
    
  } else { // Logic for non-data.frame attributes
    const char *dtype_str = CHAR(STRING_ELT(dtype, 0));
    int rank = 0;
    hsize_t *h5_dims = NULL;
    hid_t space_id = create_dataspace(dims, data, &rank, &h5_dims);
    hid_t file_type_id = get_file_type(dtype_str, data);
    herr_t status = -1;
    
    hid_t attr_id = H5Acreate2(obj_id, aname, file_type_id, space_id, H5P_DEFAULT, H5P_DEFAULT);
    if (attr_id < 0) {
      H5Oclose(obj_id); H5Sclose(space_id); H5Tclose(file_type_id); H5Fclose(file_id);
      error("Failed to create attribute");
    }
    
    if (strcmp(dtype_str, "character") == 0) {
      if (TYPEOF(data) != STRSXP) error("dtype 'character' requires character data");
      hsize_t n = (hsize_t)XLENGTH(data);
      const char **f_buffer = (const char **)malloc(n * sizeof(const char *));
      for (hsize_t i = 0; i < n; i++) f_buffer[i] = CHAR(STRING_ELT(data, i));
      const char **c_buffer = (const char **)malloc(n * sizeof(const char *));
      h5_transpose((void*)f_buffer, (void*)c_buffer, rank, h5_dims, sizeof(char*), 0);
      hid_t mem_type_id = H5Tcopy(H5T_C_S1);
      H5Tset_size(mem_type_id, H5T_VARIABLE);
      H5Tset_cset(mem_type_id, H5T_CSET_UTF8);
      status = H5Awrite(attr_id, mem_type_id, c_buffer);
      free(f_buffer); free(c_buffer); H5Tclose(mem_type_id);
    } else {
      hsize_t total_elements = 1;
      if (rank > 0 && h5_dims) {
        for(int i=0; i<rank; i++) total_elements *= h5_dims[i];
      }
      void *r_data_ptr = get_R_data_ptr(data);
      size_t el_size;
      hid_t mem_type_id;
      if (strcmp(dtype_str, "opaque") == 0 || strcmp(dtype_str, "raw") == 0) {
        if (TYPEOF(data) != RAWSXP) error("dtype 'opaque' requires raw data input");
        mem_type_id = H5Tcopy(file_type_id);
        el_size = H5Tget_size(mem_type_id);
      } else if (strcmp(dtype_str, "factor") == 0) {
        if (TYPEOF(data) != INTSXP) error("dtype 'factor' requires integer-backed factor data");
        mem_type_id = H5Tcopy(file_type_id);
        el_size = H5Tget_size(mem_type_id);
      } else {
        mem_type_id = get_mem_type(data);
        if (TYPEOF(data) == REALSXP) el_size = sizeof(double);
        else if (TYPEOF(data) == RAWSXP) el_size = sizeof(unsigned char);
        else el_size = sizeof(int);
      }
      void *c_buffer = malloc(total_elements * el_size);
      if (!c_buffer) error("Memory allocation failed");
      h5_transpose(r_data_ptr, c_buffer, rank, h5_dims, el_size, 0);
      status = H5Awrite(attr_id, mem_type_id, c_buffer);
      free(c_buffer);
      if (strcmp(dtype_str, "opaque") == 0 || strcmp(dtype_str, "raw") == 0 || strcmp(dtype_str, "factor") == 0) {
        H5Tclose(mem_type_id);
      }
    }
    H5Aclose(attr_id); H5Tclose(file_type_id); H5Sclose(space_id);
    if (status < 0) error("Failed to write data to attribute: %s", aname);
  }
  
  H5Oclose(obj_id);
  H5Fclose(file_id);
  return R_NilValue;
}

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
  
  if (group_id < 0) {
    H5Fclose(file_id);
    error("Failed to create group");
  }
  
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
  if (lcpl_id < 0) {
    H5Fclose(file_id);
    error("Failed to create link creation property list.");
  }
  
  /* Set HDF5 to create intermediate groups (like mkdir -p) */
  herr_t prop_status = H5Pset_create_intermediate_group(lcpl_id, 1);
  if (prop_status < 0) {
    H5Pclose(lcpl_id);
    H5Fclose(file_id);
    error("Failed to set intermediate group creation property.");
  }
  
  /* --- Suppress HDF5's automatic error printing --- */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  /* --- */
  
  /*
   * H5Lmove
   * We move from/to paths relative to the file root (file_id).
   * We pass our new lcpl_id to the 'to' path. H5P_DEFAULT is fine for 'from'.
   */
  herr_t status = H5Lmove(file_id, from, file_id, to, lcpl_id, H5P_DEFAULT);
  
  /* --- Restore HDF5's automatic error printing --- */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  /* --- */
  
  /* Close property list and file before checking status */
  H5Pclose(lcpl_id);
  H5Fclose(file_id);
  
  if (status < 0) {
    error("Failed to move object from '%s' to '%s'. Ensure source exists and destination path is valid.", from, to);
  }
  
  return R_NilValue;
}
