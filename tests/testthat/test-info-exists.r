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
  h5_write(file_path, "g2/d2.1", "a scalar", dims = NULL)
  h5_write_attr(file_path, "g1/d1.1", "a1", "hello")
  h5_write_attr(file_path, "g1/d1.1", "a2", 1:3, dtype = 'float64')

  # --- 2. TEST h5_exists ---
  expect_true(h5_exists(file_path, "g1"))
  expect_true(h5_exists(file_path, "g1/g1.1/d1.1.1"))
  expect_false(h5_exists(file_path, "nonexistent_group"))
  expect_false(h5_exists(file_path, "g1/nonexistent_child"))
  expect_false(h5_exists("nonexistent.h5", "g1"))

  # --- 3. TEST h5_exists_attr ---
  expect_true(h5_exists_attr(file_path, "g1/d1.1", "a1"))
  expect_false(h5_exists_attr(file_path, "g1/d1.1", "nonexistent_attribute"))
  expect_false(h5_exists_attr(file_path, "nonexistent_dataset", "a1"))
  expect_false(h5_exists_attr("nonexistent.h5", "g1/d1.1", "a1"))

  # --- 4. TEST h5_is_group and h5_is_dataset ---
  expect_true(h5_is_group(file_path, "g1"))
  expect_true(h5_is_dataset(file_path, "g1/d1.1"))
  expect_false(h5_is_group(file_path, "g1/d1.1"))
  expect_false(h5_is_dataset(file_path, "g1"))
  expect_false(h5_is_group(file_path, "nonexistent"))
  expect_false(h5_is_dataset(file_path, "nonexistent"))

  # --- 5. TEST h5_ls and h5_ls_attr ---
  # Test non-recursive listing from root
  ls_root_flat <- h5_ls(file_path, name = "/", recursive = FALSE)
  expect_equal(sort(ls_root_flat), sort(c("d1", "g1", "g2")))

  # Test recursive listing from root
  ls_root_rec <- h5_ls(file_path, name = "/", recursive = TRUE)
  expect_equal(sort(ls_root_rec), sort(c("d1", "g1", "g1/d1.1", "g1/g1.1", "g1/g1.1/d1.1.1", "g2", "g2/d2.1")))

  # Test non-recursive listing from a subgroup
  ls_g1_flat <- h5_ls(file_path, name = "/g1", recursive = FALSE)
  expect_equal(sort(ls_g1_flat), sort(c("d1.1", "g1.1")))

  # Test recursive listing from a subgroup with full.names
  ls_g1_rec_full <- h5_ls(file_path, name = "/g1", recursive = TRUE, full.names = TRUE)
  expect_equal(sort(ls_g1_rec_full), sort(c("/g1/d1.1", "/g1/g1.1", "/g1/g1.1/d1.1.1")))

  # Test attribute listing
  ls_attr <- h5_ls_attr(file_path, "g1/d1.1")
  expect_equal(sort(ls_attr), sort(c("a1", "a2")))

  # --- 6. TEST h5_typeof and h5_typeof_attr ---
  expect_equal(h5_typeof(file_path, "g1/d1.1"), "int16")
  expect_equal(h5_typeof(file_path, "g1/g1.1/d1.1.1"), "float64")
  expect_equal(h5_typeof_attr(file_path, "g1/d1.1", "a1"), "STRING")
  expect_equal(h5_typeof_attr(file_path, "g1/d1.1", "a2"), "float64")

  # --- 7. TEST h5_dim and h5_dim_attr ---
  expect_equal(h5_dim(file_path, "g1/d1.1"), 10)
  expect_equal(h5_dim(file_path, "g1/g1.1/d1.1.1"), c(2, 2))
  expect_equal(h5_dim_attr(file_path, "g1/d1.1", "a2"), 3)

  # Test scalar dim
  expect_equal(h5_dim(file_path, "g2/d2.1"), integer(0))

  # --- 8. TEST h5_str ---
  # Test that it runs without error and captures output
  expect_output(h5_str(file_path), "List of 3")
  expect_output(h5_str(file_path, "/g1"), "List of 2")
  expect_output(h5_str(file_path, "/g1/d1.1"), "num")
})
