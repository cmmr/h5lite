#include "h5lite.h"

/*
 * Helper function to set the 'dim' attribute on an R object.
 * It only sets the attribute if the rank is greater than 1, as 1D R vectors
 * do not have a 'dim' attribute.
 */
static void set_r_dimensions(SEXP result, int ndims, hsize_t *dims) {
  if (ndims > 1 && dims != NULL) {
    SEXP dim_sexp;
    PROTECT(dim_sexp = allocVector(INTSXP, ndims));
    for (int i = 0; i < ndims; i++) {
      INTEGER(dim_sexp)[i] = (int)dims[i];
    }
    setAttrib(result, R_DimSymbol, dim_sexp);
    UNPROTECT(1);
  }
}

/*
 * C implementation of h5_read() for datasets.
 * It opens the dataset, determines its type, and dispatches to the appropriate reader logic.
 */
SEXP C_h5_read_dataset(SEXP filename, SEXP dataset_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dataset_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t dset_id = H5Dopen2(file_id, dname, H5P_DEFAULT);
  if (dset_id < 0) { H5Fclose(file_id); error("Failed to open dataset: %s", dname); }
  
  /* Get type, class, and space information from the dataset. */
  hid_t file_type_id = H5Dget_type(dset_id);
  H5T_class_t class_id = H5Tget_class(file_type_id);
  hid_t space_id = H5Dget_space(dset_id);
  H5S_class_t space_class = H5Sget_simple_extent_type(space_id);
  /* Handle NULL dataspace (for objects created from R's NULL). */
  if (space_class == H5S_NULL) {
    H5Sclose(space_id); H5Tclose(file_type_id); H5Dclose(dset_id); H5Fclose(file_id);
    return R_NilValue;
  }

  int ndims = H5Sget_simple_extent_ndims(space_id);
  hsize_t total_elements = 1;
  hsize_t *dims = NULL;
  
  /* Calculate total number of elements from dimensions. */
  if (ndims > 0) {
    dims = (hsize_t *)malloc(ndims * sizeof(hsize_t));
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    for (int i = 0; i < ndims; i++) total_elements *= dims[i];
  }
  
  SEXP result = R_NilValue;
  herr_t status = -1;
  
  /* --- INTEGER and FLOAT --- */
  if (class_id == H5T_INTEGER || class_id == H5T_FLOAT) {
    /* Read all numeric types into a double buffer for safety against overflow. */
    PROTECT(result = allocVector(REALSXP, (R_xlen_t)total_elements));
    double *c_buffer = (double *)malloc(total_elements * sizeof(double));
    if (!c_buffer) {
      if (dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
      UNPROTECT(1);
      error("Memory allocation failed for read buffer");
    }
    
    /* H5Dread handles the conversion from any file numeric type to NATIVE_DOUBLE. */
    status = H5Dread(dset_id, H5T_NATIVE_DOUBLE, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
    
    if (status >= 0) {
      /* Transpose from HDF5's row-major to R's column-major order. */
      h5_transpose(c_buffer, REAL(result), ndims, dims, sizeof(double), 1);
      set_r_dimensions(result, ndims, dims);
    }
    free(c_buffer);
  /* --- COMPLEX --- */
  } else if (class_id == H5T_COMPLEX) {
    /* Read into a buffer of Rcomplex structs. */
    PROTECT(result = allocVector(CPLXSXP, (R_xlen_t)total_elements));
    Rcomplex *c_buffer = (Rcomplex *)malloc(total_elements * sizeof(Rcomplex));
    if (!c_buffer) {
      if (dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
      UNPROTECT(1);
      error("Memory allocation failed for complex read buffer");
    }
    /* Create a memory type that matches R's Rcomplex struct. */
    hid_t mem_type_id = H5Tcomplex_create(H5T_NATIVE_DOUBLE);
    status = H5Dread(dset_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
    H5Tclose(mem_type_id);

    if (status >= 0) {
      h5_transpose(c_buffer, COMPLEX(result), ndims, dims, sizeof(Rcomplex), 1);
      set_r_dimensions(result, ndims, dims);
    }
    free(c_buffer);
  /* --- STRING --- */
  } else if (class_id == H5T_STRING) {
    htri_t is_variable = H5Tis_variable_str(file_type_id);
    PROTECT(result = allocVector(STRSXP, (R_xlen_t)total_elements));
    
    /* --- Variable-Length Strings --- */
    if (is_variable) {
      /* Create a memory type for variable-length C strings. */
      hid_t mem_type = H5Tcopy(H5T_C_S1);
      H5Tset_size(mem_type, H5T_VARIABLE); H5Tset_cset(mem_type, H5T_CSET_UTF8);
      char **c_buffer = (char **)malloc(total_elements * sizeof(char *));
      if (!c_buffer) {
        if (dims) free(dims);
        H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id); H5Tclose(mem_type);
        UNPROTECT(1);
        error("Memory allocation failed for string read buffer");
      }
      /* H5Dread allocates memory for each string in c_buffer. */
      status = H5Dread(dset_id, mem_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
      
      if (status >= 0) {
        /* Transpose the array of pointers. */
        char **f_buffer = (char **)malloc(total_elements * sizeof(char *));
        h5_transpose(c_buffer, f_buffer, ndims, dims, sizeof(char*), 1);
        /* Copy the strings into the R object, handling NULL pointers as NA. */
        for (hsize_t i = 0; i < total_elements; i++) {
          if (f_buffer[i]) SET_STRING_ELT(result, i, mkChar(f_buffer[i]));
          else SET_STRING_ELT(result, i, NA_STRING);
        }
        free(f_buffer);
        set_r_dimensions(result, ndims, dims);
      }
      /* Reclaim the memory that H5Dread allocated for the strings. */
      H5Dvlen_reclaim(mem_type, space_id, H5P_DEFAULT, c_buffer);
      free(c_buffer); H5Tclose(mem_type);
    /* --- Fixed-Length Strings --- */
    } else {
      size_t type_size = H5Tget_size(file_type_id);
      /* Create a memory type for a fixed-size C string. */
      hid_t mem_type = H5Tcopy(H5T_C_S1);
      H5Tset_size(mem_type, type_size);
      char *c_buffer = (char *)malloc(total_elements * type_size);
      if (!c_buffer) {
        if (dims) free(dims);
        H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id); H5Tclose(mem_type);
        UNPROTECT(1);
        error("Memory allocation failed for fixed-string read buffer");
      }
      status = H5Dread(dset_id, mem_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
      
      if (status >= 0) {
        /* Transpose the contiguous block of characters. */
        char *f_buffer = (char *)malloc(total_elements * type_size);
        h5_transpose(c_buffer, f_buffer, ndims, dims, type_size, 1);
        /* Manually copy each fixed-size string into a null-terminated buffer to create the R string. */
        char *single_str = (char *)malloc(type_size + 1);
        for (hsize_t i = 0; i < total_elements; i++) {
          memcpy(single_str, f_buffer + (i * type_size), type_size);
          single_str[type_size] = '\0';
          SET_STRING_ELT(result, i, mkChar(single_str));
        }
        free(single_str); free(f_buffer);
        set_r_dimensions(result, ndims, dims);
      }
      free(c_buffer); H5Tclose(mem_type);
    }
  /* --- OPAQUE (used for R raw) --- */
  } else if (class_id == H5T_OPAQUE) {
    /* h5lite only supports 1-byte opaque types, which map to R's raw type. */
    size_t type_size = H5Tget_size(file_type_id);
    if (type_size != 1) {
      if (dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
      error("h5lite only supports reading 1-byte opaque types as raw vectors");
    }
    
    PROTECT(result = allocVector(RAWSXP, (R_xlen_t)total_elements));
    unsigned char *c_buffer = (unsigned char *)malloc(total_elements * type_size);
    if (!c_buffer) {
      if (dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
      UNPROTECT(1);
      error("Memory allocation failed for raw read buffer");
    }
    
    /* Create an opaque memory type for a 1-to-1 byte copy */
    hid_t mem_type = H5Tcreate(H5T_OPAQUE, type_size);
    
    /* Read as opaque into the buffer, not UCHAR */
    status = H5Dread(dset_id, mem_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
    
    /* Close the custom mem type */
    H5Tclose(mem_type);
    
    if (status >= 0) {
      h5_transpose(c_buffer, RAW(result), ndims, dims, type_size, 1);
      set_r_dimensions(result, ndims, dims);
    }
    free(c_buffer);
    
  /* --- ENUM (used for R factor) --- */
  } else if (class_id == H5T_ENUM) {
    /* Get the number of members (levels) in the enum type. */
    int n_members = H5Tget_nmembers(file_type_id);
    if (n_members <= 0) {
      if (dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
      error("enum type has no members");
    }
    
    /* 1. Read the underlying integer data. */
    PROTECT(result = allocVector(INTSXP, (R_xlen_t)total_elements));
    int *c_buffer = (int *)malloc(total_elements * sizeof(int));
    if (!c_buffer) {
      if (dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
      UNPROTECT(1);
      error("Memory allocation failed for enum read buffer");
    }
    status = H5Dread(dset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT, c_buffer);
    
    if (status >= 0) {
      h5_transpose(c_buffer, INTEGER(result), ndims, dims, sizeof(int), 1);
      set_r_dimensions(result, ndims, dims);
    }
    free(c_buffer);
    
    /* 2. Get the levels (member names) from the HDF5 enum type. */
    SEXP levels;
    PROTECT(levels = allocVector(STRSXP, n_members));
    for (int i = 0; i < n_members; i++) {
      char *level_name = H5Tget_member_name(file_type_id, i);
      SET_STRING_ELT(levels, i, mkChar(level_name));
      H5free_memory(level_name);
    }
    
    /* 3. Assemble the R factor object by setting 'levels' and 'class' attributes. */
    setAttrib(result, R_LevelsSymbol, levels);
    
    SEXP class_attr;
    PROTECT(class_attr = allocVector(STRSXP, 1));
    SET_STRING_ELT(class_attr, 0, mkChar("factor"));
    setAttrib(result, R_ClassSymbol, class_attr);
    
    UNPROTECT(2); // levels, class_attr
  /* --- COMPOUND (used for R data.frame) --- */
  } else if (class_id == H5T_COMPOUND) {
    /* Delegate to the specialized data.frame reader. */
    result = read_dataframe(dset_id, file_type_id, space_id);
    PROTECT(result); /* Protect the result from read_dataframe. */
    status = 0;      /* Mark as successful. */
  } else {
    if (dims) free(dims);
    H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
    error("Unsupported HDF5 type for reading");
  }
  
  if (dims) free(dims);
  H5Tclose(file_type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
  
  if (status < 0) {
    UNPROTECT(1);
    error("Failed to read data from dataset '%s'", dname);
  }

  UNPROTECT(1);
  return result;
}

/*
 * C implementation of h5_read_attr().
 * This function is very similar to C_h5_read_dataset but operates on attributes.
 */
SEXP C_h5_read_attribute(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  hid_t attr_id = H5Aopen_by_name(file_id, oname, aname, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) { H5Fclose(file_id); error("Failed to open attribute: %s", aname); }
  
  /* Get type, class, and space info from the attribute. */
  hid_t file_type_id = H5Aget_type(attr_id);
  H5T_class_t class_id = H5Tget_class(file_type_id);
  hid_t space_id = H5Aget_space(attr_id);
  H5S_class_t space_class = H5Sget_simple_extent_type(space_id);
  /* Handle NULL dataspace. */
  if (space_class == H5S_NULL) {
    H5Sclose(space_id); H5Tclose(file_type_id); H5Aclose(attr_id); H5Fclose(file_id);
    return R_NilValue;
  }

  int ndims = H5Sget_simple_extent_ndims(space_id);
  hsize_t total_elements = 1;
  hsize_t *dims = NULL;
  
  /* Calculate total number of elements from dimensions. */
  if (ndims > 0) {
    dims = (hsize_t *)malloc(ndims * sizeof(hsize_t));
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    for (int i = 0; i < ndims; i++) total_elements *= dims[i];
  }
  
  SEXP result = R_NilValue;
  herr_t status = -1;
  
  /* --- INTEGER and FLOAT --- */
  if (class_id == H5T_INTEGER || class_id == H5T_FLOAT) {
    /* Read all numeric types into a double buffer for safety. */
    PROTECT(result = allocVector(REALSXP, (R_xlen_t)total_elements));
    double *c_buffer = (double *)malloc(total_elements * sizeof(double));
    if (!c_buffer) {
      if(dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
      UNPROTECT(1);
      error("Memory allocation failed for attribute read buffer");
    }
    /* H5Aread handles conversion to NATIVE_DOUBLE. */
    status = H5Aread(attr_id, H5T_NATIVE_DOUBLE, c_buffer);
    if (status >= 0) {
      /* Transpose from HDF5's row-major to R's column-major order. */
      h5_transpose(c_buffer, REAL(result), ndims, dims, sizeof(double), 1);
      set_r_dimensions(result, ndims, dims);
    }
    free(c_buffer);
  /* --- COMPLEX --- */
  } else if (class_id == H5T_COMPLEX) {
    /* Read into a buffer of Rcomplex structs. */
    PROTECT(result = allocVector(CPLXSXP, (R_xlen_t)total_elements));
    Rcomplex *c_buffer = (Rcomplex *)malloc(total_elements * sizeof(Rcomplex));
    if (!c_buffer) {
      if(dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
      UNPROTECT(1);
      error("Memory allocation failed for complex attribute read buffer");
    }
    /* Create a memory type that matches R's Rcomplex struct. */
    hid_t mem_type_id = H5Tcomplex_create(H5T_NATIVE_DOUBLE);
    status = H5Aread(attr_id, mem_type_id, c_buffer);
    H5Tclose(mem_type_id);

    if (status >= 0) {
      h5_transpose(c_buffer, COMPLEX(result), ndims, dims, sizeof(Rcomplex), 1);
      set_r_dimensions(result, ndims, dims);
    }
    free(c_buffer);
  /* --- STRING --- */
  } else if (class_id == H5T_STRING) {
    htri_t is_variable = H5Tis_variable_str(file_type_id);
    PROTECT(result = allocVector(STRSXP, (R_xlen_t)total_elements));
    
    /* --- Variable-Length Strings --- */
    if (is_variable) {
      /* Create a memory type for variable-length C strings. */
      hid_t mem_type = H5Tcopy(H5T_C_S1);
      H5Tset_size(mem_type, H5T_VARIABLE); H5Tset_cset(mem_type, H5T_CSET_UTF8);
      char **c_buffer = (char **)malloc(total_elements * sizeof(char *));
      if (!c_buffer) {
        if(dims) free(dims);
        H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id); H5Tclose(mem_type);
        UNPROTECT(1);
        error("Memory allocation failed for string attribute read buffer");
      }
      /* H5Aread allocates memory for each string in c_buffer. */
      status = H5Aread(attr_id, mem_type, c_buffer);
      if(status >= 0) {
        /* Transpose the array of pointers. */
        char **f_buffer = (char **)malloc(total_elements * sizeof(char *));
        h5_transpose(c_buffer, f_buffer, ndims, dims, sizeof(char*), 1);
        /* Copy the strings into the R object, handling NULL pointers as NA. */
        for(hsize_t i=0; i<total_elements; i++) {
          if(f_buffer[i]) SET_STRING_ELT(result, i, mkChar(f_buffer[i]));
          else SET_STRING_ELT(result, i, NA_STRING);
        }
        free(f_buffer);
        set_r_dimensions(result, ndims, dims);
      }
      /* Reclaim the memory that H5Aread allocated for the strings. */
      H5Dvlen_reclaim(mem_type, space_id, H5P_DEFAULT, c_buffer);
      free(c_buffer); H5Tclose(mem_type);
    /* --- Fixed-Length Strings --- */
    } else {
      size_t type_size = H5Tget_size(file_type_id);
      /* Create a memory type for a fixed-size C string. */
      hid_t mem_type = H5Tcopy(H5T_C_S1);
      H5Tset_size(mem_type, type_size);
      char *c_buffer = (char *)malloc(total_elements * type_size);
      if (!c_buffer) {
        if(dims) free(dims);
        H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id); H5Tclose(mem_type);
        UNPROTECT(1);
        error("Memory allocation failed for fixed-string attribute read buffer");
      }
      status = H5Aread(attr_id, mem_type, c_buffer);
      if(status >= 0) {
        /* Transpose the contiguous block of characters. */
        char *f_buffer = (char *)malloc(total_elements * type_size);
        h5_transpose(c_buffer, f_buffer, ndims, dims, type_size, 1);
        /* Manually copy each fixed-size string into a null-terminated buffer to create the R string. */
        char *single_str = (char *)malloc(type_size + 1);
        for(hsize_t i=0; i<total_elements; i++) {
          memcpy(single_str, f_buffer+(i*type_size), type_size);
          single_str[type_size] = '\0';
          SET_STRING_ELT(result, i, mkChar(single_str));
        }
        free(single_str); free(f_buffer);
        set_r_dimensions(result, ndims, dims);
      }
      free(c_buffer); H5Tclose(mem_type);
    }
  /* --- OPAQUE (used for R raw) --- */
  } else if (class_id == H5T_OPAQUE) {
    /* h5lite only supports 1-byte opaque types, which map to R's raw type. */
    size_t type_size = H5Tget_size(file_type_id);
    if (type_size != 1) {
      if(dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
      error("h5lite only supports reading 1-byte opaque types as raw vectors");
    }
    
    PROTECT(result = allocVector(RAWSXP, (R_xlen_t)total_elements));
    unsigned char *c_buffer = (unsigned char *)malloc(total_elements * type_size);
    if (!c_buffer) {
      if(dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
      UNPROTECT(1);
      error("Memory allocation failed for raw attribute read buffer");
    }
    
    /* Create an opaque memory type for a 1-to-1 byte copy */
    hid_t mem_type = H5Tcreate(H5T_OPAQUE, type_size);
    
    /* Read as opaque into the buffer, not UCHAR */
    status = H5Aread(attr_id, mem_type, c_buffer);
    
    /* Close the custom mem type */
    H5Tclose(mem_type);
    
    if (status >= 0) {
      h5_transpose(c_buffer, RAW(result), ndims, dims, type_size, 1);
      set_r_dimensions(result, ndims, dims);
    }
    free(c_buffer);
  /* --- ENUM (used for R factor) --- */
  } else if (class_id == H5T_ENUM) {
    /* Get the number of members (levels) in the enum type. */
    int n_members = H5Tget_nmembers(file_type_id);
    if (n_members <= 0) {
      if(dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
      error("enum type has no members");
    }
    
    /* 1. Read the underlying integer data. */
    PROTECT(result = allocVector(INTSXP, (R_xlen_t)total_elements));
    int *c_buffer = (int *)malloc(total_elements * sizeof(int));
    if (!c_buffer) {
      if(dims) free(dims);
      H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
      UNPROTECT(1);
      error("Memory allocation failed for enum attribute read buffer");
    }
    status = H5Aread(attr_id, H5T_NATIVE_INT, c_buffer);
    if (status >= 0) {
      h5_transpose(c_buffer, INTEGER(result), ndims, dims, sizeof(int), 1);
      set_r_dimensions(result, ndims, dims);
    }
    free(c_buffer);
    
    /* 2. Get the levels (member names) from the HDF5 enum type. */
    SEXP levels;
    PROTECT(levels = allocVector(STRSXP, n_members));
    for (int i = 0; i < n_members; i++) {
      char *level_name = H5Tget_member_name(file_type_id, i);
      SET_STRING_ELT(levels, i, mkChar(level_name));
      H5free_memory(level_name);
    }
    
    /* 3. Assemble the R factor object by setting 'levels' and 'class' attributes. */
    setAttrib(result, R_LevelsSymbol, levels);
    
    SEXP class_attr;
    PROTECT(class_attr = allocVector(STRSXP, 1));
    SET_STRING_ELT(class_attr, 0, mkChar("factor"));
    setAttrib(result, R_ClassSymbol, class_attr);
    
    UNPROTECT(2); // levels, class_attr
  /* --- COMPOUND (used for R data.frame) --- */
  } else if (class_id == H5T_COMPOUND) {
    /* Delegate to the specialized data.frame attribute reader. */
    result = read_compound_attribute(attr_id, file_type_id, space_id);
    PROTECT(result);
    status = 0; /* Mark as successful. */
    
  } else {
    if(dims) free(dims);
    H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
    error("Unsupported HDF5 type");
  }
  
  if(dims) free(dims);
  H5Tclose(file_type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
  if (status < 0) {
    UNPROTECT(1);
    error("Failed to read attribute '%s' from object '%s'", aname, oname);
  }
  UNPROTECT(1);
  return result;
}
