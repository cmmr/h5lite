test_that("Data frames work (Compound)", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  df <- data.frame(
    int = 1:3,
    dbl = c(1.1, 2.2, 3.3),
    chr = c("a", "b", NA),
    fac = factor(c("a", "b", "c")),
    cpx = c(1+1i, 1+2i, 3+4i),
    raw = as.raw(1:3),
    cnv = c(1:2, NA_integer_),
    lgl = c(TRUE, FALSE, TRUE),
    skp = 1:3,
    stringsAsFactors = FALSE
  )
  
  rownames(df) <- LETTERS[1:3]
  
  
  # As a dataset ---------------------------------
  
  h5_write(df, file, "df", as = c('skp' = "skip"))
  expect_equal(h5_class(file, "df"), "data.frame")
  expect_equal(h5_typeof(file, "df"), "compound")
  
  res <- h5_read(file, "df")
  expect_null(res$skp)
  expect_equal(res$int, df$int)
  expect_equal(res$dbl, df$dbl)
  expect_equal(res$chr, df$chr)
  expect_equal(res$fac, df$fac)
  expect_equal(res$cpx, df$cpx)
  expect_equal(res$raw, df$raw)
  expect_equal(res$lgl, c(1, 0, 1))       # Default int
  expect_equal(res$cnv, c(1:2, NA_real_)) # Default float
  expect_equal(rownames(res), rownames(df))
  
  # Read with mapping
  res2 <- h5_read(file, "df", as = c("lgl" = "logical"))
  expect_equal(res2$lgl, df$lgl)
  
  
  # As an attribute (drops rownames) -------------
  
  h5_write(df, file, "df", "attr")
  expect_equal(h5_class(file, "df", "attr"), "data.frame")
  expect_equal(h5_typeof(file, "df", "attr"), "compound")
  
  res <- h5_read(file, "df", "attr")
  expect_equal(res$int, df$int)
  expect_equal(res$dbl, df$dbl)
  expect_equal(res$chr, df$chr)
  expect_equal(res$fac, df$fac)
  expect_equal(res$cpx, df$cpx)
  expect_equal(res$raw, df$raw)
  expect_equal(res$lgl, c(1, 0, 1))       # Default int
  expect_equal(res$cnv, c(1:2, NA_real_)) # Default float
  
  # Read with mapping
  res2 <- h5_read(file, "df", as = c("lgl" = "logical"))
  expect_equal(res2$lgl, df$lgl)
  
  # Zero columns = error
  no_cols <- mtcars[,integer(0),drop = FALSE]
  expect_error(h5_write(no_cols, file, "no_cols"))
})

test_that("Data frame columns with POSIXt are converted", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  now <- Sys.time()
  df <- data.frame(id = 1, time = now)
  h5_write(df, file, "df")
  
  res <- h5_read(file, "df")
  expect_true(is.character(res$time))
  expect_equal(res$time, format(now, format = "%Y-%m-%dT%H:%M:%OSZ"))
})
