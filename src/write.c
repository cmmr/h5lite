#include "h5lite.h"
#include <hdf5.h>
#include <stdlib.h>
#include <string.h>

/* --- HELPER: Open/Create HDF5 file --- */
static hid_t open_or_create_file(const char *fname) {
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

/* --- HELPER: Create Dataspace from R dims --- */
/* --- HELPER: Create Dataspace from R dims --- */
static hid_t create_dataspace(SEXP dims, SEXP data, int *out_rank, hsize_t **out_h5_dims) {
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

/* --- HELPER: Calculate Chunk Dimensions (Target ~1MB) --- */
static void calculate_chunk_dims(int rank, const hsize_t *dims, size_t type_size, hsize_t *out_chunk_dims) {
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

/* --- HELPER: Memory Type (What is it in R?) --- */
static hid_t get_mem_type(SEXP data) {
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

/* --- HELPER: File Type (What user wants on disk) --- */
static hid_t get_file_type(const char *dtype, SEXP data) {
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
    SEXP levels = getAttrib(data, R_LevelsSymbol);
    R_xlen_t n_levels = XLENGTH(levels);
    
    // Base type for ENUM is INT
    hid_t type_id = H5Tcreate(H5T_ENUM, sizeof(int));
    if (type_id < 0) error("Failed to create ENUM type");
    
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

/* --- HELPER: Get R data pointer --- */
static void* get_R_data_ptr(SEXP data) {
  if (TYPEOF(data) == REALSXP) return (void*)REAL(data);
  if (TYPEOF(data) == INTSXP)  return (void*)INTEGER(data);
  if (TYPEOF(data) == LGLSXP)  return (void*)LOGICAL(data);
  if (TYPEOF(data) == RAWSXP)  return (void*)RAW(data);
  return NULL;
}

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
    size_t el_size;
    hid_t mem_type_id;
    
    if (strcmp(dtype_str, "opaque") == 0 || strcmp(dtype_str, "raw") == 0) {
      /* OPAQUE: Force mem type = file type, 1-byte elements */
      if (TYPEOF(data) != RAWSXP) error("dtype 'opaque' requires raw data input");
      mem_type_id = H5Tcopy(file_type_id);
      el_size = H5Tget_size(mem_type_id); /* Should be 1 */
    } else if (strcmp(dtype_str, "factor") == 0) {
      /* FACTOR: Memory type must also be the ENUM type */
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
  const char *dtype_str = CHAR(STRING_ELT(dtype, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("File must exist to write attributes: %s", fname);
  
  int rank = 0;
  hsize_t *h5_dims = NULL;
  hid_t space_id = create_dataspace(dims, data, &rank, &h5_dims);
  hid_t file_type_id = get_file_type(dtype_str, data);
  herr_t status = -1;
  
  hid_t obj_id = H5Oopen(file_id, oname, H5P_DEFAULT);
  if (obj_id < 0) {
    /* No free(h5_dims) needed here! R handles it. */
    H5Sclose(space_id); 
    H5Tclose(file_type_id); 
    H5Fclose(file_id);
    error("Failed to open object: %s", oname);
  }
  
  /* --- Overwrite Logic --- */
  htri_t attr_exists = H5Aexists(obj_id, aname);
  if (attr_exists > 0) {
    H5Adelete(obj_id, aname);
  }
  /* --- End Overwrite --- */
  
  hid_t attr_id = H5Acreate2(obj_id, aname, file_type_id, space_id, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) {
    /* No free(h5_dims) needed here! R handles it. */
    H5Oclose(obj_id); 
    H5Sclose(space_id); 
    H5Tclose(file_type_id); 
    H5Fclose(file_id);
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
      /* FACTOR: Memory type must also be the ENUM type */
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
    
    h5_transpose(r_data_ptr, c_buffer, rank, h5_dims, el_size, 0); // 0 = R->HDF5
    
    status = H5Awrite(attr_id, mem_type_id, c_buffer);
    
    free(c_buffer);
    if (strcmp(dtype_str, "opaque") == 0 || strcmp(dtype_str, "raw") == 0 || strcmp(dtype_str, "factor") == 0) {
      H5Tclose(mem_type_id);
    }
  }
  
  /* No free(h5_dims) needed here! R handles it. */
  H5Aclose(attr_id); H5Tclose(file_type_id); H5Sclose(space_id); H5Oclose(obj_id); H5Fclose(file_id);
  
  if (status < 0) error("Failed to write data to attribute: %s", aname);
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
