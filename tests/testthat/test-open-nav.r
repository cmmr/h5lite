library(testthat)
library(h5lite)

test_that("h5 handle navigation ($cd, $pwd) works correctly", {
  file_path <- tempfile(fileext = ".h5")
  h <- h5_open(file_path)
  on.exit(unlink(file_path), add = TRUE)

  # 1. Initial state
  expect_equal(h$pwd(), "/")

  # 2. Absolute path cd
  h$cd("/g1/g2")
  expect_equal(h$pwd(), "/g1/g2")

  # 3. Relative path cd
  h$cd("g3")
  expect_equal(h$pwd(), "/g1/g2/g3")

  # 4. '..' navigation
  h$cd("..")
  expect_equal(h$pwd(), "/g1/g2")
  h$cd("../../g4")
  expect_equal(h$pwd(), "/g4")

  # 5. '.' navigation and extra slashes
  h$cd("./g5/./g6/")
  expect_equal(h$pwd(), "/g4/g5/g6")

  # 6. Chained cd calls
  h$cd("/")$cd("a")$cd("b")$cd("c")
  expect_equal(h$pwd(), "/a/b/c")

  # 7. cd to root
  h$cd("/")
  expect_equal(h$pwd(), "/")

  # 8. cd with '..' from root should stay at root
  h$cd("..")
  expect_equal(h$pwd(), "/")
  h$cd("../..")
  expect_equal(h$pwd(), "/")
})

test_that("h5 handle methods respect the working directory", {
  file_path <- tempfile(fileext = ".h5")
  h <- h5_open(file_path)
  on.exit(unlink(file_path), add = TRUE)

  # Navigate to a new directory
  h$cd("/data/2024")

  # Write a dataset using a relative path
  h$write("dset1", 1:10)
  h$write_attr("dset1", "units", "m")

  # Verify it was written to the correct absolute path
  expect_true(h5_exists(file_path, "/data/2024/dset1"))
  expect_equal(h5_read(file_path, "/data/2024/dset1"), 1:10)

  # Use other methods with relative paths
  expect_equal(h$ls(), "dset1")
  expect_equal(h$dim("dset1"), 10)
  expect_equal(h$read_attr("dset1", "units"), "m")

  # Test that providing an absolute path ignores the wd
  h$write("/absolute/path/dset2", 2:20)
  expect_true(h5_exists(file_path, "/absolute/path/dset2"))
  expect_equal(h$read("/absolute/path/dset2"), 2:20)
})