test_that("Raw scalars and vectors work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  vec <- as.raw(c(0x00, 0xFF, 0x1A))
  
  h5_write(vec, file, "vec")
  expect_equal(h5_read(file, "vec"), vec)
  expect_equal(h5_typeof(file, "vec"), "opaque")
  
  h5_write(vec, file, "vec", "attr")
  expect_equal(h5_typeof(file, "vec", "attr"), "opaque")
  expect_equal(h5_read(file, "vec", "attr"), vec)
})

test_that("Raw matrices work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  mat <- matrix(as.raw(1:4), 2, 2)
  h5_write(mat, file, "mat")
  expect_equal(h5_read(file, "mat"), mat)
})
