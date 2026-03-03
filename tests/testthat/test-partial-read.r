test_that("validate_start_count catches invalid inputs and scalars", {
  file <- tempfile(fileext = ".h5")
  v <- 1:10
  h5_write(v, file, "v")
  h5_write(1L, file, "v", attr = "my_attr")
  
  h5_write(I(1L), file, "scl")
  expect_equal(h5_read(file, "scl", start = 1, count = 1), 1L)
  
  # 1. XOR check (must provide both or neither)
  expect_error(h5_read(file, "v", start = 1), "must be used together")
  expect_error(h5_read(file, "v", count = 1), "must be used together")
  
  # 2. Attribute check
  expect_error(h5_read(file, "v", attr = "my_attr", start = 1, count = 1), 
               "cannot be used on attributes")
  
  # 3. Numeric checks
  expect_error(h5_read(file, "v", start = "a", count = 1), "must be numeric")
  expect_error(h5_read(file, "v", start = 1, count = "a"), "must be numeric")
  
  # 4. Length checks
  expect_error(h5_read(file, "v", start = numeric(0), count = 1), "empty vector")
  expect_error(h5_read(file, "v", start = 1, count = c(1, 2)), "single integer")
  
  # 5. Positivity checks
  expect_error(h5_read(file, "v", start = 0, count = 1), "must be positive")
  expect_error(h5_read(file, "v", start = c(1, -1), count = 1), "must be positive")
  expect_error(h5_read(file, "v", start = 1, count = 0), "must be positive")
  
  # 6. Bounds checks
  expect_error(h5_read(file, "v", start = 11, count = 1), "out of bounds")
  expect_error(h5_read(file, "v", start = c(2, 2), count = 1), "out of bounds") # 1D object
  expect_error(h5_read(file, "v", start = 8, count = 4), "out of bounds") # 8+4-1 = 11 > 10
  
  unlink(file)
})

test_that("partial reading works for 1D atomic vectors (with names)", {
  file <- tempfile(fileext = ".h5")
  
  # Setup Named Vectors
  v_int <- c(a=1L, b=2L, c=3L, d=4L, e=5L)
  v_dbl <- c(a=1.1, b=2.2, c=3.3, d=4.4, e=5.5)
  v_str <- c(a="apple", b="banana", c="cherry", d="date", e="elderberry")
  v_fct <- factor(c("low", "med", "high", "med", "low"), levels = c("low", "med", "high"))
  v_cpl <- c(1+1i, 2+2i, 3+3i, 4+4i, 5+5i)
  v_raw <- as.raw(1:5)
  names(v_fct) <- names(v_cpl) <- names(v_raw) <- letters[1:5]
  
  h5_write(v_int, file, "int")
  h5_write(v_dbl, file, "dbl")
  h5_write(v_str, file, "str")
  h5_write(v_fct, file, "fct")
  h5_write(v_cpl, file, "cpl")
  h5_write(v_raw, file, "raw")
  
  # Test Integer
  res <- h5_read(file, "int", start = 2, count = 3)
  expect_equal(res, c(b=2L, c=3L, d=4L))
  
  # Test Double
  res <- h5_read(file, "dbl", start = 4, count = 2)
  expect_equal(res, c(d=4.4, e=5.5))
  
  # Test String
  res <- h5_read(file, "str", start = 1, count = 2)
  expect_equal(res, c(a="apple", b="banana"))
  
  # Test Factor (Enums)
  res <- h5_read(file, "fct", start = 2, count = 3)
  expect_equal(as.character(res), c("med", "high", "med"))
  expect_equal(names(res), c("b", "c", "d"))
  expect_equal(levels(res), c("low", "med", "high"))
  
  # Test Complex
  res <- h5_read(file, "cpl", start = 3, count = 1)
  expect_equal(res, v_cpl[3])
  
  # Test Raw
  res <- h5_read(file, "raw", start = 2, count = 2)
  expect_equal(res, v_raw[2:3])
  expect_equal(names(res), c("b", "c"))
  
  unlink(file)
})

test_that("partial reading works for matrices (with dimnames)", {
  file <- tempfile(fileext = ".h5")
  
  # 5x4 matrix
  m <- matrix(1:20, nrow = 5, ncol = 4, 
              dimnames = list(paste0("r", 1:5), paste0("c", 1:4)))
  h5_write(m, file, "m")
  
  # 1. Shorthand rule: read 2 rows starting at row 3 (spanning all columns)
  res1 <- h5_read(file, "m", start = 3, count = 2)
  expect_equal(dim(res1), c(2, 4))
  expect_equal(rownames(res1), c("r3", "r4"))
  expect_equal(colnames(res1), c("c1", "c2", "c3", "c4"))
  expect_equal(res1[1, ], m[3, ]) # Row 3 data
  
  # 2. Specific block: start at row 2, col 3, read 2 columns
  res2 <- h5_read(file, "m", start = c(2, 3), count = 2)
  expect_equal(dim(res2), c(1, 2)) # R returns the sliced shape based on dims
  expect_equal(rownames(res2), "r2")
  expect_equal(colnames(res2), c("c3", "c4"))
  expect_equal(res2, m[2, 3:4, drop = FALSE])
  
  unlink(file)
})

test_that("partial reading works for data.frames (with row.names)", {
  file <- tempfile(fileext = ".h5")
  
  df <- data.frame(
    id = 1:5,
    val = c(1.1, 2.2, 3.3, 4.4, 5.5),
    name = c("a", "b", "c", "d", "e"),
    active = c(TRUE, FALSE, TRUE, FALSE, TRUE),
    cat = factor(c("A", "B", "A", "C", "B")),
    row.names = c("r1", "r2", "r3", "r4", "r5"),
    stringsAsFactors = FALSE
  )
  h5_write(df, file, "df")
  
  # Read a subset of 3 rows starting at row 2
  res <- h5_read(file, "df", start = 2, count = 3)
  
  # Verify structure and dimension
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 3)
  expect_equal(ncol(res), 5)
  
  # Verify row names correctly mapped the scale subset
  expect_equal(rownames(res), c("r2", "r3", "r4"))
  
  # Verify data integrity
  expect_equal(res$id, 2:4)
  expect_equal(res$val, c(2.2, 3.3, 4.4))
  expect_equal(res$name, c("b", "c", "d"))
  expect_equal(res$active, c(0, 1, 0))
  expect_equal(as.character(res$cat), c("B", "A", "C"))
  expect_equal(levels(res$cat), levels(df$cat)) # Enums should retain all global levels
  
  unlink(file)
})
