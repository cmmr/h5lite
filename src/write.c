#include "h5lite.h"


/* --- WRITER: DATA.FRAME (COMPOUND) --- */
SEXP C_h5_write_dataframe(SEXP filename, SEXP dset_name, SEXP data, SEXP dtypes, SEXP compress_level) {
  
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *dname = CHAR(STRING_ELT(dset_name, 0));
  int compress = asInteger(compress_level);
  hid_t file_id = open_or_create_file(fname);
  
  handle_overwrite(file_id, dname);
  
  // Call the new helper function for compound data (is_attribute = 0)
  write_dataframe_as_compound(file_id, file_id, dname, data, dtypes, compress, 0);
  
  H5Fclose(file_id);
  
  return R_NilValue;
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
  
  if (strcmp(dtype_str, "null") == 0) {
    write_null_dataset(file_id, dname);
    H5Fclose(file_id);
    return R_NilValue;
  }

  hid_t space_id = create_dataspace(dims, data, &rank, &h5_dims);
  hid_t file_type_id = get_file_type(dtype_str, data);
  herr_t status = -1;
  
  /* Create Link Creation Property List to auto-create groups (like mkdir -p) */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_create_intermediate_group(lcpl_id, 1);
  
  /* Create Dataset Creation Property List for compression */
  hid_t dcpl_id = H5Pcreate(H5P_DATASET_CREATE);
  
  /* Only chunk if compression is requested or we explicitly want chunking */
  if (compress > 0 && rank > 0 && XLENGTH(data) > 0) {
    
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
  
  handle_overwrite(file_id, dname);
  
  hid_t dset_id = H5Dcreate2(file_id, dname, file_type_id, space_id, lcpl_id, dcpl_id, H5P_DEFAULT);
  H5Pclose(lcpl_id);
  H5Pclose(dcpl_id);
  
  if (dset_id < 0) {
    /* No free(h5_dims) needed here! R handles it. */
    H5Sclose(space_id); H5Tclose(file_type_id); H5Fclose(file_id); // # nocov
    error("Failed to create dataset"); // # nocov
  }
  
  status = write_atomic_dataset(dset_id, data, dtype_str, rank, h5_dims);
  
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
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("File must exist to write attributes: %s", fname);
  
  hid_t obj_id = H5Oopen(file_id, oname, H5P_DEFAULT);
  if (obj_id < 0) {
    H5Fclose(file_id); // # nocov
    error("Failed to open object: %s", oname); // # nocov
  }
  
  /* --- Overwrite Logic --- */
  handle_attribute_overwrite(file_id, obj_id, aname);
  
  if (TYPEOF(data) == VECSXP) { // This is the C-level check for is.list() / is.data.frame()
    // Call the new helper function for compound data (is_attribute = 1)
    write_dataframe_as_compound(file_id, obj_id, aname, data, dtype, 0, 1);
  } else { // Logic for non-data.frame attributes
    const char *dtype_str_check = CHAR(STRING_ELT(dtype, 0));
    if (strcmp(dtype_str_check, "null") == 0) {
      write_null_attribute(file_id, obj_id, aname);
    } else {
      write_atomic_attribute(file_id, obj_id, aname, data, dtype, dims);
    }
  }
  
  H5Oclose(obj_id);
  H5Fclose(file_id);
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
    H5Pclose(lcpl_id); // # nocov
    H5Fclose(file_id); // # nocov
    return R_NilValue; // # nocov
  }
  
  hid_t group_id = H5Gcreate2(file_id, gname, lcpl_id, H5P_DEFAULT, H5P_DEFAULT);
  
  H5Pclose(lcpl_id);
  
  if (group_id < 0) {
    H5Fclose(file_id); // # nocov
    error("Failed to create group"); // # nocov
  }
  
  H5Gclose(group_id);
  H5Fclose(file_id);
  
  return R_NilValue;
}


/*
 * Moves or renames an HDF5 link (dataset, group, etc.)
 * This is an efficient metadata operation; no data is read or rewritten.
 */
SEXP C_h5_move(SEXP filename, SEXP from_name, SEXP to_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *from = CHAR(STRING_ELT(from_name, 0));
  const char *to = CHAR(STRING_ELT(to_name, 0));
  
  /* Open file with Read-Write access */
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file (read-write access required): %s", fname);
  
  /* Create Link Creation Property List */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  if (lcpl_id < 0) {
    H5Fclose(file_id); // # nocov
    error("Failed to create link creation property list."); // # nocov
  }
  
  /* Set HDF5 to create intermediate groups (like mkdir -p) */
  herr_t prop_status = H5Pset_create_intermediate_group(lcpl_id, 1);
  if (prop_status < 0) {
    H5Pclose(lcpl_id); H5Fclose(file_id); // # nocov
    error("Failed to set intermediate group creation property."); // # nocov
  }
  
  /* --- Suppress HDF5's automatic error printing --- */
  herr_t (*old_func)(hid_t, void*);
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);
  /* --- */
  
  /*
   * H5Lmove
   * We move from/to paths relative to the file root (file_id).
   * We pass our new lcpl_id to the 'to' path. H5P_DEFAULT is fine for 'from'.
   */
  herr_t status = H5Lmove(file_id, from, file_id, to, lcpl_id, H5P_DEFAULT);
  
  /* --- Restore HDF5's automatic error printing --- */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
  /* --- */
  
  /* Close property list and file before checking status */
  H5Pclose(lcpl_id);
  H5Fclose(file_id);
  
  if (status < 0) {
    error("Failed to move object from '%s' to '%s'. Ensure source exists and destination path is valid.", from, to);
  }
  
  return R_NilValue;
}
