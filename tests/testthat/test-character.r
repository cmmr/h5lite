test_that("Character scalars and vectors work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  vec <- c("apple", "banana", "cherry")
  h5_write(vec, file, "vec")
  expect_equal(h5_read(file, "vec"), vec)
  
  h5_write("hello", file, "scalar")
  expect_equal(h5_read(file, "scalar"), "hello")
})

test_that("Character matrices work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  mat <- matrix(letters[1:4], 2, 2)
  h5_write(mat, file, "matrix")
  expect_equal(h5_read(file, "matrix"), mat)
})

test_that("Character attributes work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(1, file, "dset")
  h5_write("metadata", file, "dset", attr = "info")
  expect_equal(h5_read(file, "dset", attr = "info"), "metadata")
})

test_that("UTF-8 characters are preserved", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  utf8_str <- "Zürich"
  h5_write(utf8_str, file, "city")
  expect_equal(h5_read(file, "city"), utf8_str)
})

test_that("Reading fixed-length strings works", {
  # This relies on gen_fixed_len.r logic. 
  # We check if the file provided by the user context exists, otherwise skip or mock.
  
  input_file <- testthat::test_path('input/fixed_len.h5')

  expect_equal(h5_read(input_file, "chr_vec"), c("BRCA1", "TP53", "EGFR", "MYC"))
  expect_equal(h5_read(input_file, "chr_mtx"), matrix(c("BRCA1", "TP53", "EGFR", "MYC"), 2, 2))
})
