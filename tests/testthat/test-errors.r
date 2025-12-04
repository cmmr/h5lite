library(testthat)
library(h5lite)

test_that("Functions throw errors for non-existent objects", {
  
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)
  h5_write(file_path, "my_dset", 1)
  h5_create_group(file_path, "my_group")

  # h5_read errors
  expect_error(h5_read(file_path, "nonexistent"))

  # h5_read_attr errors
  expect_error(h5_read_attr(file_path, "nonexistent", "attr"))
  expect_error(h5_read_attr(file_path, "my_dset", "no_attr"))

  # h5_write_attr error
  expect_error(h5_write_attr("nonexistent.h5", "my_dset", "attr", 1))
})

test_that("Delete functions handle errors and warnings correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  h5_write(file_path, "my_dataset", 1:10)
  h5_create_group(file_path, "my_group")
  h5_write_attr(file_path, "my_dataset", "my_attr", "value")

  # Warning on non-existent object/attribute
  expect_warning(h5_delete(file_path, "nonexistent_dset"))
  expect_warning(h5_delete_attr(file_path, "my_dataset", "nonexistent_attr"))

  # Error on non-existent file
  non_existent_file <- "this_file_does_not_exist.h5"
  expect_error(h5_delete(non_existent_file, "any_object"), "File does not exist")
  expect_error(h5_delete_attr(non_existent_file, "any_object", "any_attr"), "File does not exist")
})


test_that("Write functions validate inputs", {

    file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # h5_write requires a list to have named elements
  expect_error(h5_write(file_path, "test", list(1, 2)), "All elements in a list must be named.")

  # h5_write with mixed-mode attributes
  d_with_attrs <- matrix(1:6)
  attr(d_with_attrs, "my_info") <- "info"
  class(d_with_attrs) <- "special"
  expect_error(h5_write(file_path, "dset_mixed", d_with_attrs, attrs = c("my_info", "-class")))
})

test_that("Info functions error on non-existent files", {
  non_existent_file <- "this_file_does_not_exist.h5"

  # These functions have a direct file.exists() check
  expect_error(h5_typeof(non_existent_file, "any_object"), "File does not exist")
  expect_error(h5_typeof_attr(non_existent_file, "any_object", "any_attr"), "File does not exist")
  expect_error(h5_dim(non_existent_file, "any_object"), "File does not exist")
  expect_error(h5_dim_attr(non_existent_file, "any_object", "any_attr"), "File does not exist")

  # These functions error because their internal h5_exists() call returns FALSE
  expect_error(h5_class(non_existent_file, "any_object"), "Object 'any_object' does not exist")
  expect_error(h5_class_attr(non_existent_file, "any_object", "any_attr"), "Attribute 'any_attr' does not exist")
})

test_that("List functions error on non-existent files", {
  non_existent_file <- "this_file_does_not_exist.h5"

  expect_error(h5_ls(non_existent_file), "File does not exist")
  expect_error(h5_ls_attr(non_existent_file, "any_object"), "File does not exist")
  expect_error(h5_str(non_existent_file), "File does not exist")
})

test_that("h5_write validates inputs during recursive write", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Test for unsupported object type inside a list
  bad_list_unsupported_type <- list(a = 1, b = new.env())
  expect_error(
    h5_write(file_path, "bad_list", bad_list_unsupported_type),
    "Validation failed for 'bad_list/b': Cannot map R type to HDF5 object: 'environment'",
    fixed = TRUE
  )

  # Test for unsupported attribute type inside a list
  d_with_bad_attr <- 1
  attr(d_with_bad_attr, "bad") <- list(x = 1) # list attributes are not supported
  bad_list_unsupported_attr <- list(a = 1, b = d_with_bad_attr)
  expect_error(
    h5_write(file_path, "bad_list_attr", bad_list_unsupported_attr, attrs = TRUE),
    "Validation failed for 'bad_list_attr/b': Attribute 'bad' cannot be written to HDF5 because its type ('list') is not supported.",
    fixed = TRUE
  )

  # Test that `assert_valid_dataset` stops lists
  expect_error(
    h5lite:::assert_valid_dataset(list(a = 1)),
    "Cannot map R type to HDF5 dataset: 'list'",
    fixed = TRUE
  )
})
