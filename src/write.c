#include "h5lite.h"
#include "H5DSpublic.h" /* Required for Dimension Scales */


/*
 * Writes an atomic R vector (numeric, character, etc.) to an already created HDF5
 * dataset or attribute. This function handles data transposition and NA values for strings.
 * It is a lower-level helper called by C_h5_write_dataset and write_atomic_attribute.
 */
SEXP write_atomic_dataset(hid_t obj_id, SEXP data, const char *dtype_str, int rank, hsize_t *h5_dims) {
  herr_t status = -1;
  int must_unprotect_data = 0;
  H5I_type_t obj_type = H5Iget_type(obj_id);

  if (obj_type != H5I_DATASET && obj_type != H5I_ATTR)
    return errmsg_1("Invalid object type provided to write_atomic_dataset for %s.", dtype_str); // # nocov

  /* --- Handle Character Data (Variable-Length Strings) --- */
  if (TYPEOF(data) == STRSXP) {

    hsize_t n = (hsize_t)XLENGTH(data);
    
    /* Create a buffer of C-style strings from the R vector, handling NA values. */
    const char **f_buffer = (const char **)malloc(n * sizeof(const char *));
    if (!f_buffer) return mkChar("Memory allocation failed for string buffer.");
    for (hsize_t i = 0; i < n; i++) {
      SEXP s = STRING_ELT(data, i);
      f_buffer[i] = (s == NA_STRING) ? NULL : Rf_translateCharUTF8(s);
    }
    
    /* Transpose from R's column-major to C's row-major order. */
    const char **c_buffer = (const char **)malloc(n * sizeof(const char *));
    if (!c_buffer) { free(f_buffer); return mkChar("Memory allocation failed for string buffer"); }
    h5_transpose((void*)f_buffer, (void*)c_buffer, rank, h5_dims, sizeof(char*), 0);

    /* Create a variable-length string memory type for writing. */
    hid_t mem_type_id = create_vl_string_type(dtype_str);

    /* Write the C buffer to the HDF5 object (dataset or attribute). */
    status = write_buffer_to_object(obj_id, mem_type_id, c_buffer);

    free(f_buffer); free(c_buffer); H5Tclose(mem_type_id);
  }
  
  /* --- Handle Numeric, Logical, Opaque, Factor Data --- */
  else {
    hsize_t total_elements = 1;
    if (rank > 0 && h5_dims) {
      for(int i=0; i<rank; i++) total_elements *= h5_dims[i];
    }
    
    /* --- Special Handling for Integer/Logical to Double Promotion --- */
    /* If we are writing an integer/logical vector to a float file type,
     * we must coerce it to a REALSXP. This correctly handles NA_INTEGER -> R_NaReal.
     */
    if (TYPEOF(data) == INTSXP || TYPEOF(data) == LGLSXP) {
      if (strcmp(dtype_str, "float64") == 0 ||
          strcmp(dtype_str, "float32") == 0 ||
          strcmp(dtype_str, "float16") == 0) {
        
        data = PROTECT(coerceVector(data, REALSXP));
        must_unprotect_data = 1;
      }
    }

    /* Get a direct pointer to the R object's data. */
    void *r_data_ptr = get_R_data_ptr(data);
    if (!r_data_ptr) return errmsg_1("Failed to get data pointer for %s.", dtype_str);

    hid_t mem_type_id = create_r_memory_type(data, dtype_str);
    if (mem_type_id < 0) return errmsg_1("Failed to get memory for %s.", dtype_str);
    
    /* Allocate a C buffer and transpose the R data into it. */
    size_t el_size = H5Tget_size(mem_type_id);
    void *c_buffer = malloc(total_elements * el_size);
    if (!c_buffer) { // # nocov start
       H5Tclose(mem_type_id);
       if (must_unprotect_data) UNPROTECT(1);
       return errmsg_1("Memory allocation failed for %s.", dtype_str);
    } // # nocov end

    /* Transpose from R's column-major to C's row-major order. */
    h5_transpose(r_data_ptr, c_buffer, rank, h5_dims, el_size, 0);

    status = write_buffer_to_object(obj_id, mem_type_id, c_buffer);

    free(c_buffer);
    H5Tclose(mem_type_id);
    if (must_unprotect_data) UNPROTECT(1);
  }

  if (status < 0)
    return errmsg_1("Failed to write data to dataset for %s.", dtype_str); // # nocov

  return R_NilValue;
}


/*
 * Orchestrates the creation and writing of an atomic (non-data.frame) attribute.
 * It creates the dataspace, file type, and attribute, then calls write_atomic_dataset.
 */
static SEXP write_atomic_attribute(hid_t file_id, hid_t obj_id, const char *attr_name, SEXP data, SEXP dtype, SEXP dims) {
  
  const char *dtype_str = CHAR(STRING_ELT(dtype, 0));
  int rank = 0;
  hsize_t *h5_dims = NULL;
  
  /* 1. Create the dataspace for the attribute. */
  hid_t space_id = create_dataspace(dims, data, &rank, &h5_dims);
  if (space_id < 0) return errmsg_1("Failed to create dataspace for attribute '%s'. Check dims.", attr_name);
  
  /* 2. Determine the HDF5 file data type. */
  hid_t file_type_id = create_h5_file_type(data, dtype_str); // This also handles special types like 'factor'
  if (file_type_id < 0) { // # nocov start
    H5Sclose(space_id);
    return errmsg_1("Failed to get file type for attribute '%s'", attr_name);
  } // # nocov end
  
  /* 3. Create the attribute on the specified object. */
  hid_t attr_id = H5Acreate2(obj_id, attr_name, file_type_id, space_id, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) { // # nocov start
    H5Sclose(space_id); H5Tclose(file_type_id);
    return errmsg_1("Failed to create attribute '%s'", attr_name);
  } // # nocov end
  
  /* 4. Write the data to the newly created attribute. */
  SEXP errmsg = write_atomic_dataset(attr_id, data, dtype_str, rank, h5_dims);
  
  H5Aclose(attr_id); H5Tclose(file_type_id); H5Sclose(space_id);
  
  if (TYPEOF(errmsg) == CHARSXP)
    return errmsg_2("Failed to write data to attribute '%s'\n%s", attr_name, CHAR(errmsg)); // # nocov
  
  return R_NilValue;
}

/*
 * Creates a dataset with a null dataspace.
 */
static SEXP write_null_dataset(hid_t file_id, const char *dname) {
  hid_t space_id = H5Screate(H5S_NULL);
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_create_intermediate_group(lcpl_id, 1);
  
  herr_t status = handle_overwrite(file_id, dname);
  if (status < 0) { // # nocov start
    H5Sclose(space_id); H5Pclose(lcpl_id);
    return errmsg_1("Failed to overwrite existing dataset: %s", dname);
  } // # nocov end
  
  hid_t dset_id = H5Dcreate2(file_id, dname, H5T_STD_I32LE, space_id, lcpl_id, H5P_DEFAULT, H5P_DEFAULT);

  H5Pclose(lcpl_id); H5Sclose(space_id);
  if (dset_id < 0) return errmsg_1("Failed to create null dataset: %s", dname);

  H5Dclose(dset_id);
  return R_NilValue;
}

/*
 * Creates an attribute with a null dataspace.
 */
static SEXP write_null_attribute(hid_t file_id, hid_t obj_id, const char *attr_name) {
  hid_t space_id = H5Screate(H5S_NULL);
  hid_t attr_id = H5Acreate2(obj_id, attr_name, H5T_STD_I32LE, space_id, H5P_DEFAULT, H5P_DEFAULT);
  
  H5Sclose(space_id);
  if (attr_id < 0) return errmsg_1("Failed to create null attribute '%s'", attr_name);
  
  H5Aclose(attr_id);
  return R_NilValue;
}


/* --- WRITER: DATASET --- */
SEXP C_h5_write_dataset(SEXP filename, SEXP dset_name, SEXP data, SEXP dtype, SEXP dims, SEXP compress_level) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dset_name, 0));
  int compress = asInteger(compress_level);
  
  hid_t file_id = open_or_create_file(fname);

  /* --- Overwrite Logic --- */
  herr_t status = handle_overwrite(file_id, dname);
  if (status < 0) { // # nocov start
    H5Fclose(file_id);
    error("Failed to overwrite existing dataset: %s", dname);
  } // # nocov end

  SEXP errmsg = R_NilValue;
  
  /* --- Dispatch for Compound Types (Data Frames) --- */
  if (TYPEOF(data) == VECSXP) {
    /* Now creates Dimension Scale for row.names inside this function */
    errmsg = write_dataframe(file_id, file_id, dname, data, dtype, compress, 0);
    H5Fclose(file_id);
  }

  /* --- Atomic Dataset Logic --- */
  else {

    const char *dtype_str = CHAR(STRING_ELT(dtype, 0));
    int rank = 0;
    hsize_t *h5_dims = NULL; /* Will be created by R_alloc() - no need to free() */
    
    if (strcmp(dtype_str, "null") == 0) {
      errmsg = write_null_dataset(file_id, dname);
      H5Fclose(file_id);
    }
    else {
  
      hid_t space_id     = create_dataspace(dims, data, &rank, &h5_dims);
      hid_t file_type_id = create_h5_file_type(data, dtype_str);
      
      /* Create Link Creation Property List to auto-create groups (like mkdir -p) */
      hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
      H5Pset_create_intermediate_group(lcpl_id, 1);
      
      /* Create Dataset Creation Property List for compression */
      hid_t dcpl_id = H5Pcreate(H5P_DATASET_CREATE);
      
      /* Only chunk if compression is requested */
      if (compress > 0 && rank > 0 && XLENGTH(data) > 0) {
        
        /* Get element size (e.g., 4 bytes for int, 8 for double) */
        size_t type_size = H5Tget_size(file_type_id);
        
        /* Heuristic for choosing a chunk size (~1 MB) */
        hsize_t *chunk_dims = (hsize_t *) R_alloc(rank, sizeof(hsize_t));
        calculate_chunk_dims(rank, h5_dims, type_size, chunk_dims);
        H5Pset_chunk(dcpl_id, rank, chunk_dims);
        
        /* Enable Shuffle: Only useful if element size > 1 byte */
        if (type_size > 1) H5Pset_shuffle(dcpl_id);
        
        H5Pset_deflate(dcpl_id, (unsigned int)compress);
      }
      
      hid_t dset_id = H5Dcreate2(file_id, dname, file_type_id, space_id, lcpl_id, dcpl_id, H5P_DEFAULT);
      H5Pclose(lcpl_id);
      H5Pclose(dcpl_id);
      
      if (dset_id < 0) {
        errmsg = errmsg_1("Failed to create dataset for '%s'", dname); // # nocov
      } else {
        /* Write the main data */
        errmsg = write_atomic_dataset(dset_id, data, dtype_str, rank, h5_dims);
        
        /* --- Write Dimension Scales if present --- */
        if (errmsg == R_NilValue) {
          write_r_dimscales(file_id, dset_id, dname, data);
        }
        
        H5Dclose(dset_id);
      }
      
      H5Tclose(file_type_id); H5Sclose(space_id); H5Fclose(file_id);
    }
  }

  if (TYPEOF(errmsg) == CHARSXP) error("%s", CHAR(errmsg));
  
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
  if (obj_id < 0) { H5Fclose(file_id); error("Failed to open object: %s", oname); }

  SEXP errmsg = R_NilValue;
  
  /* --- Overwrite Logic --- */
  herr_t status = handle_attribute_overwrite(file_id, obj_id, aname);

  if (status < 0) { /* Attribute exists and could not be overwritten */
    errmsg = errmsg_1("Failed to overwrite existing attribute '%s'", aname); // # nocov
  }
  else if (TYPEOF(data) == VECSXP) { /* a data.frame */
    /* Attribute writing mode: is_attribute = 1. Scales will NOT be written. */
    errmsg = write_dataframe(file_id, obj_id, aname, data, dtype, 0, 1);
  }
  else { /* an atomic type or NULL */
    const char *dtype_str_check = CHAR(STRING_ELT(dtype, 0));
    if (strcmp(dtype_str_check, "null") == 0) {
      errmsg = write_null_attribute(file_id, obj_id, aname);
    } else {
      errmsg = write_atomic_attribute(file_id, obj_id, aname, data, dtype, dims);
    }
  }
  
  H5Oclose(obj_id);
  H5Fclose(file_id);

  if (TYPEOF(errmsg) == CHARSXP) error("%s", CHAR(errmsg));

  return R_NilValue;
}
