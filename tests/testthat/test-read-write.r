library(testthat)
library(h5lite)

test_that("Read/write cycle works for various data types", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_vec_double <- c(1.5, 2.2, 3.3)
  d_vec_int <- 1L:10L
  d_vec_logical <- c(TRUE, FALSE, TRUE)
  d_vec_char <- c("hello", "world", "h5lite")
  d_factor <- factor(c("a", "b", "a"))

  d_mat_double <- matrix(1:12, nrow = 3, ncol = 4)
  d_arr_int <- array(1L:24L, dim = c(2, 3, 4))

  d_scalar_char <- "I am a scalar"
  d_scalar_int <- 42L

  # --- 2. WRITE DATA ---
  h5_write(file_path, "d_vec_double", d_vec_double)
  h5_write(file_path, "d_vec_int", d_vec_int)
  h5_write(file_path, "d_vec_logical", d_vec_logical)
  h5_write(file_path, "d_vec_char", d_vec_char)
  h5_write(file_path, "d_factor", d_factor)
  h5_write(file_path, "d_mat_double", d_mat_double)
  h5_write(file_path, "d_arr_int", d_arr_int)
  h5_write(file_path, "d_scalar_char", I(d_scalar_char))
  h5_write(file_path, "d_scalar_int", I(d_scalar_int))

  # --- 3. READ AND VERIFY DATA ---
  expect_equal(h5_read(file_path, "d_vec_double"), d_vec_double)
  expect_equal(h5_read(file_path, "d_mat_double"), d_mat_double)
  expect_equal(h5_read(file_path, "d_arr_int"), d_arr_int)
  expect_equal(h5_read(file_path, "d_vec_char"), d_vec_char)
  expect_equal(h5_read(file_path, "d_scalar_char"), d_scalar_char)
  expect_equal(h5_read(file_path, "d_scalar_int"), d_scalar_int)
  expect_equal(h5_read(file_path, "d_factor"), d_factor)

  # Test that integer/logical data is read back as R's "numeric" (double) for safety
  expect_type(h5_read(file_path, "d_vec_int"), "double")
  expect_type(h5_read(file_path, "d_vec_logical"), "double")
  expect_equal(h5_read(file_path, "d_vec_int"), as.numeric(d_vec_int))
  expect_equal(h5_read(file_path, "d_vec_logical"), as.numeric(d_vec_logical))
})

test_that("Specific dtype writing and reading works", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_vec_float <- c(1.123456789, 2.222222222, 3.333333333)
  d_vec_schar <- c(-10L, 20L, 30L)
  d_vec_short <- c(500L, -1000L, 30000L)
  d_vec_uint64 <- c(2^50, 2^60) # R 'numeric' (double)

  h5_write(file_path, "d_vec_float", d_vec_float, dtype = "float32")
  h5_write(file_path, "d_vec_schar", d_vec_schar, dtype = "int8")
  h5_write(file_path, "d_vec_short", d_vec_short, dtype = "int16")
  h5_write(file_path, "d_vec_uint64", d_vec_uint64, dtype = "uint64")

  # Read back and check type and value
  r_vec_float <- h5_read(file_path, "d_vec_float")
  expect_type(r_vec_float, "double")
  expect_equal(r_vec_float, d_vec_float, tolerance = 1e-7)

  r_vec_schar <- h5_read(file_path, "d_vec_schar")
  expect_type(r_vec_schar, "double")
  expect_equal(r_vec_schar, as.numeric(d_vec_schar))

  r_vec_short <- h5_read(file_path, "d_vec_short")
  expect_type(r_vec_short, "double")
  expect_equal(r_vec_short, as.numeric(d_vec_short))

  r_vec_uint64 <- h5_read(file_path, "d_vec_uint64")
  expect_type(r_vec_uint64, "double")
  expect_equal(r_vec_uint64, d_vec_uint64) # R doubles can hold these values
})

test_that("Compression works correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_compressible <- rep(1:10, 1000)

  # Write once without compression, once with
  h5_write(file_path, "uncompressed", d_compressible, compress = FALSE)
  h5_write(file_path, "compressed", d_compressible, compress = TRUE)

  # Check that data is readable and correct
  expect_equal(h5_read(file_path, "uncompressed"), as.numeric(d_compressible))
  expect_equal(h5_read(file_path, "compressed"), as.numeric(d_compressible))

  # Check that compressed file is smaller
  file_uncompressed <- tempfile(fileext = ".h5"); on.exit(unlink(file_uncompressed), add = TRUE)
  h5_write(file_uncompressed, "data", d_compressible, compress = FALSE)

  file_compressed <- tempfile(fileext = ".h5"); on.exit(unlink(file_compressed), add = TRUE)
  h5_write(file_compressed, "data", d_compressible, compress = TRUE)

  expect_lt(file.size(file_compressed), file.size(file_uncompressed))
})

test_that("validate_dtype auto-selects correct integer types", {

  # Unsigned integers
  expect_equal(validate_dtype(c(0, 255)),        "uint8")
  expect_equal(validate_dtype(c(0, 65535)),      "uint16")
  expect_equal(validate_dtype(c(0, 4294967295)), "uint32")
  expect_equal(validate_dtype(c(0, 2^53 - 1)),   "uint64")
  expect_equal(validate_dtype(c(0, 2^53)),       "float64") # Exceeds safe integer

  # Signed integers
  expect_equal(validate_dtype(c(-128,        127)),        "int8")
  expect_equal(validate_dtype(c(-32768,      32767)),      "int16")
  expect_equal(validate_dtype(c(-2147483648, 2147483647)), "int32")
  expect_equal(validate_dtype(c(-(2^53 - 1), 2^53 - 1)),   "int64")
  expect_equal(validate_dtype(c(-(2^53),     0)),          "float64") # Exceeds safe integer

  # Test data.frame type check
  expect_equal(validate_dtype(data.frame(a = 1)), "data.frame")
})

test_that("I() wrapper behavior is correct", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # 1. Test warning for I() on vector with length > 1
  expect_warning(h5_write(file_path, "warn_on_I", I(1:5)))
  # Verify it was written as a 1D array, not a scalar
  expect_equal(h5_dim(file_path, "warn_on_I"), 5)

  # 2. Test that 'AsIs' class is not written as an attribute for scalars
  scalar_with_attr <- I(42)
  attr(scalar_with_attr, "units") <- "degC"

  h5_write(file_path, "scalar_attrs", scalar_with_attr, attrs = TRUE)

  # Verify the 'units' attribute was written
  expect_equal(h5_read_attr(file_path, "scalar_attrs", "units"), "degC")

  # Verify the 'class' attribute was NOT written
  expect_false("class" %in% h5_ls_attr(file_path, "scalar_attrs"))
})

test_that("assert_valid_object errors on unsupported types", {
  # Test that the internal helper function correctly errors on an unsupported type
  # like an environment.
  expect_error(
    h5lite:::assert_valid_object(new.env()),
    "Cannot map R type to HDF5 object: 'environment'",
    fixed = TRUE
  )
})

test_that("NULL values are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. Test NULL Dataset ---
  h5_write(file_path, "null_dset", NULL)

  # Verify existence and type
  expect_true(h5_exists(file_path, "null_dset"))
  expect_equal(h5_typeof(file_path, "null_dset"), "null")
  expect_equal(h5_class(file_path, "null_dset"), "NULL")

  # Verify reading back gives NULL
  expect_null(h5_read(file_path, "null_dset"))

  # --- 2. Test NULL Attribute ---
  # First, create an object to attach the attribute to
  h5_write(file_path, "dset_for_attr", 1)
  h5_write_attr(file_path, "dset_for_attr", "null_attr", NULL)

  # Verify existence and type
  expect_true(h5_exists_attr(file_path, "dset_for_attr", "null_attr"))
  expect_equal(h5_typeof_attr(file_path, "dset_for_attr", "null_attr"), "null")
  expect_equal(h5_class_attr(file_path, "dset_for_attr", "null_attr"), "NULL")

  # Verify reading back gives NULL
  expect_null(h5_read_attr(file_path, "dset_for_attr", "null_attr"))

  # --- 3. Test Overwriting with NULL ---
  h5_write(file_path, "overwrite_me", 1:10)
  h5_write(file_path, "overwrite_me", NULL) # Overwrite with NULL
  expect_null(h5_read(file_path, "overwrite_me"))

  # --- 4. Test List with NULL element ---
  my_list <- list(a = 1, b = NULL, c = "hello")
  h5_write(file_path, "list_with_null", my_list)
  read_list <- h5_read(file_path, "list_with_null")
  expect_equal(read_list, my_list)
  expect_null(read_list$b)
})

test_that("Chunking heuristic for large datasets works correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Create a large matrix of doubles.
  # A 512x512 matrix of doubles is 512 * 512 * 8 = 2,097,152 bytes (2 MiB).
  # This is larger than the 1 MiB TARGET_SIZE in the C code, which will
  # trigger the chunk dimension calculation loop that needs to be tested.
  large_matrix <- matrix(rnorm(512 * 512), nrow = 512)

  # Write the large matrix with compression enabled.
  # This will execute the calculate_chunk_dims() C function.
  h5_write(file_path, "large_matrix", large_matrix, compress = TRUE)

  # Read the data back and verify it is identical to the original.
  read_matrix <- h5_read(file_path, "large_matrix")
  expect_equal(read_matrix, large_matrix)
})
