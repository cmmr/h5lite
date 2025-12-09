library(testthat)
library(h5lite)

test_that("POSIXt objects are automatically converted to ISO 8601 strings", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # 1. Define a POSIXt object. Use a fixed time zone for reproducibility.
  time_obj <- as.POSIXct("2025-12-08 15:30:00", tz = "UTC")
  expected_str <- format(time_obj, format = "%Y-%m-%dT%H:%M:%OSZ")

  # 2. Test as a dataset
  h5_write(file_path, "timestamp_dset", time_obj)

  # Verify the stored type is string
  expect_equal(h5_typeof(file_path, "timestamp_dset"), "string")

  # Read back and verify the value
  read_dset <- h5_read(file_path, "timestamp_dset")
  expect_type(read_dset, "character")
  expect_equal(read_dset, expected_str)

  # 3. Test as an attribute
  h5_write_attr(file_path, "timestamp_dset", "timestamp_attr", time_obj)

  # Verify the stored type is string
  expect_equal(h5_typeof_attr(file_path, "timestamp_dset", "timestamp_attr"), "string")
  read_attr <- h5_read_attr(file_path, "timestamp_dset", "timestamp_attr")
  expect_type(read_attr, "character")
  expect_equal(read_attr, expected_str)
})

test_that("data.frame with POSIXt column is written as character", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # 1. Define data.frame with a POSIXt column
  time_obj <- as.POSIXct("2025-12-08 15:30:00", tz = "UTC")
  df_with_posix <- data.frame(
    id = 1:3,
    timestamp = time_obj + 0:2,
    value = c(10.1, 20.2, 30.3)
  )

  # 2. Write and Read
  h5_write(file_path, "df_posix", df_with_posix)
  df_read <- h5_read(file_path, "df_posix")

  # 3. Create expected data.frame for comparison
  df_expected <- df_with_posix
  df_expected$id <- as.numeric(df_expected$id) # integer becomes numeric
  df_expected$timestamp <- format(df_expected$timestamp, format = "%Y-%m-%dT%H:%M:%OSZ") # POSIXt becomes character

  # 4. Verify
  expect_s3_class(df_read, "data.frame")
  expect_type(df_read$timestamp, "character")
  expect_equal(df_read, df_expected)
})