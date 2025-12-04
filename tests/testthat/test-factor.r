library(testthat)
library(h5lite)

test_that("Factor datasets are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_vec_factor <- factor(c("a", "b", "a", "c"), levels = c("a", "b", "c"))
  d_mat_factor <- factor(matrix(c("low", "high", "high", "low"), nrow = 2), levels = c("low", "medium", "high"))
  d_scalar_factor <- I(factor("medium", levels = c("low", "medium", "high")))

  # --- 2. WRITE DATA ---
  h5_write(file_path, "vec_factor", d_vec_factor)
  h5_write(file_path, "mat_factor", d_mat_factor)
  h5_write(file_path, "scalar_factor", d_scalar_factor)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof(file_path, "vec_factor"), "enum")
  expect_equal(h5_class(file_path, "vec_factor"), "factor")
  expect_equal(h5_dim(file_path, "scalar_factor"), integer(0))

  # --- 4. READ AND VERIFY DATA ---
  expect_equal(h5_read(file_path, "vec_factor"), d_vec_factor)
  expect_equal(h5_read(file_path, "mat_factor"), d_mat_factor)
  expect_equal(h5_read(file_path, "scalar_factor"), as.factor(d_scalar_factor))
})

test_that("Factor attributes are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_attr_factor_vec <- factor(c("red", "green", "blue", "red"))
  d_attr_factor_scalar <- I(factor("active"))

  # --- 2. WRITE DATA ---
  h5_write(file_path, "dset", 1) # Create a dataset to attach attributes to
  h5_write_attr(file_path, "dset", "factor_attr_vec", d_attr_factor_vec)
  h5_write_attr(file_path, "dset", "factor_attr_scalar", d_attr_factor_scalar)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof_attr(file_path, "dset", "factor_attr_vec"), "enum")
  expect_equal(h5_class_attr(file_path, "dset", "factor_attr_vec"), "factor")

  # --- 4. READ AND VERIFY DATA ---
  expect_equal(h5_read_attr(file_path, "dset", "factor_attr_vec"), d_attr_factor_vec)
  expect_equal(h5_read_attr(file_path, "dset", "factor_attr_scalar"), as.factor(d_attr_factor_scalar))
})

test_that("data.frame with a factor column round-trips correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  df_with_factor <- data.frame(
    id = as.double(1:4),
    category = factor(c("A", "B", "A", "C"), levels = c("C", "A", "B")),
    value = c(10.1, 20.2, 30.3, 40.4)
  )

  # --- 2. WRITE AND READ (DATASET) ---
  h5_write(file_path, "df_factor_dset", df_with_factor)
  df_read_dset <- h5_read(file_path, "df_factor_dset")

  # --- 3. VERIFY (DATASET) ---
  expect_s3_class(df_read_dset, "data.frame")
  expect_equal(df_read_dset, df_with_factor)
  expect_s3_class(df_read_dset$category, "factor")
})
