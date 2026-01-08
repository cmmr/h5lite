test_that("Coercion on read", {
  
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(TRUE, file, "my_lgl")
  h5_write(2L,   file, "my_int")
  h5_write(3.0,  file, "my_dbl")
  h5_write(4L,   file, "my_big", as = "int64")
  h5_write(5L,   file, "obj")
  h5_write(6L,   file, "obj", "attr")
  
  expect_identical(h5_read(file, "my_lgl"), 1L)
  expect_identical(h5_read(file, "my_lgl", as = "integer"), 1L)
  expect_identical(h5_read(file, "my_lgl", as = "double"),  1.0)
  expect_identical(h5_read(file, "my_lgl", as = "logical"), TRUE)
  expect_identical(h5_read(file, "my_lgl", as = "null"),    NULL)
  expect_identical(h5_read(file, "my_lgl", as = c(my_lgl = "integer")), 1L)
  expect_identical(h5_read(file, "my_lgl", as = c(my_lgl = "auto")), 1L)
  
  expect_identical(h5_read(file, "my_int"), 2L)
  expect_identical(h5_read(file, "my_int", as = "integer"), 2L)
  expect_identical(h5_read(file, "my_int", as = "double"),  2.0)
  expect_identical(h5_read(file, "my_int", as = "logical"), TRUE)
  expect_identical(h5_read(file, "my_int", as = "null"),    NULL)
  expect_identical(h5_read(file, "my_int", as = c(my_int = "integer")), 2L)
  expect_identical(h5_read(file, "my_int", as = c(my_int = "auto")), 2L)
  
  expect_identical(h5_read(file, "my_dbl"), 3.0)
  expect_identical(h5_read(file, "my_dbl", as = "integer"), 3L)
  expect_identical(h5_read(file, "my_dbl", as = "double"),  3.0)
  expect_identical(h5_read(file, "my_dbl", as = "logical"), TRUE)
  expect_identical(h5_read(file, "my_dbl", as = "null"),    NULL)
  expect_identical(h5_read(file, "my_dbl", as = c(my_dbl = "integer")), 3L)
  expect_identical(h5_read(file, "my_dbl", as = c(my_dbl = "auto")), 3.0)
  
  expect_identical(h5_read(file, "my_big"), 4L)
  expect_identical(h5_read(file, "my_big", as = "integer"), 4L)
  expect_identical(h5_read(file, "my_big", as = "double"),  4.0)
  expect_identical(h5_read(file, "my_big", as = "logical"), TRUE)
  expect_identical(h5_read(file, "my_big", as = "null"),    NULL)
  expect_identical(h5_read(file, "my_big", as = c(my_big = "integer")), 4L)
  expect_identical(h5_read(file, "my_big", as = c(my_big = "auto")), 4L)
  
  expect_identical(h5_read(file, "my_lgl", as = c(my_lgl = "null")), NULL)
  expect_identical(h5_read(file, "my_lgl", as = c(.uint = "integer")), 1L)
  expect_identical(h5_read(file, "my_lgl", as = c(.     = "integer")), 1L)
  
  
  expect_identical(h5_read(file, "my_int", as = NULL), 2L)
  expect_error(h5_read(file, "my_int", as = 3))
  expect_error(h5_read(file, "my_int", as = structure("auto", names = '')))
  expect_error(h5_read(file, "my_int", as = "invalid"))
  expect_silent(h5_read(file, "obj", as = c('obj' = "integer")))
  
  
  skip_if_not_installed('bit64')
  b64 <- bit64::as.integer64(4L)
  expect_identical(h5_read(file, "my_big", as = "bit64"), b64)
  expect_identical(h5_read(file, "my_big", as = c(my_big = "bit64")), b64)
})


test_that("Coercion on write", {
  
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  expect_error(h5_write(TRUE, file, "my_lgl", as = c("int", "uint")))
  #expect_error(h5_write(data.frame(x = integer(0)), file, "df"))
  expect_error(h5_write(NA_integer_, file, "NA_vals", as = "int8"))
  expect_error(h5_write(Inf, file, "Inf_vals", as = "int8"))
  suppressWarnings(expect_warning(h5_write(I(1:3), file, "non-scalar")))
  
  h5_write(Sys.time(), file, 'now')
  h5_write(data.frame(x=1:5, y=6:10), file, "df", as = c(x = "skip"))
  h5_write(integer(0), file, "zerolen", as = "float16")
  h5_write(integer(0), file, "zerolen", as = "bfloat16")
  
  lst <- list(vec = 1:5, nil = NULL)
  attr(lst$vec, 'attr_lst') <- list(z = 1)
  attr(lst$vec, 'a') <- as.raw(1)
  attr(lst$vec, 'b') <- 2.0
  attr(lst$vec, 'c') <- TRUE
  attr(lst$vec, 'd') <- data.frame(x=1:3)
  h5_write(lst, file, "lst", 
           as = c('@.' = "auto", '@.integer' = "int64", '@c' = "uint8", '@raw' = "skip"))
  
})

