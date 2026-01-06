test_that("h5_typeof and h5_class", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_create_file(file)
  
  h5_write(1, file, 'ds_uint8',   as = "uint8")
  h5_write(1, file, 'ds_uint16',  as = "uint16")
  h5_write(1, file, 'ds_uint32',  as = "uint32")
  h5_write(1, file, 'ds_uint64',  as = "uint64")
  h5_write(1, file, 'ds_int8',    as = "int8")
  h5_write(1, file, 'ds_int16',   as = "int16")
  h5_write(1, file, 'ds_int32',   as = "int32")
  h5_write(1, file, 'ds_int64',   as = "int64")
  h5_write(1, file, 'ds_float16', as = "float16")
  h5_write(1, file, 'ds_float32', as = "float32")
  h5_write(1, file, 'ds_float64', as = "float64")

  h5_write(NULL,      file, 'ds_null')
  h5_write('a',       file, 'ds_utf8',  as = 'utf8')
  h5_write('a',       file, 'ds_ascii', as = 'ascii')
  h5_write(1+1i,      file, 'ds_complex')
  h5_write(mtcars,    file, 'ds_compound')
  h5_write(as.raw(1), file, 'ds_opaque')
  h5_write(as.factor(letters), file, 'ds_enum')
  
  expect_equal(h5_typeof(file, 'ds_uint8'),    'uint8')
  expect_equal(h5_typeof(file, 'ds_uint16'),   'uint16')
  expect_equal(h5_typeof(file, 'ds_uint32'),   'uint32')
  expect_equal(h5_typeof(file, 'ds_uint64'),   'uint64')
  expect_equal(h5_typeof(file, 'ds_int8'),     'int8')
  expect_equal(h5_typeof(file, 'ds_int16'),    'int16')
  expect_equal(h5_typeof(file, 'ds_int32'),    'int32')
  expect_equal(h5_typeof(file, 'ds_int64'),    'int64')
  expect_equal(h5_typeof(file, 'ds_float16'),  'float16')
  expect_equal(h5_typeof(file, 'ds_float32'),  'float32')
  expect_equal(h5_typeof(file, 'ds_float64'),  'float64')
  expect_equal(h5_typeof(file, 'ds_null'),     'null')
  expect_equal(h5_typeof(file, 'ds_utf8'),     'utf8')
  expect_equal(h5_typeof(file, 'ds_ascii'),    'ascii')
  expect_equal(h5_typeof(file, 'ds_complex'),  'complex')
  expect_equal(h5_typeof(file, 'ds_compound'), 'compound')
  expect_equal(h5_typeof(file, 'ds_opaque'),   'opaque')
  expect_equal(h5_typeof(file, 'ds_enum'),     'enum')

  expect_equal(h5_class(file, 'ds_uint8'),    'integer')
  expect_equal(h5_class(file, 'ds_int8'),     'integer')
  expect_equal(h5_class(file, 'ds_float16'),  'numeric')
  expect_equal(h5_class(file, 'ds_null'),     'NULL')
  expect_equal(h5_class(file, 'ds_utf8'),     'character')
  expect_equal(h5_class(file, 'ds_ascii'),    'character')
  expect_equal(h5_class(file, 'ds_complex'),  'complex')
  expect_equal(h5_class(file, 'ds_compound'), 'data.frame')
  expect_equal(h5_class(file, 'ds_opaque'),   'raw')
  expect_equal(h5_class(file, 'ds_enum'),     'factor')


  h5_write(1,    file, '/', 'attr_uint8', as = "uint8")
  h5_write(NULL, file, '/', 'attr_null')

  expect_equal(h5_typeof(file, '/', 'attr_uint8'), 'uint8')
  expect_equal(h5_typeof(file, '/', 'attr_null'),  'null')

  expect_equal(h5_class(file, '/', 'attr_uint8'), 'integer')
  expect_equal(h5_class(file, '/', 'attr_null'),  'NULL')


  expect_output(h5_str(file))
})


test_that("h5_dim / h5_length", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  mtx_2d <- as.matrix(mtcars)
  mtx_3d <- array(1:24, dim = c(2, 3, 4))

  # Datasets of different dimensions
  h5_write(numeric(0), file, 'vec_n0')
  h5_write(numeric(1), file, 'vec_n1')
  h5_write(numeric(2), file, 'vec_n2')
  h5_write(I(1),       file, 'scalar')
  h5_write(mtcars,     file, 'mtcars')
  h5_write(mtx_2d,     file, 'mtx_2d')
  h5_write(mtx_3d,     file, 'mtx_3d')
  
  expect_equal(h5_dim(file, 'vec_n0'), 0L)
  expect_equal(h5_dim(file, 'vec_n1'), 1L)
  expect_equal(h5_dim(file, 'vec_n2'), 2L)
  expect_equal(h5_dim(file, 'scalar'), integer(0))
  expect_equal(h5_dim(file, 'mtcars'), dim(mtcars))
  expect_equal(h5_dim(file, 'mtx_2d'), dim(mtx_2d))
  expect_equal(h5_dim(file, 'mtx_3d'), dim(mtx_3d))

  expect_equal(h5_length(file, 'vec_n0'), 0L)
  expect_equal(h5_length(file, 'vec_n1'), 1L)
  expect_equal(h5_length(file, 'vec_n2'), 2L)
  expect_equal(h5_length(file, 'scalar'), 1L)
  expect_equal(h5_length(file, 'mtcars'), length(mtcars))
  expect_equal(h5_length(file, 'mtx_2d'), length(mtx_2d))
  expect_equal(h5_length(file, 'mtx_3d'), length(mtx_3d))

  # Attributes of different dimensions
  h5_write(numeric(0), file, '/', 'vec_n0')
  h5_write(numeric(1), file, '/', 'vec_n1')
  h5_write(numeric(2), file, '/', 'vec_n2')
  h5_write(I(1),       file, '/', 'scalar')
  h5_write(mtcars,     file, '/', 'mtcars')
  h5_write(mtx_2d,     file, '/', 'mtx_2d')
  h5_write(mtx_3d,     file, '/', 'mtx_3d')
  
  expect_equal(h5_dim(file, '/', 'vec_n0'), 0L)
  expect_equal(h5_dim(file, '/', 'vec_n1'), 1L)
  expect_equal(h5_dim(file, '/', 'vec_n2'), 2L)
  expect_equal(h5_dim(file, '/', 'scalar'), integer(0))
  expect_equal(h5_dim(file, '/', 'mtcars'), dim(mtcars))
  expect_equal(h5_dim(file, '/', 'mtx_2d'), dim(mtx_2d))
  expect_equal(h5_dim(file, '/', 'mtx_3d'), dim(mtx_3d))

  expect_equal(h5_length(file, '/', 'vec_n0'), 0L)
  expect_equal(h5_length(file, '/', 'vec_n1'), 1L)
  expect_equal(h5_length(file, '/', 'vec_n2'), 2L)
  expect_equal(h5_length(file, '/', 'scalar'), 1L)
  expect_equal(h5_length(file, '/', 'mtcars'), length(mtcars))
  expect_equal(h5_length(file, '/', 'mtx_2d'), length(mtx_2d))
  expect_equal(h5_length(file, '/', 'mtx_3d'), length(mtx_3d))

  expect_equal(h5_length(file, "/"), 7L)
  expect_equal(h5_length(file, "/", "missing_attr"), NA_integer_)
  expect_equal(h5_length(file, "missing_object"), NA_integer_)
  expect_equal(h5_length(file, "missing_object", "missing_attr"), NA_integer_)

  expect_output(h5_str(file))
})


test_that("h5_exists", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))

  expect_false(h5_exists(file))
  expect_false(h5_exists(file, "/"))
  expect_false(h5_exists(file, "missing_object"))
  expect_false(h5_exists(file, "/", "missing_attr"))
  expect_false(h5_exists(file, "missing_object", "missing_attr"))

  h5_create_file(file)

  expect_true(h5_exists(file))
  expect_true(h5_exists(file, "/"))
  expect_false(h5_exists(file, "missing_object"))
  expect_false(h5_exists(file, "/", "missing_attr"))
  expect_false(h5_exists(file, "missing_object", "missing_attr"))

  h5_write(1, file, "object")
  expect_true(h5_exists(file, "object"))
  expect_false(h5_exists(file, "/", "missing_attr"))
  expect_false(h5_exists(file, "object", "missing_attr"))

  h5_write(1, file, "/", "attr")
  expect_true(h5_exists(file, "/", "attr"))
  expect_false(h5_exists(file, "object", "attr"))

  h5_write(1, file, "object", "attr")
  expect_true(h5_exists(file, "object", "attr"))

  expect_error(h5_exists(tempfile(fileext = ".h5"), assert = TRUE))
  expect_error(h5_exists(file, "missing_object",    assert = TRUE))
  expect_error(h5_exists(file, "/", "missing_attr", assert = TRUE))
})


test_that("h5_is_group / h5_is_dataset", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))

  expect_false(h5_is_group(file, "/"))
  expect_false(h5_is_group(file, "/", "missing_attr"))
  expect_false(h5_is_group(file, "missing_object"))
  expect_false(h5_is_group(file, "missing_object", "missing_attr"))
  expect_false(h5_is_dataset(file, "/"))
  expect_false(h5_is_dataset(file, "/", "missing_attr"))
  expect_false(h5_is_dataset(file, "missing_object"))
  expect_false(h5_is_dataset(file, "missing_object", "missing_attr"))

  h5_create_file(file)

  expect_true(h5_is_group(file, "/"))
  expect_false(h5_is_group(file, "/", "missing_attr"))
  expect_false(h5_is_group(file, "missing_object"))
  expect_false(h5_is_group(file, "missing_object", "missing_attr"))
  expect_false(h5_is_dataset(file, "/"))
  expect_false(h5_is_dataset(file, "/", "missing_attr"))
  expect_false(h5_is_dataset(file, "missing_object"))
  expect_false(h5_is_dataset(file, "missing_object", "missing_attr"))

  h5_create_group(file, "group")
  h5_write(1, file, "dataset")

  expect_true(h5_is_group(file, "group"))
  expect_true(h5_is_dataset(file, "dataset"))
  expect_false(h5_is_group(file, "dataset"))
  expect_false(h5_is_dataset(file, "group"))
  expect_false(h5_is_group(file, "group", "missing_attr"))
  expect_false(h5_is_dataset(file, "dataset", "missing_attr"))

  
  h5_write(1, file, "group", "group_attr")
  h5_write(1, file, "dataset", "dataset_attr")

  expect_true(h5_is_dataset(file, "group", "group_attr"))
  expect_true(h5_is_dataset(file, "dataset", "dataset_attr"))
  expect_false(h5_is_group(file, "group", "group_attr"))
  expect_false(h5_is_group(file, "dataset", "dataset_attr"))
})


test_that("h5_names / h5_attr_names", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))

  expect_error(h5_names(file))
  expect_error(h5_names(file, "missing_object"))
  expect_error(h5_names(file, "/", "missing_attr"))
  expect_error(h5_names(file, "missing_object", "missing_attr"))

  expect_error(h5_attr_names(file))
  expect_error(h5_attr_names(file, "missing_object"))
  expect_error(h5_attr_names(file, "/", "missing_attr"))
  expect_error(h5_attr_names(file, "missing_object", "missing_attr"))

  h5_create_file(file)

  expect_equal(h5_names(file), character(0))
  expect_equal(h5_names(file, "/"), character(0))

  expect_error(h5_names(file, "missing_object"))
  expect_error(h5_names(file, "/", "missing_attr"))
  expect_error(h5_names(file, "missing_object", "missing_attr"))

  expect_equal(h5_attr_names(file), character(0))
  expect_equal(h5_attr_names(file, "/"), character(0))

  expect_error(h5_attr_names(file, "missing_object"))

  vec <- setNames(1:3, c("a", "b", "c"))
  h5_write(mtcars, file, "ds_mtcars")
  h5_write(vec,    file, "ds_vec")
  h5_write(mtcars, file, "/", "attr_mtcars")
  h5_write(vec,    file, "/", "attr_vec")
  h5_write(1:10,   file, "group/unnamed")

  expect_equal(h5_names(file), c("ds_mtcars", "ds_vec", "group"))
  expect_equal(h5_names(file, "/"), c("ds_mtcars", "ds_vec", "group"))
  expect_equal(h5_names(file, "ds_mtcars"), names(mtcars))
  expect_equal(h5_names(file, "ds_vec"), names(vec))
  expect_equal(h5_names(file, "group"), c("unnamed"))
  expect_equal(h5_names(file, "group/unnamed"), character(0))
  expect_equal(h5_names(file, "/", "attr_mtcars"), names(mtcars))
  expect_equal(h5_names(file, "/", "attr_vec"), character(0))

  expect_equal(h5_attr_names(file), c("attr_mtcars", "attr_vec"))
  expect_equal(h5_attr_names(file, "/"), c("attr_mtcars", "attr_vec"))
  expect_equal(h5_attr_names(file, "group"), character(0))
  expect_equal(h5_attr_names(file, "group/unnamed"), character(0))
})
