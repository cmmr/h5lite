library(testthat)
library(h5lite)

test_that("Integer datasets are written with correct types and round-trip", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_int_no_na <- 1L:100L
  d_int_with_na <- c(1L, 2L, NA_integer_, 4L)
  d_mat_int <- matrix(1L:12L, nrow = 4)
  d_scalar_int <- I(42L)

  # --- 2. WRITE DATA ---
  h5_write(file_path, "int_no_na", d_int_no_na)
  h5_write(file_path, "int_with_na", d_int_with_na)
  h5_write(file_path, "mat_int", d_mat_int)
  h5_write(file_path, "scalar_int", d_scalar_int)

  # --- 3. VERIFY TYPES ---
  # Without NA, should be an efficient integer type (uint8)
  expect_equal(h5_typeof(file_path, "int_no_na"), "uint8")
  expect_equal(h5_typeof(file_path, "scalar_int"), "uint8")
  expect_equal(h5_dim(file_path, "scalar_int"), integer(0))
  # With NA, should be promoted to float16
  expect_equal(h5_typeof(file_path, "int_with_na"), "float16")

  # --- 4. READ AND VERIFY DATA ---
  # Reading converts to numeric (double) for safety, which is expected.
  expect_equal(h5_read(file_path, "int_no_na"), as.numeric(d_int_no_na))
  expect_equal(h5_read(file_path, "int_with_na"), as.numeric(d_int_with_na))
  expect_equal(h5_read(file_path, "mat_int"), d_mat_int)
  expect_equal(h5_read(file_path, "scalar_int"), as.integer(d_scalar_int))
})

test_that("Integer attributes are written with correct types and round-trip", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_attr_no_na <- c(1L, 2L, 3L)
  d_attr_with_na <- c(10L, NA_integer_, 20L)

  # --- 2. WRITE DATA ---
  h5_write(file_path, "dset", 1) # Dummy dataset
  h5_write_attr(file_path, "dset", "attr_no_na", d_attr_no_na)
  h5_write_attr(file_path, "dset", "attr_with_na", d_attr_with_na)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof_attr(file_path, "dset", "attr_no_na"), "uint8")
  expect_equal(h5_typeof_attr(file_path, "dset", "attr_with_na"), "float16")

  # --- 4. READ AND VERIFY DATA ---
  expect_equal(h5_read_attr(file_path, "dset", "attr_no_na"), as.numeric(d_attr_no_na))
  expect_equal(h5_read_attr(file_path, "dset", "attr_with_na"), as.numeric(d_attr_with_na))
})

test_that("data.frame with integer column containing NA round-trips correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  df <- data.frame(id = 1:3, value = c(10L, NA_integer_, 30L))
  h5_write(file_path, "df_int_na", df)
  df_read <- h5_read(file_path, "df_int_na")

  # The read-back data.frame will have numeric columns for integer/logical
  df_expected <- df
  df_expected$id <- as.numeric(df_expected$id)
  df_expected$value <- as.numeric(df_expected$value)
  expect_equal(df_read, df_expected)
})

test_that("Writing integer data with NA to a non-float dtype throws an error", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_int_with_na <- c(1L, NA_integer_, 3L)

  # Attempting to write NA to an integer type should fail loudly
  expect_error(h5_write(file_path, "int_na_as_int", d_int_with_na, dtype = "int32"))

  # Also test for attributes
  h5_write(file_path, "dset", 1)
  expect_error(h5_write_attr(file_path, "dset", "int_attr_with_na", d_int_with_na, dtype = "int16"))
})

test_that("Writing integer data outside the dtype range throws an error", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Test 1: Value too large for the specified unsigned type
  d_too_large <- c(100L, 300L) # 300 is > 255 (max for uint8)
  expect_error(h5_write(file_path, "too_large", d_too_large, dtype = "uint8"))

  # Test 2: Negative value for an unsigned type
  d_negative <- c(-10L, 50L) # -10 is < 0 (min for uint8)
  expect_error(h5_write(file_path, "negative", d_negative, dtype = "uint8"))
})

test_that("Automatic integer type selection is correct", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- Unsigned Integer Types ---
  h5_write(file_path, "u8", c(0L, 255L))
  expect_equal(h5_typeof(file_path, "u8"), "uint8")

  h5_write(file_path, "u16", c(0L, 256L))
  expect_equal(h5_typeof(file_path, "u16"), "uint16")

  h5_write(file_path, "u32", c(0L, 65536L))
  expect_equal(h5_typeof(file_path, "u32"), "uint32")

  # For values > 2^31-1, R uses numeric (double)
  h5_write(file_path, "u64", c(0, 2^32))
  expect_equal(h5_typeof(file_path, "u64"), "uint64")

  # Value exceeds R's safe integer range, should become float64
  h5_write(file_path, "u_as_f64", c(0, 2^53))
  expect_equal(h5_typeof(file_path, "u_as_f64"), "float64")

  # --- Signed Integer Types ---
  h5_write(file_path, "s8", c(-128L, 127L))
  expect_equal(h5_typeof(file_path, "s8"), "int8")

  h5_write(file_path, "s16", c(-129L, 128L))
  expect_equal(h5_typeof(file_path, "s16"), "int16")

  h5_write(file_path, "s32", c(-32769L, 32768L))
  expect_equal(h5_typeof(file_path, "s32"), "int32")

  # For values outside R's 32-bit integer range, use numeric (double)
  h5_write(file_path, "s64", c(-2^32, 2^32))
  expect_equal(h5_typeof(file_path, "s64"), "int64")

  # Value exceeds R's safe integer range, should become float64
  h5_write(file_path, "s_as_f64", c(-2^54, 0))
  expect_equal(h5_typeof(file_path, "s_as_f64"), "float64")
})

test_that("Writing a zero-length integer vector works", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Test with auto dtype
  h5_write(file_path, "zero_len_int_auto", integer(0))
  expect_equal(h5_read(file_path, "zero_len_int_auto"), numeric(0))
  expect_equal(h5_typeof(file_path, "zero_len_int_auto"), "uint8") # Default for empty

  # Test with specified dtype
  h5_write(file_path, "zero_len_int_dtype", integer(0), dtype = "int32")
  expect_equal(h5_read(file_path, "zero_len_int_dtype"), numeric(0))
  expect_equal(h5_typeof(file_path, "zero_len_int_dtype"), "int32")
})
