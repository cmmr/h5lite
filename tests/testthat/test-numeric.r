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
  expect_equal(h5_typeof(file_path, "special_vals"), "float16")

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

test_that("Writing numeric data outside the dtype range throws an error", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Test 1: Value too large for the specified unsigned type
  d_too_large <- c(100, 75000) # 75000 is > 65504 (max for float16)
  expect_error(h5_write(file_path, "too_large", d_too_large, dtype = "float16"))

  # Test 2: Negative value for an unsigned type
  d_negative <- c(-10, 50) # -10 is < 0 (min for uint8)
  expect_error(h5_write(file_path, "negative", d_negative, dtype = "uint8"))
})

test_that("Auto-selection of float types for data with NAs is correct", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Test case 1: Data with NA, fits within float16 integer precision.
  # The range [-2048, 2048] can be perfectly represented by float16.
  d_na_float16 <- c(100, -500, NA, 2048)
  h5_write(file_path, "na_f16", d_na_float16)
  expect_equal(h5_typeof(file_path, "na_f16"), "float16")
  expect_equal(h5_read(file_path, "na_f16"), d_na_float16)

  # Test case 2: Data with NA, exceeds float16 but fits float32 precision.
  # The range [-16777216, 16777216] can be represented by float32.
  d_na_float32 <- c(100, -500, NA, 2049) # 2049 is just outside float16's range
  h5_write(file_path, "na_f32", d_na_float32)
  expect_equal(h5_typeof(file_path, "na_f32"), "float32")
  expect_equal(h5_read(file_path, "na_f32"), d_na_float32)

  # Test case 3: Data with NA, exceeds float32 precision, defaults to float64.
  d_na_float64 <- c(NA, 2^24 + 1) # This value is outside float32's precise integer range
  h5_write(file_path, "na_f64", d_na_float64)
  expect_equal(h5_typeof(file_path, "na_f64"), "float64")
  expect_equal(h5_read(file_path, "na_f64"), d_na_float64)
})

test_that("Writing a zero-length numeric vector works", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Test with auto dtype
  h5_write(file_path, "zero_len_num_auto", numeric(0))
  expect_equal(h5_read(file_path, "zero_len_num_auto"), numeric(0))
  expect_equal(h5_typeof(file_path, "zero_len_num_auto"), "uint8") # Default for empty

  # Test with specified dtype
  h5_write(file_path, "zero_len_num_dtype", numeric(0), dtype = "float32")
  expect_equal(h5_read(file_path, "zero_len_num_dtype"), numeric(0))
  expect_equal(h5_typeof(file_path, "zero_len_num_dtype"), "float32")
})

test_that("Writing a vector of only non-finite values works", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_all_non_finite <- c(NA, NaN, Inf, -Inf)
  h5_write(file_path, "all_non_finite", d_all_non_finite)

  expect_equal(h5_typeof(file_path, "all_non_finite"), "float16")
  expect_equal(h5_read(file_path, "all_non_finite"), d_all_non_finite)
})
