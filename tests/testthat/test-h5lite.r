library(testthat)
library(h5lite)

test_that("Full read/write/list/info cycle works", {
  
  # --- 1. SETUP ---
  
  file_path <- tempfile(fileext = ".h5")
  # Ensure cleanup even if tests fail
  on.exit(unlink(file_path), add = TRUE)
  
  # Define all R objects we will write
  d_vec_double <- c(1.5, 2.2, 3.3)
  d_vec_int <- 1L:10L
  d_vec_logical <- c(TRUE, FALSE, TRUE)
  d_vec_char <- c("hello", "world", "h5lite")
  d_vec_raw <- as.raw(c(0x01, 0x10, 0xFF)) # New
  
  d_mat_double <- matrix(1:12, nrow = 3, ncol = 4)
  d_arr_int <- array(1L:24L, dim = c(2, 3, 4))
  d_mat_raw <- matrix(as.raw(1:12), nrow = 3, ncol = 4) # New
  
  d_scalar_char <- "I am a scalar"
  d_scalar_int <- 42L
  
  # New types for non-R dtypes
  d_vec_float <- c(1.123456789, 2.222222222, 3.333333333)
  d_vec_schar <- c(-10L, 20L, 30L) # Signed char
  d_vec_short <- c(500L, -1000L, 30000L)
  d_vec_uint64 <- c(2^50, 2^60) # R 'numeric' (double)
  
  # Attributes
  a_scalar_char <- "Root attribute"
  a_mat_int <- matrix(1L:4L, nrow = 2, ncol = 2)
  a_vec_double <- c(9.8, 9.9)
  a_vec_raw <- as.raw(c(0xAA, 0xBB)) # New
  
  
  # --- 2. WRITE DATA ---
  
  # Write datasets
  h5_write(file_path, "/g1/d_vec_double", d_vec_double)
  h5_write(file_path, "/g1/d_vec_int", d_vec_int, dtype = "int32")
  h5_write(file_path, "/g1/g2/d_mat_double", d_mat_double)
  h5_write(file_path, "/g1/g2/d_arr_int", d_arr_int, dtype = "int32")
  h5_write(file_path, "/g3/d_vec_logical", d_vec_logical)
  h5_write(file_path, "/g3/d_vec_char", d_vec_char)
  h5_write(file_path, "/g3/d_scalar_char", d_scalar_char, dims = NULL)
  h5_write(file_path, "/g3/d_vec_raw", d_vec_raw, dtype = "raw") # New
  h5_write(file_path, "/g3/d_mat_raw", d_mat_raw, dtype = "raw") # New
  h5_write(file_path, "/d_scalar_int", d_scalar_int, dtype = "int32", dims = NULL)
  
  # Write specific dtypes
  h5_write(file_path, "/g4/d_vec_float", d_vec_float, dtype = "float32")
  h5_write(file_path, "/g4/d_vec_schar", d_vec_schar, dtype = "int8")
  h5_write(file_path, "/g4/d_vec_short", d_vec_short, dtype = "int16")
  h5_write(file_path, "/g4/d_vec_uint64", d_vec_uint64, dtype = "uint64")
  
  # Write attributes
  h5_write_attr(file_path, "/", "a_scalar_char", a_scalar_char, dims = NULL)
  h5_write_attr(file_path, "/g1/g2/d_arr_int", "a_mat_int", a_mat_int, dtype = "int32")
  h5_write_attr(file_path, "/g1/d_vec_double", "a_vec_double", a_vec_double)
  h5_write_attr(file_path, "/g3", "a_vec_raw", a_vec_raw, dtype = "raw") # New
  
  
  # --- 3. TEST LISTING (h5_ls, h5_ls_attr) ---
  
  # Test recursive listing from root
  ls_all <- h5_ls(file_path, name = "/", recursive = TRUE)
  expect_true("g1/d_vec_double" %in% ls_all)
  expect_true("g1/g2/d_arr_int" %in% ls_all)
  expect_true("g3/d_scalar_char" %in% ls_all)
  expect_true("g4/d_vec_short" %in% ls_all)
  
  # Test non-recursive (flat) listing from root
  ls_flat <- h5_ls(file_path, name = "/", recursive = FALSE)
  expect_equal(sort(ls_flat), sort(c("g1", "g3", "g4", "d_scalar_int")))
  expect_false("g1/d_vec_double" %in% ls_flat)
  
  # Test non-recursive listing from a sub-group
  ls_g3 <- h5_ls(file_path, name = "/g3", recursive = FALSE)
  expect_equal(sort(ls_g3), sort(c("d_vec_logical", "d_vec_char", "d_scalar_char", "d_vec_raw", "d_mat_raw")))
  
  # Test attribute listing
  expect_equal(h5_ls_attr(file_path, "/"), "a_scalar_char")
  expect_equal(h5_ls_attr(file_path, "/g1/g2/d_arr_int"), "a_mat_int")
  expect_equal(h5_ls_attr(file_path, "/g1/d_vec_double"), "a_vec_double")
  expect_equal(h5_ls_attr(file_path, "/g3"), "a_vec_raw") # New
  
  
  # --- 4. TEST METADATA (h5_typeof, h5_dim) ---
  
  # Test typeof (on-disk type)
  expect_equal(h5_typeof(file_path, "/g1/d_vec_double"), "float64")
  expect_equal(h5_typeof(file_path, "/g1/d_vec_int"), "int32")
  expect_equal(h5_typeof(file_path, "/g3/d_vec_char"), "STRING")
  expect_equal(h5_typeof(file_path, "/d_scalar_int"), "int32")
  
  # New dtype tests (UPDATED EXPECTATIONS)
  expect_equal(h5_typeof(file_path, "/g3/d_vec_logical"), "uint8") # logical -> uchar -> uint8
  expect_equal(h5_typeof(file_path, "/g4/d_vec_float"), "float32") # float -> float32
  expect_equal(h5_typeof(file_path, "/g4/d_vec_schar"), "int8") # char -> int8
  expect_equal(h5_typeof(file_path, "/g4/d_vec_short"), "int16") # short -> int16
  expect_equal(h5_typeof(file_path, "/g4/d_vec_uint64"), "uint64") # uint64 -> uint64
  expect_equal(h5_typeof(file_path, "/g3/d_vec_raw"), "OPAQUE") # New
  
  # Test typeof_attr
  expect_equal(h5_typeof_attr(file_path, "/", "a_scalar_char"), "STRING")
  expect_equal(h5_typeof_attr(file_path, "/g1/g2/d_arr_int", "a_mat_int"), "int32")
  expect_equal(h5_typeof_attr(file_path, "/g3", "a_vec_raw"), "OPAQUE") # New
  
  # Test dim
  expect_equal(h5_dim(file_path, "/g1/g2/d_mat_double"), dim(d_mat_double))
  expect_equal(h5_dim(file_path, "/g1/g2/d_arr_int"), dim(d_arr_int))
  expect_equal(h5_dim(file_path, "/g1/d_vec_int"), length(d_vec_int))
  expect_equal(h5_dim(file_path, "/d_scalar_int"), integer(0)) # Scalars
  expect_equal(h5_dim(file_path, "/g3/d_mat_raw"), dim(d_mat_raw)) # New
  
  # Test dim_attr
  expect_equal(h5_dim_attr(file_path, "/g1/g2/d_arr_int", "a_mat_int"), dim(a_mat_int))
  expect_equal(h5_dim_attr(file_path, "/", "a_scalar_char"), integer(0))
  expect_equal(h5_dim_attr(file_path, "/g3", "a_vec_raw"), length(a_vec_raw)) # New
  
  
  # --- 5. TEST READ DATA INTEGRITY (h5_read, h5_read_attr) ---
  
  # Test datasets
  expect_equal(h5_read(file_path, "/g1/d_vec_double"), d_vec_double)
  expect_equal(h5_read(file_path, "/g1/g2/d_mat_double"), d_mat_double)
  expect_equal(h5_read(file_path, "/g1/g2/d_arr_int"), d_arr_int)
  expect_equal(h5_read(file_path, "/g3/d_vec_char"), d_vec_char)
  expect_equal(h5_read(file_path, "/d_scalar_int"), d_scalar_int)
  expect_equal(h5_read(file_path, "/g3/d_vec_raw"), d_vec_raw) # New
  expect_equal(h5_read(file_path, "/g3/d_mat_raw"), d_mat_raw) # New
  
  # Test that integer/logical data is read back as R's "numeric" (double)
  expect_type(h5_read(file_path, "/g1/d_vec_int"), "double")
  expect_type(h5_read(file_path, "/g3/d_vec_logical"), "double")
  expect_equal(h5_read(file_path, "/g1/d_vec_int"), as.numeric(d_vec_int))
  expect_equal(h5_read(file_path, "/g3/d_vec_logical"), as.numeric(d_vec_logical))
  
  # Test attributes
  expect_equal(h5_read_attr(file_path, "/", "a_scalar_char"), a_scalar_char)
  expect_equal(h5_read_attr(file_path, "/g1/d_vec_double", "a_vec_double"), a_vec_double)
  expect_equal(h5_read_attr(file_path, "/g1/g2/d_arr_int", "a_mat_int"), a_mat_int)
  expect_equal(h5_read_attr(file_path, "/g3", "a_vec_raw"), a_vec_raw) # New
  
  # Test new dtypes read-back
  r_vec_float <- h5_read(file_path, "/g4/d_vec_float")
  expect_type(r_vec_float, "double")
  expect_equal(r_vec_float, d_vec_float, tolerance = 1e-7) 
  
  r_vec_schar <- h5_read(file_path, "/g4/d_vec_schar")
  expect_type(r_vec_schar, "double")
  expect_equal(r_vec_schar, as.numeric(d_vec_schar))
  
  r_vec_short <- h5_read(file_path, "/g4/d_vec_short")
  expect_type(r_vec_short, "double")
  expect_equal(r_vec_short, as.numeric(d_vec_short))
  
  r_vec_uint64 <- h5_read(file_path, "/g4/d_vec_uint64")
  expect_type(r_vec_uint64, "double")
  expect_equal(r_vec_uint64, d_vec_uint64) # R doubles can hold these values
  
  
  # --- 6. TEST OVERWRITE ---
  
  # Overwrite a dataset
  d_new_vec <- c(99, 88, 77)
  h5_write(file_path, "/g1/d_vec_double", d_new_vec, dtype = "double")
  
  # Check new data
  expect_equal(h5_read(file_path, "/g1/d_vec_double"), d_new_vec)
  # Check new type and dim
  expect_equal(h5_typeof(file_path, "/g1/d_vec_double"), "float64")
  expect_equal(h5_dim(file_path, "/g1/d_vec_double"), length(d_new_vec))
  
  # Overwrite an attribute
  a_new_attr <- "new_version_string"
  h5_write_attr(file_path, "/", "a_scalar_char", a_new_attr, dims = NULL)
  expect_equal(h5_read_attr(file_path, "/", "a_scalar_char"), a_new_attr)
  expect_equal(h5_typeof_attr(file_path, "/", "a_scalar_char"), "STRING")
  expect_equal(h5_dim_attr(file_path, "/", "a_scalar_char"), integer(0))
  
  # Check that other data is unaffected
  expect_equal(h5_read(file_path, "/g1/d_vec_int"), as.numeric(d_vec_int))
})


test_that("Create and Delete functions work correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)
  
  # 1. Test Group Creation
  h5_create_group(file_path, "/g1/g2/g3")
  h5_write(file_path, "/g1/d1", 1, dims = NULL)
  
  expect_equal(sort(h5_ls(file_path, recursive = TRUE)), 
               sort(c("g1", "g1/d1", "g1/g2", "g1/g2/g3")))
  
  # 2. Test Dataset Deletion
  h5_delete(file_path, "/g1/d1")
  expect_false("g1/d1" %in% h5_ls(file_path, recursive = TRUE))
  
  # 3. Test Group Deletion (Recursive)
  h5_write(file_path, "/g1/g2/g3/d2", 2, dims = NULL)
  expect_true("g1/g2/g3/d2" %in% h5_ls(file_path, recursive = TRUE))
  
  h5_delete_group(file_path, "/g1/g2") # Should delete g2, g3, and d2
  
  expect_false("g1/g2" %in% h5_ls(file_path, recursive = TRUE))
  expect_false("g1/g2/g3" %in% h5_ls(file_path, recursive = TRUE))
  expect_false("g1/g2/g3/d2" %in% h5_ls(file_path, recursive = TRUE))
  expect_true("g1" %in% h5_ls(file_path, recursive = TRUE)) # g1 should still exist
  
  # 4. Test Attribute Deletion
  h5_write_attr(file_path, "/g1", "my_attr", "hello", dims = NULL)
  expect_equal(h5_ls_attr(file_path, "/g1"), "my_attr")
  
  h5_delete_attr(file_path, "/g1", "my_attr")
  expect_equal(h5_ls_attr(file_path, "/g1"), character(0))
})

test_that("Compression works correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)
  
  # Create a compressible vector
  d_compressible <- rep(1:10, 1000)
  
  # Write once without compression, once with
  h5_write(file_path, "uncompressed", d_compressible, compress = FALSE)
  h5_write(file_path, "compressed", d_compressible, compress = TRUE)
  
  # Check that data is readable and correct
  expect_equal(h5_read(file_path, "uncompressed"), as.numeric(d_compressible))
  expect_equal(h5_read(file_path, "compressed"), as.numeric(d_compressible))
  
  # To check if compression actually happened, we can't easily inspect
  # the file from here without another library. A good proxy is that
  # a file with a compressed dataset should be smaller than a file
  # with just the uncompressed version of the same data.
  
  file_uncompressed <- tempfile(fileext = ".h5")
  on.exit(unlink(file_uncompressed), add = TRUE)
  h5_write(file_uncompressed, "data", d_compressible, compress = FALSE)
  
  file_compressed <- tempfile(fileext = ".h5")
  on.exit(unlink(file_compressed), add = TRUE)
  h5_write(file_compressed, "data", d_compressible, compress = TRUE)
  
  # The compressed file should be significantly smaller
  expect_lt(file.size(file_compressed), file.size(file_uncompressed))
})
