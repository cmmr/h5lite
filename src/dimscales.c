#include "h5lite.h"


/* --- HELPERS --- */

/* Helper function to set the 'dim' attribute on an R object. */
void set_r_dimensions(SEXP result, int ndims, hsize_t *dims) {
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

/* * Callback function to iterate over attached dimension scales.
 * We stop at the first one found, assuming it's the primary label set.
 */
herr_t visitor_find_scale(hid_t dset, unsigned dim, hid_t scale, void *visitor_data) {
  scale_visitor_t *data = (scale_visitor_t *)visitor_data;
  H5Iinc_ref(scale); /* Increment ref count to keep ID valid after return */
data->scale_id = scale;
data->found = 1;
return 1; /* Stop iteration after finding the first scale */
}


/* --- ATOMIC DATASET DIMENSION SCALES READER --- */
/*
 * Reads Dimension Scales attached to a dataset and converts them into R 
 * dimnames (list of character vectors).
 */
void read_r_dimscales(hid_t dset_id, int rank, SEXP result) {
  if (rank == 0) return; 
  
  SEXP dimnames_list = R_NilValue;
  int has_any_scale = 0;
  
  /* Allocate list of length 'rank' (e.g., 2 for a matrix) */
  if (rank == 1) { dimnames_list = PROTECT(allocVector(VECSXP, 1)); } 
  else           { dimnames_list = PROTECT(allocVector(VECSXP, rank)); }
  
  /* Iterate through each dimension (0 to rank-1) */
  for (int i = 0; i < rank; i++) {
    /* Check if this dimension has any scales attached */
    if (H5DSget_num_scales(dset_id, (unsigned)i) > 0) {
      
      scale_visitor_t vis_data = { -1, 0 };
      H5DSiterate_scales(dset_id, (unsigned)i, NULL, visitor_find_scale, &vis_data);
      
      if (vis_data.found && vis_data.scale_id >= 0) {
        hid_t scale_id = vis_data.scale_id;
        hid_t ftype = H5Dget_type(scale_id);
        hid_t space = H5Dget_space(scale_id);
        
        int s_ndims = H5Sget_simple_extent_ndims(space);
        hsize_t *s_dims = (hsize_t*)R_alloc(s_ndims > 0 ? s_ndims : 1, sizeof(hsize_t));
        if(s_ndims > 0) H5Sget_simple_extent_dims(space, s_dims, NULL);
        
        hsize_t total = 1;
        for(int k=0; k<s_ndims; k++) total *= s_dims[k];
        
        /* Only use string scales as R dimnames */
        if (H5Tget_class(ftype) == H5T_STRING) {
          SEXP names_vec = PROTECT(read_character(scale_id, 1, ftype, space, s_ndims, s_dims, total));
          
          /* Validate length matches expected dimension length */
          if (TYPEOF(names_vec) == STRSXP && (hsize_t)XLENGTH(names_vec) == total) {
            SET_VECTOR_ELT(dimnames_list, i, names_vec);
            has_any_scale = 1;
          }
          UNPROTECT(1);
        }
        H5Tclose(ftype); H5Sclose(space); H5Dclose(scale_id); 
      }
    }
  }
  
  /* Attach to R object */
  if (has_any_scale) {
    /* Special case: 1D vector uses "names" attribute, not "dimnames" list */
    if (rank == 1 && getAttrib(result, R_DimSymbol) == R_NilValue) {
      SEXP names = VECTOR_ELT(dimnames_list, 0);
      if (names != R_NilValue) { setAttrib(result, R_NamesSymbol, names); }
    } else {
      setAttrib(result, R_DimNamesSymbol, dimnames_list);
    }
  }
  UNPROTECT(1); 
}


/* --- DIMENSION SCALES WRITER (ATOMIC) --- */

/*
 * Checks if the SEXP has `names` or `dimnames` and creates/attaches HDF5 Dimension Scales.
 * Used for atomic vectors, matrices, and arrays.
 */
void write_r_dimscales(hid_t loc_id, hid_t dset_id, const char *dname, SEXP data) {
  
  /* Handle matrices and arrays (Detected by presence of 'dim' attribute) */
  if (getAttrib(data, R_DimSymbol) != R_NilValue) {
    SEXP dimnames = getAttrib(data, R_DimNamesSymbol);
    
    if (dimnames != R_NilValue && TYPEOF(dimnames) == VECSXP) {
      
      SEXP dims = getAttrib(data, R_DimSymbol);
      int rank = (int)XLENGTH(dims);
      
      /* Rank 2 is treated as a Matrix (rownames, colnames) */
      if (rank == 2) {
        if (XLENGTH(dimnames) == 2) {
          for (int i = 0; i < 2; i++) {
            char scale_name[1024];
            SEXP dlabels = VECTOR_ELT(dimnames, i);
            
            /* Skip NULL dimnames (e.g. only colnames set, rownames NULL) */
            if (dlabels == R_NilValue) continue; 
            
            if      (i == 0) { snprintf(scale_name, sizeof(scale_name), "%s_rownames", dname); }
            else if (i == 1) { snprintf(scale_name, sizeof(scale_name), "%s_colnames", dname); }
            
            write_single_scale(loc_id, dset_id, scale_name, dlabels, (unsigned)i);
          }
        }
      } 
      /* Rank != 2 is treated as an Array */
      else {
        if (XLENGTH(dimnames) == rank) {
          for (int i = 0; i < rank; i++) {
            char scale_name[1024];
            SEXP dlabels = VECTOR_ELT(dimnames, i);
            
            if (dlabels == R_NilValue) continue;
            
            snprintf(scale_name, sizeof(scale_name), "%s_dimnames_%d", dname, i + 1);
            write_single_scale(loc_id, dset_id, scale_name, dlabels, (unsigned)i);
          }
        }
      }
    }
  }
  
  else {
    /* Handle atomic vectors (names) */
    SEXP names = getAttrib(data, R_NamesSymbol);
    if (names != R_NilValue && TYPEOF(names) == STRSXP && XLENGTH(names) > 0) {
      char scale_name[1024];
      snprintf(scale_name, sizeof(scale_name), "%s_names", dname);
      write_single_scale(loc_id, dset_id, scale_name, names, 0);
    }
  }
}


/* --- DIMENSION SCALES HELPER --- */
/*
 * Creates a string dataset and attaches it as a Dimension Scale to the parent dataset.
 * * 1. Creates a new dataset (e.g., "dset_rownames") with UTF-8 strings.
 * 2. Marks it as a Dimension Scale using H5DSset_scale.
 * 3. Attaches it to the main dataset using H5DSattach_scale.
 */
void write_single_scale(hid_t loc_id, hid_t dset_id, const char *scale_name, SEXP labels, unsigned int dim_idx) {
  
  if (labels == R_NilValue || TYPEOF(labels) != STRSXP || XLENGTH(labels) == 0) return;
  
  /* 1. Remove existing scale if we are overwriting to prevent stale data */
  handle_overwrite(loc_id, scale_name);
  
  /* 2. Create the dataset for the labels */
  hsize_t scale_dim  = (hsize_t)XLENGTH(labels);
  hid_t space_id     = H5Screate_simple(1, &scale_dim, NULL);
  hid_t file_type_id = H5Tcopy(H5T_C_S1);
  H5Tset_size(file_type_id, H5T_VARIABLE);
  H5Tset_cset(file_type_id, H5T_CSET_UTF8);
  
  /* Create property list to ensure the SCALE NAME is UTF-8 */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_char_encoding(lcpl_id, H5T_CSET_UTF8);
  
  hid_t scale_dset_id = H5Dcreate2(loc_id, scale_name, file_type_id, space_id, lcpl_id, H5P_DEFAULT, H5P_DEFAULT);
  
  H5Pclose(lcpl_id);
  
  if (scale_dset_id >= 0) {
    /* 3. Write the strings */
    write_atomic_dataset(scale_dset_id, labels, "utf8", 1, &scale_dim);
    
    /* 4. Convert to Dimension Scale */
    H5DSset_scale(scale_dset_id, NULL);
    
    /* 5. Attach to main dataset */
    H5DSattach_scale(dset_id, scale_dset_id, dim_idx);
    
    H5Dclose(scale_dset_id);
  }
  H5Tclose(file_type_id);
  H5Sclose(space_id);
}
