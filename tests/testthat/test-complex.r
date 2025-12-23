test_that("Complex scalars and vectors work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  vec <- c(1+2i, 3+4i)
  h5_write(vec, file, "vec")
  expect_equal(h5_typeof(file, "vec"), "complex")
  expect_equal(h5_read(file, "vec"), vec)
  
  h5_write(I(1+1i), file, "scalar")
  expect_equal(h5_read(file, "scalar"), 1+1i)
})

test_that("Complex matrices work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  mat <- matrix(c(1i, 2i, 3i, 4i), 2, 2)
  h5_write(mat, file, "mat")
  expect_equal(h5_read(file, "mat"), mat)
})

test_that("Complex attributes work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(1, file, "dset")
  h5_write(0+1i, file, "dset", attr = "imag")
  expect_equal(h5_read(file, "dset", attr = "imag"), 0+1i)
})
