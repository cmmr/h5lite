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
  /* Turn off error handling so H5Fis_hdf5 doesn't print an error if the file doesn't exist. */
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  htri_t is_hdf5 = H5Fis_hdf5(fname);
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  /* Open the file if it's a valid HDF5 file, otherwise create a new one. */
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
    *out_rank = (int)XLENGTH(dims);
    if (*out_rank == 0) error("dims must be NULL or a vector");
    
    /* R_alloc allocates memory that is garbage-collected by R. No free() needed. */
    hsize_t *h5_dims = (hsize_t *)R_alloc(*out_rank, sizeof(hsize_t));
    
    const int *r_dims = INTEGER(dims);
    hsize_t total_elements = 1;
    for (int i = 0; i < *out_rank; i++) {
      h5_dims[i] = (hsize_t)r_dims[i];
      total_elements *= h5_dims[i];
    }
    
    if (total_elements != (hsize_t)XLENGTH(data)) {
      error("Dimensions do not match data length"); // # nocov
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
  H5Eset_auto(H5E_DEFAULT, NULL, NULL); // Suppress error for non-existent link.
  
  htri_t link_exists = H5Lexists(file_id, name, H5P_DEFAULT);
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (link_exists > 0) {
    if (H5Ldelete(file_id, name, H5P_DEFAULT) < 0) {
      H5Fclose(file_id); // # nocov
      error("Failed to overwrite existing object '%s'", name); // # nocov
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
  H5Eset_auto(H5E_DEFAULT, NULL, NULL); // Suppress error for non-existent attribute.
  
  htri_t attr_exists = H5Aexists(obj_id, attr_name);
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (attr_exists > 0) {
    if (H5Adelete(obj_id, attr_name) < 0) {
      H5Oclose(obj_id); H5Fclose(file_id); // # nocov
      error("Failed to overwrite existing attribute '%s'", attr_name); // # nocov
    }
  }
}

/*
 * Low-level utility to write a pre-serialized C buffer to an HDF5 object.
 * It dispatches to H5Dwrite or H5Awrite based on the type of obj_id.
 * This function has no knowledge of R objects.
 */
herr_t write_buffer_to_object(hid_t obj_id, hid_t mem_type_id, void *buffer) {
  herr_t status = -1;
  
  /* Check if obj_id is a dataset or an attribute and call the appropriate write function. */
  H5I_type_t obj_type = H5Iget_type(obj_id);
  
  if (obj_type == H5I_DATASET) {
    /* For datasets, we specify memory and file space (H5S_ALL means entire space). */
    status = H5Dwrite(obj_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
  } else if (obj_type == H5I_ATTR) {
    /* For attributes, the dataspace is part of the attribute, so we only need the memory type. */
    status = H5Awrite(obj_id, mem_type_id, buffer);
  }
  
  return status;
}

/*
 * Implements a heuristic to determine chunk dimensions for a dataset.
 * The goal is to create chunks that are roughly 1MB in size by iteratively
 * halving the largest dimension until the target size is met.
 */
void calculate_chunk_dims(int rank, const hsize_t *dims, size_t type_size, hsize_t *out_chunk_dims) {
  const hsize_t TARGET_SIZE = 1024 * 1024; /* Target 1 MiB per chunk */
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
    
    /* Safety check: if largest dim is 1, we can't shrink anymore. */
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
    case CPLXSXP: return H5Tcomplex_create(H5T_NATIVE_DOUBLE); /* Custom complex type, must be closed */
    case STRSXP:  return -1;                /* Handled specially */
    default: error("Unsupported R data type"); // # nocov
  }
  return -1;
}

/*
 * Translates a user-provided string (e.g., "int32", "float64") into a
 * portable, little-endian HDF5 file datatype ID. Also handles special
 * types like "character", "raw", and "factor".
 */
hid_t get_file_type(const char *dtype, SEXP data) {
  /* Mappings from user-friendly strings to HDF5 standard types for portability. */
  
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
  if (strcmp(dtype, "complex") == 0) return H5Tcomplex_create(H5T_IEEE_F64LE);
  
  /* Special Types */
  
  if (strcmp(dtype, "character") == 0) { /* Variable-length UTF-8 string */
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
      error("dtype 'factor' requires factor data input"); // # nocov
    }
    
    SEXP levels = PROTECT(getAttrib(data, R_LevelsSymbol));
    R_xlen_t n_levels = XLENGTH(levels);
    
    /* Base type for enum is INT. */
    hid_t type_id = H5Tcreate(H5T_ENUM, sizeof(int));
    if (type_id < 0) {
      UNPROTECT(1); // # nocov
      error("Failed to create enum type"); // # nocov
    }
    
    /* Insert each level name and its corresponding integer value into the enum type. */
    for (R_xlen_t i = 0; i < n_levels; i++) {
      // R factors are 1-based, so value is i+1
      int val = i + 1;
      H5Tenum_insert(type_id, CHAR(STRING_ELT(levels, i)), &val);
    }
    UNPROTECT(1);
    return type_id;
  }
  
  error("Unknown dtype: %s", dtype); // # nocov
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
  if (TYPEOF(data) == CPLXSXP) return (void*)COMPLEX(data);
  if (TYPEOF(data) == STRSXP)  return NULL; /* Handled separately */
  return NULL; // # nocov
}
