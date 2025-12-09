#include "h5lite.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Use the type helper defined in info.c */
extern SEXP h5_type_to_rstr(hid_t type_id);

/* --- COLOR & FORMATTING DEFINITIONS --- */

/* ANSI Color Codes
 * \033[90m = Bright Black (Dark Grey) - nice for "subtle" info
 * \033[3m  = Italic
 * \033[0m  = Reset to default
 */
#define COL_SUBTLE "\033[90m"
#define COL_ITALIC "\033[3m"
#define COL_RESET  "\033[0m"

/* --- FORMATTING HELPERS --- */

/*
 * Constructs the type string based on HDF5 type and dataspace.
 * Format examples:
 * "<float64 scalar>"   (Scalar)
 * "<int32 x 10>"       (1D Array)
 * "<double x 10 x 5>"  (2D Array)
 * * @param obj_id   ID of the object (Dataset or Attribute)
 * @param type_id  ID of the datatype (caller must open/get this)
 * @param space_id ID of the dataspace (caller must open/get this)
 * @param buffer   Buffer to write the string into
 * @param buf_len  Size of buffer
 */
static void format_type_and_dims(hid_t type_id, hid_t space_id, char *buffer, size_t buf_len) {
  /* Ensure buffer starts empty */
  if (buf_len > 0) buffer[0] = '\0';
  else return;
  
  /* 1. Get Type Name (e.g., "int32") */
  SEXP type_sexp = h5_type_to_rstr(type_id);
  PROTECT(type_sexp); 
  const char *type_base = CHAR(STRING_ELT(type_sexp, 0));
  
  /* 2. Get Dimensions */
  int ndims = H5Sget_simple_extent_ndims(space_id);
  
  if (ndims == 0) {
    /* Scalar Case: "<type scalar>" */
    snprintf(buffer, buf_len, "<%s scalar>", type_base);
  } else {
    /* Array Case: "<type x dim1 x ...>" */
    snprintf(buffer, buf_len, "<%s", type_base);
    
    hsize_t dims[32];
    if (ndims > 32) ndims = 32; /* Cap for display safety */
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    
    char tmp[64];
    for(int i = 0; i < ndims; i++) {
      snprintf(tmp, sizeof(tmp), " x %llu", (unsigned long long)dims[i]);
      
      /* Safe concatenation: ensure we don't write past buf_len */
      size_t current_len = strlen(buffer);
      if (current_len < buf_len - 1) {
        strncat(buffer, tmp, buf_len - current_len - 1);
      }
    }
    
    /* Close string: ">" */
    size_t current_len = strlen(buffer);
    if (current_len < buf_len - 1) {
      strncat(buffer, ">", buf_len - current_len - 1);
    } else {
      buffer[buf_len - 2] = '>';
      buffer[buf_len - 1] = '\0';
    }
  }
  
  UNPROTECT(1); // type_sexp
}

/* --- RECURSIVE PRINTING LOGIC --- */

/*
 * Recursively lists contents of a group/object with UTF-8 tree formatting.
 * * @param loc_id The ID of the current group being scanned.
 * @param prefix The current ASCII prefix string.
 * @param show_attrs Boolean (1 or 0) indicating whether to list attributes.
 */
static void h5_list_recursive(hid_t loc_id, const char *prefix, int show_attrs) {
  /* * HDF5 1.12+ signature for H5Oget_info requires 3 arguments. */
  unsigned fields = H5O_INFO_BASIC;
  if (show_attrs) fields |= H5O_INFO_NUM_ATTRS;
  
  H5O_info_t oinfo;
  if(H5Oget_info(loc_id, &oinfo, fields) < 0) return;
  
  hsize_t n_attrs = 0;
  if (show_attrs) {
    n_attrs = oinfo.num_attrs;
  }
  
  /* Get number of links (children objects) if this is a group */
  hsize_t n_links = 0;
  if (oinfo.type == H5O_TYPE_GROUP) {
    H5G_info_t ginfo;
    if(H5Gget_info(loc_id, &ginfo) >= 0) {
      n_links = ginfo.nlinks;
    }
  }
  
  hsize_t total_items = n_attrs + n_links;
  if (total_items == 0) return;
  
  /* * Tree Connectors (UTF-8 Box Drawing Characters)
   * We use Hex codes to avoid source file encoding issues.
   * Visual Width: 4 chars
   *
   * conn_norm: "├──"  (\xE2\x94\x9C + 2x \xE2\x94\x80)
   * conn_last: "└──"  (\xE2\x94\x94 + 2x \xE2\x94\x80)
   * pref_norm: "│  "  (\xE2\x94\x82 + 2 spaces)
   * pref_last: "   "  (3 spaces)
   */
  
  const char *conn_norm = "\xE2\x94\x9C\xE2\x94\x80\xE2\x94\x80";
  const char *conn_last = "\xE2\x94\x94\xE2\x94\x80\xE2\x94\x80";
  const char *pref_norm = "\xE2\x94\x82   ";
  const char *pref_last = "    ";
  
  /* Iterate over Attributes first (only if requested) */
  if (show_attrs) {
    for (hsize_t i = 0; i < n_attrs; i++) {
      int is_last = (i == total_items - 1); 
      
      /* Open Attribute */
      hid_t attr_id = H5Aopen_by_idx(loc_id, ".", H5_INDEX_NAME, H5_ITER_NATIVE, i, H5P_DEFAULT, H5P_DEFAULT);
      if (attr_id < 0) continue;
      
      /* Get Name */
      char attr_name[256];
      H5Aget_name(attr_id, sizeof(attr_name), attr_name);
      
      /* Get Type Info */
      hid_t atype = H5Aget_type(attr_id);
      hid_t aspace = H5Aget_space(attr_id);
      char type_str[256];
      format_type_and_dims(atype, aspace, type_str, sizeof(type_str));
      H5Sclose(aspace);
      H5Tclose(atype);
      H5Aclose(attr_id);
      
      /* Print: 
       * Structure: prefix + connector + " " + @ + ITALIC(name) + " " + SUBTLE(type) 
       */
      Rprintf("%s%s @%s%s%s %s%s%s\n", 
              prefix, 
              (is_last ? conn_last : conn_norm), 
              COL_ITALIC, attr_name, COL_RESET, 
              COL_SUBTLE, type_str, COL_RESET);
    }
  }
  
  /* Iterate over Links (children) second */
  for (hsize_t i = 0; i < n_links; i++) {
    hsize_t global_idx = n_attrs + i;
    int is_last = (global_idx == total_items - 1);
    
    /* Get Link Name */
    char name[256];
    if(H5Lget_name_by_idx(loc_id, ".", H5_INDEX_NAME, H5_ITER_NATIVE, i, name, sizeof(name), H5P_DEFAULT) < 0) continue;
    
    /* Open Object to inspect type/recurse */
    hid_t oid = H5Oopen(loc_id, name, H5P_DEFAULT);
    if (oid < 0) {
      /* Could not open (e.g. broken link), print basic info */
      Rprintf("%s%s %s " COL_SUBTLE "<Error>" COL_RESET "\n", 
              prefix, (is_last ? conn_last : conn_norm), name);
      continue; 
    }
    
    /* Determine Object Info */
    H5O_info_t child_info;
    H5Oget_info(oid, &child_info, H5O_INFO_BASIC);
    
    char type_str[256] = ""; // Start empty
    int is_group = (child_info.type == H5O_TYPE_GROUP);
    
    if (is_group) {
      /* Group: Leave type_str empty */
    } else if (child_info.type == H5O_TYPE_DATASET) {
      hid_t dtype = H5Dget_type(oid);
      hid_t dspace = H5Dget_space(oid);
      format_type_and_dims(dtype, dspace, type_str, sizeof(type_str));
      H5Sclose(dspace);
      H5Tclose(dtype);
    } else {
      snprintf(type_str, sizeof(type_str), "<NamedType>");
    }
    
    /* Print current node 
     * If Group: Just print Name
     * If Dataset: Print Name + Subtle Type Info
     */
    if (is_group) {
      Rprintf("%s%s %s\n", 
              prefix, 
              (is_last ? conn_last : conn_norm), 
              name);
    } else {
      Rprintf("%s%s %s " COL_SUBTLE "%s" COL_RESET "\n", 
              prefix, 
              (is_last ? conn_last : conn_norm), 
              name, type_str);
    }
    
    /* Recurse if Group */
    if (is_group) {
      /* Create new prefix */
      /* If this node was last, children get empty space, else vertical pipe */
      char new_prefix[1024]; 
      
      /* Safety: Ensure we don't overflow the prefix stack buffer */
      snprintf(new_prefix, sizeof(new_prefix), "%s%s", prefix, (is_last ? pref_last : pref_norm));
      
      h5_list_recursive(oid, new_prefix, show_attrs);
    }
    
    H5Oclose(oid);
  }
}

/*
 * C implementation of h5_str().
 * Prints a tree-structured recursive summary of an HDF5 object.
 * * @param filename   HDF5 file path
 * @param group_name Root group to start listing from
 * @param attrs      Logical TRUE to list attributes, FALSE to hide them.
 */
SEXP C_h5_str(SEXP filename, SEXP group_name, SEXP attrs) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *gname = CHAR(STRING_ELT(group_name, 0));
  int show_attrs = LOGICAL(attrs)[0];
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t group_id = H5Oopen(file_id, gname, H5P_DEFAULT);
  if (group_id < 0) {
    H5Fclose(file_id); // # nocov
    error("Failed to open group/object: %s", gname); // # nocov
  }
  
  /* Print Header (Directory Style) */
  /* Just the name, no bold */
  Rprintf("%s\n", gname);
  
  /* Start Recursion with empty prefix */
  h5_list_recursive(group_id, "", show_attrs);
  
  H5Oclose(group_id);
  H5Fclose(file_id);
  
  return R_NilValue;
}


/* --- DATA COLLECTION HELPERS (Unchanged for h5_ls) --- */

/*
 * A struct to pass data between the main 'ls' function and the HDF5 callback functions.
 * This allows the callbacks to either count items or fill an R character vector.
 */
typedef struct {
  int count;
  int idx;
  SEXP names;
  const char *gname;
  int full_names;
} h5_op_data_t;

/*
 * H5Ovisit callback for recursively listing objects.
 * This is used for `h5_ls(recursive = TRUE)`.
 */
static herr_t op_visit_cb(hid_t obj, const char *name, const H5O_info_t *info, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  /* Skip the root object itself. */
  if (strcmp(name, ".") == 0 || strlen(name) == 0) return 0;
  
  /* If names is not NULL, we are in the "fill" pass. Otherwise, we are counting. */
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

/*
 * H5Literate callback for non-recursively listing objects.
 * This is used for `h5_ls(recursive = FALSE)`.
 */
static herr_t op_iterate_cb(hid_t group, const char *name, const H5L_info_t *info, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  
  /* If names is not NULL, we are in the "fill" pass. Otherwise, we are counting. */
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

/*
 * H5Aiterate callback for listing attribute names.
 * Used by C_h5_ls_attr.
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
 * C implementation of h5_ls().
 * Lists objects in a group, either recursively or non-recursively.
 * It uses a two-pass approach: first pass counts items, second pass allocates and fills the R vector.
 */
SEXP C_h5_ls(SEXP filename, SEXP group_name, SEXP recursive, SEXP full_names) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *gname = CHAR(STRING_ELT(group_name, 0));
  int is_recursive = LOGICAL(recursive)[0];
  int use_full_names = LOGICAL(full_names)[0];
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t group_id = H5Oopen(file_id, gname, H5P_DEFAULT);
  if (group_id < 0) {
    H5Fclose(file_id); // # nocov
    error("Failed to open group/object: %s", gname); // # nocov
  }
  
  /* Initialize the data structure to pass to the callback. */
  h5_op_data_t op_data;
  op_data.count = 0;
  op_data.idx = 0;
  op_data.names = R_NilValue;
  op_data.gname = gname;
  op_data.full_names = use_full_names;
  
  /* First pass: Count the number of items. `op_data.names` is NULL. */
  if (is_recursive) {
    H5Ovisit(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, op_visit_cb, &op_data, H5O_INFO_BASIC);
  } else {
    H5Literate(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, NULL, op_iterate_cb, &op_data);
  }
  
  /* Second pass: Allocate the R vector and fill it with names. */
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

/*
 * C implementation of h5_ls_attr().
 * Lists the names of all attributes on a given object.
 */
SEXP C_h5_ls_attr(SEXP filename, SEXP obj_name) {
  const char *fname = CHAR(STRING_ELT(filename, 0));
  const char *oname = CHAR(STRING_ELT(obj_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t obj_id = H5Oopen(file_id, oname, H5P_DEFAULT);
  if (obj_id < 0) {
    H5Fclose(file_id); // # nocov
    error("Failed to open object: %s", oname); // # nocov
  }
  
  /* Get the number of attributes on the object. */
  H5O_info_t oinfo;
  /* Updated to 3-arg signature for HDF5 1.12+ */
  herr_t status = H5Oget_info(obj_id, &oinfo, H5O_INFO_NUM_ATTRS);
  if (status < 0) {
    H5Oclose(obj_id); H5Fclose(file_id); // # nocov
    error("Failed to get object info"); // # nocov
  }
  
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
