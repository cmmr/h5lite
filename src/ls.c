#include "h5lite.h"

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
  if (buf_len <= 0) return;
  buffer[0] = '\0';
  
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
    
    hsize_t *dims = (hsize_t *)R_alloc(ndims, sizeof(hsize_t));
    H5Sget_simple_extent_dims(space_id, dims, NULL);
    
    char tmp[64];
    for(int i = 0; i < ndims; i++) {
      /* \xC3\x97 = × */
      snprintf(tmp, sizeof(tmp), " \xC3\x97 %llu", (unsigned long long)dims[i]);
      
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
    } else { // # nocov start
      buffer[buf_len - 2] = '>'; 
      buffer[buf_len - 1] = '\0'; 
    } // # nocov end
  }
  
  UNPROTECT(1); // type_sexp
}

/*
 * Helper to format the type of a compound member. 
 * Since members don't have dataspaces (unless they are arrays), 
 * we inspect the type class directly.
 */
static void format_member_type(hid_t type_id, char *buffer, size_t buf_len) {
  if (buf_len == 0) return;
  buffer[0] = '\0';

  SEXP type_sexp = h5_type_to_rstr(type_id);
  PROTECT(type_sexp); 
  const char *type_base = CHAR(STRING_ELT(type_sexp, 0));

  H5T_class_t tclass = H5Tget_class(type_id);
  
  if (tclass == H5T_ARRAY) { // # nocov start
    /* Array member */
    int ndims = H5Tget_array_ndims(type_id);
    hsize_t dims[32];
    H5Tget_array_dims2(type_id, dims);
    
    snprintf(buffer, buf_len, "<%s", type_base);
    char tmp[64];
    for(int i=0; i<ndims; i++) {
       snprintf(tmp, sizeof(tmp), " \xC3\x97 %llu", (unsigned long long)dims[i]);
       strncat(buffer, tmp, buf_len - strlen(buffer) - 1);
    }
    strncat(buffer, ">", buf_len - strlen(buffer) - 1);

  } // # nocov end
  else {
    /* Non-array member: Just print the type (e.g. "<uint8>" or "<utf8[3]>") */
    snprintf(buffer, buf_len, "<%s>", type_base);
  }

  UNPROTECT(1); // type_sexp
}

/* --- RECURSIVE PRINTING LOGIC --- */

/*
 * Recursively lists contents of a group/object with UTF-8 tree formatting.
 * * @param loc_id The ID of the current group being scanned.
 * @param prefix The current ASCII prefix string.
 * @param show_attrs Boolean (1 or 0) indicating whether to list attributes.
 * @param show_members Boolean (1 or 0) indicating whether to list compound members.
 */
static void h5_list_recursive(hid_t loc_id, const char *prefix, int show_attrs, int show_members, int show_markup) {
  
  
  
  /* --- COLOR & FORMATTING DEFINITIONS --- */
  
  /* ANSI Color Codes
   * \033[90m = Bright Black (Dark Grey) - nice for "subtle" info
   * \033[3m  = Italic
   * \033[0m  = Reset to default
   */
  const char *col_subtle = show_markup ? "\033[90m" : "";
  const char *col_italic = show_markup ? "\033[3m"  : "";
  const char *col_reset  = show_markup ? "\033[0m"  : "";
  
  
  unsigned fields = H5O_INFO_BASIC;
  if (show_attrs) fields |= H5O_INFO_NUM_ATTRS;
  
  H5O_info_t oinfo;
  if(H5Oget_info(loc_id, &oinfo, fields) < 0) return;
  
  /* 1. Count Attributes */
  hsize_t n_attrs = 0;
  if (show_attrs) {
    n_attrs = oinfo.num_attrs;
  }

  /* 2. Count Compound Members (if this object is a compound dataset) */
  hsize_t n_members = 0;
  hid_t compound_tid = -1;
  if (oinfo.type == H5O_TYPE_DATASET && show_members) {
    compound_tid = H5Dget_type(loc_id);
    if (H5Tget_class(compound_tid) == H5T_COMPOUND) {
      n_members = H5Tget_nmembers(compound_tid);
    } else {
      H5Tclose(compound_tid);
      compound_tid = -1;
    }
  }
  
  /* 3. Count Links (children objects) if this is a group */
  hsize_t n_links = 0;
  if (oinfo.type == H5O_TYPE_GROUP) {
    H5G_info_t ginfo;
    if(H5Gget_info(loc_id, &ginfo) >= 0) {
      n_links = ginfo.nlinks;
    }
  }
  
  hsize_t total_items = n_attrs + n_members + n_links;
  
  if (total_items == 0) {
    if (compound_tid >= 0) H5Tclose(compound_tid);
    return;
  }
  
  /* Tree Connectors */
  const char *conn_norm = "\xE2\x94\x9C\xE2\x94\x80\xE2\x94\x80";
  const char *conn_last = "\xE2\x94\x94\xE2\x94\x80\xE2\x94\x80";
  const char *pref_norm = "\xE2\x94\x82   ";
  const char *pref_last = "    ";
  
  /* --- PHASE 1: Attributes --- */
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
      hid_t atype  = H5Aget_type(attr_id);
      hid_t aspace = H5Aget_space(attr_id);
      char type_str[256];
      format_type_and_dims(atype, aspace, type_str, sizeof(type_str));
      H5Sclose(aspace);
      
      /* Print: prefix + connector + " " + @ + ITALIC(name) + " " + SUBTLE(type) */
      Rprintf("%s%s @%s%s%s %s%s%s\n", 
              prefix, 
              (is_last ? conn_last : conn_norm), 
              col_italic, attr_name, col_reset, 
              col_subtle, type_str, col_reset);
      
      /* Check for Compound Attribute Members */
      if (show_members && H5Tget_class(atype) == H5T_COMPOUND) {
        int n_memb = H5Tget_nmembers(atype);
        if (n_memb > 0) {
           /* Prepare prefix for the attribute's members.
            * If the attribute itself was last, its children get blank space.
            * Otherwise they get a vertical bar.
            */
           char memb_prefix[1024];
           snprintf(memb_prefix, sizeof(memb_prefix), "%s%s", prefix, (is_last ? pref_last : pref_norm));
           
           for (int m = 0; m < n_memb; m++) {
             int is_last_memb = (m == n_memb - 1);
             char *mname = H5Tget_member_name(atype, (unsigned)m);
             hid_t mtype = H5Tget_member_type(atype, (unsigned)m);
             char mtype_str[256];
             format_member_type(mtype, mtype_str, sizeof(mtype_str));
             
             Rprintf("%s%s $%s%s%s %s%s%s\n", 
                     memb_prefix,
                     (is_last_memb ? conn_last : conn_norm),
                     col_italic, mname, col_reset, 
                     col_subtle, mtype_str, col_reset);
             
             H5free_memory(mname);
             H5Tclose(mtype);
           }
        }
      }

      /* Close attribute type AFTER using it */
      H5Tclose(atype);
      H5Aclose(attr_id);
    }
  }

  /* --- PHASE 2: Compound Members (Datasets) --- */
  if (n_members > 0 && compound_tid >= 0) {
    for (hsize_t i = 0; i < n_members; i++) {
      /* Calculate global index to determine tree structure */
      hsize_t global_idx = n_attrs + i;
      int is_last = (global_idx == total_items - 1);

      char *memb_name = H5Tget_member_name(compound_tid, (unsigned)i);
      hid_t memb_type = H5Tget_member_type(compound_tid, (unsigned)i);
      
      char type_str[256];
      format_member_type(memb_type, type_str, sizeof(type_str));
      
      /* Print: prefix + connector + " " + $ + ITALIC(name) + " " + SUBTLE(type) */
      Rprintf("%s%s $%s%s%s %s%s%s\n", 
              prefix, 
              (is_last ? conn_last : conn_norm), 
              col_italic, memb_name, col_reset, 
              col_subtle, type_str, col_reset);

      H5free_memory(memb_name);
      H5Tclose(memb_type);
    }
    H5Tclose(compound_tid);
  }

  /* --- PHASE 3: Links (Children) --- */
  for (hsize_t i = 0; i < n_links; i++) {
    hsize_t global_idx = n_attrs + n_members + i;
    int is_last = (global_idx == total_items - 1);
    
    /* Get Link Name */
    char name[256];
    if(H5Lget_name_by_idx(loc_id, ".", H5_INDEX_NAME, H5_ITER_NATIVE, i, name, sizeof(name), H5P_DEFAULT) < 0) continue;
    
    /* Open Object to inspect type/recurse */
    hid_t oid = H5Oopen(loc_id, name, H5P_DEFAULT);
    if (oid < 0) { // # nocov start
      Rprintf("%s%s %s %s<Error>%s\n", 
              prefix, (is_last ? conn_last : conn_norm), 
              name, col_subtle, col_reset); 
      continue; 
    } // # nocov end
    
    /* Determine Object Info */
    H5O_info_t child_info;
    H5Oget_info(oid, &child_info, H5O_INFO_BASIC);
    
    char type_str[256] = ""; 
    int is_group = (child_info.type == H5O_TYPE_GROUP);
    int is_dataset = (child_info.type == H5O_TYPE_DATASET);
    int is_compound_ds = 0;
    
    if (is_group) {
      /* Group: Leave type_str empty */
    } else if (is_dataset) {
      hid_t dtype = H5Dget_type(oid);
      if (H5Tget_class(dtype) == H5T_COMPOUND) is_compound_ds = 1;
      hid_t dspace = H5Dget_space(oid);
      format_type_and_dims(dtype, dspace, type_str, sizeof(type_str));
      H5Sclose(dspace);
      H5Tclose(dtype);
    } else {
      snprintf(type_str, sizeof(type_str), "<NamedType>");  // # nocov
    }
    
    /* Print current node 
     * If Group: Print Name suffixed with /
     * If Dataset: Print Name + Subtle Type Info
     */
    if (is_group) {
      Rprintf("%s%s %s/\n", 
              prefix, (is_last ? conn_last : conn_norm), 
              name);
    } else {
      Rprintf("%s%s %s %s%s%s\n", 
              prefix, (is_last ? conn_last : conn_norm), 
              name, col_subtle, type_str, col_reset);
    }
    
    /* Recurse if Group OR if Compound Dataset (to show members) OR if Attributes requested */
    int should_recurse = is_group || show_attrs || (is_compound_ds && show_members);
    
    if (should_recurse) {
      /* Create new prefix */
      char new_prefix[1024]; 
      
      /* Safety: Ensure we don't overflow the prefix stack buffer */
      snprintf(new_prefix, sizeof(new_prefix), "%s%s", prefix, (is_last ? pref_last : pref_norm));
      
      h5_list_recursive(oid, new_prefix, show_attrs, show_members, show_markup);
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
 * @param members    Logical TRUE to list compound members, FALSE to hide them.
 */
SEXP C_h5_str(SEXP filename, SEXP group_name, SEXP attrs, SEXP members, SEXP markup) {
  const char *fname = Rf_translateCharUTF8(STRING_ELT(filename, 0));
  const char *gname = Rf_translateCharUTF8(STRING_ELT(group_name, 0));
  int show_attrs   = LOGICAL(attrs)[0];
  int show_members = LOGICAL(members)[0];
  int show_markup  = LOGICAL(markup)[0];
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t group_id = H5Oopen(file_id, gname, H5P_DEFAULT);
  if (group_id < 0) { // # nocov start
    H5Fclose(file_id); 
    error("Failed to open group/object: %s", gname); 
  } // # nocov end
  
  /* Print Header (Directory Style) */
  /* If it's a group, append trailing slash for consistency */
  H5O_info_t root_info;
  H5Oget_info(group_id, &root_info, H5O_INFO_BASIC);
  if (root_info.type == H5O_TYPE_GROUP && gname[strlen(gname)-1] != '/') {
      Rprintf("%s/\n", gname);
  } else {
      Rprintf("%s\n", gname);
  }
  
  /* Start Recursion with empty prefix */
  h5_list_recursive(group_id, "", show_attrs, show_members, show_markup);
  
  H5Oclose(group_id);
  H5Fclose(file_id);
  
  return R_NilValue;
}


/* --- DATA COLLECTION HELPERS --- */

/*
 * Helper to check if an object name is an HDF5 dimension scale.
 */
static int is_dimension_scale(hid_t loc_id, const char *name) {
  hid_t did = H5Dopen(loc_id, name, H5P_DEFAULT);
  if (did < 0) return 0;
  int is_scale = H5DSis_scale(did);
  H5Dclose(did);
  return (is_scale > 0);
}

/*
 * H5Ovisit callback for recursively listing objects.
 * This is used for `h5_ls(recursive = TRUE)`.
 */
static herr_t op_visit_cb(hid_t obj, const char *name, const H5O_info_t *info, void *op_data) {
  h5_op_data_t *data = (h5_op_data_t *)op_data;
  /* Skip the root object itself. */
  if (strcmp(name, ".") == 0 || strlen(name) == 0) return 0;
  
  /* Filter out dimension scales if requested */
  if (!data->show_scales && info->type == H5O_TYPE_DATASET) {
    if (is_dimension_scale(obj, name)) return 0;
  }
  
  /* If names is not NULL, we are in the "fill" pass. Otherwise, we are counting. */
  if (data->names != R_NilValue) {
    if (data->full_names) {
      int gname_is_root = (strcmp(data->gname, "/") == 0);
      size_t len = (gname_is_root ? 1 : strlen(data->gname)) + 1 + strlen(name) + 1;
      char *full_name = (char *)malloc(len);
      if (gname_is_root) {
        snprintf(full_name, len, "/%s", name);
      } else {
        snprintf(full_name, len, "%s/%s", data->gname, name);
      }
      SET_STRING_ELT(data->names, data->idx, mkCharCE(full_name, CE_UTF8));
      free(full_name);
    } else {
      SET_STRING_ELT(data->names, data->idx, mkCharCE(name, CE_UTF8));
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
  
  /* Filter out dimension scales if requested */
  if (!data->show_scales) {
    H5O_info_t oinfo;
    /* Use H5Oget_info_by_name to determine if it's a dataset */
    if (H5Oget_info_by_name(group, name, &oinfo, H5O_INFO_BASIC, H5P_DEFAULT) >= 0) {
      if (oinfo.type == H5O_TYPE_DATASET) {
        if (is_dimension_scale(group, name)) return 0;
      }
    }
  }
  
  /* If names is not NULL, we are in the "fill" pass. Otherwise, we are counting. */
  if (data->names != R_NilValue) {
    if (data->full_names) {
      int gname_is_root = (strcmp(data->gname, "/") == 0);
      size_t len = (gname_is_root ? 1 : strlen(data->gname)) + 1 + strlen(name) + 1;
      char *full_name = (char *)malloc(len);
      if (gname_is_root) {
        snprintf(full_name, len, "/%s", name);
      } else {
        snprintf(full_name, len, "%s/%s", data->gname, name);
      }
      SET_STRING_ELT(data->names, data->idx, mkCharCE(full_name, CE_UTF8));
      free(full_name);
    } else {
      SET_STRING_ELT(data->names, data->idx, mkCharCE(name, CE_UTF8));
    }
    data->idx++;
  } else {
    data->count++;
  }
  return 0;
}

/*
 * C implementation of h5_ls().
 * Lists objects in a group, either recursively or non-recursively.
 * It uses a two-pass approach: first pass counts items, second pass allocates and fills the R vector.
 */
SEXP C_h5_ls(SEXP filename, SEXP group_name, SEXP recursive, SEXP full_names, SEXP scales) {
  const char *fname = Rf_translateCharUTF8(STRING_ELT(filename, 0));
  const char *gname = Rf_translateCharUTF8(STRING_ELT(group_name, 0));
  int is_recursive   = LOGICAL(recursive)[0];
  int use_full_names = LOGICAL(full_names)[0];
  int show_scales    = LOGICAL(scales)[0];
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t group_id = H5Oopen(file_id, gname, H5P_DEFAULT);
  if (group_id < 0) { H5Fclose(file_id); error("Failed to open group/object: %s", gname); }
  
  /* Initialize the data structure to pass to the callback. */
  h5_op_data_t op_data;
  op_data.count       = 0;
  op_data.idx         = 0;
  op_data.names       = R_NilValue;
  op_data.gname       = gname;
  op_data.full_names  = use_full_names;
  op_data.show_scales = show_scales;
  
  /* First pass: Count the number of items. `op_data.names` is NULL. */
  if (is_recursive) { H5Ovisit(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, op_visit_cb, &op_data, H5O_INFO_BASIC); }
  else              { H5Literate(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, NULL, op_iterate_cb, &op_data); }
  
  /* Second pass: Allocate the R vector and fill it with names. */
  if (op_data.count > 0) {
    PROTECT(op_data.names = allocVector(STRSXP, op_data.count));
    if (is_recursive) { H5Ovisit(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, op_visit_cb, &op_data, H5O_INFO_BASIC); }
    else              { H5Literate(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, NULL, op_iterate_cb, &op_data); }
  } else {
    PROTECT(op_data.names = allocVector(STRSXP, 0));
  }
  
  H5Oclose(group_id);
  H5Fclose(file_id);
  
  UNPROTECT(1);
  return op_data.names;
}
