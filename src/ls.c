#include "h5lite.h"
#include <hdf5.h>
#include <stdlib.h>
#include <string.h>

/* --- DISCOVERY HELPERS --- */

typedef struct {
  int count;
  int idx;
  SEXP names;
  const char *gname; // Starting group name
  int full_names;    // Flag for full names
} h5_op_data_t;

/* Callback for Recursive LS (H5Ovisit) */
static herr_t op_visit_cb(hid_t obj, const char *name, const H5O_info_t *info, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  if (strcmp(name, ".") == 0 || strlen(name) == 0) return 0; // Skip root
  
  if (data->names != R_NilValue) {
    if (data->full_names) {
      // Construct full path: gname + / + name
      // Handle the case where gname is "/" to avoid "//"
      int gname_is_root = (strcmp(data->gname, "/") == 0);
      size_t len = (gname_is_root ? 0 : strlen(data->gname)) + 1 + strlen(name) + 1;
      char *full_name = (char *)malloc(len);
      if (gname_is_root) {
        snprintf(full_name, len, "%s", name);
      } else {
        snprintf(full_name, len, "%s/%s", data->gname, name);
      }
      SET_STRING_ELT(data->names, data->idx, mkChar(full_name));
      free(full_name);
    } else {
      SET_STRING_ELT(data->names, data->idx, mkChar(name));
    }
    data->idx++;
  } else {
    data->count++;
  }
  return 0;
}

/* Callback for Flat LS (H5Literate) */
static herr_t op_iterate_cb(hid_t group, const char *name, const H5L_info_t *info, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  
  if (data->names != R_NilValue) {
    if (data->full_names) {
      // Construct full path: gname + / + name
      int gname_is_root = (strcmp(data->gname, "/") == 0);
      size_t len = (gname_is_root ? 0 : strlen(data->gname)) + 1 + strlen(name) + 1;
      char *full_name = (char *)malloc(len);
      if (gname_is_root) {
        snprintf(full_name, len, "%s", name);
      } else {
        snprintf(full_name, len, "%s/%s", data->gname, name);
      }
      SET_STRING_ELT(data->names, data->idx, mkChar(full_name));
      free(full_name);
    } else {
      SET_STRING_ELT(data->names, data->idx, mkChar(name));
    }
    data->idx++;
  } else {
    data->count++;
  }
  return 0;
}

/* Callback for Attribute LS (H5Aiterate) */
static herr_t op_attr_cb(hid_t location_id, const char *attr_name, const H5A_info_t *ainfo, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  
  if (data->names != R_NilValue) {
    SET_STRING_ELT(data->names, data->idx, mkChar(attr_name));
    data->idx++;
  }
  return 0;
}


/* --- DISCOVERY FUNCTIONS --- */

SEXP C_h5_ls(SEXP filename, SEXP group_name, SEXP recursive, SEXP full_names) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *gname = CHAR(STRING_ELT(group_name, 0));
  int is_recursive = LOGICAL(recursive)[0];
  int use_full_names = LOGICAL(full_names)[0];
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t group_id = H5Oopen(file_id, gname, H5P_DEFAULT);
  if (group_id < 0) {
    H5Fclose(file_id);
    error("Failed to open group/object: %s", gname);
  }
  
  h5_op_data_t op_data;
  op_data.count = 0;
  op_data.idx = 0;
  op_data.names = R_NilValue;
  op_data.gname = gname;
  op_data.full_names = use_full_names;
  
  /* PASS 1: Count objects */
  if (is_recursive) {
    /* HDF5 1.14.6 API: Added H5O_INFO_BASIC */
    H5Ovisit(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, op_visit_cb, &op_data, H5O_INFO_BASIC);
  } else {
    H5Literate(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, NULL, op_iterate_cb, &op_data);
  }
  
  /* PASS 2: Collect names */
  if (op_data.count > 0) {
    PROTECT(op_data.names = allocVector(STRSXP, op_data.count));
    
    if (is_recursive) {
      /* HDF5 1.14.6 API: Added H5O_INFO_BASIC */
      H5Ovisit(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, op_visit_cb, &op_data, H5O_INFO_BASIC);
    } else {
      H5Literate(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, NULL, op_iterate_cb, &op_data);
    }
  } else {
    PROTECT(op_data.names = allocVector(STRSXP, 0));
  }
  
  H5Oclose(group_id);
  H5Fclose(file_id);
  
  UNPROTECT(1);
  return op_data.names;
}


SEXP C_h5_ls_attr(SEXP filename, SEXP obj_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t obj_id = H5Oopen(file_id, oname, H5P_DEFAULT);
  if (obj_id < 0) {
    H5Fclose(file_id);
    error("Failed to open object: %s", oname);
  }
  
  H5O_info_t oinfo;
  /* HDF5 1.14.6 API: Added H5O_INFO_NUM_ATTRS */
  herr_t status = H5Oget_info(obj_id, &oinfo, H5O_INFO_NUM_ATTRS);
  if (status < 0) {
    H5Oclose(obj_id); H5Fclose(file_id);
    error("Failed to get object info");
  }
  
  hsize_t n_attrs = oinfo.num_attrs;
  SEXP result;
  
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
