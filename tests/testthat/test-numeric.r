library(testthat)
library(h5lite)

test_that("Numeric datasets are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_vec_num <- c(1.1, 2.2, 3.3)
  d_mat_num <- matrix(c(1.5, 2.5, 3.5, 4.5), nrow = 2)
  d_scalar_num <- I(3.14)
  d_special_vals <- c(1.0, NA, NaN, Inf, -Inf, 2.0)

  # --- 2. WRITE DATA ---
  h5_write(file_path, "vec_num", d_vec_num)
  h5_write(file_path, "mat_num", d_mat_num)
  h5_write(file_path, "scalar_num", d_scalar_num)
  h5_write(file_path, "special_vals", d_special_vals)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof(file_path, "vec_num"), "float64")
  expect_equal(h5_class(file_path, "vec_num"), "numeric")
  expect_equal(h5_dim(file_path, "scalar_num"), integer(0))
  expect_equal(h5_typeof(file_path, "special_vals"), "float64")

  # --- 4. READ AND VERIFY DATA ---
  expect_equal(h5_read(file_path, "vec_num"), d_vec_num)
  expect_equal(h5_read(file_path, "mat_num"), d_mat_num)
  expect_equal(h5_read(file_path, "scalar_num"), as.numeric(d_scalar_num))
  expect_equal(h5_read(file_path, "special_vals"), d_special_vals)
})

test_that("Numeric attributes are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_attr_num_vec <- c(10.1, 20.2, 30.3)
  d_attr_special <- c(NA, NaN, Inf)

  # --- 2. WRITE DATA ---
  h5_write(file_path, "dset", 1) # Create a dataset to attach attributes to
  h5_write_attr(file_path, "dset", "num_attr_vec", d_attr_num_vec)
  h5_write_attr(file_path, "dset", "num_attr_special", d_attr_special)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof_attr(file_path, "dset", "num_attr_vec"), "float64")
  expect_equal(h5_class_attr(file_path, "dset", "num_attr_vec"), "numeric")

  # --- 4. READ AND VERIFY DATA ---
  expect_equal(h5_read_attr(file_path, "dset", "num_attr_vec"), d_attr_num_vec)
  expect_equal(h5_read_attr(file_path, "dset", "num_attr_special"), d_attr_special)
})

test_that("data.frame with a numeric column round-trips correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  df <- data.frame(id = 1:4, value = c(10.1, NA, 30.3, NaN))
  h5_write(file_path, "df_num", df)
  df_read <- h5_read(file_path, "df_num")

  df_expected <- df
  df_expected$id <- as.numeric(df_expected$id)
  expect_equal(df_read, df_expected)
})

test_that("Writing non-finite numeric data to an integer dtype throws an error", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_special_vals <- c(1.0, NA, NaN, Inf, -Inf)

  # Test for datasets
  expect_error(h5_write(file_path, "special_vals_as_int", d_special_vals, dtype = "int32"))

  # Test for attributes
  h5_write(file_path, "dset", 1)
  expect_error(h5_write_attr(file_path, "dset", "special_attr_as_int", d_special_vals, dtype = "int16"))
})

test_that("Writing numeric data with fractions to an integer dtype results in truncation", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_numeric_with_fractions <- c(1.2, 3.9, -2.5)
  d_expected_truncation <- c(1, 3, -2)

  # Test for datasets
  h5_write(file_path, "truncated_dset", d_numeric_with_fractions, dtype = "int8")
  expect_equal(h5_read(file_path, "truncated_dset"), d_expected_truncation)

  # Test for attributes
  h5_write_attr(file_path, "truncated_dset", "truncated_attr", d_numeric_with_fractions, dtype = "int16")
  expect_equal(h5_read_attr(file_path, "truncated_dset", "truncated_attr"), d_expected_truncation)
})

test_that("Special float values round-trip correctly with float16 and float32 dtypes", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_special_vals <- c(1.0, NA, NaN, Inf, -Inf, -1.0)

  # --- Test with float16 ---
  # Dataset
  h5_write(file_path, "special_f16_dset", d_special_vals, dtype = "float16")
  expect_equal(h5_read(file_path, "special_f16_dset"), d_special_vals)
  expect_equal(h5_typeof(file_path, "special_f16_dset"), "float16")

  # Attribute
  h5_write_attr(file_path, "special_f16_dset", "special_f16_attr", d_special_vals, dtype = "float16")
  expect_equal(h5_read_attr(file_path, "special_f16_dset", "special_f16_attr"), d_special_vals)
  expect_equal(h5_typeof_attr(file_path, "special_f16_dset", "special_f16_attr"), "float16")

  # --- Test with float32 ---
  # Dataset
  h5_write(file_path, "special_f32_dset", d_special_vals, dtype = "float32")
  expect_equal(h5_read(file_path, "special_f32_dset"), d_special_vals)
  expect_equal(h5_typeof(file_path, "special_f32_dset"), "float32")

  # Attribute
  h5_write_attr(file_path, "special_f32_dset", "special_f32_attr", d_special_vals, dtype = "float32")
  expect_equal(h5_read_attr(file_path, "special_f32_dset", "special_f32_attr"), d_special_vals)
  expect_equal(h5_typeof_attr(file_path, "special_f32_dset", "special_f32_attr"), "float32")
})