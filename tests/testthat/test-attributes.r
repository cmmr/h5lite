library(testthat)
library(h5lite)

test_that("h5_write with attrs=TRUE writes all attributes except 'dim'", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_with_attrs <- matrix(1:6, nrow = 2, ncol = 3)
  attr(d_with_attrs, "my_info") <- "This is a test matrix"
  attr(d_with_attrs, "my_version") <- 1.2
  class(d_with_attrs) <- c("special_matrix", "matrix", "array")

  h5_write(file_path, "dset_with_attrs", d_with_attrs, attrs = TRUE)

  written_attrs <- h5_ls_attr(file_path, "dset_with_attrs")
  expect_equal(sort(written_attrs), sort(c("my_info", "my_version", "class")))

  expect_equal(h5_read_attr(file_path, "dset_with_attrs", "my_info"), "This is a test matrix")
  expect_equal(h5_read_attr(file_path, "dset_with_attrs", "my_version"), 1.2)
  expect_equal(h5_read_attr(file_path, "dset_with_attrs", "class"), c("special_matrix", "matrix", "array"))
})

test_that("h5_write with character vector for attrs works correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_with_attrs <- matrix(1:6, nrow = 2, ncol = 3)
  attr(d_with_attrs, "my_info") <- "This is a test matrix"
  attr(d_with_attrs, "my_version") <- 1.2
  class(d_with_attrs) <- c("special_matrix", "matrix", "array")

  # 1. Test inclusion list
  h5_write(file_path, "dset_include", d_with_attrs, attrs = c("my_info", "class"))
  written_attrs_include <- h5_ls_attr(file_path, "dset_include")
  expect_equal(sort(written_attrs_include), sort(c("my_info", "class")))
  expect_equal(h5_read_attr(file_path, "dset_include", "my_info"), "This is a test matrix")

  # 2. Test exclusion list
  h5_write(file_path, "dset_exclude", d_with_attrs, attrs = c("-my_version", "-class"))
  written_attrs_exclude <- h5_ls_attr(file_path, "dset_exclude")
  expect_equal(written_attrs_exclude, "my_info")
})

test_that("h5_read with attrs argument works correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  d_original <- matrix(1:6, nrow = 2, ncol = 3)
  attr(d_original, "my_info") <- "This is a test matrix"
  attr(d_original, "my_version") <- 1.2
  class(d_original) <- c("special_matrix", "matrix", "array")
  h5_write(file_path, "dset", d_original, attrs = TRUE)

  # Test: attrs = TRUE (read all)
  d_read_all <- h5_read(file_path, "dset", attrs = TRUE)
  expect_equal(d_read_all, d_original)

  # Test: attrs = FALSE (read none)
  d_read_none <- h5_read(file_path, "dset", attrs = FALSE)
  expect_equal(d_read_none, matrix(1:6, nrow = 2, ncol = 3)) # No attributes
  expect_null(attr(d_read_none, "my_info"))

  # Test: Inclusion list
  d_read_include <- h5_read(file_path, "dset", attrs = c("my_info", "non_existent"))
  expect_equal(attr(d_read_include, "my_info"), "This is a test matrix")
  expect_null(attr(d_read_include, "my_version"))

  # Test: Exclusion list
  d_read_exclude <- h5_read(file_path, "dset", attrs = c("-class"))
  expect_equal(attr(d_read_exclude, "my_info"), "This is a test matrix")
  expect_equal(attr(d_read_exclude, "my_version"), 1.2)
  expect_null(attr(d_read_exclude, "class"))
})

test_that("Factor attributes are written and read correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Create a dataset and a factor attribute
  dset <- 1:5
  attr(dset, "my_factor_attr") <- factor(c("low", "medium", "high", "low"))

  # Write the dataset with its attributes
  h5_write(file_path, "dset_with_factor_attr", dset, attrs = TRUE)

  # Read the dataset back with attributes
  dset_read <- h5_read(file_path, "dset_with_factor_attr", attrs = TRUE)

  # Verify the factor attribute was restored correctly
  expect_equal(dset_read, dset)
  expect_s3_class(attr(dset_read, "my_factor_attr"), "factor")
})