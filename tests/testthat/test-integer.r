test_that("Integer scalars and vectors work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  # 1. Simple Integer Vector
  vec <- 1:10
  h5_write(vec, file, "vec")
  expect_equal(h5_read(file, "vec"), vec)
  expect_equal(h5_class(file, "vec"), "numeric") # Stored as integer, read as numeric by default
  expect_equal(h5_read(file, "vec", as = "integer"), vec)

  # 2. Integer Scalar (1D array of length 1)
  h5_write(42L, file, "scalar")
  expect_equal(h5_read(file, "scalar"), 42L)
  
  # 3. Explicit Scalar (I(x))
  h5_write(I(42L), file, "scalar_I")
  expect_equal(h5_dim(file, "scalar_I"), integer(0)) # Rank 0
  expect_equal(h5_read(file, "scalar_I"), 42L)

  # 4. Integers with NA (Auto-promoted to float to store NaN)
  vec_na <- c(1L, NA_integer_, 3L)
  h5_write(vec_na, file, "vec_na")
  expect_true(startsWith(h5_typeof(file, "vec_na"), "float")) # Promoted
  read_back <- h5_read(file, "vec_na")
  expect_true(is.double(read_back))
  expect_true(is.nan(read_back[2]))
  
  # 5. Named vector
  vec_named <- structure(c(1:5), names = letters[1:5])
  h5_write(vec_named, file, "vec_named")
  expect_equal(h5_read(file, "vec_named"), vec_named)
  expect_equal(h5_names(file, "vec_named"), letters[1:5])
  
  # Force read back as integer (NaN becomes NA_integer_)
  expect_equal(h5_read(file, "vec_na", as = "integer"), vec_na)
})

test_that("Integer matrices and arrays work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  mat <- matrix(1:9, nrow = 3)
  h5_write(mat, file, "mat")
  expect_equal(h5_read(file, "mat"), mat)
  expect_equal(h5_dim(file, "mat"), c(3, 3))
  expect_equal(h5_names(file, "mat"), character(0))
  expect_equal(h5_length(file, "mat"), 9L)
  
  mat_named <- matrix(1:9, nrow = 3, dimnames = list(letters[1:3], LETTERS[1:3]))
  h5_write(mat_named, file, "mat_named")
  expect_equal(h5_read(file, "mat_named"), mat_named)
  expect_equal(h5_names(file, "mat_named"), LETTERS[1:3])
  
  mat_rownm <- matrix(1:9, nrow = 3, dimnames = list(letters[1:3], NULL))
  h5_write(mat_rownm, file, "mat_rownm")
  expect_equal(h5_read(file, "mat_rownm"), mat_rownm)
  expect_equal(h5_names(file, "mat_rownm"), character(0))
  
  mat_colnm <- matrix(1:9, nrow = 3, dimnames = list(NULL, LETTERS[1:3]))
  h5_write(mat_colnm, file, "mat_colnm")
  expect_equal(h5_read(file, "mat_colnm"), mat_colnm)
  expect_equal(h5_names(file, "mat_colnm"), LETTERS[1:3])
  
  arr3d <- array(
    data = 1:24, 
    dim = c(2,3,4), 
    dimnames = list(LETTERS[1:2], LETTERS[3:5], LETTERS[7:10]) )
  
  h5_write(arr3d, file, "arr3d")
  expect_equal(h5_read(file, "arr3d"), arr3d)
  expect_equal(h5_dim(file, "arr3d"), c(2,3,4) )
  expect_equal(h5_names(file, "arr3d"), LETTERS[3:5])
  expect_equal(h5_length(file, "arr3d"), prod(c(2,3,4)))
})

test_that("Integer attributes work", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(1:5, file, "data")
  h5_write(100L, file, "data", attr = "meta")
  
  expect_equal(h5_read(file, "data", attr = "meta", as = "integer"), 100L)
  
  expect_null(h5_delete(file, "data", attr = "meta"))
  expect_null(h5_delete(file, "data"))
  expect_error(h5_write(1:5, file, "data", attr = "meta"))
})

test_that("Specific integer types (int8-int64) can be forced", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  val <- c(-100L, 100L)
  
  h5_write(val, file, "i8", as = "int8")
  expect_equal(h5_typeof(file, "i8"), "int8")
  expect_equal(h5_read(file, "i8", as = "integer"), val)

  # Can't write -100 to a uint
  expect_error(h5_write(val, file, "u8", as = "uint8"))
})

test_that("Auto-selection of int size edge cases", {
  
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(as.integer(c(0, 0)),         file, 'uint8_lo')
  h5_write(as.integer(c(0, 2^8 - 1)),   file, 'uint8_hi')
  h5_write(as.integer(c(0, 2^8)),       file, 'uint16_lo')
  h5_write(as.integer(c(0, 2^16 - 1)),  file, 'uint16_hi')
  h5_write(as.integer(c(0, 2^16)),      file, 'uint32_lo')
  h5_write(as.integer(c(-1, -2^7)),     file, 'int8_lo')
  h5_write(as.integer(c(-1, 2^7 - 1)),  file, 'int8_hi')
  h5_write(as.integer(c(-1, -2^15)),    file, 'int16_lo')
  h5_write(as.integer(c(-1, 2^15 - 1)), file, 'int16_hi')
  h5_write(as.integer(c(-1, 2^15)),     file, 'int32_lo')
  
  expect_equal(h5_typeof(file, "uint8_lo"),  "uint8")
  expect_equal(h5_typeof(file, "uint8_hi"),  "uint8")
  expect_equal(h5_typeof(file, "uint16_lo"), "uint16")
  expect_equal(h5_typeof(file, "uint16_hi"), "uint16")
  expect_equal(h5_typeof(file, "uint32_lo"), "uint32")
  expect_equal(h5_typeof(file, "int8_lo"),   "int8")
  expect_equal(h5_typeof(file, "int8_hi"),   "int8")
  expect_equal(h5_typeof(file, "int16_lo"),  "int16")
  expect_equal(h5_typeof(file, "int16_hi"),  "int16")
  expect_equal(h5_typeof(file, "int32_lo"),  "int32")
})

test_that("Compression", {
  
  file_compressed   <- tempfile(fileext = ".h5")
  file_uncompressed <- tempfile(fileext = ".h5")
  on.exit(unlink(c(file_compressed, file_uncompressed)))
  
  vec <- rep(1L, 10000000)
  h5_write(vec, file_compressed,   "vec", compress = TRUE)
  h5_write(vec, file_uncompressed, "vec", compress = FALSE)
  expect_lt(file.size(file_compressed), file.size(file_uncompressed))
  
  
  mtx <- matrix(vec, nrow = 100)
  h5_write(mtx, file_compressed, "mtx", compress = TRUE)
  expect_equal(h5_read(file_compressed, "mtx"), mtx)
  
})



