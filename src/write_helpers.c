#include "h5lite.h"

/* --- Open/Create HDF5 file --- */
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

/* --- Create Dataspace from R dims --- */
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

/* --- Handle Overwriting an Existing Dataset/Group --- */
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
    H5Ldelete(file_id, name, H5P_DEFAULT);
  }
}

/* --- Write compound data to a dataset OR attribute --- */
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

/* --- Calculate Chunk Dimensions (Target ~1MB) --- */
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

/* --- Memory Type (What is it in R?) --- */
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

/* --- File Type (What user wants on disk) --- */
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

/* --- Get R data pointer --- */
void* get_R_data_ptr(SEXP data) {
  if (TYPEOF(data) == REALSXP) return (void*)REAL(data);
  if (TYPEOF(data) == INTSXP)  return (void*)INTEGER(data);
  if (TYPEOF(data) == LGLSXP)  return (void*)LOGICAL(data);
  if (TYPEOF(data) == RAWSXP)  return (void*)RAW(data);
  if (TYPEOF(data) == STRSXP)  return NULL; /* Handled separately */
  return NULL;
}
