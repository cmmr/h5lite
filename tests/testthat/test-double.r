test_that("Double scalars and vectors work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  vec <- c(1.1, 2.2, 3.3)
  h5_write(vec, file, "vec")
  expect_equal(h5_read(file, "vec"), vec)
  
  h5_write(pi, file, "scalar")
  expect_equal(h5_read(file, "scalar"), pi)
})

test_that("Special values (NA, NaN, Inf) work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  vec <- c(1.0, NA_real_, NaN, Inf, -Inf)
  h5_write(vec, file, "special")
  
  res <- h5_read(file, "special")
  expect_equal(res[1], 1.0)
  expect_true(is.na(res[2]))
  expect_true(is.nan(res[3]))
  expect_equal(res[4], Inf)
  expect_equal(res[5], -Inf)
})

test_that("Double matrices work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  mat <- matrix(rnorm(9), 3, 3)
  h5_write(mat, file, "matrix")
  expect_equal(h5_read(file, "matrix"), mat)
})

test_that("Double attributes work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(1, file, "dset")
  h5_write(1.23, file, "dset", attr = "p_val")
  expect_equal(h5_read(file, "dset", attr = "p_val"), 1.23)
})

test_that("Precision control (float32)", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  val <- 1.123456789
  # Write as 32-bit float
  h5_write(val, file, "f32", as = "float32")
  expect_equal(h5_typeof(file, "f32"), "float32")
  
  # Precision should be lost
  read_val <- h5_read(file, "f32")
  expect_false(read_val == val)
  expect_equal(read_val, val, tolerance = 1e-7)
})
