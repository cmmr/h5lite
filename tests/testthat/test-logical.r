library(testthat)
library(h5lite)

test_that("Logical datasets are written with correct types and round-trip correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_logical_no_na <- c(TRUE, FALSE, TRUE, TRUE)
  d_logical_with_na <- c(TRUE, FALSE, NA, TRUE)
  d_scalar_logical <- I(TRUE)

  # --- 2. WRITE DATA ---
  h5_write(file_path, "logical_no_na", d_logical_no_na)
  h5_write(file_path, "logical_with_na", d_logical_with_na)
  h5_write(file_path, "scalar_logical", d_scalar_logical)

  # --- 3. VERIFY TYPES ---
  # Without NA, should be an efficient integer type (uint8)
  expect_equal(h5_typeof(file_path, "logical_no_na"), "uint8")
  # With NA, should be promoted to float64
  expect_equal(h5_typeof(file_path, "logical_with_na"), "float64")
  # Scalar
  expect_equal(h5_dim(file_path, "scalar_logical"), integer(0))

  # --- 4. READ AND VERIFY DATA ---
  # Reading converts to numeric (double) for safety, which is expected.
  expect_equal(h5_read(file_path, "logical_no_na"), as.numeric(d_logical_no_na))
  expect_equal(h5_read(file_path, "logical_with_na"), as.numeric(d_logical_with_na))
  expect_equal(h5_read(file_path, "scalar_logical"), as.numeric(as.logical(d_scalar_logical)))
})

test_that("Logical attributes are written with correct types and round-trip correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_attr_no_na <- c(TRUE, FALSE)
  d_attr_with_na <- c(TRUE, NA, FALSE)

  # --- 2. WRITE DATA ---
  h5_write(file_path, "dset", 1) # Dummy dataset
  h5_write_attr(file_path, "dset", "attr_no_na", d_attr_no_na)
  h5_write_attr(file_path, "dset", "attr_with_na", d_attr_with_na)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof_attr(file_path, "dset", "attr_no_na"), "uint8")
  expect_equal(h5_typeof_attr(file_path, "dset", "attr_with_na"), "float64")

  # --- 4. READ AND VERIFY DATA ---
  expect_equal(h5_read_attr(file_path, "dset", "attr_no_na"), as.numeric(d_attr_no_na))
  expect_equal(h5_read_attr(file_path, "dset", "attr_with_na"), as.numeric(d_attr_with_na))
})

test_that("data.frame with logical column containing NA round-trips correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  df_with_logical_na <- data.frame(
    id = 1:3,
    is_valid = c(TRUE, NA, FALSE)
  )

  # --- 2. WRITE AND READ ---
  h5_write(file_path, "df_logical_na", df_with_logical_na)
  df_read <- h5_read(file_path, "df_logical_na")

  # --- 3. VERIFY ---
  # The read-back data.frame will have numeric columns for integer/logical
  df_expected <- df_with_logical_na
  df_expected$id <- as.numeric(df_expected$id)
  df_expected$is_valid <- as.numeric(df_expected$is_valid)
  expect_equal(df_read, df_expected)
})

test_that("Writing logical data with NA to a non-float dtype throws an error", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_logical_with_na <- c(TRUE, NA, FALSE)

  # Test for datasets
  expect_error(h5_write(file_path, "logical_na_as_int", d_logical_with_na, dtype = "uint8"))

  # Test for attributes
  h5_write(file_path, "dset", 1)
  expect_error(h5_write_attr(file_path, "dset", "logical_attr_with_na", d_logical_with_na, dtype = "int32"))
})
