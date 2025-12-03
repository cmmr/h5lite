#include "h5lite.h"

/*
 * Writes an atomic R vector (numeric, character, etc.) to an already created HDF5
 * dataset or attribute. This function handles data transposition and NA values for strings.
 * It is a lower-level helper called by C_h5_write_dataset and write_atomic_attribute.
 */
herr_t write_atomic_dataset(hid_t obj_id, SEXP data, const char *dtype_str, int rank, hsize_t *h5_dims) {
  herr_t status = -1;
  H5I_type_t obj_type = H5Iget_type(obj_id);

  if (obj_type != H5I_DATASET && obj_type != H5I_ATTR) {
    error("Invalid object type provided to write_atomic_dataset");
  }

  /* --- Handle Character Data (Variable-Length Strings) --- */
  if (strcmp(dtype_str, "character") == 0) {
    if (TYPEOF(data) != STRSXP) error("dtype 'character' requires character data");

    hsize_t n = (hsize_t)XLENGTH(data);
    /* Create a buffer of C-style strings from the R vector, handling NA values. */
    const char **f_buffer = (const char **)malloc(n * sizeof(const char *));
    if (!f_buffer) error("Memory allocation failed for string buffer");
    for (hsize_t i = 0; i < n; i++) {
      SEXP s = STRING_ELT(data, i);
      f_buffer[i] = (s == NA_STRING) ? NULL : CHAR(s);
    }
    
    /* Transpose from R's column-major to C's row-major order. */
    const char **c_buffer = (const char **)malloc(n * sizeof(const char *));
    if (!c_buffer) { free(f_buffer); error("Memory allocation failed for string buffer"); }
    h5_transpose((void*)f_buffer, (void*)c_buffer, rank, h5_dims, sizeof(char*), 0);

    /* Create a variable-length string memory type for writing. */
    hid_t mem_type_id = H5Tcopy(H5T_C_S1);
    H5Tset_size(mem_type_id, H5T_VARIABLE);
    H5Tset_cset(mem_type_id, H5T_CSET_UTF8);

    /* Write the C buffer to the HDF5 object (dataset or attribute). */
    status = write_buffer_to_object(obj_id, mem_type_id, c_buffer);

    free(f_buffer); free(c_buffer); H5Tclose(mem_type_id);

  } else { // Numeric, Logical, Opaque, Factor
    hsize_t total_elements = 1;
    if (rank > 0 && h5_dims) {
      for(int i=0; i<rank; i++) total_elements *= h5_dims[i];
    }

    /* Get a direct pointer to the R object's data. */
    void *r_data_ptr = get_R_data_ptr(data);
    if (!r_data_ptr) error("Failed to get data pointer for the given R type.");
    size_t el_size;
    hid_t mem_type_id;
    int must_close_mem_type = 0;

    if (strcmp(dtype_str, "raw") == 0) {
      /* Use OPAQUE memory type for raw data to match file type. */
      mem_type_id = H5Tcreate(H5T_OPAQUE, 1);
      el_size = sizeof(unsigned char);
      must_close_mem_type = 1;
    } else if (strcmp(dtype_str, "factor") == 0) {
      /* Use ENUM memory type for factor data to match file type. */
      /* We recreate the enum type definition from the R factor. */
      mem_type_id = get_file_type("factor", data);
      el_size = sizeof(int);
      must_close_mem_type = 1;
    } else { // Numeric/Logical
      mem_type_id = get_mem_type(data);
      /* Determine element size and if the memory type needs to be closed. */
      if (TYPEOF(data) == REALSXP) el_size = sizeof(double);
      else if (TYPEOF(data) == CPLXSXP) {
        el_size = sizeof(Rcomplex);
        must_close_mem_type = 1; // We created this type, so we must close it
      }
      else el_size = sizeof(int);
      // must_close_mem_type is already 0 for others
    }

    /* Allocate a C buffer and transpose the R data into it. */
    void *c_buffer = malloc(total_elements * el_size);
    if (!c_buffer) {
       if (must_close_mem_type) H5Tclose(mem_type_id);
       error("Memory allocation failed");
    }

    /* Transpose from R's column-major to C's row-major order. */
    h5_transpose(r_data_ptr, c_buffer, rank, h5_dims, el_size, 0);

    status = write_buffer_to_object(obj_id, mem_type_id, c_buffer);

    free(c_buffer);
    if (must_close_mem_type) H5Tclose(mem_type_id);
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
  
  /* 1. Create the dataspace for the attribute. */
  hid_t space_id = create_dataspace(dims, data, &rank, &h5_dims);
  if (space_id < 0) { H5Oclose(obj_id); H5Fclose(file_id); error("Failed to create dataspace for attribute."); }
  
  /* 2. Determine the HDF5 file data type. */
  hid_t file_type_id = get_file_type(dtype_str, data); // This also handles special types like 'factor'
  if (file_type_id < 0) {
    H5Sclose(space_id);
    H5Oclose(obj_id);
    H5Fclose(file_id);
    error("Failed to get file type for attribute.");
  }
  
  /* 3. Create the attribute on the specified object. */
  hid_t attr_id = H5Acreate2(obj_id, attr_name, file_type_id, space_id, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) {
    H5Sclose(space_id);
    H5Tclose(file_type_id);
    H5Oclose(obj_id);
    H5Fclose(file_id);
    error("Failed to create attribute '%s'", attr_name);
  }
  
  /* 4. Write the data to the newly created attribute. */
  herr_t status = write_atomic_dataset(attr_id, data, dtype_str, rank, h5_dims);
  
  H5Aclose(attr_id); H5Tclose(file_type_id); H5Sclose(space_id);
  
  if (status < 0) { H5Oclose(obj_id); H5Fclose(file_id); error("Failed to write data to attribute: %s", attr_name); }
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
