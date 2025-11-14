
test_that("writing and reading a factor to a dataset works", {
  # Create a factor
  set.seed(123)
  original_factor <- as.factor(sample(c("apple", "banana", "cherry"), 10, replace = TRUE))
  
  # Create a temporary file
  file <- tempfile(fileext = ".h5")
  
  # Write the factor to the HDF5 file
  h5_write(file, "my_factor", original_factor)
  
  # Read the factor back
  read_factor <- h5_read(file, "my_factor")
  
  # Check that the read factor is identical to the original
  expect_identical(original_factor, read_factor)
  
  # Clean up
  file.remove(file)
})

test_that("writing and reading a factor to an attribute works", {
  # Create a factor
  set.seed(456)
  original_factor <- as.factor(c("red", "green", "blue"))
  
  # Create a temporary file and a group
  file <- tempfile(fileext = ".h5")
  h5_create_group(file, "my_group")
  
  # Write the factor as an attribute
  h5_write_attr(file, "my_group", "my_factor_attr", original_factor)
  
  # Read the factor attribute back
  read_factor_attr <- h5_read_attr(file, "my_group", "my_factor_attr")
  
  # Check that the read attribute is identical to the original
  expect_identical(original_factor, read_factor_attr)
  
  # Clean up
  file.remove(file)
})
