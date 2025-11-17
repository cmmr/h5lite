#include "h5lite.h"
#include <stdlib.h>
#include <string.h>

/* Use the type helper defined in info.c */
extern SEXP h5_type_to_rstr(hid_t type_id);

/* --- HELPER: Format Dimensions with Brackets --- */
/* Formats dataspace dimensions into a string like "[100,50]" */
/* Returns empty string for scalars */
static void format_dims_bracket(hid_t space_id, char *buffer, size_t buf_len) {
  int ndims = H5Sget_simple_extent_ndims(space_id);
  
  /* Handle Scalar or Error */
  if (ndims <= 0) {
    buffer[0] = '\0';
    return;
  }
  
  /* Cap dimensions to prevent buffer overflow on extreme cases */
  hsize_t dims[32];
  if (ndims > 32) ndims = 32; 
  
  H5Sget_simple_extent_dims(space_id, dims, NULL);
  
  buffer[0] = '[';
  buffer[1] = '\0';
  
  char temp[64];
  for (int i = 0; i < ndims; i++) {
    snprintf(temp, sizeof(temp), "%llu", (unsigned long long)dims[i]);
    strncat(buffer, temp, buf_len - strlen(buffer) - 1);
    if (i < ndims - 1) {
      strncat(buffer, ",", buf_len - strlen(buffer) - 1);
    }
  }
  strncat(buffer, "]", buf_len - strlen(buffer) - 1);
}

/* --- SUMMARY/PRINT HELPERS --- */

/* Callback for printing attributes */
/* op_data is the name (path) of the parent object */
static herr_t op_print_attr_cb(hid_t loc_id, const char *attr_name, const H5A_info_t *ainfo, void *op_data) {
  const char *parent_name = (const char *)op_data;
  
  hid_t attr_id = H5Aopen(loc_id, attr_name, H5P_DEFAULT);
  if (attr_id < 0) return 0;
  
  /* 1. Get Dimensions (e.g., "[10]" or "") */
  char dim_str[128] = "";
  hid_t space_id = H5Aget_space(attr_id);
  format_dims_bracket(space_id, dim_str, sizeof(dim_str));
  H5Sclose(space_id);
  
  /* 2. Get Type Name (e.g., "int32") */
  hid_t type_id = H5Aget_type(attr_id);
  SEXP type_sexp = h5_type_to_rstr(type_id);
  PROTECT(type_sexp);
  const char *type_base = CHAR(STRING_ELT(type_sexp, 0));
  
  /* 3. Construct Composite Type String: "int32[10]" */
  char full_type[256];
  snprintf(full_type, sizeof(full_type), "%s%s", type_base, dim_str);
  
  /* 4. Construct Full Name: "parent@attr" */
  /* Note: If parent is ".", we usually just print "@attr", but here we assume paths. */
  Rprintf("%-12s %s @%s\n", full_type, parent_name, attr_name);
  
  UNPROTECT(1); // type_sexp
  H5Tclose(type_id);
  H5Aclose(attr_id);
  return 0;
}

/* Callback for Recursive Summary (H5Ovisit) */
static herr_t op_print_cb(hid_t root_id, const char *name, const H5O_info_t *info, void *op_data) {
  /* Skip visiting the root node itself to avoid "." in output, 
   unless specifically desired. Standard ls -R behavior usually lists children. */
  if (strcmp(name, ".") == 0 || strlen(name) == 0) return 0;
  
  char full_type[256] = "Unknown";
  char dim_str[128] = "";
  
  /* --- Determine "Type" String --- */
  if (info->type == H5O_TYPE_GROUP) {
    snprintf(full_type, sizeof(full_type), "Group");
  } 
  else if (info->type == H5O_TYPE_DATASET) {
    hid_t dset_id = H5Dopen2(root_id, name, H5P_DEFAULT);
    if (dset_id >= 0) {
      /* Get Dims: "[10,10]" */
      hid_t space_id = H5Dget_space(dset_id);
      format_dims_bracket(space_id, dim_str, sizeof(dim_str));
      H5Sclose(space_id);
      
      /* Get Type: "float64" */
      hid_t type_id = H5Dget_type(dset_id);
      SEXP type_sexp = h5_type_to_rstr(type_id);
      PROTECT(type_sexp);
      const char *type_base = CHAR(STRING_ELT(type_sexp, 0));
      
      /* Combine: "float64[10,10]" */
      snprintf(full_type, sizeof(full_type), "%s%s", type_base, dim_str);
      
      UNPROTECT(1);
      H5Tclose(type_id);
      H5Dclose(dset_id);
    }
  } 
  else if (info->type == H5O_TYPE_NAMED_DATATYPE) {
    snprintf(full_type, sizeof(full_type), "NamedType");
  }
  
  /* --- Print Object Line --- */
  /* Format: Type Name */
  Rprintf("%-12s %s\n", full_type, name);
  
  /* --- List Attributes --- */
  /* Open object to iterate attributes. Pass 'name' as op_data so we can print "name@attr" */
  hid_t oid = H5Oopen(root_id, name, H5P_DEFAULT);
  if (oid >= 0) {
    H5Aiterate2(oid, H5_INDEX_NAME, H5_ITER_NATIVE, NULL, op_print_attr_cb, (void*)name);
    H5Oclose(oid);
  }
  
  return 0;
}

/* --- SUMMARY FUNCTION --- */
SEXP C_h5_str(SEXP filename, SEXP group_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *gname = CHAR(STRING_ELT(group_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t group_id = H5Oopen(file_id, gname, H5P_DEFAULT);
  if (group_id < 0) {
    H5Fclose(file_id);
    error("Failed to open group/object: %s", gname);
  }
  
  /* Print Header */
  Rprintf("Listing contents of: %s\n", fname);
  Rprintf("Root group: %s\n", gname);
  Rprintf("----------------------------------------------------------------\n");
  Rprintf("%-12s %s\n", "Type", "Name");
  Rprintf("----------------------------------------------------------------\n");
  
  /* Recursively visit all objects */
  herr_t status = H5Ovisit(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, op_print_cb, NULL, H5O_INFO_BASIC);
  
  if (status < 0) {
    H5Oclose(group_id);
    H5Fclose(file_id);
    error("Error occurred during HDF5 traversal");
  }
  
  H5Oclose(group_id);
  H5Fclose(file_id);
  
  return R_NilValue;
}


typedef struct {
  int count;
  int idx;
  SEXP names;
  const char *gname;
  int full_names;
} h5_op_data_t;

static herr_t op_visit_cb(hid_t obj, const char *name, const H5O_info_t *info, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  if (strcmp(name, ".") == 0 || strlen(name) == 0) return 0;
  
  if (data->names != R_NilValue) {
    if (data->full_names) {
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

static herr_t op_iterate_cb(hid_t group, const char *name, const H5L_info_t *info, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  
  if (data->names != R_NilValue) {
    if (data->full_names) {
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

static herr_t op_attr_cb(hid_t location_id, const char *attr_name, const H5A_info_t *ainfo, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  if (data->names != R_NilValue) {
    SET_STRING_ELT(data->names, data->idx, mkChar(attr_name));
    data->idx++;
  }
  return 0;
}

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
  
  if (is_recursive) {
    H5Ovisit(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, op_visit_cb, &op_data, H5O_INFO_BASIC);
  } else {
    H5Literate(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, NULL, op_iterate_cb, &op_data);
  }
  
  if (op_data.count > 0) {
    PROTECT(op_data.names = allocVector(STRSXP, op_data.count));
    if (is_recursive) {
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
