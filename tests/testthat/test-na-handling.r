library(testthat)
library(h5lite)

test_that("NA values in character vectors are handled correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # 1. Test with a simple character vector
  vec_with_na <- c("a", "b", NA, "d", NA)
  h5_write(file_path, "vec_with_na", vec_with_na)
  vec_read <- h5_read(file_path, "vec_with_na")
  expect_identical(vec_read, vec_with_na)

  # 2. Test with a matrix of characters
  mat_with_na <- matrix(c("a", NA, "c", "d"), nrow = 2)
  h5_write(file_path, "mat_with_na", mat_with_na)
  mat_read <- h5_read(file_path, "mat_with_na")
  expect_identical(mat_read, mat_with_na)

  # 3. Test with a scalar NA
  scalar_na <- NA_character_
  h5_write(file_path, "scalar_na", I(scalar_na))
  scalar_read <- h5_read(file_path, "scalar_na")
  expect_identical(scalar_read, scalar_na)
})

test_that("NA values in character attributes are handled correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  h5_write(file_path, "dset", 1)

  attr_with_na <- c("config1", NA, "config3")
  h5_write_attr(file_path, "dset", "attr_with_na", attr_with_na)
  attr_read <- h5_read_attr(file_path, "dset", "attr_with_na")
  expect_identical(attr_read, attr_with_na)
})

test_that("NA values in data.frame character columns are handled correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  df_with_na <- data.frame(
    id    = as.numeric(1:4), 
    label = c("A", NA, "C", NA), 
    stringsAsFactors = FALSE )
  h5_write(file_path, "df_with_na", df_with_na)
  df_read <- h5_read(file_path, "df_with_na")
  expect_identical(df_read, df_with_na)
})
