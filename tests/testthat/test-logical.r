test_that("Logical scalars and vectors work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))

  # 1. Vector
  vec <- c(TRUE, FALSE, TRUE)
  h5_write(vec, file, "vec")
  
  # Default read is integer (0/1)
  expect_equal(h5_read(file, "vec"), c(1, 0, 1))
  # Explicit read as logical
  expect_equal(h5_read(file, "vec", as = "logical"), vec)
  
  # 2. Scalar
  h5_write(TRUE, file, "scalar")
  expect_equal(h5_read(file, "scalar", as = "logical"), TRUE)
})

test_that("Logical matrices work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  mat <- matrix(c(TRUE, FALSE, FALSE, TRUE), 2, 2)
  h5_write(mat, file, "matrix")
  expect_equal(h5_read(file, "matrix", as = "logical"), mat)
})

test_that("Logical attributes work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(1, file, "dset")
  h5_write(TRUE, file, "dset", attr = "is_valid")
  expect_equal(h5_read(file, "dset", attr = "is_valid", as = "logical"), TRUE)
})

test_that("NAs in logicals are handled", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  # Logical NAs are integer NA_integer_ internally in R, so h5lite sees int NA
  # It promotes to float to store NaN unless we force integer/logical
  vec <- c(TRUE, NA, FALSE)
  
  # Default write (auto) -> Promotes to float because of NA
  h5_write(vec, file, "auto")
  expect_true(startsWith(h5_typeof(file, "auto"), "float"))
  expect_equal(h5_read(file, "auto", as = "logical"), vec)
})
