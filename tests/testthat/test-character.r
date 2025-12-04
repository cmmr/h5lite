library(testthat)
library(h5lite)

test_that("Character datasets are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_vec_char <- c("hello", "world", NA_character_, "h5lite")
  d_mat_char <- matrix(c("a", "b", "c", NA_character_), nrow = 2)
  d_scalar_char <- I("a single string")

  # --- 2. WRITE DATA ---
  h5_write(file_path, "vec_char", d_vec_char)
  h5_write(file_path, "mat_char", d_mat_char)
  h5_write(file_path, "scalar_char", d_scalar_char)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof(file_path, "vec_char"), "string")
  expect_equal(h5_class(file_path, "vec_char"), "character")
  expect_equal(h5_dim(file_path, "scalar_char"), integer(0))

  # --- 4. READ AND VERIFY DATA ---
  # Use expect_identical to be strict about NA handling
  expect_identical(h5_read(file_path, "vec_char"), d_vec_char)
  expect_identical(h5_read(file_path, "mat_char"), d_mat_char)
  expect_identical(h5_read(file_path, "scalar_char"), as.character(d_scalar_char))
})

test_that("Character attributes are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  d_attr_char_vec <- c("config_a", "config_b", NA_character_)
  d_attr_char_scalar <- I("metadata")

  # --- 2. WRITE DATA ---
  h5_write(file_path, "dset", 1) # Create a dataset to attach attributes to
  h5_write_attr(file_path, "dset", "char_attr_vec", d_attr_char_vec)
  h5_write_attr(file_path, "dset", "char_attr_scalar", d_attr_char_scalar)

  # --- 3. VERIFY TYPES ---
  expect_equal(h5_typeof_attr(file_path, "dset", "char_attr_vec"), "string")
  expect_equal(h5_class_attr(file_path, "dset", "char_attr_vec"), "character")

  # --- 4. READ AND VERIFY DATA ---
  expect_identical(h5_read_attr(file_path, "dset", "char_attr_vec"), d_attr_char_vec)
  expect_identical(h5_read_attr(file_path, "dset", "char_attr_scalar"), as.character(d_attr_char_scalar))
})

test_that("data.frame with a character column round-trips correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. DEFINE DATA ---
  df_with_char <- data.frame(
    id = as.double(1:4),
    label = c("A", "B", NA_character_, "D"),
    value = c(10.1, 20.2, 30.3, 40.4),
    stringsAsFactors = FALSE
  )

  # --- 2. WRITE AND READ (DATASET) ---
  h5_write(file_path, "df_char_dset", df_with_char)
  df_read_dset <- h5_read(file_path, "df_char_dset")

  # --- 3. VERIFY (DATASET) ---
  expect_s3_class(df_read_dset, "data.frame")
  expect_identical(df_read_dset, df_with_char)
  expect_type(df_read_dset$label, "character")

  # --- 4. WRITE AND READ (ATTRIBUTE) ---
  h5_write(file_path, "dset_for_attr", 1) # Dummy object
  h5_write_attr(file_path, "dset_for_attr", "df_char_attr", df_with_char)
  df_read_attr <- h5_read_attr(file_path, "dset_for_attr", "df_char_attr")

  # --- 5. VERIFY (ATTRIBUTE) ---
  expect_s3_class(df_read_attr, "data.frame")
  expect_identical(df_read_attr, df_with_char)
  expect_type(df_read_attr$label, "character")
})

test_that("fixed-length strings", {
  file_path <- test_path('input/fixed_len.h5')
  chr_vec <- expect_silent(h5_read(file_path, 'chr_vec'))
  chr_mtx <- expect_silent(h5_read(file_path, 'chr_mtx'))
  expect_identical(chr_vec, c("BRCA1", "TP53", "EGFR", "MYC"))
  expect_identical(chr_mtx, t(matrix(chr_vec, nrow = 2)))
})
