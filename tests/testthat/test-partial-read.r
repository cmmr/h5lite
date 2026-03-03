test_that("validate_start_count handles missing count correctly", {
  file <- tempfile(fileext = ".h5")
  v <- 1:10
  h5_write(v, file, "v")
  h5_write(1L, file, "v", attr = "my_attr")
  
  # 1. Start is provided, count is NULL (Valid exact index)
  expect_silent(h5_read(file, "v", start = 1))
  
  # 2. Count is provided, start is NULL (Invalid)
  expect_error(h5_read(file, "v", count = 1), "must be provided if `count` is specified")
  
  # 3. Attribute check
  expect_error(h5_read(file, "v", attr = "my_attr", start = 1), 
               "cannot be used on attributes")
  
  # 4. Numeric checks
  expect_error(h5_read(file, "v", start = "a"), "must be numeric")
  expect_error(h5_read(file, "v", start = 1, count = "a"), "must be numeric")
  
  # 5. Positivity checks
  expect_error(h5_read(file, "v", start = 0), "must be positive")
  expect_error(h5_read(file, "v", start = c(1, -1)), "must be positive")
  expect_error(h5_read(file, "v", start = 1, count = 0), "must be positive")
  
  # 6. Bounds checks
  expect_error(h5_read(file, "v", start = 11), "out of bounds")
  expect_error(h5_read(file, "v", start = 10, count = 2), "out of bounds")
  
  # 7. Other errors
  expect_error(h5_read(file, "v", start = numeric(0)), "cannot be an empty vector")
  expect_error(h5_read(file, "v", start = 1, count = 1:2), "must be a single numeric value")
  expect_error(h5_read(file, "v", start = 1, count = numeric(0)), "must be a single numeric value")
  expect_error(h5_read(file, "v", start = 1:2), "more dimensions than the dataset")
  
  unlink(file)
})

test_that("partial reading works for 1D atomic vectors (with naming logic)", {
  file <- tempfile(fileext = ".h5")
  
  # Scalar
  h5_write(I(42), file, "scl")
  
  res0 <- h5_read(file, "scl", start = 1)
  expect_equal(res0, 42)
  
  res0 <- h5_read(file, "scl", start = 1, count = 1)
  expect_equal(res0, 42)
  
  # Setup Named Vector
  v_int <- c(a=1L, b=2L, c=3L, d=4L, e=5L)
  h5_write(v_int, file, "int")
  
  # 1. Range Indexing (count > 1)
  res1 <- h5_read(file, "int", start = 2, count = 3)
  expect_equal(res1, c(b=2L, c=3L, d=4L))
  
  # 2. Range Indexing of 1 (count = 1) -> retains name
  res2 <- h5_read(file, "int", start = 3, count = 1)
  expect_equal(res2, c(c=3L))
  
  # 3. Exact Point Indexing (count = NULL) -> strips name
  res3 <- h5_read(file, "int", start = 3)
  expect_equal(res3, 3L)
  expect_null(names(res3))
  
  unlink(file)
})

test_that("partial reading works for matrices (with dimension dropping)", {
  file <- tempfile(fileext = ".h5")
  
  # 5x4 matrix
  m <- matrix(1:20, nrow = 5, ncol = 4, 
              dimnames = list(paste0("r", 1:5), paste0("c", 1:4)))
  h5_write(m, file, "m")
  
  # 1. Range Indexing (rows)
  res1 <- h5_read(file, "m", start = 3, count = 2)
  expect_equal(dim(res1), c(2, 4))
  expect_equal(rownames(res1), c("r3", "r4"))
  expect_equal(colnames(res1), c("c1", "c2", "c3", "c4"))
  
  # 2. Exact Indexing (row) -> drops matrix to vector, inherits column names
  res2 <- h5_read(file, "m", start = 3)
  expect_null(dim(res2))
  expect_equal(names(res2), c("c1", "c2", "c3", "c4"))
  expect_equal(res2, m[3, ])
  
  # 3. Range Indexing of 1 (row) -> preserves 1xN matrix, inherits row name
  res3 <- h5_read(file, "m", start = 3, count = 1)
  expect_equal(dim(res3), c(1, 4))
  expect_equal(rownames(res3), "r3")
  expect_equal(colnames(res3), c("c1", "c2", "c3", "c4"))
  
  # 4. Multi-value Exact+Range (row exactly, cols range) -> drops row, named vector
  res4 <- h5_read(file, "m", start = c(3, 2), count = 2)
  expect_null(dim(res4))
  expect_equal(names(res4), c("c2", "c3"))
  expect_equal(res4, m[3, 2:3])
  
  # 5. Multi-value Exact (row exactly, col exactly) -> fully unnamed scalar
  res5 <- h5_read(file, "m", start = c(3, 2))
  expect_null(dim(res5))
  expect_null(names(res5))
  expect_equal(res5, m[3, 2][[1]])
  
  unlink(file)
})

test_that("partial reading works for data.frames (no dropping allowed)", {
  file <- tempfile(fileext = ".h5")
  
  df <- data.frame(
    id = 1:5,
    val = c(1.1, 2.2, 3.3, 4.4, 5.5),
    name = c("a", "b", "c", "d", "e"),
    row.names = c("r1", "r2", "r3", "r4", "r5"),
    stringsAsFactors = FALSE
  )
  h5_write(df, file, "df")
  
  # 1. Range Indexing
  res1 <- h5_read(file, "df", start = 2, count = 3)
  expect_s3_class(res1, "data.frame")
  expect_equal(nrow(res1), 3)
  expect_equal(rownames(res1), c("r2", "r3", "r4"))
  
  # 2. Exact Indexing (count = NULL) -> Data Frames should never drop!
  res2 <- h5_read(file, "df", start = 2)
  expect_s3_class(res2, "data.frame")
  expect_equal(nrow(res2), 1)
  expect_equal(rownames(res2), "r2")
  expect_equal(res2$val, 2.2)
  
  unlink(file)
})

test_that("partial reading works for named N-dimensional arrays", {
  file <- tempfile(fileext = ".h5")
  
  # Create a 2x3x4x5 array (Rows=2, Cols=3, 3rd=4, 4th=5)
  arr4 <- array(
    data     = 1:120,
    dim      = c(2, 3, 4, 5), 
    dimnames = list(LETTERS[1:2], LETTERS[3:5], LETTERS[6:9], LETTERS[10:14]) )
  h5_write(arr4, file, "arr4")
  
  # 1. Target 4th=2, 3rd=3, Row=1. Read 2 rows (count=2).
  # Exact point indices: 4th, 3rd. (Dropped)
  # Range target: Rows. (Preserved)
  # Untargeted: Cols. (Preserved)
  # Result: 2x3 matrix
  res1 <- h5_read(file, "arr4", start = c(2, 3, 1), count = 2)
  expect_equal(dim(res1), c(2, 3))
  expect_equal(res1, arr4[1:2,, 3, 2, drop=TRUE])
  
  # 2. Exact index deep down: Target 4th=2, 3rd=3, Row=2, Col=1. (count=NULL)
  # Drops all dimensions -> scalar
  res2 <- h5_read(file, "arr4", start = c(2, 3, 2, 1))
  expect_null(dim(res2))
  expect_equal(res2, arr4[2, 1, 3, 2])
  
  # 3. Same target as above, but Range index (count=1).
  # Drops 4th, 3rd, Rows. Preserves Cols.
  # Result: 1D vector of length 1
  res3 <- h5_read(file, "arr4", start = c(2, 3, 2, 1), count = 1)
  expect_equal(length(res3), 1)
  expect_equal(names(res3), 'C')
  expect_equal(unname(res3), arr4[2, 1, 3, 2])
  
  unlink(file)
})

test_that("partial reading works for unnamed N-dimensional arrays", {
  file <- tempfile(fileext = ".h5")
  
  # Create a 2x3x4x5 array (Rows=2, Cols=3, 3rd=4, 4th=5)
  arr4 <- array(data = 1:120, dim = c(2, 3, 4, 5))
  h5_write(arr4, file, "arr4")
  
  # 1. Target 4th=2, 3rd=3, Row=1. Read 2 rows (count=2).
  # Exact point indices: 4th, 3rd. (Dropped)
  # Range target: Rows. (Preserved)
  # Untargeted: Cols. (Preserved)
  # Result: 2x3 matrix
  res1 <- h5_read(file, "arr4", start = c(2, 3, 1), count = 2)
  expect_equal(dim(res1), c(2, 3))
  expect_equal(res1, arr4[1:2,, 3, 2, drop=TRUE])
  
  # 2. Exact index deep down: Target 4th=2, 3rd=3, Row=2, Col=1. (count=NULL)
  # Drops all dimensions -> scalar
  res2 <- h5_read(file, "arr4", start = c(2, 3, 2, 1))
  expect_null(dim(res2))
  expect_equal(res2, arr4[2, 1, 3, 2])
  
  # 3. Same target as above, but Range index (count=1).
  # Drops 4th, 3rd, Rows. Preserves Cols.
  # Result: 1D vector of length 1
  res3 <- h5_read(file, "arr4", start = c(2, 3, 2, 1), count = 1)
  expect_equal(length(res3), 1)
  expect_equal(names(res3), NULL)
  expect_equal(res3, arr4[2, 1, 3, 2])
  
  unlink(file)
})
