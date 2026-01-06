#include "h5lite.h"

/* --- HELPER: Map H5T to String --- */
SEXP h5_type_to_rstr(hid_t type_id) {
  
  H5T_class_t class_id = H5Tget_class(type_id);
  
  if (class_id == H5T_INTEGER) {
    
    /* Check for standard integer types first (LE and BE) */
    if (H5Tequal(type_id, H5T_STD_I8LE)  > 0 || H5Tequal(type_id, H5T_STD_I8BE)  > 0) return mkString("int8");
    if (H5Tequal(type_id, H5T_STD_I16LE) > 0 || H5Tequal(type_id, H5T_STD_I16BE) > 0) return mkString("int16");
    if (H5Tequal(type_id, H5T_STD_I32LE) > 0 || H5Tequal(type_id, H5T_STD_I32BE) > 0) return mkString("int32");
    if (H5Tequal(type_id, H5T_STD_I64LE) > 0 || H5Tequal(type_id, H5T_STD_I64BE) > 0) return mkString("int64");
    
    if (H5Tequal(type_id, H5T_STD_U8LE)  > 0 || H5Tequal(type_id, H5T_STD_U8BE)  > 0) return mkString("uint8");
    if (H5Tequal(type_id, H5T_STD_U16LE) > 0 || H5Tequal(type_id, H5T_STD_U16BE) > 0) return mkString("uint16");
    if (H5Tequal(type_id, H5T_STD_U32LE) > 0 || H5Tequal(type_id, H5T_STD_U32BE) > 0) return mkString("uint32");
    if (H5Tequal(type_id, H5T_STD_U64LE) > 0 || H5Tequal(type_id, H5T_STD_U64BE) > 0) return mkString("uint64");
    
    /* Generic fallback */
    return mkString("int"); // # nocov
  }
  
  if (class_id == H5T_FLOAT) {
    
    /* Check for standard float types first (LE and BE) */
    if (H5Tequal(type_id, H5T_IEEE_F16LE) > 0 || H5Tequal(type_id, H5T_IEEE_F16BE) > 0) return mkString("float16");
    if (H5Tequal(type_id, H5T_IEEE_F32LE) > 0 || H5Tequal(type_id, H5T_IEEE_F32BE) > 0) return mkString("float32");
    if (H5Tequal(type_id, H5T_IEEE_F64LE) > 0 || H5Tequal(type_id, H5T_IEEE_F64BE) > 0) return mkString("float64");
    
    /* Generic fallback */
    return mkString("float"); // # nocov
  }
  
  /* Handle other classes */
  switch(class_id) {
    case H5T_STRING: {
      H5T_cset_t cset = H5Tget_cset(type_id);
      if (cset == H5T_CSET_ASCII) return mkString("ascii");
      if (cset == H5T_CSET_UTF8)  return mkString("utf8");
      return mkString("string"); // # nocov
    }
    case H5T_COMPLEX:   return mkString("complex");
    case H5T_OPAQUE:    return mkString("opaque");
    case H5T_COMPOUND:  return mkString("compound");
    case H5T_ENUM:      return mkString("enum");
    case H5T_BITFIELD:  return mkString("bitfield");  // # nocov
    case H5T_REFERENCE: return mkString("reference"); // # nocov
    case H5T_VLEN:      return mkString("vlen");      // # nocov
    case H5T_ARRAY:     return mkString("array");     // # nocov
    default:            return mkString("unknown");   // # nocov
  }
  
  return mkString("unknown"); // # nocov
}

/* --- TYPEOF DATASET --- */
SEXP C_h5_typeof(SEXP filename, SEXP dset_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dset_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t dset_id = H5Dopen2(file_id, dname, H5P_DEFAULT);
  if (dset_id < 0) { // # nocov start
    H5Fclose(file_id);
    error("Failed to open dataset: %s", dname);
  } // # nocov end
  
  /* First, check for a NULL dataspace, which overrides the data type */
  hid_t space_id = H5Dget_space(dset_id);
  H5S_class_t space_class = H5Sget_simple_extent_type(space_id);
  H5Sclose(space_id);
  if (space_class == H5S_NULL) {
    H5Dclose(dset_id); H5Fclose(file_id);
    return mkString("null");
  }
  
  hid_t type_id = H5Dget_type(dset_id);
  SEXP  result  = h5_type_to_rstr(type_id);
  
  H5Tclose(type_id); H5Dclose(dset_id); H5Fclose(file_id);
  return result;
}

/* --- TYPEOF ATTRIBUTE --- */
SEXP C_h5_typeof_attr(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t attr_id = H5Aopen_by_name(file_id, oname, aname, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) { // # nocov start
    H5Fclose(file_id);
    error("Failed to open attribute: %s", aname);
  } // # nocov end
  
  /* First, check for a NULL dataspace */
  hid_t space_id = H5Aget_space(attr_id);
  H5S_class_t space_class = H5Sget_simple_extent_type(space_id);
  H5Sclose(space_id);
  if (space_class == H5S_NULL) {
    H5Aclose(attr_id); H5Fclose(file_id);
    return mkString("null");
  }
  
  hid_t type_id = H5Aget_type(attr_id);
  SEXP  result  = h5_type_to_rstr(type_id);
  
  H5Tclose(type_id); H5Aclose(attr_id); H5Fclose(file_id);
  return result;
}

/* --- DIM DATASET --- */
SEXP C_h5_dim(SEXP filename, SEXP dset_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dset_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t dset_id = H5Dopen2(file_id, dname, H5P_DEFAULT);
  if (dset_id < 0) { // # nocov start
    H5Fclose(file_id);
    error("Failed to open dataset: %s", dname);
  } // # nocov end
  
  hid_t space_id = H5Dget_space(dset_id);
  hid_t type_id  = H5Dget_type(dset_id);
  int   ndims    = H5Sget_simple_extent_ndims(space_id);
  
  if (ndims < 0) { // # nocov start
    H5Tclose(type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
    error("Failed to get dataset space: %s", dname);
  } // # nocov end
  
  SEXP result;
  
  /* If it's a 1D compound dataset, return c(nrow, ncol) like R's data.frame */
  if (H5Tget_class(type_id) == H5T_COMPOUND && ndims == 1) {
    result = PROTECT(allocVector(INTSXP, 2));
    hsize_t dims[1];
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    INTEGER(result)[0] = (int)dims[0];
    INTEGER(result)[1] = H5Tget_nmembers(type_id);
  } else {
    result = PROTECT(allocVector(INTSXP, ndims));
    if (ndims > 0) {
      hsize_t *dims = (hsize_t *)R_alloc(ndims, sizeof(hsize_t));
      H5Sget_simple_extent_dims(space_id, dims, NULL);
      for (int i = 0; i < ndims; i++) {
        /* Return dims exactly as HDF5 reports them (no transpose) */
        INTEGER(result)[i] = (int)dims[i];
      }
    }
  }
  
  H5Tclose(type_id); H5Sclose(space_id); H5Dclose(dset_id); H5Fclose(file_id);
  UNPROTECT(1);
  return result;
}

/* --- DIM ATTRIBUTE --- */
SEXP C_h5_dim_attr(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t attr_id = H5Aopen_by_name(file_id, oname, aname, H5P_DEFAULT, H5P_DEFAULT);
  if (attr_id < 0) { H5Fclose(file_id); error("Failed to open attribute: %s", aname); }
  
  hid_t space_id = H5Aget_space(attr_id);
  hid_t type_id  = H5Aget_type(attr_id);
  int   ndims    = H5Sget_simple_extent_ndims(space_id);
  
  if (ndims < 0) { // # nocov start
    H5Tclose(type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
    error("Failed to get attribute space: %s", aname);
  } // # nocov end
  
  SEXP result;
  
  if (H5Tget_class(type_id) == H5T_COMPOUND && ndims == 1) {
    result = PROTECT(allocVector(INTSXP, 2));
    hsize_t dims[1];
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    INTEGER(result)[0] = (int)dims[0];
    INTEGER(result)[1] = H5Tget_nmembers(type_id);
  } else {
    result = PROTECT(allocVector(INTSXP, ndims));
    if (ndims > 0) {
      hsize_t *dims = (hsize_t *)R_alloc(ndims, sizeof(hsize_t));
      H5Sget_simple_extent_dims(space_id, dims, NULL);
      for (int i = 0; i < ndims; i++) {
        INTEGER(result)[i] = (int)dims[i];
      }
    }
  }
  
  H5Tclose(type_id); H5Sclose(space_id); H5Aclose(attr_id); H5Fclose(file_id);
  UNPROTECT(1);
  return result;
}

/* --- EXISTS --- */
SEXP C_h5_exists(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  
  /* Suppress all HDF5 errors for this function */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  htri_t result = 0; // Default to FALSE
  
  /*
   * Try to open the file. 
   * If H5Fopen fails (e.g., text file, corrupt, no permission),
   * file_id will be < 0 and we will return FALSE.
   */
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  
  if (file_id >= 0) { /* File is valid HDF5 */
  
  if (attr_name != R_NilValue) { /* Check if the attribute exists */
  const char *aname = CHAR(STRING_ELT(attr_name, 0));
    result = H5Aexists_by_name(file_id, oname, aname, H5P_DEFAULT);
  }
  else { /* Check if the link exists (dataset, group, etc.) */
  result = H5Lexists(file_id, oname, H5P_DEFAULT);
  }
  H5Fclose(file_id);
  }
  
  /* Restore error handler */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  return ScalarLogical(result > 0);
}

/* --- HELPER: Check object type --- */
static int check_obj_type(const char *fname, const char *oname, H5O_type_t check_type) {
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) return 0;
  
  int result = 0;
  
  // Suppress errors for H5Oget_info_by_name
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  
  H5O_info_t oinfo;
  /* HDF5 1.12.0 API: Added H5O_INFO_BASIC */
  herr_t status = H5Oget_info_by_name(file_id, oname, &oinfo, H5O_INFO_BASIC, H5P_DEFAULT);
  
  // Restore error handler
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  
  if (status >= 0) {
    if (oinfo.type == check_type) {
      result = 1;
    }
  }
  
  H5Fclose(file_id);
  return result;
}

/* --- IS GROUP --- */
SEXP C_h5_is_group(SEXP filename, SEXP name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(name, 0));
  
  int is_group = check_obj_type(fname, oname, H5O_TYPE_GROUP);
  
  return ScalarLogical(is_group);
}

/* --- IS DATASET --- */
SEXP C_h5_is_dataset(SEXP filename, SEXP name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(name, 0));
  
  int is_dataset = check_obj_type(fname, oname, H5O_TYPE_DATASET);
  
  return ScalarLogical(is_dataset);
}

/* --- NAMES --- */
SEXP C_h5_names(SEXP filename, SEXP dset_name, SEXP attr_name ) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dset_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t loc_id;
  hid_t type_id;
  int is_dataset = 0;
  
  /* --- 1. Open Object (Dataset or Attribute) --- */
  if (attr_name != R_NilValue) {
    const char *aname = CHAR(STRING_ELT(attr_name, 0));
    loc_id = H5Aopen_by_name(file_id, dname, aname, H5P_DEFAULT, H5P_DEFAULT);
    if (loc_id < 0) { H5Fclose(file_id); error("Failed to open attribute: %s", aname); }
    type_id = H5Aget_type(loc_id);
    is_dataset = 0; /* Attributes cannot have Dimension Scales */
  } else {
    loc_id = H5Dopen2(file_id, dname, H5P_DEFAULT);
    if (loc_id < 0) { H5Fclose(file_id); error("Failed to open dataset: %s", dname); }
    type_id = H5Dget_type(loc_id);
    is_dataset = 1;
  }
  
  H5T_class_t class_id = H5Tget_class(type_id);
  SEXP result = R_NilValue;
  
  /* --- 2. Handle Compound Types (Data Frames) --- */
  /* This works for both Datasets and Attributes */
  if (class_id == H5T_COMPOUND) {
    int n_members = H5Tget_nmembers(type_id);
    if (n_members >= 0) {
      result = PROTECT(allocVector(STRSXP, n_members));
      for (int i = 0; i < n_members; i++) {
        char *name = H5Tget_member_name(type_id, i);
        if (name) { SET_STRING_ELT(result, i, mkChar(name)); }
        else      { SET_STRING_ELT(result, i, NA_STRING); } // # nocov
        H5free_memory(name);
      }
      UNPROTECT(1); /* Unprotect result before returning (re-protected below if needed) */
    }
    /* Re-protect for consistency with the shared return path below */
    if (result != R_NilValue) PROTECT(result);
  }
  
  /* --- 3. Handle Atomic Datasets (Dimension Scales) --- */
  else if (is_dataset) {
    
    hid_t space_id = H5Dget_space(loc_id);
    int rank = H5Sget_simple_extent_ndims(space_id);
    H5Sclose(space_id);
    
    if (rank > 0) {
      /* Determine which dimension scale to look for.
       * 1D Dataset: Dim 0 (the only dimension).
       * 2D+ Dataset: Dim 1 (Columns). */
      unsigned int dim_idx = (rank == 1) ? 0 : 1;
      
      /* Check if there are any scales attached to this dimension */
      if (H5DSget_num_scales(loc_id, dim_idx) > 0) {
        
        scale_visitor_t vis_data = { -1, 0 };
        H5DSiterate_scales(loc_id, dim_idx, NULL, visitor_find_scale, &vis_data);
        
        if (vis_data.found && vis_data.scale_id >= 0) {
          hid_t scale_id = vis_data.scale_id;
          hid_t s_type   = H5Dget_type(scale_id);
          
          /* Only use String scales for names */
          if (H5Tget_class(s_type) == H5T_STRING) {
            hid_t s_space = H5Dget_space(scale_id);
            int s_rank    = H5Sget_simple_extent_ndims(s_space);
            hsize_t *s_dims = (hsize_t *)R_alloc(s_rank > 0 ? s_rank : 1, sizeof(hsize_t));
            if (s_rank > 0) H5Sget_simple_extent_dims(s_space, s_dims, NULL);
            
            hsize_t total = 1;
            for(int k=0; k<s_rank; k++) total *= s_dims[k];
            
            result = read_character(scale_id, 1, s_type, s_space, s_rank, s_dims, total);
            
            /* read_character returns an unprotected SEXP, so protect it */
            if (result != R_NilValue) PROTECT(result);
            
            H5Sclose(s_space);
          }
          
          H5Tclose(s_type);
          H5Dclose(scale_id);
        }
      }
    }
  }
  
  /* --- Cleanup --- */
  H5Tclose(type_id);
  if (attr_name != R_NilValue) { H5Aclose(loc_id); }
  else                         { H5Dclose(loc_id); }
  H5Fclose(file_id);
  
  /* --- Return --- */
  if (result != R_NilValue) UNPROTECT(1);
  return result;
}



/*
 * H5Aiterate callback for listing attribute names.
 * Used by C_h5_attr_names.
 */
static herr_t op_attr_cb(hid_t location_id, const char *attr_name, const H5A_info_t *ainfo, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  if (data->names != R_NilValue) {
    SET_STRING_ELT(data->names, data->idx, mkChar(attr_name));
    data->idx++;
  }
  return 0;
}


/*
 * C implementation of h5_attr_names().
 * Lists the names of all attributes on a given object.
 */
SEXP C_h5_attr_names(SEXP filename, SEXP obj_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t obj_id = H5Oopen(file_id, oname, H5P_DEFAULT);
  if (obj_id < 0) { H5Fclose(file_id); error("Failed to open object: %s", oname); }
  
  /* Get the number of attributes on the object. */
  H5O_info_t oinfo;
  herr_t     status = H5Oget_info(obj_id, &oinfo, H5O_INFO_NUM_ATTRS);
  if (status < 0) { // # nocov start
    H5Oclose(obj_id); H5Fclose(file_id);
    error("Failed to get object info");
  } // # nocov end
  
  hsize_t n_attrs = oinfo.num_attrs;
  SEXP result;
  
  /* Allocate the result vector and use H5Aiterate to fill it. */
  if (n_attrs > 0) {
    PROTECT(result = allocVector(STRSXP, (R_xlen_t)n_attrs));
    h5_op_data_t op_data;
    op_data.names = result;
    op_data.idx = 0;
    H5Aiterate2(obj_id, H5_INDEX_NAME, H5_ITER_NATIVE, NULL, op_attr_cb, &op_data);
  } else {
    PROTECT(result = allocVector(STRSXP, 0));
  }
  
  H5Oclose(obj_id);
  H5Fclose(file_id);
  
  UNPROTECT(1);
  return result;
}
