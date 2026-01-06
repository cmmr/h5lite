test_that("Lists (Groups) work recursively", {
  
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  lst <- list(
    a = 1:5,
    b = list(sub = "hello"),
    c = matrix(1:4, 2, 2)
  )
  attr(lst, "meta") <- "top_level"
  
  h5_write(lst, file, "lst")
  expect_true(h5_is_group(file, "lst"))
  expect_true(h5_is_group(file, "lst/b"))
  
  res <- h5_read(file, "lst")
  expect_equal(res$a, lst$a)
  expect_equal(res$b$sub, lst$b$sub)
  expect_equal(res$c, lst$c)
  expect_equal(attr(res, "meta"), "top_level")
})


test_that("Mappings apply per list element/attr", {
  
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  lst <- list(
    a = "alpha",
    b = bit64::as.integer64(10),
    c = data.frame(x = 1:5, y = letters[1:5]),
    d = NULL,
    e = 123,
    z = list(z1 = "omega")
  )
  attr(lst$a, "f") <- data.frame(i = 6:9, j = letters[6:9])
  attr(lst$a, "g") <- NA_integer_
  attr(lst$a, "h") <- 20L
  
  h5_write(lst, file, "lst", as = c('@integer' = "uint8", 'e' = "skip"))
  
  res <- h5_read(file, "lst", as = c('.int64' = "bit64"))
  lst$e <- NULL
  expect_equal(res, lst)
  
})
