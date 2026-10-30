#include "h5lite.h"

/*
 * C implementation of h5_create_group().
 * Recursively creates groups to ensure the full path exists.
 * * Uses H5Pset_create_intermediate_group(1) to act like `mkdir -p`.
 */
SEXP C_h5_create_group(SEXP filename, SEXP group_name) {
  const char *fname = Rf_translateCharUTF8(STRING_ELT(filename, 0));
  const char *gname = Rf_translateCharUTF8(STRING_ELT(group_name, 0));
  
  /* 1. Root Group Optimization
   * The root group "/" always exists in a valid HDF5 file.
   * We just need to ensure the file exists, without opening an existing
   * file for writing (it may be read-only).
   */
  if (strcmp(gname, "/") == 0) {
    htri_t is_hdf5 = -1;
    H5E_BEGIN_TRY { is_hdf5 = H5Fis_hdf5(fname); } H5E_END_TRY;
    if (is_hdf5 > 0) return R_NilValue;

    hid_t file_id = open_or_create_file(fname);
    if (file_id >= 0) H5Fclose(file_id);
    return R_NilValue;
  }

  hid_t file_id = open_or_create_file(fname);

  /* Create any missing parents first, so they too track creation order */
  create_parent_groups(file_id, gname);

  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_create_intermediate_group(lcpl_id, 1);
  H5Pset_char_encoding(lcpl_id, H5T_CSET_UTF8);
  hid_t gcpl_id = ordered_gcpl();

  /* 2. Error Suppression
   * We expect H5Gcreate2 to fail if the group already exists.
   * We turn off HDF5's auto-error printing so the user doesn't see the
   * "name already exists" traceback in the console.
   */
  H5E_auto2_t old_func;
  void *old_client_data;
  H5Eget_auto(H5E_DEFAULT, &old_func, &old_client_data);
  H5Eset_auto(H5E_DEFAULT, NULL, NULL);

  /* Try to create the group */
  hid_t group_id = H5Gcreate2(file_id, gname, lcpl_id, gcpl_id, H5P_DEFAULT);

  /* Restore original error handler immediately */
  H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);

  H5Pclose(lcpl_id);
  H5Pclose(gcpl_id);
  
  if (group_id < 0) {
    /* Creation failed. Now we check: did it fail because it already exists? */
    
    /* Suppress errors for the check as well */
    H5Eset_auto(H5E_DEFAULT, NULL, NULL);
    hid_t check_id = H5Gopen2(file_id, gname, H5P_DEFAULT);
    H5Eset_auto(H5E_DEFAULT, old_func, old_client_data);
    
    if (check_id >= 0) {
      H5Gclose(check_id); /* It exists and is a group. Success. */
    } else {
      H5Fclose(file_id);
      /* Now we allow the error to be raised to R (e.g. file permission, or it's a Dataset) */
      error("Failed to create group (or object exists and is not a group): %s", gname);
    }
  }
  else {
    H5Gclose(group_id);
  }
  
  H5Fclose(file_id);
  return R_NilValue;
}


/* --- DIMENSION SCALE BOOKKEEPING --- */

#define MAX_SCALES_PER_DIM 64

typedef struct {
  hid_t ids[MAX_SCALES_PER_DIM];
  int   n;
} scale_list_t;

typedef struct {
  char  **paths;
  size_t  n, cap;
  const char *prefix;
} path_list_t;

/* H5DSiterate_scales callback: keeps every scale attached to one dimension. */
static herr_t collect_scales(hid_t dset, unsigned dim, hid_t scale, void *op_data) {
  scale_list_t *list = (scale_list_t *)op_data;
  if (list->n >= MAX_SCALES_PER_DIM) return 1;
  H5Iinc_ref(scale); /* Keep the ID valid after the callback returns */
  list->ids[list->n++] = scale;
  return 0;
}

/* H5Ovisit callback: records the full path of every dataset below a group. */
static herr_t collect_datasets(hid_t obj, const char *name, const H5O_info_t *info, void *op_data) {
  path_list_t *list = (path_list_t *)op_data;
  if (info->type != H5O_TYPE_DATASET) return 0;

  if (list->n == list->cap) {
    size_t cap  = list->cap ? list->cap * 2 : 16;
    char **grow = (char **)realloc(list->paths, cap * sizeof(char *));
    if (!grow) return -1;
    list->paths = grow;
    list->cap   = cap;
  }

  size_t len  = strlen(list->prefix) + strlen(name) + 2;
  char  *path = (char *)malloc(len);
  if (!path) return -1;
  snprintf(path, len, "%s/%s", list->prefix, name);
  list->paths[list->n++] = path;
  return 0;
}

static void free_path_list(path_list_t *list) {
  for (size_t i = 0; i < list->n; i++) free(list->paths[i]);
  free(list->paths);
}

/* Lists every dataset inside the group `group` (an absolute path). */
static path_list_t list_datasets(hid_t file_id, const char *group) {
  path_list_t list = { NULL, 0, 0, strcmp(group, "/") == 0 ? "" : group };
  hid_t group_id = H5Gopen2(file_id, group, H5P_DEFAULT);
  if (group_id >= 0) {
    H5Ovisit(group_id, H5_INDEX_NAME, H5_ITER_NATIVE, collect_datasets, &list, H5O_INFO_BASIC);
    H5Gclose(group_id);
  }
  return list;
}

/* Number of datasets a dimension scale is attached to. */
int scale_ref_count(hid_t scale_id) {
  if (H5Aexists(scale_id, "REFERENCE_LIST") <= 0) return 0;
  hid_t attr_id  = H5Aopen(scale_id, "REFERENCE_LIST", H5P_DEFAULT);
  hid_t space_id = H5Aget_space(attr_id);
  int   n        = (int)H5Sget_simple_extent_npoints(space_id);
  H5Sclose(space_id);
  H5Aclose(attr_id);
  return n;
}

/* The absolute path of an object, or NULL. The caller frees the result. */
static char *object_path(hid_t obj_id) {
  ssize_t len = H5Iget_name(obj_id, NULL, 0);
  if (len <= 0) return NULL;
  char *path = (char *)malloc((size_t)len + 1);
  if (path) H5Iget_name(obj_id, path, (size_t)len + 1);
  return path;
}

/* Detaches the scale `scale_id` from every dataset in the file that uses it. */
static void detach_everywhere(hid_t file_id, hid_t scale_id) {
  path_list_t all = list_datasets(file_id, "/");
  for (size_t i = 0; i < all.n && scale_ref_count(scale_id) > 0; i++) {
    hid_t dset_id = H5Dopen2(file_id, all.paths[i], H5P_DEFAULT);
    if (dset_id < 0) continue;
    hid_t space_id = H5Dget_space(dset_id);
    int   rank     = H5Sget_simple_extent_ndims(space_id);
    H5Sclose(space_id);
    for (int d = 0; d < rank; d++)
      if (H5DSis_attached(dset_id, scale_id, (unsigned)d) > 0)
        H5DSdetach_scale(dset_id, scale_id, (unsigned)d);
    H5Dclose(dset_id);
  }
  free_path_list(&all);
}

/*
 * Prepares the dataset at `path` for deletion: detaches its dimension scales,
 * deleting any that no other dataset uses and that are named after it, as
 * h5lite names them ("<path>_names", etc.). Other scales, such as a netCDF
 * coordinate variable, are kept. If the dataset is itself a scale (and
 * `detach_if_scale`), it is detached from the datasets it labels.
 */
static void release_scales(hid_t file_id, const char *path, int detach_if_scale) {
  hid_t dset_id = H5Dopen2(file_id, path, H5P_DEFAULT);
  if (dset_id < 0) return; /* Already deleted along with another dataset */

  if (detach_if_scale && H5DSis_scale(dset_id) > 0 && scale_ref_count(dset_id) > 0)
    detach_everywhere(file_id, dset_id);

  char  *own   = object_path(dset_id);
  size_t n_own = own ? strlen(own) : 0;

  hid_t space_id = H5Dget_space(dset_id);
  int   rank     = H5Sget_simple_extent_ndims(space_id);
  H5Sclose(space_id);

  for (int d = 0; d < rank; d++) {
    scale_list_t list = { {0}, 0 };
    if (H5DSget_num_scales(dset_id, (unsigned)d) > 0)
      H5DSiterate_scales(dset_id, (unsigned)d, NULL, collect_scales, &list);

    for (int k = 0; k < list.n; k++) {
      hid_t scale_id = list.ids[k];
      H5DSdetach_scale(dset_id, scale_id, (unsigned)d);
      char *scale_path = (own && scale_ref_count(scale_id) == 0) ? object_path(scale_id) : NULL;
      if (scale_path && !(strncmp(scale_path, own, n_own) == 0 && scale_path[n_own] == '_')) {
        free(scale_path);
        scale_path = NULL;
      }
      H5Dclose(scale_id);
      if (scale_path) { H5Ldelete(file_id, scale_path, H5P_DEFAULT); free(scale_path); }
    }
  }
  free(own);
  H5Dclose(dset_id);
}

/*
 * Deletes the object at `name`, keeping dimension scales consistent: the
 * object's own scales are removed with it, and a deleted scale is first
 * detached from the datasets it labels.
 */
herr_t delete_object(hid_t file_id, const char *name) {

  H5E_BEGIN_TRY {
    H5O_info_t info;
    if (H5Oget_info_by_name(file_id, name, &info, H5O_INFO_BASIC, H5P_DEFAULT) >= 0) {
      if (info.type == H5O_TYPE_DATASET) {
        release_scales(file_id, name, 1);
      }
      else if (info.type == H5O_TYPE_GROUP) {
        /* Ordinary datasets first, which removes most scales without scanning
         * the file; then any scale here that still labels a dataset elsewhere. */
        hid_t   group_id = H5Gopen2(file_id, name, H5P_DEFAULT);
        char   *gpath    = (group_id >= 0) ? object_path(group_id) : NULL;
        if (group_id >= 0) H5Gclose(group_id);
        if (gpath) {
          path_list_t list = list_datasets(file_id, gpath);
          for (size_t i = 0; i < list.n; i++) release_scales(file_id, list.paths[i], 0);
          for (size_t i = 0; i < list.n; i++) release_scales(file_id, list.paths[i], 1);
          free_path_list(&list);
          free(gpath);
        }
      }
    }
  } H5E_END_TRY;

  return H5Ldelete(file_id, name, H5P_DEFAULT);
}

/* Writes into `out` the first of `base`, `base_2`, `base_3`, ... that is not yet a link. */
void free_link_name(hid_t loc_id, const char *base, char *out, size_t size) {
  snprintf(out, size, "%s", base);
  H5E_BEGIN_TRY {
    for (int k = 2; H5Lexists(loc_id, out, H5P_DEFAULT) > 0; k++)
      snprintf(out, size, "%s_%d", base, k);
  } H5E_END_TRY;
}


/*
 * C implementation of h5_move().
 * Wraps H5Lmove to rename or move objects within the file. A dataset's own
 * dimension scales (named "<from>_...") are moved along with it.
 * `from_name` and `to_name` must be absolute paths.
 */
SEXP C_h5_move(SEXP filename, SEXP from_name, SEXP to_name) {
  const char *fname = Rf_translateCharUTF8(STRING_ELT(filename, 0));
  const char *src   = Rf_translateCharUTF8(STRING_ELT(from_name, 0));
  const char *dest  = Rf_translateCharUTF8(STRING_ELT(to_name, 0));
  size_t      n_src = strlen(src);

  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);

  /* Find the scales that label only this dataset and are named after it */
  char *scales[H5S_MAX_RANK * MAX_SCALES_PER_DIM];
  int   n_scales = 0;

  H5E_BEGIN_TRY {
    hid_t dset_id = H5Dopen2(file_id, src, H5P_DEFAULT);
    if (dset_id >= 0) {
      hid_t space_id = H5Dget_space(dset_id);
      int   rank     = H5Sget_simple_extent_ndims(space_id);
      H5Sclose(space_id);
      for (int d = 0; d < rank; d++) {
        scale_list_t list = { {0}, 0 };
        if (H5DSget_num_scales(dset_id, (unsigned)d) > 0)
          H5DSiterate_scales(dset_id, (unsigned)d, NULL, collect_scales, &list);
        for (int k = 0; k < list.n; k++) {
          char *path = (scale_ref_count(list.ids[k]) == 1) ? object_path(list.ids[k]) : NULL;
          if (path && strncmp(path, src, n_src) == 0 && path[n_src] == '_') { scales[n_scales++] = path; }
          else                                                               { free(path); }
          H5Dclose(list.ids[k]);
        }
      }
      H5Dclose(dset_id);
    }
  } H5E_END_TRY;

  /* Create Link Creation Property List to auto-create parent groups for destination */
  hid_t lcpl_id = H5Pcreate(H5P_LINK_CREATE);
  H5Pset_create_intermediate_group(lcpl_id, 1);
  H5Pset_char_encoding(lcpl_id, H5T_CSET_UTF8);

  create_parent_groups(file_id, dest);
  herr_t status = H5Lmove(file_id, src, file_id, dest, lcpl_id, H5P_DEFAULT);

  /* Rename "<from>_names" to "<to>_names", etc., unless that name is taken */
  for (int i = 0; i < n_scales; i++) {
    if (status >= 0) {
      size_t len      = strlen(dest) + strlen(scales[i] + n_src) + 1;
      char  *new_path = (char *)malloc(len);
      if (new_path) {
        snprintf(new_path, len, "%s%s", dest, scales[i] + n_src);
        H5E_BEGIN_TRY {
          if (H5Lexists(file_id, new_path, H5P_DEFAULT) <= 0)
            H5Lmove(file_id, scales[i], file_id, new_path, lcpl_id, H5P_DEFAULT);
        } H5E_END_TRY;
        free(new_path);
      }
    }
    free(scales[i]);
  }

  H5Pclose(lcpl_id);
  H5Fclose(file_id);

  if (status < 0) error("Failed to move/rename object from '%s' to '%s'", src, dest);

  return R_NilValue;
}

/*
 * C implementation of h5_delete().
 * Deletes a link (Group or Dataset), keeping dimension scales consistent.
 */
SEXP C_h5_delete(SEXP filename, SEXP name) {
  const char *fname = Rf_translateCharUTF8(STRING_ELT(filename, 0));
  const char *obj   = Rf_translateCharUTF8(STRING_ELT(name, 0));

  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);

  herr_t status = delete_object(file_id, obj);

  H5Fclose(file_id);

  if (status < 0) error("Failed to delete object: %s", obj);

  return R_NilValue;
}

/*
 * C implementation of h5_delete_attr().
 * Deletes an attribute using H5Adelete.
 */
SEXP C_h5_delete_attr(SEXP filename, SEXP obj_name, SEXP attr_name) {
  const char *fname = Rf_translateCharUTF8(STRING_ELT(filename, 0));
  const char *oname = Rf_translateCharUTF8(STRING_ELT(obj_name, 0));
  const char *aname = Rf_translateCharUTF8(STRING_ELT(attr_name, 0));
  
  hid_t file_id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  if (file_id < 0) error("Failed to open file: %s", fname);
  
  hid_t obj_id = H5Oopen(file_id, oname, H5P_DEFAULT);
  if (obj_id < 0) { H5Fclose(file_id); error("Failed to open object: %s", oname); }
  
  herr_t status = H5Adelete(obj_id, aname);
  
  H5Oclose(obj_id);
  H5Fclose(file_id);
  
  if (status < 0) error("Failed to delete attribute '%s' from '%s'", aname, oname);
  
  return R_NilValue;
}
