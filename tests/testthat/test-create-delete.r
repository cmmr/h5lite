library(testthat)
library(h5lite)

test_that("Create and Delete functions work correctly", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # 1. Test Group Creation
  h5_create_group(file_path, "/g1/g2/g3")
  h5_write(file_path, "/g1/d1", I(1))

  expect_equal(sort(h5_ls(file_path, recursive = TRUE)),
               sort(c("g1", "g1/d1", "g1/g2", "g1/g2/g3")))

  # 2. Test Dataset Deletion
  h5_delete_dataset(file_path, "/g1/d1")
  expect_false("g1/d1" %in% h5_ls(file_path, recursive = TRUE))

  # 3. Test Group Deletion (Recursive)
  h5_write(file_path, "/g1/g2/g3/d2", I(2))
  expect_true("g1/g2/g3/d2" %in% h5_ls(file_path, recursive = TRUE))

  h5_delete_group(file_path, "/g1/g2") # Should delete g2, g3, and d2

  expect_false("g1/g2" %in% h5_ls(file_path, recursive = TRUE))
  expect_false("g1/g2/g3" %in% h5_ls(file_path, recursive = TRUE))
  expect_false("g1/g2/g3/d2" %in% h5_ls(file_path, recursive = TRUE))
  expect_true("g1" %in% h5_ls(file_path, recursive = TRUE)) # g1 should still exist

  # 4. Test Attribute Deletion
  h5_write_attr(file_path, "/g1", "my_attr", I("hello"))
  expect_equal(h5_ls_attr(file_path, "/g1"), "my_attr")

  h5_delete_attr(file_path, "/g1", "my_attr")
  expect_equal(h5_ls_attr(file_path, "/g1"), character(0))
})

test_that("h5_move works for datasets, groups, and auto-creates parents", {
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)
  
  # Create a sample file structure
  h5_write(file_path, "/group1/dataset_a", 1:10)
  h5_write(file_path, "/group1/dataset_b", 99)
  h5_create_group(file_path, "/group2")
  
  # 1. Rename a dataset within the same group
  h5_move(file_path, "/group1/dataset_a", "/group1/dataset_a_renamed")
  
  expect_false(h5_exists(file_path, "/group1/dataset_a"))
  expect_true(h5_exists(file_path, "/group1/dataset_a_renamed"))
  expect_equal(h5_read(file_path, "/group1/dataset_a_renamed"), 1:10)
  
  # 2. Move a dataset to another existing group
  h5_move(file_path, "/group1/dataset_b", "/group2/dataset_b_moved")
  
  expect_false(h5_exists(file_path, "/group1/dataset_b"))
  expect_true(h5_exists(file_path, "/group2/dataset_b_moved"))
  expect_equal(h5_read(file_path, "/group2/dataset_b_moved"), 99)
  
  # 3. Rename a group
  h5_move(file_path, "/group2", "/group2_renamed")
  
  expect_false(h5_exists(file_path, "/group2"))
  expect_true(h5_exists(file_path, "/group2_renamed"))
  # Check that the child object moved with the group
  expect_true(h5_exists(file_path, "/group2_renamed/dataset_b_moved"))
  
  # 4. Move an entire group into another group
  h5_move(file_path, "/group1", "/group2_renamed/group1_moved")
  
  expect_false(h5_exists(file_path, "/group1"))
  expect_true(h5_exists(file_path, "/group2_renamed/group1_moved"))
  # Check that children moved with it
  expect_true(h5_exists(file_path, "/group2_renamed/group1_moved/dataset_a_renamed"))
  
  # 5. Test automatic creation of intermediate parent groups
  h5_move(file_path, "/group2_renamed/group1_moved", "/new/path/for/group1")
  
  expect_true(h5_exists(file_path, "/new/path/for/group1"))
  expect_true(h5_is_group(file_path, "/new/path/for")) # Check parent was created
  expect_true(h5_is_group(file_path, "/new/path"))
  expect_true(h5_is_group(file_path, "/new"))
  
  # 6. Test error on moving non-existent object
  expect_error(
    h5_move(file_path, "/does/not/exist", "/foo"),
    "Failed to move object"
  )
})
