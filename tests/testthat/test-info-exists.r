library(testthat)
library(h5lite)

test_that("Info, existence, and type checking functions work correctly", {
  
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # --- 1. SETUP: Create a deeper, more complex structure ---
  # /
  # |-- d1
  # |-- g1/
  # |   |-- d1.1
  # |   `-- g1.1/
  # |       `-- d1.1.1
  # `-- g2/
  #     `-- d2.1
  h5_write(file_path, "d1", 1:5)
  h5_write(file_path, "g1/d1.1", 1:10, dtype = "int16")
  h5_write(file_path, "g1/g1.1/d1.1.1", matrix(1:4, 2, 2), dtype = 'float64')
  h5_write(file_path, "g2/d2.1", I("a scalar"))
  h5_write_attr(file_path, "g1/d1.1", "a1", "hello")
  h5_write_attr(file_path, "g1/d1.1", "a2", 1:3, dtype = "float64")
  h5_write_attr(file_path, "g1/d1.1", "a3_scalar", I(100))
  h5_write(file_path, "uint16_dset", 1, dtype = "uint16")
  h5_write(file_path, "uint32_dset", 1, dtype = "uint32")
  h5_write(file_path, "uint64_dset", 1, dtype = "uint64")

  # --- 2. TEST h5_exists ---
  expect_true(h5_exists(file_path, "g1"))
  expect_true(h5_exists(file_path, "g1/g1.1/d1.1.1"))
  expect_false(h5_exists(file_path, "nonexistent_group"))
  expect_false(h5_exists(file_path, "g1/nonexistent_child"))
  expect_false(h5_exists("nonexistent.h5", "g1"))

  # --- 3. TEST h5_exists_attr ---
  expect_true(h5_exists_attr(file_path, "g1/d1.1", "a1"))
  expect_false(h5_exists_attr(file_path, "g1/d1.1", "nonexistent_attr"))
  expect_false(h5_exists_attr(file_path, "nonexistent_dataset", "a1"))
  expect_false(h5_exists_attr("nonexistent.h5", "g1/d1.1", "a1"))

  # --- 4. TEST h5_is_group and h5_is_dataset ---
  expect_true(h5_is_group(file_path, "g1"))
  expect_true(h5_is_dataset(file_path, "g1/d1.1"))
  expect_false(h5_is_group(file_path, "g1/d1.1"))
  expect_false(h5_is_dataset(file_path, "g1"))
  expect_false(h5_is_group(file_path, "nonexistent"))
  expect_false(h5_is_dataset(file_path, "nonexistent"))
  expect_false(h5_is_group("nonexistent.h5", "any"))
  expect_false(h5_is_dataset("nonexistent.h5", "any"))

  # --- 5. TEST h5_ls and h5_ls_attr ---
  # Test non-recursive listing from root
  ls_root_flat <- h5_ls(file_path, name = "/", recursive = FALSE)
  expect_equal(sort(ls_root_flat), sort(c("d1", "g1", "g2", "uint16_dset", "uint32_dset", "uint64_dset")))

  # Test recursive listing from root
  ls_root_rec <- h5_ls(file_path, name = "/", recursive = TRUE)
  expect_equal(
    sort(ls_root_rec), 
    sort(c(
      "d1", "g1", "g1/d1.1", "g1/g1.1", "g1/g1.1/d1.1.1", "g2", "g2/d2.1", 
      "uint16_dset", "uint32_dset", "uint64_dset" )))

  # Test non-recursive listing from a subgroup
  ls_g1_flat <- h5_ls(file_path, name = "/g1", recursive = FALSE)
  expect_equal(sort(ls_g1_flat), sort(c("d1.1", "g1.1")))

  # Test recursive listing from a subgroup with full.names
  ls_g1_rec_full <- h5_ls(file_path, name = "/g1", recursive = TRUE, full.names = TRUE)
  expect_equal(sort(ls_g1_rec_full), sort(c("/g1/d1.1", "/g1/g1.1", "/g1/g1.1/d1.1.1")))

  # Test recursive listing from root with full.names = TRUE (covers a specific branch in C code)
  ls_root_rec_full <- h5_ls(file_path, name = "/", recursive = TRUE, full.names = TRUE)
  expect_equal(sort(ls_root_rec_full), sort(h5_ls(file_path, recursive = TRUE)))

  # Test non-recursive listing from root with full.names = TRUE (covers a specific branch in C code)
  ls_root_flat_full <- h5_ls(file_path, name = "/", recursive = FALSE, full.names = TRUE)
  expect_equal(sort(ls_root_flat_full), sort(h5_ls(file_path, recursive = FALSE)))

  # Test attribute listing
  ls_attr <- h5_ls_attr(file_path, "g1/d1.1")
  expect_equal(sort(ls_attr), sort(c("a1", "a2", "a3_scalar")))

  # --- 6. TEST h5_typeof and h5_typeof_attr ---
  expect_equal(h5_typeof(file_path, "g1/d1.1"), "int16")
  expect_equal(h5_typeof(file_path, "g1/g1.1/d1.1.1"), "float64")
  expect_equal(h5_typeof(file_path, "uint16_dset"), "uint16")
  expect_equal(h5_typeof(file_path, "uint32_dset"), "uint32")
  expect_equal(h5_typeof(file_path, "uint64_dset"), "uint64")
  expect_equal(h5_typeof_attr(file_path, "g1/d1.1", "a1"), "string")
  expect_equal(h5_typeof_attr(file_path, "g1/d1.1", "a2"), "float64")

  # --- 7. TEST h5_dim and h5_dim_attr ---
  expect_equal(h5_dim(file_path, "g1/d1.1"), 10)
  expect_equal(h5_dim(file_path, "g1/g1.1/d1.1.1"), c(2, 2))

  # Test scalar dim
  expect_equal(h5_dim_attr(file_path, "g1/d1.1", "a2"), 3)
  expect_equal(h5_dim(file_path, "g2/d2.1"), integer(0))
  expect_equal(h5_dim_attr(file_path, "g1/d1.1", "a3_scalar"), integer(0))

  # --- 8. TEST h5_str ---
  # Test that it runs without error and captures output
  expect_output(h5_str(file_path))
  expect_output(h5_str(file_path, "/g1"))
  expect_output(h5_str(file_path, "/g1/d1.1"))
})

test_that("h5_exists and write operations handle non-HDF5 files correctly", {
  # Create a plain text file
  text_file <- tempfile(fileext = ".txt")
  on.exit(unlink(text_file), add = TRUE)
  writeLines("This is not an HDF5 file.", text_file)

  # 1. h5_exists should return FALSE for a non-HDF5 file
  expect_false(h5_exists(text_file))
  expect_false(h5_exists(text_file, "/"))
  expect_false(h5_exists(text_file, "any_object"))

  # 2. Attempting to write to a non-HDF5 file should throw an error
  expect_error(
    h5_write(text_file, "dset", 1:10),
    "File exists but is not a valid HDF5 file"
  )
})
