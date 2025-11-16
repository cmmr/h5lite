#ifndef H5LITE_H
#define H5LITE_H

#include <R.h>
#include <Rinternals.h>
#include <hdf5.h>

/* --- read.c --- */
SEXP C_h5_read_dataset(SEXP filename, SEXP dataset_name);
SEXP C_h5_read_attribute(SEXP filename, SEXP obj_name, SEXP attr_name);

/* --- write.c --- */
SEXP C_h5_write_dataset(SEXP filename, SEXP dset_name, SEXP data, SEXP dtype, SEXP dims, SEXP compress_level);
SEXP C_h5_write_attribute(SEXP filename, SEXP obj_name, SEXP attr_name, SEXP data, SEXP dtype, SEXP dims);
SEXP C_h5_create_group(SEXP filename, SEXP group_name);
SEXP C_h5_move(SEXP filename, SEXP from_name, SEXP to_name);

/* --- ls.c --- */
SEXP C_h5_str(SEXP filename, SEXP obj_name);
SEXP C_h5_ls(SEXP filename, SEXP group_name, SEXP recursive, SEXP full_names);
SEXP C_h5_ls_attr(SEXP filename, SEXP obj_name);

/* --- info.c --- */
SEXP h5_type_to_rstr(hid_t type_id);
SEXP C_h5_typeof(SEXP filename, SEXP dset_name);
SEXP C_h5_typeof_attr(SEXP filename, SEXP obj_name, SEXP attr_name);
SEXP C_h5_dim(SEXP filename, SEXP dset_name);
SEXP C_h5_dim_attr(SEXP filename, SEXP obj_name, SEXP attr_name);
SEXP C_h5_exists(SEXP filename, SEXP name);
SEXP C_h5_exists_attr(SEXP filename, SEXP obj_name, SEXP attr_name);
SEXP C_h5_is_group(SEXP filename, SEXP name);
SEXP C_h5_is_dataset(SEXP filename, SEXP name);

/* --- util.c --- */
void h5_transpose(void *src, void *dest, int rank, hsize_t *dims, size_t el_size, int direction_to_r);

/* --- delete.c (NEW) --- */
SEXP C_h5_delete_link(SEXP filename, SEXP name);
SEXP C_h5_delete_attr(SEXP filename, SEXP obj_name, SEXP attr_name);

#endif
