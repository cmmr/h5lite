#ifndef H5LITE_H
#define H5LITE_H

#include <R.h>
#include <Rinternals.h>
#include <hdf5.h>
#include <H5DSpublic.h> /* Dimension Scales */
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* For mapping the user's `as` argument. */
typedef enum {
  R_TYPE_NOMATCH,
  R_TYPE_NULL,
  R_TYPE_AUTO,
  R_TYPE_LOGICAL,
  R_TYPE_INTEGER,
  R_TYPE_DOUBLE,
  R_TYPE_BIT64
} R_TYPE;

/* Callback struct for C_h5_ls and C_h5_attr_names. */
typedef struct {
  int count;
  int idx;
  SEXP names;
  const char *gname;
  int full_names;
  int show_scales;
} h5_op_data_t;

/* Callback data struct for finding the first attached scale */
typedef struct {
  hid_t scale_id;
  int found;
} scale_visitor_t;


/* --- data.frame.c --- */
SEXP read_data_frame(hid_t obj_id, int is_dataset, hid_t file_type_id, hid_t space_id, SEXP rmap);
SEXP write_dataframe(
hid_t file_id, hid_t loc_id, const char *obj_name, SEXP data, 
SEXP dtypes, int compress_level, int is_attribute);

/* --- dimscales.c --- */
herr_t visitor_find_scale(hid_t dset, unsigned dim, hid_t scale, void *visitor_data);
void set_r_dimensions(SEXP result, int ndims, hsize_t *dims);
void read_r_dimscales(hid_t dset_id, int rank, SEXP result);
void write_r_dimscales(hid_t loc_id, hid_t dset_id, const char *dname, SEXP data);
void write_single_scale(hid_t loc_id, hid_t dset_id, const char *scale_name, SEXP labels, unsigned int dim_idx);

/* --- info.c --- */
SEXP h5_type_to_rstr(hid_t type_id);
SEXP C_h5_typeof(SEXP filename, SEXP dset_name);
SEXP C_h5_typeof_attr(SEXP filename, SEXP obj_name, SEXP attr_name);
SEXP C_h5_dim(SEXP filename, SEXP dset_name);
SEXP C_h5_dim_attr(SEXP filename, SEXP obj_name, SEXP attr_name);
SEXP C_h5_exists(SEXP filename, SEXP obj_name, SEXP attr_name);
SEXP C_h5_is_group(SEXP filename, SEXP name);
SEXP C_h5_is_dataset(SEXP filename, SEXP name);
SEXP C_h5_names(SEXP filename, SEXP dset_name, SEXP attr_name);
SEXP C_h5_attr_names(SEXP filename, SEXP obj_name);

/* --- ls.c --- */
SEXP C_h5_str(SEXP filename, SEXP obj_name, SEXP attrs, SEXP members, SEXP markup);
SEXP C_h5_ls(SEXP filename, SEXP group_name, SEXP recursive, SEXP full_names, SEXP scales);

/* --- organize.c --- */
SEXP C_h5_create_group(SEXP filename, SEXP group_name);
SEXP C_h5_move(SEXP filename, SEXP from_name, SEXP to_name);
SEXP C_h5_delete(SEXP filename, SEXP name);
SEXP C_h5_delete_attr(SEXP filename, SEXP obj_name, SEXP attr_name);

/* --- read.c --- */
SEXP C_h5_read_dataset(SEXP filename, SEXP dataset_name, SEXP rmap, SEXP element_name);
SEXP C_h5_read_attribute(SEXP filename, SEXP obj_name, SEXP attr_name, SEXP rmap);
SEXP read_character(hid_t loc_id, int is_dataset, hid_t file_type_id, hid_t space_id, 
                    int ndims, hsize_t *dims, hsize_t total_elements);

/* --- util.c --- */
SEXP errmsg_1(const char *fmt, const char *str1);
SEXP errmsg_2(const char *fmt, const char *str1, const char *str2);
SEXP errmsg_3(const char *fmt, const char *str1, const char *str2, const char *str3);
void *get_R_data_ptr(SEXP data);
size_t get_R_el_size(SEXP data);
void h5_transpose(void *src, void *dest, int rank, hsize_t *dims, size_t el_size, int direction_to_r);
R_TYPE rtype_from_map(hid_t file_type_id, SEXP rmap, const char *el_name);
SEXP coerce_to_rtype(SEXP data, R_TYPE rtype, hid_t file_type_id);

/* --- write.c --- */
SEXP C_h5_write_dataset(SEXP filename, SEXP dset_name, SEXP data, SEXP dtype, SEXP dims, SEXP compress_level);
SEXP C_h5_write_attribute(SEXP filename, SEXP obj_name, SEXP attr_name, SEXP data, SEXP dtype, SEXP dims);
SEXP write_atomic_dataset(hid_t obj_id, SEXP data, const char *dtype_str, int rank, hsize_t *h5_dims);

/* --- write_utils.c --- */
hid_t open_or_create_file(const char *fname);
hid_t create_dataspace(SEXP dims, SEXP data, int *out_rank, hsize_t **out_h5_dims);
herr_t handle_overwrite(hid_t file_id, const char *name);
herr_t handle_attribute_overwrite(hid_t file_id, hid_t obj_id, const char *attr_name);
herr_t write_buffer_to_object(hid_t obj_id, hid_t mem_type_id, void *buffer);
void calculate_chunk_dims(int rank, const hsize_t *dims, size_t type_size, hsize_t *out_chunk_dims);
hid_t create_r_memory_type(SEXP data, const char *dtype);
hid_t create_h5_file_type(SEXP data, const char *dtype);
hid_t create_string_type(const char *dtype);
size_t get_fixed_byte_width(const char *dtype);

#endif
