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

test_that("Internal get_attributes_to_read() function has full coverage", {
  # Access the internal helper function
  get_attrs_to_read <- h5lite:::get_attributes_to_read
  available_attrs <- c("class", "names", "info", "version")

  # --- 1. Test logical 'attrs' argument ---
  # attrs = TRUE should return all available attributes
  expect_equal(get_attrs_to_read(available_attrs, TRUE), available_attrs)
  # attrs = FALSE should return an empty character vector
  expect_equal(get_attrs_to_read(available_attrs, FALSE), character(0))

  # --- 2. Test character 'attrs' argument (inclusion mode) ---
  # Include a subset of existing attributes
  expect_equal(get_attrs_to_read(available_attrs, c("class", "info")), c("class", "info"))
  # Include a mix of existing and non-existing attributes
  expect_equal(get_attrs_to_read(available_attrs, c("info", "non_existent")), "info")
  # Include only non-existing attributes
  expect_equal(get_attrs_to_read(available_attrs, c("foo", "bar")), character(0))

  # --- 3. Test character 'attrs' argument (exclusion mode) ---
  # Exclude a subset of attributes
  expect_equal(get_attrs_to_read(available_attrs, c("-class", "-version")), c("names", "info"))
  # Exclude a mix of existing and non-existing attributes
  expect_equal(get_attrs_to_read(available_attrs, c("-names", "-non_existent")), c("class", "info", "version"))
  # Exclude all attributes
  expect_equal(get_attrs_to_read(available_attrs, paste0("-", available_attrs)), character(0))

  # --- 4. Test error condition for mixed inclusion/exclusion ---
  expect_error(get_attrs_to_read(available_attrs, c("class", "-info")))

  # --- 5. Test other 'attrs' inputs that should result in no attributes ---
  # Empty character vector
  expect_equal(get_attrs_to_read(available_attrs, character(0)), character(0))
  # NULL input
  expect_equal(get_attrs_to_read(available_attrs, NULL), character(0))
  # Numeric input
  expect_equal(get_attrs_to_read(available_attrs, 123), character(0))
})

test_that("Internal get_attributes_to_write() function has full coverage", {
  # Access the internal helper function
  get_attrs_to_write <- h5lite:::get_attributes_to_write

  # Create a sample object with attributes
  d <- 1
  attr(d, "info") <- "some info"
  attr(d, "version") <- 1.2
  class(d) <- "my_class"

  # --- 1. Test logical 'attrs' argument ---
  expect_equal(names(get_attrs_to_write(d, TRUE)), c("info", "version", "class"))
  expect_equal(get_attrs_to_write(d, FALSE), list())

  # --- 2. Test character 'attrs' argument (inclusion/exclusion) ---
  expect_equal(names(get_attrs_to_write(d, c("info", "class"))), c("info", "class"))
  expect_equal(names(get_attrs_to_write(d, c("-version"))), c("info", "class"))

  # --- 3. Test default case (return list()) for other inputs ---
  expect_equal(get_attrs_to_write(d, NULL), list())
  expect_equal(get_attrs_to_write(d, character(0)), list())
  expect_equal(get_attrs_to_write(d, 123), list())
})

test_that("h5_write errors when an attribute has an unsupported type", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Create an object with an attribute that is a list (unsupported)
  d_with_bad_attr <- 1
  attr(d_with_bad_attr, "bad_attr") <- list(a = 1, b = 2)

  # Expect an error when trying to write with attrs = TRUE
  expect_error(
    h5_write(file_path, "dset_with_bad_attr", d_with_bad_attr, attrs = TRUE),
    "Attribute 'bad_attr' cannot be written to HDF5 because its type ('list') is not supported.",
    fixed = TRUE
  )
})

test_that("Overwriting an existing attribute works correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Create a dataset to attach the attribute to
  h5_write(file_path, "my_dset", 1)

  # 1. Write an attribute for the first time
  h5_write_attr(file_path, "my_dset", "my_attr", "initial_value")
  expect_equal(h5_read_attr(file_path, "my_dset", "my_attr"), "initial_value")

  # 2. Overwrite the attribute with a new value
  h5_write_attr(file_path, "my_dset", "my_attr", "new_value")
  expect_equal(h5_read_attr(file_path, "my_dset", "my_attr"), "new_value")
})
