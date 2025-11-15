library(testthat)
library(h5lite)

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