library(testthat)
library(h5lite)

# --- Test Setup ---
# A standard data.frame with various types
df_standard <- data.frame(
  col_double = c(1.1, 2.2, 3.3),
  col_int = 1:3,
  col_char = c("apple", "banana", "cherry"),
  col_factor = factor(c("X", "Y", "X")),
  col_logical = c(TRUE, FALSE, TRUE),
  stringsAsFactors = FALSE
)

# Edge case data.frames
df_zero_row <- df_standard[0, ]
df_zero_col <- data.frame(row.names = 1:3)
df_zero_all <- data.frame()


test_that("data.frame as dataset: basic round-trip works", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  h5_write(file_path, "df_standard", df_standard)
  df_read <- h5_read(file_path, "df_standard")

  expect_s3_class(df_read, "data.frame")
  # Logicals and integers are read back as doubles, which is expected for safety.
  # We compare after converting the column to numeric.
  df_standard_cmp <- df_standard
  df_standard_cmp$col_logical <- as.numeric(df_standard_cmp$col_logical) # TRUE -> 1, FALSE -> 0
  expect_equal(df_read, df_standard_cmp)
})

test_that("data.frame as dataset: round-trip with attributes works", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  df_with_attrs <- df_standard
  attr(df_with_attrs, "my_attr") <- "some metadata"
  attr(df_with_attrs, "version") <- 1.2

  h5_write(file_path, "df_with_attrs", df_with_attrs, attrs = TRUE)
  df_read <- h5_read(file_path, "df_with_attrs", attrs = TRUE)

  # Convert logical and integer columns to double for comparison
  df_with_attrs$col_logical <- as.numeric(df_with_attrs$col_logical) 
  expect_equal(df_read, df_with_attrs)
})

test_that("data.frame as dataset: edge cases (zero rows/cols) work", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- Zero Rows ---
  h5_write(file_path, "df_zero_row", df_zero_row)
  df_read_zero_row <- h5_read(file_path, "df_zero_row")
  expect_s3_class(df_read_zero_row, "data.frame")
  expect_equal(nrow(df_read_zero_row), 0)
  expect_equal(sort(names(df_read_zero_row)), sort(names(df_zero_row)))

  # --- Zero Columns ---
  # Writing a 0-col data.frame should throw an error
  expect_error(
    h5_write(file_path, "df_zero_col", df_zero_col),
    "Cannot write a data.frame with zero columns to HDF5.",
    fixed = TRUE
  )

  # --- Zero Rows and Columns ---
  # This should also throw an error because it has zero columns
  expect_error(
    h5_write(file_path, "df_zero_all", df_zero_all),
    "Cannot write a data.frame with zero columns to HDF5.",
    fixed = TRUE
  )
})

test_that("data.frame as attribute: round-trip works", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # Create a dummy dataset to attach the attribute to
  h5_write(file_path, "my_data", 1)

  # --- Standard data.frame attribute ---
  h5_write_attr(file_path, "my_data", "df_attr", df_standard)
  df_attr_read <- h5_read_attr(file_path, "my_data", "df_attr")

  df_standard_cmp <- df_standard
  df_standard_cmp$col_logical <- as.numeric(df_standard_cmp$col_logical) # Convert for comparison
  expect_equal(df_attr_read, df_standard_cmp)

  # --- Zero-row data.frame attribute ---
  h5_write_attr(file_path, "my_data", "df_zero_row_attr", df_zero_row)
  df_zero_row_attr_read <- h5_read_attr(file_path, "my_data", "df_zero_row_attr")
  expect_s3_class(df_zero_row_attr_read, "data.frame")
  expect_equal(nrow(df_zero_row_attr_read), 0)
  expect_equal(sort(names(df_zero_row_attr_read)), sort(names(df_zero_row)))

  # --- Zero-column data.frame attribute ---
  # Writing a 0-col df as an attribute should throw an error
  expect_error(
    h5_write_attr(file_path, "my_data", "df_zero_col_attr", df_zero_col),
    "Cannot write a data.frame with zero columns as an HDF5 attribute.",
    fixed = TRUE
  )
})
