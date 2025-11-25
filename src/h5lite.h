#ifndef H5LITE_H
#define H5LITE_H

#include <R.h>
#include <Rinternals.h>
#include <hdf5.h>
#include <stdlib.h>
#include <string.h>

/* --- read.c --- */
SEXP C_h5_read_dataset(SEXP filename, SEXP dataset_name);
SEXP C_h5_read_attribute(SEXP filename, SEXP obj_name, SEXP attr_name);

/* --- read_dataframe.c --- */
SEXP read_dataframe(hid_t dset_id, hid_t file_type_id, hid_t space_id);
SEXP read_compound_attribute(hid_t attr_id, hid_t file_type_id, hid_t space_id);

/* --- write.c --- */
hid_t open_or_create_file(const char *fname);
SEXP C_h5_write_dataset(SEXP filename, SEXP dset_name, SEXP data, SEXP dtype, SEXP dims, SEXP compress_level);
SEXP C_h5_write_dataframe(SEXP filename, SEXP dset_name, SEXP data, SEXP dtypes, SEXP compress_level);
SEXP C_h5_write_attribute(SEXP filename, SEXP obj_name, SEXP attr_name, SEXP data, SEXP dtype, SEXP dims);
SEXP C_h5_create_group(SEXP filename, SEXP group_name);
SEXP C_h5_move(SEXP filename, SEXP from_name, SEXP to_name);

/* --- write_helpers.c --- */
hid_t open_or_create_file(const char *fname);
hid_t create_dataspace(SEXP dims, SEXP data, int *out_rank, hsize_t **out_h5_dims);
void  handle_overwrite(hid_t file_id, const char *name);
void  handle_attribute_overwrite(hid_t file_id, hid_t obj_id, const char *attr_name);
void  write_null_dataset(hid_t file_id, const char *dname);
void  write_null_attribute(hid_t file_id, hid_t obj_id, const char *attr_name);
herr_t write_buffer_to_object(hid_t obj_id, hid_t mem_type_id, void *buffer);
herr_t write_atomic_dataset(hid_t obj_id, SEXP data, const char *dtype_str, int rank, hsize_t *h5_dims);
void  write_atomic_attribute(hid_t file_id, hid_t obj_id, const char *attr_name, SEXP data, SEXP dtype, SEXP dims);
void  write_dataframe_as_compound(hid_t file_id, hid_t loc_id, const char *obj_name, SEXP data, SEXP dtypes, int compress_level, int is_attribute);
void  calculate_chunk_dims(int rank, const hsize_t *dims, size_t type_size, hsize_t *out_chunk_dims);
hid_t get_mem_type(SEXP data);
hid_t get_file_type(const char *dtype, SEXP data);
void* get_R_data_ptr(SEXP data);

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

/* --- delete.c --- */
SEXP C_h5_delete(SEXP filename, SEXP name);
SEXP C_h5_delete_attr(SEXP filename, SEXP obj_name, SEXP attr_name);

#endif
