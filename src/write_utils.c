#include "h5lite.h"

extern herr_t H5Pset_zfp_rate(hid_t plist, double rate);
extern herr_t H5Pset_zfp_precision(hid_t plist, unsigned int prec);
extern herr_t H5Pset_zfp_accuracy(hid_t plist, double acc);
extern herr_t H5Pset_zfp_reversible(hid_t plist);

/* --- Centralized Compression Logic --- */
void apply_compression(hid_t dcpl_id, hid_t type_id, int rank, hsize_t *chunk_dims, SEXP compress) {
  
  const char *codec     = CHAR(STRING_ELT(getAttrib(compress, install("codec")), 0));
  double dbl_level      = asReal(getAttrib(compress, install("level")));
  int    blosc          = asInteger(getAttrib(compress, install("blosc")));
  int    int_packing    = asInteger(getAttrib(compress, install("int_packing")));
  int    float_rounding = asInteger(getAttrib(compress, install("float_rounding")));
  int    checksum       = asLogical(getAttrib(compress, install("checksum")));
  int    b2_delta       = asLogical(getAttrib(compress, install("b2_delta")));
  int    b2_trunc       = asInteger(getAttrib(compress, install("b2_trunc")));
  
  unsigned int int_level = (unsigned int)dbl_level; 
  
  /* 1. Gracefully bypass all filters for scalar datasets */
  if (rank == 0) return;
  
  H5T_class_t tclass = H5Tget_class(type_id);
  size_t type_size   = H5Tget_size(type_id);
  int    is_numeric  = (tclass == H5T_INTEGER || tclass == H5T_FLOAT);
  int    is_float    = (tclass == H5T_FLOAT);
  
  int is_scaled = 0;
  if      (tclass == H5T_INTEGER && int_packing    != NA_INTEGER) { is_scaled = 1; }
  else if (tclass == H5T_FLOAT   && float_rounding != NA_INTEGER) { is_scaled = 2; }
  
  /* 2. Sanity Checks: Gatekeeping for SZIP and ZFP variants */
  if (strncmp(codec, "szip", 4) == 0) {
    if (!is_numeric || is_scaled)                { codec = "gzip"; int_level = 5; }
  }
  else if (strncmp(codec, "zfp",  3) == 0) {
    if      (!is_numeric || is_scaled)         { codec = "gzip"; int_level = 5; }
    else if (type_size != 4 && type_size != 8) { codec = "gzip"; int_level = 5; }
    else if (blosc > 0 && !is_float)           { codec = "gzip"; int_level = 5; }
  }
  
  /* Adjust chunking for SZIP */
  unsigned int pixels_per_block = 32;
  if (strncmp(codec, "szip", 4) == 0) {
    hsize_t fastest_dim = chunk_dims[rank - 1];
    if (fastest_dim >= 32) {
      chunk_dims[rank - 1] = (fastest_dim / 32) * 32;
    } else if (fastest_dim >= 2) {
      chunk_dims[rank - 1] = (fastest_dim / 2) * 2;
      pixels_per_block = (unsigned int)chunk_dims[rank - 1];
    } else {
      codec = "gzip";
      int_level = 5;
    }
  }
  
  /* 3. Set Chunking (Mandatory prerequisite for all subsequent filters) */
  H5Pset_chunk(dcpl_id, rank, chunk_dims);
  
  /* 4. Apply Scale-Offset */
  if (is_scaled) {
    if (is_float) { H5Pset_scaleoffset(dcpl_id, H5Z_SO_FLOAT_DSCALE, float_rounding); }
    else          { H5Pset_scaleoffset(dcpl_id, H5Z_SO_INT,          int_packing);    }
  }
  
  /* 5. Determine Shuffle (Strictly mutually exclusive with Scale-Offset) */
  unsigned int blosc_shuffle = 0;
  if      (is_scaled)                       {}
  else if (strncmp(codec, "szip",  4) == 0) {} 
  else if (strncmp(codec, "zfp",   3) == 0) {} 
  else if (strncmp(codec, "bshuf", 5) == 0) {} 
  else if (blosc > 0)     { blosc_shuffle = 2; } 
  else if (type_size > 1) { H5Pset_shuffle(dcpl_id); }
  
  /* 6. Apply Primary Compressor */
  if (strcmp(codec, "gzip") == 0) { H5Pset_deflate(dcpl_id, int_level); }
  
  else if (blosc > 0) {
    int filter_id = (blosc == 1) ? 32001 : 32026;
    
    unsigned int blosc_level = int_level;
    if      (strcmp(codec, "zstd") == 0) { blosc_level = (unsigned int)ceil((int_level * 9.0) / 22.0); }
    else if (strcmp(codec, "lz4")  == 0) { blosc_level = (unsigned int)ceil((int_level * 9.0) / 12.0); }
    if (blosc_level > 9) blosc_level = 9;
    
    int nelmts = 7;
    unsigned int meta = blosc_level;
    unsigned int mask = blosc_shuffle;
    
    if (blosc == 2 && !is_scaled) {
      if (b2_delta) mask += 4;
      
      if (b2_trunc != NA_INTEGER) {
        mask += 8;
        nelmts = 8;
        meta = (unsigned int)b2_trunc;
      }
    }
    
    int compcode = 0; 
    if      (strcmp(codec, "lz4")      == 0) { compcode = int_level ? 2 : 1; }
    else if (strcmp(codec, "snappy")   == 0) { compcode = 3;  }
    else if (strcmp(codec, "gzip")     == 0) { compcode = 4;  }
    else if (strcmp(codec, "zstd")     == 0) { compcode = 5;  }
    else if (strcmp(codec, "ndlz")     == 0) { compcode = 32; }
    else if (strcmp(codec, "zfp-rate") == 0) {
      compcode = 35; nelmts = 8; 
      meta = (unsigned int)round((dbl_level / (type_size * 8.0)) * 100.0);
    }
    else if (strcmp(codec, "zfp-prec") == 0) { 
      compcode = 34; nelmts = 8; 
      meta = int_level; 
    }
    else if (strcmp(codec, "zfp-acc")  == 0) { 
      compcode = 33; nelmts = 8; 
      int exp = (int)floor(log10(dbl_level));
      meta = (unsigned int)((uint8_t)exp);
    }
    
    unsigned int cd_values[8] = {0, 0, 0, 0, blosc_level, mask, compcode, meta};
    H5Pset_filter(dcpl_id, filter_id, H5Z_FLAG_OPTIONAL, nelmts, cd_values);
  }
  
  else if (strcmp(codec, "szip-ec") == 0) { H5Pset_szip(dcpl_id, H5_SZIP_EC_OPTION_MASK, pixels_per_block); } 
  else if (strcmp(codec, "szip-nn") == 0) { H5Pset_szip(dcpl_id, H5_SZIP_NN_OPTION_MASK, pixels_per_block); } 
  
  else if (strcmp(codec, "zstd")    == 0) {
    unsigned int cd_values[1] = { int_level };
    H5Pset_filter(dcpl_id, 32015, H5Z_FLAG_OPTIONAL, 1, cd_values);
  } 
  else if (strcmp(codec, "lz4") == 0) {
    unsigned int cd_values[2] = { 0, int_level > 0 ? 9 : 0 }; 
    H5Pset_filter(dcpl_id, 32004, H5Z_FLAG_OPTIONAL, 2, cd_values);
  } 
  else if (strncmp(codec, "bshuf", 5) == 0) {
    unsigned int cd_values[3] = { 0, 0, int_level };
    if      (strcmp(codec, "bshuf-lz4")  == 0) cd_values[1] = 2;
    else if (strcmp(codec, "bshuf-zstd") == 0) cd_values[1] = 3;
    H5Pset_filter(dcpl_id, 32008, H5Z_FLAG_OPTIONAL, 3, cd_values);
  }
  else if (strcmp(codec, "bzip2") == 0) {
    unsigned int cd_values[1] = { int_level };
    H5Pset_filter(dcpl_id, 307, H5Z_FLAG_OPTIONAL, 1, cd_values);
  }
  else if (strcmp(codec, "lzf") == 0) {
    H5Pset_filter(dcpl_id, 32000, H5Z_FLAG_OPTIONAL, 0, NULL);
  }
  else if (strcmp(codec, "snappy") == 0) {
    H5Pset_filter(dcpl_id, 32003, H5Z_FLAG_OPTIONAL, 0, NULL);
  }
  
  else if (strcmp(codec, "zfp-rev")  == 0) { H5Pset_zfp_reversible(dcpl_id);          }
  else if (strcmp(codec, "zfp-prec") == 0) { H5Pset_zfp_precision(dcpl_id, int_level);    }
  else if (strcmp(codec, "zfp-acc")  == 0) { H5Pset_zfp_accuracy(dcpl_id, dbl_level); }
  else if (strcmp(codec, "zfp-rate") == 0) { H5Pset_zfp_rate(dcpl_id, dbl_level);     }
  
  /* 7. Apply Checksum (Must be the absolute last filter in the pipeline) */
  if (checksum) H5Pset_fletcher32(dcpl_id);
}

/*
 * Opens an HDF5 file with read-write access.
 * If the file does not exist, it creates a new one.
 * If the file exists but is not a valid HDF5 file (e.g., text file), it throws an error.
 */
hid_t open_or_create_file(const char *fname) {
  hid_t file_id = -1;
  /* Suppress HDF5's auto error printing for H5Fis_hdf5.
   * It will (correctly) error if the file doesn't exist,
   * but we don't want to show that stack trace to the user.
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
  
  if (is_hdf5 > 0) {
    /* File exists and is a valid HDF5 file, open it. */
    file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  }
  else {
    /* File is not a valid HDF5 file. Check if it exists at all. */
    FILE *fp = fopen(fname, "r");
    
    /* File exists but is not HDF5. This is an error (prevent overwriting user data). */
    if (fp != NULL) { fclose(fp); error("File exists but is not a valid HDF5 file: %s", fname); }
    
    /* File does not exist, so create it. */
    file_id = H5Fcreate(fname, H5F_ACC_EXCL, H5P_DEFAULT, H5P_DEFAULT);
  }
  
  if (file_id < 0)
    error("Failed to open or create file: %s", fname); // # nocov
  
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
    if (XLENGTH(data) != 1) return -1;
    space_id = H5Screate(H5S_SCALAR);
  } else {
    /* ARRAY */
    *out_rank = (int)XLENGTH(dims);
    if (*out_rank == 0) return -1;
    
    /* R_alloc allocates memory that is garbage-collected by R. No free() needed. */
    hsize_t *h5_dims = (hsize_t *)R_alloc(*out_rank, sizeof(hsize_t));
    
    const int *r_dims = INTEGER(dims);
    hsize_t total_elements = 1;
    for (int i = 0; i < *out_rank; i++) {
      h5_dims[i] = (hsize_t)r_dims[i];
      total_elements *= h5_dims[i];
    }
    
    if (total_elements != (hsize_t)XLENGTH(data)) return -1;
    *out_h5_dims = h5_dims;
    space_id = H5Screate_simple(*out_rank, h5_dims, NULL);
  }
  return space_id;
}

/*
 * Checks if a link (dataset or group) exists and deletes it if it does.
 * This is used to implement "overwrite-by-default" behavior.
 */
herr_t handle_overwrite(hid_t file_id, const char *name) {
  /* Suppress HDF5's auto error printing for H5Lexists */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL); // Suppress error for non-existent link.
  
  htri_t link_exists = H5Lexists(file_id, name, H5P_DEFAULT);
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (link_exists > 0) { return H5Ldelete(file_id, name, H5P_DEFAULT); }
  else                 { return 0; }
}

/*
 * Checks if an attribute exists on an object and deletes it if it does.
 * This is used to implement "overwrite-by-default" behavior for attributes.
 */
herr_t handle_attribute_overwrite(hid_t file_id, hid_t obj_id, const char *attr_name) {
  /* Suppress HDF5's auto error printing for H5Aexists */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL); // Suppress error for non-existent attribute.
  
  htri_t attr_exists = H5Aexists(obj_id, attr_name);
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (attr_exists > 0) { return H5Adelete(obj_id, attr_name); }
  else                 { return 0; }
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
 * The goal is to create chunks that are roughly 1MB in size (default)
 * by iteratively halving the largest dimension until the target size is met.
 */
void calculate_chunk_dims(int rank, const hsize_t *dims, size_t type_size, SEXP compress, hsize_t *out_chunk_dims) {
  
  hsize_t target_size   = (hsize_t)asInteger(getAttrib(compress, install("chunk_size")));
  hsize_t current_bytes = type_size;

  for (int i = 0; i < rank; i++) {
    out_chunk_dims[i] = dims[i];
    current_bytes *= dims[i];
  }

  if (current_bytes > target_size) {
    while (current_bytes > target_size) {
      int max_idx = 0;
      for (int i = 1; i < rank; i++) {
        if (out_chunk_dims[i] > out_chunk_dims[max_idx]) max_idx = i;
      }
      if (out_chunk_dims[max_idx] <= 1) break;
      out_chunk_dims[max_idx] = (out_chunk_dims[max_idx] + 1) / 2;
      
      current_bytes = type_size;
      for (int i = 0; i < rank; i++) current_bytes *= out_chunk_dims[i];
    }
  }
}

/*
 * Creates an enum type for a factor.
 * * @param data The R factor object.
 * @param native_mem_layout If 1, uses H5T_NATIVE_INT to match R's memory layout (INTSXP).
 * If 0, uses the smallest sufficient standard integer type (U8/U16/U32)
 * to optimize file storage.
 */
static hid_t create_enum_type(SEXP data, int native_mem_layout) {
  
  SEXP levels = PROTECT(getAttrib(data, R_LevelsSymbol));
  R_xlen_t n_levels = XLENGTH(levels);
  
  hid_t type_id;
  
  if (native_mem_layout) {
    type_id = H5Tenum_create(H5T_NATIVE_INT);
  }
  else {
    if      (n_levels < 256)     type_id = H5Tenum_create(H5T_STD_U8LE);
    else if (n_levels < 65536)   type_id = H5Tenum_create(H5T_STD_U16LE);
    else                         type_id = H5Tenum_create(H5T_STD_U32LE); // # nocov
  }
  
  if (type_id < 0) { UNPROTECT(1); return -1; } // # nocov
  
  /* Insert each level name and its corresponding integer value into the enum type. */
  for (R_xlen_t i = 0; i < n_levels; i++) {
    unsigned long long val_idx = i + 1; /* R factors are 1-based */
    const char *name = Rf_translateCharUTF8(STRING_ELT(levels, i));
    
    /* H5Tenum_insert requires a pointer to the value matching the base type size */
    if (native_mem_layout) {
      int val = (int)val_idx;
      H5Tenum_insert(type_id, name, &val);
    }
    else {
      if      (n_levels < 256)   { uint8_t  val = (uint8_t)val_idx;  H5Tenum_insert(type_id, name, &val); }
      else if (n_levels < 65536) { uint16_t val = (uint16_t)val_idx; H5Tenum_insert(type_id, name, &val); }
      else                       { uint32_t val = (uint32_t)val_idx; H5Tenum_insert(type_id, name, &val); } // # nocov
    }
  }
  
  UNPROTECT(1);
  return type_id;
}

/*
 * Gets the native HDF5 memory type corresponding to an R vector's C-level type.
 * For example, REALSXP -> H5T_NATIVE_DOUBLE.
 */
hid_t create_r_memory_type(SEXP data, const char *dtype) {
  
  if (Rf_inherits(data, "integer64")) return H5Tcopy(H5T_NATIVE_INT64);
  if (Rf_inherits(data, "factor"))    return create_enum_type(data, 1);
  
  switch (TYPEOF(data)) {
    case REALSXP: return H5Tcopy(H5T_NATIVE_DOUBLE);
    case INTSXP:  return H5Tcopy(H5T_NATIVE_INT);
    case LGLSXP:  return H5Tcopy(H5T_NATIVE_INT);
    case CPLXSXP: return H5Tcomplex_create(H5T_NATIVE_DOUBLE);
    case RAWSXP:  return H5Tcreate(H5T_OPAQUE, 1);
    case STRSXP:  return create_string_type(dtype);
  }
  
  return -1; // # nocov
}

/*
 * Translates a user-provided string (e.g., "int32", "float64") into a
 * portable, little-endian HDF5 file datatype ID. Also handles special
 * types like "character", "raw", and "factor".
 */
hid_t create_h5_file_type(SEXP data, const char *dtype) {
  
  /* Mappings from user-friendly strings to HDF5 standard types for portability. */
  
  /* Floating Point Types (IEEE Standard) */
  if (strcmp(dtype, "float64")  == 0) return H5Tcopy(H5T_IEEE_F64LE);
  if (strcmp(dtype, "float32")  == 0) return H5Tcopy(H5T_IEEE_F32LE);
  if (strcmp(dtype, "float16")  == 0) return H5Tcopy(H5T_IEEE_F16LE);
  if (strcmp(dtype, "bfloat16") == 0) return H5Tcopy(H5T_FLOAT_BFLOAT16LE);
  
  /* Signed Integer Types (Standard) */
  if (strcmp(dtype, "int64") == 0) return H5Tcopy(H5T_STD_I64LE);
  if (strcmp(dtype, "int32") == 0) return H5Tcopy(H5T_STD_I32LE);
  if (strcmp(dtype, "int16") == 0) return H5Tcopy(H5T_STD_I16LE);
  if (strcmp(dtype, "int8")  == 0) return H5Tcopy(H5T_STD_I8LE);
  
  /* Unsigned Integer Types (Standard) */
  if (strcmp(dtype, "uint64") == 0) return H5Tcopy(H5T_STD_U64LE);
  if (strcmp(dtype, "uint32") == 0) return H5Tcopy(H5T_STD_U32LE);
  if (strcmp(dtype, "uint16") == 0) return H5Tcopy(H5T_STD_U16LE);
  if (strcmp(dtype, "uint8")  == 0) return H5Tcopy(H5T_STD_U8LE);
  
  /* String Types */
  if (TYPEOF(data) == STRSXP) return create_string_type(dtype);
  
  /* Other Types */
  if (strcmp(dtype, "raw")     == 0) return H5Tcreate(H5T_OPAQUE, 1);
  if (strcmp(dtype, "factor")  == 0) return create_enum_type(data, 0);
  if (strcmp(dtype, "complex") == 0) return H5Tcopy(H5T_COMPLEX_IEEE_F64LE);
  if (strcmp(dtype, "bit64")   == 0) return H5Tcopy(H5T_STD_I64LE);
  
  return -1; // # nocov
}
/*
 * Parses the dtype string to determine the byte width for fixed-length strings.
 * * Logic:
 * - Looks for a '[' delimiter (e.g., "ascii[100]").
 * - If found, parses the integer following it.
 * - Validates that the integer is positive and followed by a closing ']'.
 * * Returns:
 * - The byte width (size_t) if a valid fixed length is specified.
 * - 0 if the dtype indicates a variable-length string (no bracket or invalid format).
 */
size_t get_fixed_byte_width(const char *dtype) {
  if (!dtype) return 0;
  
  /* Look for the opening bracket */
  const char *open_bracket = strchr(dtype, '[');
  
  if (open_bracket) {
    char *endptr;
    
    /* Parse the integer immediately following '[' */
    long val = strtol(open_bracket + 1, &endptr, 10);
    
    /* Ensure:
     * 1. A number was actually parsed (endptr moved).
     * 2. The value is positive (size > 0).
     * 3. The parsing stopped exactly at the closing bracket ']'.
     */
    if (endptr != (open_bracket + 1) && val > 0 && *endptr == ']') {
      return (size_t)val;
    }
  }
  
  return 0; /* 0 indicates Variable Length */
}


/*
 * Creates an HDF5 string memory type.
 * Supports both Variable Length (default) and Fixed Length strings.
 *
 * Dtype Examples:
 * - "ascii"      -> Variable Length, ASCII encoded
 * - "utf8"       -> Variable Length, UTF-8 encoded
 * - "ascii[10]"   -> Fixed Length (10 bytes), ASCII encoded
 * - "utf8[100]"   -> Fixed Length (100 bytes), UTF-8 encoded
 */
hid_t create_string_type(const char *dtype) {
  
  /* 1. Determine Encoding */
  /* Check prefix: if it starts with "utf8", use UTF-8. Default to ASCII. */
  H5T_cset_t cset = H5T_CSET_ASCII;
  if (strncmp(dtype, "utf8", 4) == 0) {
    cset = H5T_CSET_UTF8;
  }
  
  /* 2. Determine Size (Fixed vs Variable) */
  size_t fixed_width = get_fixed_byte_width(dtype);
  size_t h5_size     = (fixed_width > 0) ? fixed_width : H5T_VARIABLE;
  
  /* 3. Create and Configure Type */
  hid_t str_type = H5Tcopy(H5T_C_S1);
  H5Tset_size(str_type, h5_size);
  H5Tset_cset(str_type, cset);
  
  return str_type;
}
