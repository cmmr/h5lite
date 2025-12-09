library(testthat)
library(h5lite)

test_that("h5_open creates a valid handle and file", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # File should not exist initially
  expect_false(file.exists(file_path))

  # Create the handle
  h <- h5_open(file_path)

  # File should now exist
  expect_true(file.exists(file_path))

  # Check the handle's class and type
  expect_s3_class(h, "h5")
  expect_true(is.environment(h))
  expect_equal(h$.file, file_path)
})

test_that("h5 handle methods work correctly", {
  file_path <- tempfile(fileext = ".h5")
  h <- h5_open(file_path)
  on.exit(unlink(file_path), add = TRUE)

  # Test write and read
  h$write("d1", 1:10)
  expect_equal(h$read("d1"), 1:10)

  # Test attribute write and read
  h$write_attr("d1", "a1", I("hello"))
  expect_equal(h$read_attr("d1", "a1"), "hello")

  # Test info functions
  expect_true(h$exists("d1"))
  expect_false(h$exists("d2"))
  expect_true(h$exists_attr("d1", "a1"))
  expect_false(h$exists_attr("d1", "a2"))
  expect_true(h$is_dataset("d1"))
  expect_false(h$is_group("d1"))
  expect_equal(h$dim("d1"), 10)
  expect_equal(h$dim_attr("d1", "a1"), integer(0))
  expect_equal(h$typeof("d1"), "uint8")
  expect_equal(h$typeof_attr("d1", "a1"), "string")
  expect_equal(h$class("d1"), "numeric")
  expect_equal(h$class_attr("d1", "a1"), "character")

  # Test ls functions
  expect_equal(h$ls(), "d1")
  expect_equal(h$ls_attr("d1"), "a1")

  # Test organization functions
  h$create_group("g1")
  expect_true(h$is_group("g1"))
  h$move("d1", "g1/d1_moved")
  expect_true(h$exists("g1/d1_moved"))
  expect_false(h$exists("d1"))

  # Test delete functions
  h$delete_attr("g1/d1_moved", "a1")
  expect_false(h$exists_attr("g1/d1_moved", "a1"))
  h$delete("g1")
  expect_false(h$exists("g1"))
  
  # Test create_file (should do nothing if file exists)
  expect_silent(h$create_file())
})

test_that("h5 handle close() method invalidates the handle", {
  file_path <- tempfile(fileext = ".h5")
  h <- h5_open(file_path)
  on.exit(unlink(file_path), add = TRUE)

  h$write("d1", 1)
  h$close()

  # All subsequent calls should fail with the same error
  err_msg <- "This h5 file handle has been closed."
  expect_error(h$ls(), err_msg)
  expect_error(h$read("d1"), err_msg)
  expect_error(h$write("d2", 2), err_msg)
  expect_error(h$exists("d1"), err_msg)
  expect_error(h$delete("d1"), err_msg)
  expect_error(h$create_group("g1"), err_msg)
  expect_error(h$close(), err_msg) # Even closing again should fail
})

test_that("print.h5 and str.h5 methods work correctly", {
  file_path <- tempfile(fileext = ".h5")
  h <- h5_open(file_path)
  on.exit(unlink(file_path), add = TRUE)

  h$write("d1", 1:5)
  h$write("g1/d2", "hello")

  # Test print on an open handle
  expect_output(print(h), "<h5 handle>")
  expect_output(print(h), "  File:  ")
  expect_output(print(h), "  Objects (root):  2", fixed = TRUE)

  # Test str on an open handle
  # Check that key components are present in the str output
  expect_output(str(h), "d1")
  expect_output(str(h), "d2")

  # Test print on a closed handle
  h$close()
  expect_output(print(h), "<h5 handle for a closed file>")
  
  # Test print on a handle where the file has been deleted
  h_deleted <- h5_open("deleted_file.h5");
  unlink("deleted_file.h5")
  expect_output(print(h_deleted), "File:  deleted_file.h5", fixed = TRUE)
  expect_output(print(h_deleted), "<h5 handle>")
  # Size and Objects should not be printed
  expect_no_match(capture_output(print(h_deleted)), "Size:")
})

test_that("as.character.h5 method works correctly", {
  file_path <- tempfile(fileext = ".h5")
  h <- h5_open(file_path)
  on.exit(unlink(file_path), add = TRUE)

  # Should return the file path for an open handle
  expect_equal(as.character(h), file_path)

  # Should return NULL for a closed handle
  h$close()
  expect_null(as.character(h))
})

test_that("[[ and [[<- subsetting methods work correctly", {
  file_path <- tempfile(fileext = ".h5")
  h <- h5_open(file_path)
  on.exit(unlink(file_path), add = TRUE)

  # --- Test Dataset Access ---
  # Write a dataset
  h[["d1"]] <- 1:10 # This modifies h by reference
  expect_true(h$exists("d1"))
  # Read it back
  expect_equal(h[["d1"]], 1:10)

  # --- Test Attribute Access ---
  # Write an attribute
  h[["d1@a1"]] <- "hello attribute" # Modifies h by reference
  expect_true(h$exists_attr("d1", "a1"))
  # Read it back
  expect_equal(h[["d1@a1"]], "hello attribute")

  # --- Test Overwriting ---
  h[["d1"]] <- 11:20 # Overwrite dataset by reference
  expect_equal(h[["d1"]], 11:20)
  h[["d1@a1"]] <- "new value" # Overwrite attribute by reference
  expect_equal(h[["d1@a1"]], "new value")

  # --- Test Error Conditions ---
  # Invalid index type
  expect_error(h[[1]], "requires a single character name")
  expect_error(h[[c("a", "b")]], "requires a single character name")
  expect_error(h[[1]] <- 1, "requires a single character name")

  # --- Test Invalid Attribute Syntax ---
  expect_error(h[["d1@a1@a2"]], "Only one '@' is permitted")
  expect_error(h[["d1@"]] <- 1, "Attribute name cannot be empty")
  expect_error(h[["d1@"]], "Attribute name cannot be empty")

  # --- Test Attribute on Current Working Directory ---
  # At root
  h[["@root_attr"]] <- "root attribute value"
  expect_true(h$exists_attr("/", "root_attr"))
  expect_equal(h[["@root_attr"]], "root attribute value")

  # Inside a group
  h$create_group("g1")
  h$cd("g1")
  expect_equal(h$pwd(), "/g1")

  h[["@group_attr"]] <- "group attribute value"
  expect_true(h$exists_attr(".", "group_attr")) # Check relative to current WD
  expect_equal(h[["@group_attr"]], "group attribute value")
  expect_equal(h$read_attr(".", "group_attr"), "group attribute value")
})
