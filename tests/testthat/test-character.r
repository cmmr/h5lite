test_that("Character scalars work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(I("hello"), file, "scalar")
  expect_equal(h5_read(file, "scalar"), "hello")
  
  h5_write(I("hello"), file, "scalar", as = "ascii")
  expect_equal(h5_read(file, "scalar"), "hello")
  
  h5_write(I("hello"), file, "scalar", as = "utf")
  expect_equal(h5_read(file, "scalar"), "hello")
  
  h5_write(I("hello"), file, "scalar", as = "ascii[]")
  expect_equal(h5_read(file, "scalar"), "hello")
  
  h5_write(I("hello"), file, "scalar", as = "utf[]")
  expect_equal(h5_read(file, "scalar"), "hello")
  
  h5_write(I("hello"), file, "scalar", as = "ascii[10]")
  expect_equal(h5_read(file, "scalar"), "hello")
  
  h5_write(I("hello"), file, "scalar", as = "utf[10]")
  expect_equal(h5_read(file, "scalar"), "hello")
})


test_that("Character vectors work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  vec <- c("apple", "banana", "cherry")
  
  h5_write(vec, file, "vec")
  expect_equal(h5_read(file, "vec"), vec)
  
  h5_write(vec, file, "vec", as = "ascii")
  expect_equal(h5_read(file, "vec"), vec)
  
  h5_write(vec, file, "vec", as = "utf")
  expect_equal(h5_read(file, "vec"), vec)
  
  h5_write(vec, file, "vec", as = "ascii[]")
  expect_equal(h5_read(file, "vec"), vec)
  
  h5_write(vec, file, "vec", as = "utf[]")
  expect_equal(h5_read(file, "vec"), vec)
  
  h5_write(vec, file, "vec", as = "ascii[10]")
  expect_equal(h5_read(file, "vec"), vec)
  
  h5_write(vec, file, "vec", as = "utf[10]")
  expect_equal(h5_read(file, "vec"), vec)
})


test_that("Character matrices work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  mat <- matrix(letters[1:4], 2, 2)
  
  h5_write(mat, file, "matrix")
  expect_equal(h5_read(file, "matrix"), mat)
  
  h5_write(mat, file, "matrix", as = "ascii")
  expect_equal(h5_read(file, "matrix"), mat)
  
  h5_write(mat, file, "matrix", as = "ascii[]")
  expect_equal(h5_read(file, "matrix"), mat)
  
  h5_write(mat, file, "matrix", as = "ascii[5]")
  expect_equal(h5_read(file, "matrix"), mat)
  
  h5_write(mat, file, "matrix", as = "utf8")
  expect_equal(h5_read(file, "matrix"), mat)
  
  h5_write(mat, file, "matrix", as = "utf8[]")
  expect_equal(h5_read(file, "matrix"), mat)
  
  h5_write(mat, file, "matrix", as = "utf8[5]")
  expect_equal(h5_read(file, "matrix"), mat)
})


test_that("Character attributes work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(1, file, "dset")
  
  h5_write("metadata", file, "dset", attr = "info")
  expect_equal(h5_read(file, "dset", attr = "info"), "metadata")
  
  h5_write("metadata", file, "dset", attr = "info", as = "utf8")
  expect_equal(h5_read(file, "dset", attr = "info"), "metadata")
  
  h5_write("metadata", file, "dset", attr = "info", as = "utf8[]")
  expect_equal(h5_read(file, "dset", attr = "info"), "metadata")
  
  h5_write("metadata", file, "dset", attr = "info", as = "utf8[10]")
  expect_equal(h5_read(file, "dset", attr = "info"), "metadata")
  
  h5_write("metadata", file, "dset", attr = "info", as = "ascii")
  expect_equal(h5_read(file, "dset", attr = "info"), "metadata")
  
  h5_write("metadata", file, "dset", attr = "info", as = "ascii[]")
  expect_equal(h5_read(file, "dset", attr = "info"), "metadata")
  
  h5_write("metadata", file, "dset", attr = "info", as = "ascii[10]")
  expect_equal(h5_read(file, "dset", attr = "info"), "metadata")
})

test_that("UTF-8 characters are preserved", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  utf8_str  <- "Zürich"
  ascii_str <- "Zurich"
  
  h5_write(utf8_str, file, "city")
  expect_equal(h5_read(file, "city"), utf8_str)
  
  h5_write(utf8_str, file, "city", as = "utf8")
  expect_equal(h5_read(file, "city"), utf8_str)
  
  h5_write(utf8_str, file, "city", as = "utf8[]")
  expect_equal(h5_read(file, "city"), utf8_str)
  
  h5_write(utf8_str, file, "city", as = "utf8[20]")
  expect_equal(h5_read(file, "city"), utf8_str)
  
  h5_write(utf8_str, file, "city", as = 'ascii')
  expect_equal(h5_read(file, "city"), ascii_str)
  
  h5_write(utf8_str, file, "city", as = 'ascii[]')
  expect_equal(h5_read(file, "city"), ascii_str)
  
  h5_write(utf8_str, file, "city", as = 'ascii[20]')
  expect_equal(h5_read(file, "city"), ascii_str)
})

test_that("Character errors work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  expect_error(h5_write('A',        file, "x", as = 'invalid'))
  expect_error(h5_write(c('A', NA), file, "x", as = 'utf[]'))
  expect_error(h5_write(c('A', NA), file, "x", as = 'utf[10]'))
  expect_error(h5_write(c('A', NA), file, "x", as = 'ascii[]'))
  expect_error(h5_write(c('A', NA), file, "x", as = 'ascii[10]'))
})
