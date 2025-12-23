test_that("File creation and existence", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  expect_false(h5_exists(file))
  h5_create_file(file)
  expect_true(h5_exists(file))
  expect_true(h5_exists(file, "/"))
})

test_that("Group creation", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_create_group(file, "foo/bar")
  expect_true(h5_is_group(file, "foo"))
  expect_true(h5_is_group(file, "foo/bar"))
})

test_that("Move and Delete", {
  
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  expect_error(h5_delete(file, "a"))
  
  h5_write(1, file, "a")
  
  expect_error(h5_delete(file, "b", warn = "invalid"))
  expect_error(h5_delete(file, name = 123))
  suppressWarnings({
    expect_warning(h5_delete(file, "b",      warn = TRUE))
    expect_warning(h5_delete(file, "a", "b", warn = TRUE))
  })
  
  # Move
  h5_move(file, "a", "b")
  expect_false(h5_exists(file, "a"))
  expect_true(h5_exists(file, "b"))
  
  # Delete
  h5_delete(file, "b")
  expect_false(h5_exists(file, "b"))
})

test_that("ls, str, and names", {
  file <- tempfile(fileext = ".h5")
  on.exit(unlink(file))
  
  h5_write(1, file, "g1/d1")
  h5_write(2, file, "g1/d2")
  
  lst <- list(
    a = 1:5,
    b = list(),
    c = matrix(1:4, 2, 2),
    d = data.frame(x=1:4, y=LETTERS[1:4]),
    e = logical(0),
    f = I('a_scalar') )
  attr(lst,   'attr1') <- lst$d
  attr(lst$a, 'attr2') <- lst$e
  attr(lst$a, 'attr3') <- lst$f
  h5_write(lst, file, "lst")
  
  expect_equal(sort(h5_names(file, "g1")), c("d1", "d2"))
  expect_equal(h5_attr_names(file, "lst"), c("attr1"))
  expect_equal(length(h5_ls(file, recursive = TRUE)), 10)
  expect_equal(length(h5_ls(file, recursive = TRUE, full.names = TRUE)), 10)
  expect_equal(length(h5_ls(file, recursive = FALSE)), 2)
  expect_equal(length(h5_ls(file, recursive = FALSE, full.names = TRUE)), 2)
  expect_equal(length(h5_ls(file, "lst/b")), 0)
  expect_equal(length(h5_ls(file, "lst", full.names = TRUE)), 6)
  expect_output(h5_str(file))
  expect_output(h5_str(file, "lst"))
  expect_output(h5_str(file, "lst", attrs = FALSE))
  
  expect_error(h5_ls(tempfile())) # file doesn't exist
})
