# This file should be saved as: tests/testthat/test-class.r

library(testthat)
library(h5lite)

test_that("h5_class and h5_class_attr return correct R classes", {
  
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)
  
  # --- 1. Setup: Create a comprehensive HDF5 file ---
  
  # Datasets of various types
  h5_write(file_path, "dset_int", 1:10)             # Stored as uint8 -> numeric
  h5_write(file_path, "dset_double", 1.5)           # Stored as float64 -> numeric
  h5_write(file_path, "dset_char", "hello")         # Stored as string -> character
  h5_write(file_path, "dset_factor", factor(c("a", "b"))) # Stored as enum -> factor
  h5_write(file_path, "dset_raw", as.raw(c(0x01, 0x02))) # Stored as opaque -> raw
  
  # A simple group
  h5_create_group(file_path, "group_simple")
  
  # A data.frame, which is written as a compound dataset
  h5_write(file_path, "dset_df", data.frame(a = 1:2, b = c("x", "y")), attrs = TRUE)
  
  # Attributes of various types
  h5_write_attr(file_path, "dset_int", "attr_int", 1L)
  h5_write_attr(file_path, "dset_int", "attr_double", 2.2)
  h5_write_attr(file_path, "dset_int", "attr_char", "attr_val")
  h5_write_attr(file_path, "dset_int", "attr_factor", factor(c("x", "y")))
  h5_write_attr(file_path, "dset_int", "attr_raw", as.raw(0x10))
  
  
  # --- 2. Test h5_class ---
  
  # Test basic object types
  expect_equal(h5_class(file_path, "dset_int"), "numeric")
  expect_equal(h5_class(file_path, "dset_double"), "numeric")
  expect_equal(h5_class(file_path, "dset_char"), "character")
  expect_equal(h5_class(file_path, "dset_factor"), "factor")
  expect_equal(h5_class(file_path, "dset_raw"), "raw")
  expect_equal(h5_class(file_path, "group_simple"), "list")
  expect_equal(h5_class(file_path, "dset_df"), "data.frame")
  
  # Test the 'attrs' argument behavior
  # 'attrs=FALSE' (default) should report the object type from its HDF5 class
  expect_equal(h5_class(file_path, "dset_df", attrs = FALSE), "data.frame")
  
  # 'attrs=TRUE' should find the "class" HDF5 attribute and return its value
  expect_equal(h5_class(file_path, "dset_df", attrs = TRUE), "data.frame")
  
  # 'attrs=c("class")' should also find the "class" attribute
  expect_equal(h5_class(file_path, "dset_df", attrs = c("class")), "data.frame")
  
  # 'attrs' with a non-"class" value should ignore the attribute
  expect_equal(h5_class(file_path, "dset_df", attrs = c("row.names")), "data.frame")
  
  # Test error case for non-existent object
  expect_error(
    h5_class(file_path, "non_existent_object"),
    "Object 'non_existent_object' does not exist"
  )
  
  
  # --- 3. Test h5_class_attr ---
  
  # Test basic attribute types
  expect_equal(h5_class_attr(file_path, "dset_int", "attr_int"), "numeric")
  expect_equal(h5_class_attr(file_path, "dset_int", "attr_double"), "numeric")
  expect_equal(h5_class_attr(file_path, "dset_int", "attr_char"), "character")
  expect_equal(h5_class_attr(file_path, "dset_int", "attr_factor"), "factor")
  expect_equal(h5_class_attr(file_path, "dset_int", "attr_raw"), "raw")
  
  # Test error case for non-existent attribute
  expect_error(
    h5_class_attr(file_path, "dset_int", "non_existent_attr"),
    "Attribute 'non_existent_attr' does not exist"
  )
  
  # Test error case for attribute on non-existent object
  expect_error(
    h5_class_attr(file_path, "non_existent_object", "attr_int"),
    "Attribute 'attr_int' does not exist"
  )
  
})


test_that("Internal helper map_hdf5_type_to_r_class works", {
  # Access the internal helper function
  map_fun <- h5lite:::map_hdf5_type_to_r_class
  
  # Test numeric types
  expect_equal(map_fun("int8"), "numeric")
  expect_equal(map_fun("uint8"), "numeric")
  expect_equal(map_fun("int16"), "numeric")
  expect_equal(map_fun("uint16"), "numeric")
  expect_equal(map_fun("int32"), "numeric")
  expect_equal(map_fun("uint32"), "numeric")
  expect_equal(map_fun("int64"), "numeric")
  expect_equal(map_fun("uint64"), "numeric")
  expect_equal(map_fun("float16"), "numeric")
  expect_equal(map_fun("float32"), "numeric")
  expect_equal(map_fun("float64"), "numeric")
  expect_equal(map_fun("int"), "numeric")
  expect_equal(map_fun("float"), "numeric")
  
  # Test other supported types
  expect_equal(map_fun("string"), "character")
  expect_equal(map_fun("enum"), "factor")
  expect_equal(map_fun("opaque"), "raw")
  expect_equal(map_fun("compound"), "data.frame")
  
  # Test unsupported/NA types
  expect_equal(map_fun("vlen"), NA_character_)
  expect_equal(map_fun("reference"), NA_character_)
  expect_equal(map_fun("bitfield"), NA_character_)
  expect_equal(map_fun("array"), NA_character_)
  expect_equal(map_fun("unknown"), NA_character_)
  expect_equal(map_fun("gibberish"), NA_character_)
})
