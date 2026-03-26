#include "h5lite.h"

/* Helper function to map HDF5 filter IDs to human-readable strings.
 * This covers standard filters and the official registry from The HDF Group. */
static const char* get_filter_name(H5Z_filter_t filter_id) {
  
  // # nocov start
  switch(filter_id) {
  
    /* Standard HDF5 Filters */
    case H5Z_FILTER_DEFLATE:     return "gzip";
    case H5Z_FILTER_SHUFFLE:     return "shuffle";
    case H5Z_FILTER_FLETCHER32:  return "fletcher32";
    case H5Z_FILTER_SZIP:        return "szip";
    case H5Z_FILTER_NBIT:        return "nbit";
    case H5Z_FILTER_SCALEOFFSET: return "scaleoffset";
    
    /* Registered Third-Party Plugins from The HDF Group */
    case 257:   return "hzip";
    case 258:   return "fpzip";
    case 305:   return "lzo";
    case 307:   return "bzip2";
    case 32000: return "lzf";
    case 32001: return "blosc";
    case 32002: return "mafisc";
    case 32003: return "snappy";
    case 32004: return "lz4";
    case 32005: return "apax";
    case 32006: return "cbf";
    case 32007: return "jpeg-xr";
    case 32008: return "bitshuffle";
    case 32009: return "spdp";
    case 32010: return "lpc-rice";
    case 32011: return "ccsds-123";
    case 32012: return "jpeg-ls";
    case 32013: return "zfp";
    case 32014: return "fpzip";
    case 32015: return "zstd";
    case 32016: return "b3d";
    case 32017: return "sz";
    case 32018: return "fcidecomp";
    case 32019: return "jpeg";
    case 32020: return "vbz";
    case 32021: return "fapec";
    case 32022: return "bitgroom";
    case 32023: return "gbr";
    case 32024: return "sz3";
    case 32025: return "delta-rice";
    case 32026: return "blosc2";
    case 32027: return "flac";
    case 32028: return "sperr";
    case 32029: return "trpx";
    case 32030: return "ffmpeg";
    case 32031: return "jpeg2000";
      
    default: return ""; /* Empty string acts as a signal to use the file-stored name */
  }
  // # nocov end
}


/*
 * C_h5_inspect
 * * Inspects a dataset and returns an R list describing its DCPL properties:
 * - layout: The storage layout (compact, contiguous, chunked, virtual)
 * - chunk_dims: R numeric vector of chunk dimensions (if chunked), otherwise NULL
 * - filters: A list of lists describing each filter in the pipeline
 */
SEXP C_h5_inspect(SEXP filename, SEXP dset_name) {
  int nprotect = 0;
  
  const char *fname = Rf_translateCharUTF8(STRING_ELT(filename, 0));
  const char *dname = Rf_translateCharUTF8(STRING_ELT(dset_name, 0));
  
  /* Open the file and dataset read-only */
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file for inspection: %s", fname);
  
  hid_t dset_id = H5Dopen2(file_id, dname, H5P_DEFAULT);
  if (dset_id < 0) { // # nocov start
    H5Fclose(file_id);
    error("Failed to open dataset: %s", dname);
  } // # nocov end
  
  /* Get Dataset Creation Property List (DCPL) */
  hid_t dcpl_id = H5Dget_create_plist(dset_id);
  if (dcpl_id < 0) { // # nocov start
    H5Dclose(dset_id);
    H5Fclose(file_id);
    error("Failed to retrieve DCPL for dataset: %s", dname);
  } // # nocov end
  
  /* --- 1. Inspect Layout --- */
  H5D_layout_t layout = H5Pget_layout(dcpl_id);
  const char *layout_str = "unknown";
  if      (layout == H5D_COMPACT)    layout_str = "compact";
  else if (layout == H5D_CONTIGUOUS) layout_str = "contiguous";
  else if (layout == H5D_CHUNKED)    layout_str = "chunked";
  else if (layout == H5D_VIRTUAL)    layout_str = "virtual"; // # nocov
  
  SEXP r_layout = PROTECT(mkString(layout_str));
  nprotect++;
  
  /* --- 2. Inspect Chunking --- */
  SEXP r_chunk_dims = R_NilValue;
  if (layout == H5D_CHUNKED) {
    int rank = H5Pget_chunk(dcpl_id, 0, NULL);
    if (rank > 0) {
      hsize_t *dims = (hsize_t *)R_alloc(rank, sizeof(hsize_t));
      H5Pget_chunk(dcpl_id, rank, dims);
      
      r_chunk_dims = PROTECT(allocVector(REALSXP, rank));
      nprotect++;
      for (int i = 0; i < rank; i++) {
        REAL(r_chunk_dims)[i] = (double)dims[i];
      }
    }
  }
  
  /* --- 3. Inspect Filters --- */
  int n_filters = H5Pget_nfilters(dcpl_id);
  SEXP r_filters = PROTECT(allocVector(VECSXP, n_filters));
  nprotect++;
  
  for (int i = 0; i < n_filters; i++) {
    unsigned int flags;
    size_t cd_nelmts = 0;
    char stored_name[256] = "";
    
    /* First pass: get the required number of cd_values */
    H5Pget_filter2(dcpl_id, (unsigned)i, &flags, &cd_nelmts, NULL, 0, NULL, NULL);
    
    unsigned int *cd_values = NULL;
    if (cd_nelmts > 0) {
      cd_values = (unsigned int *)R_alloc(cd_nelmts, sizeof(unsigned int));
    }
    
    /* Second pass: retrieve the actual filter details */
    H5Z_filter_t filter_id = H5Pget_filter2(dcpl_id, (unsigned)i, &flags, &cd_nelmts, cd_values, sizeof(stored_name), stored_name, NULL);
    
    /* Determine human-readable name */
    const char *hr_name = get_filter_name(filter_id);
    if (strlen(hr_name) == 0) {
      hr_name = (strlen(stored_name) > 0) ? stored_name : "unknown_plugin"; // # nocov
    }
    
    /* Create an R list for this specific filter */
    SEXP f_list = PROTECT(allocVector(VECSXP, 3));
    
    SEXP r_f_name = PROTECT(mkString(hr_name));
    SEXP r_f_id   = PROTECT(ScalarInteger(filter_id));
    SEXP r_f_cd   = PROTECT(allocVector(INTSXP, cd_nelmts));
    for (size_t j = 0; j < cd_nelmts; j++) {
      INTEGER(r_f_cd)[j] = cd_values[j];
    }
    
    SET_VECTOR_ELT(f_list, 0, r_f_name);
    SET_VECTOR_ELT(f_list, 1, r_f_id);
    SET_VECTOR_ELT(f_list, 2, r_f_cd);
    
    /* Set names for the filter's sub-list */
    SEXP f_names = PROTECT(allocVector(STRSXP, 3));
    SET_STRING_ELT(f_names, 0, mkChar("name"));
    SET_STRING_ELT(f_names, 1, mkChar("id"));
    SET_STRING_ELT(f_names, 2, mkChar("cd_values"));
    setAttrib(f_list, R_NamesSymbol, f_names);
    
    SET_VECTOR_ELT(r_filters, i, f_list);
    UNPROTECT(5); /* f_names, r_f_cd, r_f_id, r_f_name, f_list */
  }
  
  /* --- 4. Inspect Sizes and Type --- */
  hid_t space_id = H5Dget_space(dset_id);
  hid_t type_id  = H5Dget_type(dset_id);
  
  /* Calculate uncompressed size: Total elements * size of each element */
  hssize_t n_elements = H5Sget_simple_extent_npoints(space_id);
  size_t type_size = H5Tget_size(type_id);
  double uncompressed_size = (double)n_elements * (double)type_size;
  
  /* Get actual size on disk */
  double storage_size = (double)H5Dget_storage_size(dset_id);
  
  /* Call the R-string constructor directly and protect its output */
  SEXP r_type         = PROTECT(h5_type_to_rstr(type_id));
  SEXP r_uncomp_size  = PROTECT(ScalarReal(uncompressed_size));
  SEXP r_storage_size = PROTECT(ScalarReal(storage_size));
  nprotect += 3;
  
  H5Tclose(type_id);
  H5Sclose(space_id);
  
  /* --- 5. Assemble Final List --- */
  SEXP r_out = PROTECT(allocVector(VECSXP, 6));
  nprotect++;
  
  SET_VECTOR_ELT(r_out, 0, r_type);
  SET_VECTOR_ELT(r_out, 1, r_layout);
  SET_VECTOR_ELT(r_out, 2, r_uncomp_size);
  SET_VECTOR_ELT(r_out, 3, r_storage_size);
  SET_VECTOR_ELT(r_out, 4, r_chunk_dims);
  SET_VECTOR_ELT(r_out, 5, r_filters);
  
  SEXP out_names = PROTECT(allocVector(STRSXP, 6));
  nprotect++;
  SET_STRING_ELT(out_names, 0, mkChar("type"));
  SET_STRING_ELT(out_names, 1, mkChar("layout"));
  SET_STRING_ELT(out_names, 2, mkChar("uncompressed_size"));
  SET_STRING_ELT(out_names, 3, mkChar("storage_size"));
  SET_STRING_ELT(out_names, 4, mkChar("chunk_dims"));
  SET_STRING_ELT(out_names, 5, mkChar("filters"));
  setAttrib(r_out, R_NamesSymbol, out_names);
  
  /* Clean up HDF5 resources */
  H5Pclose(dcpl_id);
  H5Dclose(dset_id);
  H5Fclose(file_id);
  
  UNPROTECT(nprotect);
  return r_out;
}
