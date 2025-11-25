#include "h5lite.h"

/*
 * Opens an HDF5 file with read-write access.
 * If the file does not exist or is not a valid HDF5 file, it creates a new one,
 * truncating any existing content.
 */
hid_t open_or_create_file(const char *fname) {
  hid_t file_id = -1;
  
  /* Suppress HDF5's auto error printing for H5Fis_hdf5
   * It will (correctly) error if the file doesn't exist,
   * but we don't want to show that to the user.
   */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  /* Save old error handler */
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  /* Turn off error handling */
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  htri_t is_hdf5 = H5Fis_hdf5(fname);
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (is_hdf5 > 0) {
    file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  } else {
    /* File doesn't exist or isn't HDF5, create/truncate it */
    file_id = H5Fcreate(fname, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
  }
  if (file_id < 0) error("Failed to open or create file: %s", fname);
  return file_id;
}

/*
 * Creates an HDF5 dataspace from R dimension information.
 * Handles both scalar (dims = R_NilValue) and array objects.
 * Validates that the product of dimensions matches the length of the data.
 */
hid_t create_dataspace(SEXP dims, SEXP data, int *out_rank, hsize_t **out_h5_dims) {
  hid_t space_id = -1;
  *out_h5_dims = NULL;
  
  if (dims == R_NilValue) {
    /* SCALAR */
    *out_rank = 0;
    if (XLENGTH(data) != 1) error("Data for scalar must have length 1");
    space_id = H5Screate(H5S_SCALAR);
  } else {
    /* ARRAY */
    *out_rank = (int)length(dims);
    if (*out_rank == 0) error("dims must be NULL or a vector");
    
    /* R_alloc takes (n, size). No check for NULL needed. */
    hsize_t *h5_dims = (hsize_t *)R_alloc(*out_rank, sizeof(hsize_t));
    
    int *r_dims = INTEGER(dims);
    hsize_t total_elements = 1;
    for (int i = 0; i < *out_rank; i++) {
      h5_dims[i] = (hsize_t)r_dims[i];
      total_elements *= h5_dims[i];
    }
    
    if (total_elements != (hsize_t)XLENGTH(data)) {
      /* No free(h5_dims) needed here! R handles it. */
      error("Dimensions do not match data length");
    }
    *out_h5_dims = h5_dims;
    space_id = H5Screate_simple(*out_rank, h5_dims, NULL);
  }
  return space_id;
}

/*
 * Checks if a link (dataset or group) exists and deletes it if it does.
 * This is used to implement "overwrite-by-default" behavior.
 */
void handle_overwrite(hid_t file_id, const char *name) {
  /* Suppress HDF5's auto error printing for H5Lexists */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  htri_t link_exists = H5Lexists(file_id, name, H5P_DEFAULT);
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (link_exists > 0) {
    if (H5Ldelete(file_id, name, H5P_DEFAULT) < 0) {
      H5Fclose(file_id);
      error("Failed to overwrite existing object '%s'", name);
    }
  }
}

/*
 * Checks if an attribute exists on an object and deletes it if it does.
 * This is used to implement "overwrite-by-default" behavior for attributes.
 */
void handle_attribute_overwrite(hid_t file_id, hid_t obj_id, const char *attr_name) {
  /* Suppress HDF5's auto error printing for H5Aexists */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  htri_t attr_exists = H5Aexists(obj_id, attr_name);
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (attr_exists > 0) {
    if (H5Adelete(obj_id, attr_name) < 0) {
      H5Oclose(obj_id);
      H5Fclose(file_id);
      error("Failed to overwrite existing attribute '%s'", attr_name);
    }
  }
}

/*
 * Creates an attribute with a null dataspace.
 */
void write_null_attribute(hid_t file_id, hid_t obj_id, const char *attr_name) {
  hid_t space_id = H5Screate(H5S_NULL);
  hid_t attr_id = H5Acreate2(obj_id, attr_name, H5T_STD_I32LE, space_id, H5P_DEFAULT, H5P_DEFAULT);
  
  H5Sclose(space_id);
  if (attr_id < 0) {
    H5Oclose(obj_id);
    H5Fclose(file_id);
    error("Failed to create null attribute '%s'", attr_name);
  }
  
  H5Aclose(attr_id);
}

/*
 * Creates a dataset with a null dataspace.
 */
void write_null_dataset(hid_t file_id, const char *dname) {
  hid_t space_id = H5Screate(H5S_NULL);
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_create_intermediate_group(lcpl_id, 1);
  
  handle_overwrite(file_id, dname);
  
  hid_t dset_id = H5Dcreate2(file_id, dname, H5T_STD_I32LE, space_id, lcpl_id, H5P_DEFAULT, H5P_DEFAULT);

  H5Pclose(lcpl_id); H5Sclose(space_id);
  if (dset_id < 0) { H5Fclose(file_id); error("Failed to create null dataset: %s", dname); }
  H5Dclose(dset_id);
}

/*
 * Low-level utility to write a pre-serialized C buffer to an HDF5 object.
 * It dispatches to H5Dwrite or H5Awrite based on the type of obj_id.
 * This function has no knowledge of R objects.
 */
herr_t write_buffer_to_object(hid_t obj_id, hid_t mem_type_id, void *buffer) {
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
  SEXP     col_names = getAttrib(data, R_NamesSymbol);
  
  /* --- 2. Create File and Memory Compound Types --- */
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
        case REALSXP: *((double*)dest) = REAL(r_col)[r]; break;
        case INTSXP:  *((int*)dest) = INTEGER(r_col)[r]; break;
        case LGLSXP:  *((int*)dest) = LOGICAL(r_col)[r]; break;
        case RAWSXP:  *((unsigned char*)dest) = RAW(r_col)[r]; break;
        case STRSXP:
          {
            SEXP s = STRING_ELT(r_col, r);
            *((const char**)dest) = (s == NA_STRING) ? NULL : CHAR(s);
          }
          break;
        default:
          free(buffer);
          for(int i=0; i<n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
          H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Tclose(vl_string_mem_type);
          error("Unsupported R column type in data.frame");
      }
    }
  }
  
  /* --- 4. Create Dataspace and Object (Dataset or Attribute) --- */
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
  if (obj_id < 0) { // Object creation failed
    free(buffer);
    for(int i=0; i<n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
    H5Tclose(vl_string_mem_type);
    H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Sclose(space_id);
    if (is_attribute) {
      H5Oclose(loc_id); // This is obj_id from the caller
      H5Fclose(file_id);
      error("Failed to create compound attribute '%s'", obj_name);
    } else {
      H5Fclose(file_id); // This is loc_id from the caller
      error("Failed to create compound dataset '%s'", obj_name);
    }
  }
  
  if (obj_id >= 0) {
    write_status = write_buffer_to_object(obj_id, mem_type_id, buffer);
    if (is_attribute) H5Aclose(obj_id); else H5Dclose(obj_id);
  }
  
  free(buffer);
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
      error("Failed to write compound attribute '%s'", obj_name);
    } else {
      H5Fclose(file_id);
      error("Failed to write compound dataset '%s'", obj_name);
    }
  }
  
  return;
}

/*
 * Writes an atomic R vector (numeric, character, etc.) to an already created HDF5
 * dataset. This function handles data transposition and NA values for strings.
 * It is a lower-level helper called by C_h5_write_dataset.
 */
herr_t write_atomic_dataset(hid_t obj_id, SEXP data, const char *dtype_str, int rank, hsize_t *h5_dims) {
  herr_t status = -1;
  H5I_type_t obj_type = H5Iget_type(obj_id);

  if (obj_type != H5I_DATASET && obj_type != H5I_ATTR) {
    error("Invalid object type provided to write_atomic_dataset");
  }

  if (strcmp(dtype_str, "character") == 0) {
    if (TYPEOF(data) != STRSXP) error("dtype 'character' requires character data");

    hsize_t n = (hsize_t)XLENGTH(data);
    const char **f_buffer = (const char **)malloc(n * sizeof(const char *));
    for (hsize_t i = 0; i < n; i++) {
      SEXP s = STRING_ELT(data, i);
      f_buffer[i] = (s == NA_STRING) ? NULL : CHAR(s);
    }

    const char **c_buffer = (const char **)malloc(n * sizeof(const char *));
    h5_transpose((void*)f_buffer, (void*)c_buffer, rank, h5_dims, sizeof(char*), 0);

    hid_t mem_type_id = H5Tcopy(H5T_C_S1);
    H5Tset_size(mem_type_id, H5T_VARIABLE);
    H5Tset_cset(mem_type_id, H5T_CSET_UTF8);

    if (obj_type == H5I_ATTR) {
      status = H5Awrite(obj_id, mem_type_id, c_buffer);
    } else { // H5I_DATASET
      status = H5Dwrite(obj_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
    }

    free(f_buffer); free(c_buffer); H5Tclose(mem_type_id);

  } else { // Numeric, Logical, Opaque, Factor
    hsize_t total_elements = 1;
    if (rank > 0 && h5_dims) {
      for(int i=0; i<rank; i++) total_elements *= h5_dims[i];
    }

    void *r_data_ptr = get_R_data_ptr(data);
    if (!r_data_ptr) error("Failed to get data pointer for the given R type.");
    size_t el_size;
    hid_t mem_type_id;

    if (strcmp(dtype_str, "raw") == 0) {
      mem_type_id = H5Tcopy(H5T_NATIVE_UCHAR);
      el_size = sizeof(unsigned char);
    } else if (strcmp(dtype_str, "factor") == 0) {
      mem_type_id = H5Tcopy(H5T_NATIVE_INT);
      el_size = sizeof(int);
    } else { // Numeric/Logical
      mem_type_id = get_mem_type(data);
      if (TYPEOF(data) == REALSXP) el_size = sizeof(double);
      else el_size = sizeof(int);
    }

    void *c_buffer = malloc(total_elements * el_size);
    if (!c_buffer) error("Memory allocation failed");

    h5_transpose(r_data_ptr, c_buffer, rank, h5_dims, el_size, 0);

    if (obj_type == H5I_ATTR) {
      status = H5Awrite(obj_id, mem_type_id, c_buffer);
    } else { // H5I_DATASET
      status = H5Dwrite(obj_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
    }

    free(c_buffer);
  }
  return status;
}

/*
 * Orchestrates the creation and writing of an atomic (non-data.frame) attribute.
 * It creates the dataspace, file type, and attribute, then calls write_atomic_dataset.
 */
void write_atomic_attribute(hid_t file_id, hid_t obj_id, const char *attr_name, SEXP data, SEXP dtype, SEXP dims) {
  
  const char *dtype_str = CHAR(STRING_ELT(dtype, 0));
  int rank = 0;
  hsize_t *h5_dims = NULL;
  
  hid_t space_id = create_dataspace(dims, data, &rank, &h5_dims);
  if (space_id < 0) { H5Oclose(obj_id); H5Fclose(file_id); error("Failed to create dataspace for attribute."); }
  
  hid_t file_type_id = get_file_type(dtype_str, data);
  if (file_type_id < 0) {
    H5Sclose(space_id);
    H5Oclose(obj_id);
    H5Fclose(file_id);
    error("Failed to get file type for attribute.");
  }
  
  hid_t attr_id = H5Acreate2(obj_id, attr_name, file_type_id, space_id, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) {
    H5Sclose(space_id);
    H5Tclose(file_type_id);
    H5Oclose(obj_id);
    H5Fclose(file_id);
    error("Failed to create attribute '%s'", attr_name);
  }
  
  herr_t status = write_atomic_dataset(attr_id, data, dtype_str, rank, h5_dims);
  
  H5Aclose(attr_id); H5Tclose(file_type_id); H5Sclose(space_id);
  
  if (status < 0) { H5Oclose(obj_id); H5Fclose(file_id); error("Failed to write data to attribute: %s", attr_name); }
}

/*
 * Implements a heuristic to determine chunk dimensions for a dataset.
 * The goal is to create chunks that are roughly 1MB in size by iteratively
 * halving the largest dimension until the target size is met.
 */
void calculate_chunk_dims(int rank, const hsize_t *dims, size_t type_size, hsize_t *out_chunk_dims) {
  hsize_t TARGET_SIZE = 1024 * 1024; /* Target 1 MiB per chunk */
hsize_t current_bytes = type_size;

/* 1. Start with the full dimensions */
for (int i = 0; i < rank; i++) {
  out_chunk_dims[i] = dims[i];
  current_bytes *= dims[i];
}

/* 2. If the dataset is small (< 1MB), just use one chunk (full dims) */
if (current_bytes <= TARGET_SIZE) {
  return;
}

/* 3. Iteratively reduce dimensions until we fit in the target size */
while (current_bytes > TARGET_SIZE) {
  /* Find the largest dimension */
  int max_idx = 0;
  for (int i = 1; i < rank; i++) {
    if (out_chunk_dims[i] > out_chunk_dims[max_idx]) {
      max_idx = i;
    }
  }
  
  /* Safety check: if largest dim is 1, we can't shrink anymore */
  if (out_chunk_dims[max_idx] <= 1) break;
  
  /* Halve the largest dimension (ceiling division) */
  out_chunk_dims[max_idx] = (out_chunk_dims[max_idx] + 1) / 2;
  
  /* Recalculate total bytes */
  current_bytes = type_size;
  for (int i = 0; i < rank; i++) {
    current_bytes *= out_chunk_dims[i];
  }
}
}

/*
 * Gets the native HDF5 memory type corresponding to an R vector's C-level type.
 * For example, REALSXP -> H5T_NATIVE_DOUBLE.
 */
hid_t get_mem_type(SEXP data) {
  switch (TYPEOF(data)) {
    case REALSXP: return H5T_NATIVE_DOUBLE;
    case INTSXP:  return H5T_NATIVE_INT;
    case LGLSXP:  return H5T_NATIVE_INT;    /* R's logicals are int */
    case RAWSXP:  return H5T_NATIVE_UCHAR;  /* R's raw is unsigned char */
    case STRSXP:  return -1;                /* Handled specially */
    default: error("Unsupported R data type");
  }
  return -1;
}

/*
 * Translates a user-provided string (e.g., "int32", "float64") into a
 * portable, little-endian HDF5 file datatype ID. Also handles special
 * types like "character", "raw", and "factor".
 */
hid_t get_file_type(const char *dtype, SEXP data) {
  /* Mappings from user-friendly strings to HDF5 standard types for portability */
  
  /* Floating Point Types (IEEE Standard) */
  if (strcmp(dtype, "float16") == 0) return H5Tcopy(H5T_IEEE_F16LE);
  if (strcmp(dtype, "float32") == 0) return H5Tcopy(H5T_IEEE_F32LE);
  if (strcmp(dtype, "float64") == 0) return H5Tcopy(H5T_IEEE_F64LE);
  
  /* Signed Integer Types (Standard) */
  if (strcmp(dtype, "int8")  == 0) return H5Tcopy(H5T_STD_I8LE);
  if (strcmp(dtype, "int16") == 0) return H5Tcopy(H5T_STD_I16LE);
  if (strcmp(dtype, "int32") == 0) return H5Tcopy(H5T_STD_I32LE);
  if (strcmp(dtype, "int64") == 0) return H5Tcopy(H5T_STD_I64LE);
  
  /* Unsigned Integer Types (Standard) */
  if (strcmp(dtype, "uint8")  == 0) return H5Tcopy(H5T_STD_U8LE);
  if (strcmp(dtype, "uint16") == 0) return H5Tcopy(H5T_STD_U16LE);
  if (strcmp(dtype, "uint32") == 0) return H5Tcopy(H5T_STD_U32LE);
  if (strcmp(dtype, "uint64") == 0) return H5Tcopy(H5T_STD_U64LE);
  
  /* System-dependent Native types (less portable, but sometimes needed) */
  if (strcmp(dtype, "char")   == 0) return H5Tcopy(H5T_NATIVE_CHAR);
  if (strcmp(dtype, "uchar")  == 0) return H5Tcopy(H5T_NATIVE_UCHAR);
  if (strcmp(dtype, "short")  == 0) return H5Tcopy(H5T_NATIVE_SHORT);
  if (strcmp(dtype, "ushort") == 0) return H5Tcopy(H5T_NATIVE_USHORT);
  if (strcmp(dtype, "int")    == 0) return H5Tcopy(H5T_NATIVE_INT);
  if (strcmp(dtype, "uint")   == 0) return H5Tcopy(H5T_NATIVE_UINT);
  if (strcmp(dtype, "long")   == 0) return H5Tcopy(H5T_NATIVE_LONG);
  if (strcmp(dtype, "ulong")  == 0) return H5Tcopy(H5T_NATIVE_ULONG);
  if (strcmp(dtype, "llong")  == 0) return H5Tcopy(H5T_NATIVE_LLONG);
  if (strcmp(dtype, "ullong") == 0) return H5Tcopy(H5T_NATIVE_ULLONG);
  if (strcmp(dtype, "float")  == 0) return H5Tcopy(H5T_NATIVE_FLOAT);
  if (strcmp(dtype, "double") == 0) return H5Tcopy(H5T_NATIVE_DOUBLE);
  
  /* Special Types */
  
  if (strcmp(dtype, "character") == 0) {
    hid_t t = H5Tcopy(H5T_C_S1);
    H5Tset_size(t, H5T_VARIABLE);
    H5Tset_cset(t, H5T_CSET_UTF8);
    return t;
  }
  
  /* R raw -> H5T_OPAQUE (size 1) */
  if (strcmp(dtype, "raw") == 0) {
    hid_t t = H5Tcreate(H5T_OPAQUE, 1);
    return t;
  }
  
  if (strcmp(dtype, "factor") == 0) {
    
    if (TYPEOF(data) != INTSXP || !isFactor(data)) {
      error("dtype 'factor' requires factor data input");
    }
    
    SEXP     levels   = getAttrib(data, R_LevelsSymbol);
    R_xlen_t n_levels = XLENGTH(levels);
    
    // Base type for enum is INT
    hid_t type_id = H5Tcreate(H5T_ENUM, sizeof(int));
    if (type_id < 0) error("Failed to create enum type");
    
    for (R_xlen_t i = 0; i < n_levels; i++) {
      // R factors are 1-based, so value is i+1
      int val = i + 1;
      H5Tenum_insert(type_id, CHAR(STRING_ELT(levels, i)), &val);
    }
    
    return type_id;
  }
  
  error("Unknown dtype: %s", dtype);
  return -1;
}

/*
 * Gets a void* pointer to the underlying C array of an atomic R vector.
 * Returns NULL for types that are handled specially (like STRSXP).
 */
void* get_R_data_ptr(SEXP data) {
  if (TYPEOF(data) == REALSXP) return (void*)REAL(data);
  if (TYPEOF(data) == INTSXP)  return (void*)INTEGER(data);
  if (TYPEOF(data) == LGLSXP)  return (void*)LOGICAL(data);
  if (TYPEOF(data) == RAWSXP)  return (void*)RAW(data);
  if (TYPEOF(data) == STRSXP)  return NULL; /* Handled separately */
  return NULL;
}
