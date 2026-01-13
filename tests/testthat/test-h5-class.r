test_that("h5 wrapper object works", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5 <- h5_open(file)
  
  # Write via method
  h5$write(1:10, "dset")
  expect_true(h5$exists("dset"))
  
  # Read via method
  expect_equal(h5$read("dset"), 1:10)
  
  
  # Misc functions
  expect_output(str(h5))
  expect_output(print(h5))
  expect_equal(as.character(h5), file)
  expect_equal(h5$class("dset"), "numeric")
  expect_equal(h5$dim("dset"), 10)
  expect_equal(h5$typeof("dset"), "uint8")
  expect_true(h5$is_dataset("dset"))
  expect_false(h5$is_group("dset"))
  expect_equal(h5$names("dset"), character(0))
  expect_equal(h5$attr_names("dset"), character(0))
  expect_null(h5$move("dset", "dset2"))
  
  
  # Navigation
  h5$create_group("sub")
  expect_equal(h5$class("sub"), "list")
  h5$cd("sub")
  expect_equal(h5$pwd(), "/sub")
  
  h5$write("hidden", "deep") # Should be at /sub/deep
  expect_true(h5_exists(file, "/sub/deep"))
  
  # Relative read/delete
  expect_equal(h5$read("deep"), "hidden")
  expect_null(h5$delete("../dset2"))
  
  
  # Pass-by-reference check
  h5_alias <- h5
  h5_alias$cd("/")
  expect_equal(h5$pwd(), "/")
  
  
  # Closing
  h5$close()
  
  expect_output(print(h5))
  expect_error(h5$ls(), "handle has been closed")
})
