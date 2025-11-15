library(testthat)
library(h5lite)

test_that("Functions throw errors for non-existent objects", {
  
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)
  h5_write(file_path, "my_dset", 1)
  h5_create_group(file_path, "my_group")

  # h5_read errors
  expect_error(h5_read(file_path, "nonexistent"))
  expect_error(h5_read(file_path, "my_group"))

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

  # Error on mismatched delete type
  expect_error(h5_delete(file_path, "my_group"))
  expect_error(h5_delete_group(file_path, "my_dataset"))

  # Warning on non-existent object/attribute
  expect_warning(h5_delete(file_path, "nonexistent_dset"))
  expect_warning(h5_delete_group(file_path, "nonexistent_group"))
  expect_warning(h5_delete_attr(file_path, "my_dataset", "nonexistent_attr"))
})


test_that("Write functions validate inputs", {

    file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # h5_write_all requires a list
  expect_error(h5_write_all(file_path, "test", 1:5), "'data' must be a list.")

  # h5_write with mixed-mode attributes
  d_with_attrs <- matrix(1:6)
  attr(d_with_attrs, "my_info") <- "info"
  class(d_with_attrs) <- "special"
  expect_error(h5_write(file_path, "dset_mixed", d_with_attrs, attrs = c("my_info", "-class")))
})
