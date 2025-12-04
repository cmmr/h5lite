library(testthat)
library(h5lite)

test_that("Raw datasets are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_vec_raw <- as.raw(c(0x01, 0x10, 0xFF, 0x00))
  d_mat_raw <- matrix(as.raw(1:12), nrow = 3, ncol = 4)
  d_scalar_raw <- I(as.raw(0x42))

  # --- 2. WRITE DATA ---
  h5_write(file_path, "vec_raw", d_vec_raw)
  h5_write(file_path, "mat_raw", d_mat_raw)
  h5_write(file_path, "scalar_raw", d_scalar_raw)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof(file_path, "vec_raw"), "opaque")
  expect_equal(h5_class(file_path, "vec_raw"), "raw")
  expect_equal(h5_dim(file_path, "scalar_raw"), integer(0))

  # --- 4. READ AND VERIFY DATA ---
  expect_equal(h5_read(file_path, "vec_raw"), d_vec_raw)
  expect_equal(h5_read(file_path, "mat_raw"), d_mat_raw)
  expect_equal(h5_read(file_path, "scalar_raw"), as.raw(d_scalar_raw))
})

test_that("Raw attributes are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_attr_raw_vec <- as.raw(c(0xDE, 0xAD, 0xBE, 0xEF))
  d_attr_raw_scalar <- I(as.raw(0x99))

  # --- 2. WRITE DATA ---
  h5_write(file_path, "dset", 1) # Create a dataset to attach attributes to
  h5_write_attr(file_path, "dset", "raw_attr_vec", d_attr_raw_vec)
  h5_write_attr(file_path, "dset", "raw_attr_scalar", d_attr_raw_scalar)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof_attr(file_path, "dset", "raw_attr_vec"), "opaque")
  expect_equal(h5_class_attr(file_path, "dset", "raw_attr_vec"), "raw")

  # --- 4. READ AND VERIFY DATA ---
  expect_equal(h5_read_attr(file_path, "dset", "raw_attr_vec"), d_attr_raw_vec)
  expect_equal(h5_read_attr(file_path, "dset", "raw_attr_scalar"), as.raw(d_attr_raw_scalar))
})

test_that("data.frame with a raw column round-trips correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  df_with_raw <- data.frame(
    id = as.double(1:4),
    data = as.raw(c(0xDE, 0xAD, 0xBE, 0xEF)),
    label = c("a", "b", "c", "d")
  )

  # --- 2. WRITE AND READ (DATASET) ---
  h5_write(file_path, "df_raw_dset", df_with_raw)
  df_read_dset <- h5_read(file_path, "df_raw_dset")

  # --- 3. VERIFY (DATASET) ---
  expect_s3_class(df_read_dset, "data.frame")
  expect_equal(df_read_dset, df_with_raw)
  expect_type(df_read_dset$data, "raw")

  # --- 4. WRITE AND READ (ATTRIBUTE) ---
  h5_write(file_path, "dset_for_attr", 1) # Dummy object
  h5_write_attr(file_path, "dset_for_attr", "df_raw_attr", df_with_raw)
  df_read_attr <- h5_read_attr(file_path, "dset_for_attr", "df_raw_attr")

  # --- 5. VERIFY (ATTRIBUTE) ---
  expect_s3_class(df_read_attr, "data.frame")
  expect_equal(df_read_attr, df_with_raw)
  expect_type(df_read_attr$data, "raw")
})
