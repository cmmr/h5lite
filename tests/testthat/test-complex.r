library(testthat)
library(h5lite)

test_that("Complex data is written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  # Using NA_complex_ which should be handled as NaN values
  d_vec_complex <- c(1 + 2i, 3 - 4i, 5 + 0i, 0 - 6i, NA_complex_)
  d_mat_complex <- matrix(c(1 + 1i, 2 + 2i, 3 + 3i, 4 + 4i), nrow = 2)
  d_scalar_complex <- 1.2 + 3.4i

  # --- 2. WRITE DATA ---
  h5_write(file_path, "vec_cplx", d_vec_complex)
  h5_write(file_path, "mat_cplx", d_mat_complex)
  h5_write(file_path, "scalar_cplx", I(d_scalar_complex))

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof(file_path, "vec_cplx"), "complex")
  expect_equal(h5_class(file_path, "vec_cplx"), "complex")
  expect_equal(h5_dim(file_path, "scalar_cplx"), integer(0))

  # --- 4. READ AND VERIFY DATA ---
  r_vec_complex <- h5_read(file_path, "vec_cplx")
  r_mat_complex <- h5_read(file_path, "mat_cplx")
  r_scalar_complex <- h5_read(file_path, "scalar_cplx")

  expect_equal(r_vec_complex, d_vec_complex)
  expect_equal(r_mat_complex, d_mat_complex)
  expect_equal(r_scalar_complex, d_scalar_complex)
})

test_that("Complex attributes are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_attr_complex <- c(1 + 1i, -2 - 2i, NA_complex_)
  d_attr_scalar <- I(5 + 5i)

  # --- 2. WRITE DATA ---
  h5_write(file_path, "dset", 1) # Create a dataset to attach attributes to
  h5_write_attr(file_path, "dset", "cplx_attr_vec", d_attr_complex)
  h5_write_attr(file_path, "dset", "cplx_attr_scalar", d_attr_scalar)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof_attr(file_path, "dset", "cplx_attr_vec"), "complex")
  expect_equal(h5_class_attr(file_path, "dset", "cplx_attr_vec"), "complex")

  # --- 4. READ AND VERIFY DATA ---
  expect_equal(h5_read_attr(file_path, "dset", "cplx_attr_vec"), d_attr_complex)
  expect_equal(h5_read_attr(file_path, "dset", "cplx_attr_scalar"), as.complex(d_attr_scalar))
})

test_that("data.frame with a complex column round-trips correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  df_with_complex <- data.frame(
    id = as.double(1:3),
    cplx_data = c(1 + 2i, 3 - 4i, NA_complex_),
    label = c("one", "two", "three")
  )

  # --- 2. WRITE AND READ (DATASET) ---
  h5_write(file_path, "df_cplx_dset", df_with_complex)
  df_read_dset <- h5_read(file_path, "df_cplx_dset")

  # --- 3. VERIFY (DATASET) ---
  # The integer 'id' column will be read back as numeric (double).
  df_expected <- df_with_complex
  df_expected$id <- as.numeric(df_expected$id)

  expect_s3_class(df_read_dset, "data.frame")
  expect_equal(df_read_dset, df_expected)
  expect_type(df_read_dset$cplx_data, "complex")
})
