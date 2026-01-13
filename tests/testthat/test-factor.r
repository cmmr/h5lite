test_that("Factors work (ENUM)", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  f <- factor(c("a", "b", "a", "c"))
  m <- structure(f, dim = c(2, 2))
  h5_write(f, file, "f")
  h5_write(m, file, "m")
  
  expect_equal(h5_typeof(file, "f"), "enum")
  expect_equal(h5_typeof(file, "m"), "enum")
  expect_equal(h5_read(file, "f"), f)
  expect_equal(h5_read(file, "m"), m)
})

test_that("Factors with NA throw error", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  f <- factor(c("a", NA), levels = c("a", "b"))
  expect_error(h5_write(f, file, "f"), "Factors with NA values cannot be written")
})

test_that("Factor attributes work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(1, file, "dset")
  f <- factor("low", levels = c("low", "high"))
  h5_write(f, file, "dset", attr = "quality")
  
  expect_equal(h5_read(file, "dset", attr = "quality"), f)
})

test_that("Different magnitudes of levels", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  uids <- apply(expand.grid(letters, letters), 1L, paste0, collapse = '')
  
  h5_write(sm <- factor(uids[1:10], levels = uids[1:255]), file, 'enum_uint8')
  h5_write(md <- factor(uids[1:10], levels = uids[1:256]), file, 'enum_uint16')
  
  expect_equal(h5_read(file, "enum_uint8"),  sm)
  expect_equal(h5_read(file, "enum_uint16"), md)
})
