library(testthat)
library(h5lite)

test_that("h5_write_all and h5_read_all work correctly", {
  
  file_path <- tempfile(fileext = ".h5")
  on.exit(unlink(file_path), add = TRUE)

  # 1. Create a nested list with non-alphabetical names and attributes
  original_list <- list(
    zeta = list(z_vec = 1:3),
    alpha = list(
      a_mat = matrix(1:4, 2),
      a_vec = 1:5
    ),
    beta = 2.5,
    empty_group = list()
  )
  attr(original_list$alpha, "info") <- "alpha group"
  attr(original_list$alpha$a_mat, "info") <- "a_mat dataset"

  # 2. Write the list to the file
  h5_write_all(file_path, "session_data", original_list)

  # 3. Read the entire structure back
  read_list <- h5_read_all(file_path, "session_data")

  # 4. VERIFY: h5_read_all returns items sorted by name.
  # The structure should be identical, but the top-level order will be alphabetical.
  expect_equal(names(read_list), c("alpha", "beta", "empty_group", "zeta"))

  # To compare the content regardless of order, sort the original list by name
  sorted_original_list <- original_list[order(names(original_list))]

  # Now, expect_equal should pass
  expect_equal(read_list, sorted_original_list)

  # 5. Test validation for unnamed list elements
  bad_list_unnamed <- list(a = 1, 2) # second element is unnamed
  expect_error(h5_write_all(file_path, "bad_data", bad_list_unnamed),
               "All elements in a list must be named.")

  bad_list_no_names <- list(1, 2)
  expect_error(h5_write_all(file_path, "bad_data", bad_list_no_names),
               "All elements in a list must be named.")

  nested_bad_list <- list(a = 1, b = list(c = 3, 4)) # unnamed element in nested list
  expect_error(h5_write_all(file_path, "bad_data", nested_bad_list),
               "All elements in a list must be named.")

  # 6. Test that h5_read_all on a dataset behaves like h5_read
  dset_read <- h5_read_all(file_path, "/session_data/beta")
  expect_equal(dset_read, 2.5)
})
