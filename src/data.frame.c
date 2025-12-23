#include "h5lite.h"


/* --- COMPOUND (DATA FRAME) READER --- */

SEXP read_data_frame(hid_t obj_id, int is_dataset, hid_t file_type_id, hid_t space_id, SEXP rmap) {
  
  int ndims = H5Sget_simple_extent_ndims(space_id);
  hsize_t n_rows = (ndims > 0) ? H5Sget_simple_extent_npoints(space_id) : 1;
  
  int n_cols = H5Tget_nmembers(file_type_id);
  if (n_cols < 0) return mkChar("Failed to get number of compound members");
  
  H5T_class_t *member_classes   = (H5T_class_t *)R_alloc(n_cols, sizeof(H5T_class_t));
  R_TYPE      *member_rtypes    = (R_TYPE *)     R_alloc(n_cols, sizeof(R_TYPE));
  hid_t       *mem_member_types = (hid_t *)      R_alloc(n_cols, sizeof(hid_t));
  size_t       total_mem_size   = 0;
  
  SEXP result         = PROTECT(allocVector(VECSXP, n_cols));
  SEXP col_names_sexp = allocVector(STRSXP, n_cols);
  setAttrib(result, R_NamesSymbol, col_names_sexp);
  
  /* 1. Setup Types */
  for (int c = 0; c < n_cols; c++) {
    char *member_name = H5Tget_member_name(file_type_id, c);
    if (member_name) { SET_STRING_ELT(col_names_sexp, c, mkChar(member_name)); }
    else             { SET_STRING_ELT(col_names_sexp, c, NA_STRING); } // # nocov
    
    hid_t file_member_type = H5Tget_member_type(file_type_id, c);
    H5T_class_t file_class = H5Tget_class(file_member_type);
    member_classes[c] = file_class;
    member_rtypes[c] = rtype_from_map(file_member_type, rmap, member_name);
    
    if (file_class == H5T_INTEGER || file_class == H5T_FLOAT) {
      char bit64 = member_rtypes[c] == R_TYPE_BIT64;
      if (bit64) { mem_member_types[c] = H5Tcopy(H5T_NATIVE_INT64);  }
      else       { mem_member_types[c] = H5Tcopy(H5T_NATIVE_DOUBLE); }
    }
    else if (file_class == H5T_ENUM) {
      mem_member_types[c] = H5Tcopy(file_member_type);
    }
    else if (file_class == H5T_STRING) {
      mem_member_types[c] = H5Tcopy(H5T_C_S1);
      H5Tset_size(mem_member_types[c], H5T_VARIABLE);
      H5Tset_cset(mem_member_types[c], H5T_CSET_UTF8);
    }
    else if (file_class == H5T_OPAQUE) {
      mem_member_types[c] = H5Tcopy(file_member_type);
    }
    else if (file_class == H5T_COMPLEX) {
      mem_member_types[c] = H5Tcomplex_create(H5T_NATIVE_DOUBLE);
    }
    else { // # nocov start
      for (int i = 0; i < c; i++) H5Tclose(mem_member_types[i]);
      H5Tclose(file_member_type); UNPROTECT(1);
      return errmsg_1("Unsupported member type in compound dataset: %s", CHAR(STRING_ELT(col_names_sexp, c)));
    } // # nocov end
    total_mem_size += H5Tget_size(mem_member_types[c]);
    H5free_memory(member_name);
    H5Tclose(file_member_type);
  }
  
  /* 2. Create Compound Memory Type */
  hid_t mem_type_id = H5Tcreate(H5T_COMPOUND, total_mem_size);
  size_t mem_offset = 0;
  for (int c = 0; c < n_cols; c++) {
    char *member_name = H5Tget_member_name(file_type_id, c);
    H5Tinsert(mem_type_id, member_name, mem_offset, mem_member_types[c]);
    mem_offset += H5Tget_size(mem_member_types[c]);
    H5free_memory(member_name);
  }
  
  /* 3. Read Data */
  char *buffer = (char *)malloc(n_rows * total_mem_size);
  if (!buffer) { // # nocov start
    H5Tclose(mem_type_id); UNPROTECT(1); /* result */
    for (int c = 0; c < n_cols; c++) H5Tclose(mem_member_types[c]);
    return mkChar("Memory allocation failed"); 
  } // # nocov end
  
  herr_t status;
  if (is_dataset) { status = H5Dread(obj_id, mem_type_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer); }
  else            { status = H5Aread(obj_id, mem_type_id, buffer); }
  
  if (status < 0) {  // # nocov start
    free(buffer); H5Tclose(mem_type_id); UNPROTECT(1); /* result */
    for (int c = 0; c < n_cols; c++) H5Tclose(mem_member_types[c]);
    return mkChar("Failed to read compound data"); 
  } // # nocov end
  
  /* 4. Unpack Buffer */
  for (int c = 0; c < n_cols; c++) {
    size_t      member_offset = H5Tget_member_offset(mem_type_id, c);
    SEXP        r_column      = R_NilValue;
    H5T_class_t mclass        = member_classes[c];
    
    if (mclass == H5T_INTEGER || mclass == H5T_FLOAT) {
      r_column = PROTECT(allocVector(REALSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        double val; memcpy(&val, src, sizeof(double));
        REAL(r_column)[r] = val;
      }
      R_TYPE rtype = member_rtypes[c];
      if (rtype != R_TYPE_DOUBLE) {
        hid_t file_member_type = H5Tget_member_type(file_type_id, c);
        UNPROTECT(1);
        r_column = PROTECT(coerce_to_rtype(r_column, rtype, file_member_type));
        H5Tclose(file_member_type);
      }
    }
    else if (mclass == H5T_COMPLEX) {
      r_column = PROTECT(allocVector(CPLXSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        Rcomplex val; memcpy(&val, src, sizeof(Rcomplex));
        COMPLEX(r_column)[r] = val;
      }
    }
    else if (mclass == H5T_ENUM) {
      r_column = PROTECT(allocVector(INTSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        int val; memcpy(&val, src, sizeof(int));
        INTEGER(r_column)[r] = val;
      }
      hid_t file_member_type = H5Tget_member_type(file_type_id, c);
      int n_levels = H5Tget_nmembers(file_member_type);
      SEXP levels = PROTECT(allocVector(STRSXP, n_levels));
      for (int i = 0; i < n_levels; i++) {
        char *lname = H5Tget_member_name(file_member_type, i);
        SET_STRING_ELT(levels, i, mkChar(lname));
        H5free_memory(lname);
      }
      setAttrib(r_column, R_LevelsSymbol, levels);
      UNPROTECT(1);
      SEXP class_attr = PROTECT(allocVector(STRSXP, 1));
      SET_STRING_ELT(class_attr, 0, mkChar("factor"));
      setAttrib(r_column, R_ClassSymbol, class_attr);
      UNPROTECT(1);
      H5Tclose(file_member_type);
    } 
    else if (mclass == H5T_STRING) {
      r_column = PROTECT(allocVector(STRSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        char *str_ptr; memcpy(&str_ptr, src, sizeof(char *)); 
        if (str_ptr) { SET_STRING_ELT(r_column, r, mkChar(str_ptr)); }
        else         { SET_STRING_ELT(r_column, r, NA_STRING); }
      }
    } 
    else if (mclass == H5T_OPAQUE) {
      r_column = PROTECT(allocVector(RAWSXP, n_rows));
      for (hsize_t r = 0; r < n_rows; r++) {
        char *src = buffer + (r * total_mem_size) + member_offset;
        unsigned char val; memcpy(&val, src, sizeof(unsigned char));
        RAW(r_column)[r] = val;
      }
    }
    else { r_column = PROTECT(allocVector(LGLSXP, 0)); }  // # nocov
    
    SET_VECTOR_ELT(result, c, r_column);
    UNPROTECT(1);
  }
  
  SEXP class_attr = PROTECT(allocVector(STRSXP, 1));
  SET_STRING_ELT(class_attr, 0, mkChar("data.frame"));
  setAttrib(result, R_ClassSymbol, class_attr);
  UNPROTECT(1); 
  
  /* --- ROW NAMES HANDLING --- */
  
  /* Default: Integer sequence c(NA, -n_rows) */
  SEXP row_names_attr = PROTECT(allocVector(INTSXP, 2));
  INTEGER(row_names_attr)[0] = NA_INTEGER;
  INTEGER(row_names_attr)[1] = -n_rows; 
  
  /* NEW: Check for Dimension Scales on Dim 0 to set explicit row.names */
  if (is_dataset) {
    if (H5DSget_num_scales(obj_id, 0) > 0) {
      scale_visitor_t vis_data = { -1, 0 };
      H5DSiterate_scales(obj_id, 0, NULL, visitor_find_scale, &vis_data);
      
      if (vis_data.found && vis_data.scale_id >= 0) {
        hid_t scale_id = vis_data.scale_id;
        hid_t s_type   = H5Dget_type(scale_id);
        
        if (H5Tget_class(s_type) == H5T_STRING) {
          hid_t s_space = H5Dget_space(scale_id);
          hsize_t s_npoints = H5Sget_simple_extent_npoints(s_space);
          
          if (s_npoints == (hsize_t)n_rows) {
            /* Prepare args for read_character */
            int s_ndims = H5Sget_simple_extent_ndims(s_space);
            hsize_t *s_dims = (hsize_t*)R_alloc(s_ndims > 0 ? s_ndims : 1, sizeof(hsize_t));
            if (s_ndims > 0) H5Sget_simple_extent_dims(s_space, s_dims, NULL);
            
            SEXP scale_vals = PROTECT(read_character(scale_id, 1, s_type, s_space, s_ndims, s_dims, s_npoints));
            
            if (TYPEOF(scale_vals) == STRSXP) {
              /* Success! Replace the integer default with these strings */
              UNPROTECT(1); /* Unprotect the old row_names_attr */
              row_names_attr = scale_vals; /* Now protected by the PROTECT above */
            } else {
              UNPROTECT(1); /* Failed read, discard */ // # nocov
            }
          }
          H5Sclose(s_space);
        }
        H5Tclose(s_type);
        H5Dclose(scale_id);
      }
    }
  }
  
  setAttrib(result, R_RowNamesSymbol, row_names_attr);
  UNPROTECT(1); /* row_names_attr */
              
  if (is_dataset) { H5Dvlen_reclaim(mem_type_id, space_id, H5P_DEFAULT, buffer); }
  else            { H5Treclaim(mem_type_id, space_id, H5P_DEFAULT, buffer);      }
  free(buffer);
  
  for (int i = 0; i < n_cols; i++) H5Tclose(mem_member_types[i]);
  H5Tclose(mem_type_id);
  
  UNPROTECT(1);
  return result;
}

/*
 * Writes an R data.frame as a compound HDF5 object (dataset or attribute).
 *
 * This function handles the complexities of mapping R's column types to HDF5
 * compound members. It uses a "duplicate-and-coerce" strategy to safely handle
 * type promotions (e.g., integer to double for NA values) without altering the
 * user's original R object.
 */
SEXP write_dataframe(
  hid_t file_id, hid_t loc_id, const char *obj_name, SEXP data, 
  SEXP dtypes, int compress_level, int is_attribute) {

  /* --- 1. Get data.frame properties --- */
  R_xlen_t n_cols = XLENGTH(data);
  if (n_cols == 0) return errmsg_1("Cannot write empty data.frame '%s'", obj_name);
  R_xlen_t n_rows = (n_cols > 0) ? XLENGTH(VECTOR_ELT(data, 0)) : 0;
  
  /* Create and protect a shallow copy of `data` so we can modify it without affecting the original R object. */
  data = PROTECT(duplicate(data));
  SEXP col_names = PROTECT(getAttrib(data, R_NamesSymbol));
  
  /* --- 2. Prepare Columns, Types, and Coercion --- */
  /* We use col_ptrs to store the columns we will actually write. 
     If type promotion is needed (int -> float), we coerce here and store the result in col_ptrs. */
  SEXP *col_ptrs = (SEXP *) R_alloc(n_cols, sizeof(SEXP));

  hid_t *ft_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
  hid_t *mt_members = (hid_t *) R_alloc(n_cols, sizeof(hid_t));
  
  size_t total_file_size = 0;
  size_t total_mem_size = 0;

  for (R_xlen_t c = 0; c < n_cols; c++) {
    SEXP r_column = VECTOR_ELT(data, c);
    const char *dtype_str = CHAR(STRING_ELT(dtypes, c));
    
    /* Check if we need to promote Integer/Logical to Double to handle NAs correctly. */
    if (TYPEOF(r_column) == INTSXP || TYPEOF(r_column) == LGLSXP) {
      if (strcmp(dtype_str, "float64") == 0 ||
          strcmp(dtype_str, "float32") == 0 ||
          strcmp(dtype_str, "float16") == 0) {
        /* Coerce to REAL. This handles NA_INTEGER -> NA_REAL conversion automatically. */
        r_column = coerceVector(r_column, REALSXP);
        SET_VECTOR_ELT(data, c, r_column); // Update the data copy with the coerced column
      }
    }
    
    col_ptrs[c] = r_column;

    /* Now determine HDF5 types based on the (possibly coerced) column */
    ft_members[c] = create_h5_file_type(r_column, dtype_str);
    mt_members[c] = create_r_memory_type(r_column);
    if (ft_members[c] < 0 || mt_members[c] < 0) { // # nocov start
      for (int i = 0; i < c; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
      UNPROTECT(2); // data, col_names
      const char *col_name = CHAR(STRING_ELT(col_names, c));
      return errmsg_3("Could not resolve %s data type for column '%s' of object '%s'.", dtype_str, col_name, obj_name);
    } // # nocov end
    
    total_file_size += H5Tget_size(ft_members[c]);
    total_mem_size  += H5Tget_size(mt_members[c]);
  }
  
  hid_t file_type_id = H5Tcreate(H5T_COMPOUND, total_file_size);
  hid_t mem_type_id  = H5Tcreate(H5T_COMPOUND, total_mem_size);
  size_t file_offset = 0;
  size_t mem_offset  = 0;
  
  for (R_xlen_t c = 0; c < n_cols; c++) {
    const char *col_name = CHAR(STRING_ELT(col_names, c));
    H5Tinsert(file_type_id, col_name, file_offset, ft_members[c]);
    H5Tinsert(mem_type_id,  col_name, mem_offset,  mt_members[c]);
    file_offset += H5Tget_size(ft_members[c]);
    mem_offset  += H5Tget_size(mt_members[c]);
  }
  
  /* --- 3. Create C Buffer and Serialize Data --- */
  char *buffer = (char *) malloc(n_rows * total_mem_size);
  if (!buffer) { // # nocov start
    for (int c = 0; c < n_cols; c++) { H5Tclose(ft_members[c]); H5Tclose(mt_members[c]); }
    H5Tclose(file_type_id); H5Tclose(mem_type_id); UNPROTECT(2); // data, col_names
    return errmsg_1("Memory allocation failed for data.frame buffer: %s", obj_name);
  } // # nocov end
  
  for (hsize_t r = 0; r < n_rows; r++) {
    char *row_ptr = buffer + (r * total_mem_size);
    for (R_xlen_t c = 0; c < n_cols; c++) {
      size_t col_offset = H5Tget_member_offset(mem_type_id, c);
      char *dest = row_ptr + col_offset;
      
      /* Use the pointer from col_ptrs, which may be a coerced SEXP */
      SEXP r_col = col_ptrs[c];
      
      switch (TYPEOF(r_col)) {
        case REALSXP: {
          /* Handles doubles, bit64, and promoted integers/logicals */
          double val = REAL(r_col)[r];
          memcpy(dest, &val, sizeof(double));
          break;
        }
        case INTSXP: {
          int int_val = INTEGER(r_col)[r];
          memcpy(dest, &int_val, sizeof(int));
          break;
        }
        case LGLSXP: {
          int lgl_val = LOGICAL(r_col)[r];
          memcpy(dest, &lgl_val, sizeof(int));
          break;
        }
        case RAWSXP: {
          unsigned char val = RAW(r_col)[r];
          memcpy(dest, &val, sizeof(unsigned char));
          break;
        }
        case CPLXSXP: {
          Rcomplex val = COMPLEX(r_col)[r];
          memcpy(dest, &val, sizeof(Rcomplex));
          break;
        }
        case STRSXP: {
          SEXP s = STRING_ELT(r_col, r);
          const char *ptr = (s == NA_STRING) ? NULL : CHAR(s);
          memcpy(dest, &ptr, sizeof(const char *));
          break;
        }
        default: { // # nocov start
          free(buffer); UNPROTECT(2); // data, col_names
          for (int i = 0; i < n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
          H5Tclose(file_type_id); H5Tclose(mem_type_id);
          return errmsg_1("Unsupported R column type in data.frame: %s", CHAR(STRING_ELT(dtypes, c)));
        } // # nocov end
      }
    }
  }
  
  /* --- 4. Create Dataspace and Object --- */
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
  
  if (obj_id < 0) { // # nocov start
    free(buffer); UNPROTECT(2); // data, col_names
    for(int i = 0; i < n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
    H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Sclose(space_id);
    if (is_attribute) { return errmsg_1("Failed to create compound attribute '%s'", obj_name); } 
    else              { return errmsg_1("Failed to create compound dataset '%s'", obj_name);   }
  } // # nocov end
  
  /* --- 5. Write Data and Clean Up --- */
  herr_t status = write_buffer_to_object(obj_id, mem_type_id, buffer);
  
  /* Attach Row Names as Dimension Scale (if Dataset) */
  /* Only done if this is a dataset (not an attribute) and success so far */
  if (!is_attribute && status >= 0) {
      SEXP row_names = getAttrib(data, R_RowNamesSymbol);
      /* Only write row names if they are explicit strings.
       * R uses a special "compact" integer form for implicit row names (1:n), which we ignore. */
      if (row_names != R_NilValue && TYPEOF(row_names) == STRSXP) {
          char scale_name[1024];
          snprintf(scale_name, sizeof(scale_name), ".%s_rownames", obj_name);
          
          /* Use helper to write scale to Dim 0 */
          write_single_scale(loc_id, obj_id, scale_name, row_names, 0);
      }
  }

  if (is_attribute) { H5Aclose(obj_id); }
  else              { H5Dclose(obj_id); }
  
  free(buffer); UNPROTECT(2); // data, col_names
  for(int i = 0; i < n_cols; i++) { H5Tclose(ft_members[i]); H5Tclose(mt_members[i]); }
  H5Tclose(file_type_id); H5Tclose(mem_type_id); H5Sclose(space_id);
  
  if (status < 0) {
    if (is_attribute) { return errmsg_1("Failed to write compound attribute '%s'", obj_name); } // # nocov
    else              { return errmsg_1("Failed to write compound dataset '%s'", obj_name);   } // # nocov
  }
  
  return R_NilValue;
}
