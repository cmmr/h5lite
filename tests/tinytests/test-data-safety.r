# ==============================================================================
# Regression tests for crashes, leaked handles, and silent data loss.
# ==============================================================================


# ==============================================================================
# 1. Memory safety and leaked handles
# ==============================================================================
local({
  #test_that("start and count must be whole numbers", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # Variable-length strings: a rejected selection used to free garbage pointers
  h5_write(c("aa", NA, "cc", "dd", "ee", "ff", "gg"), f, "s")
  expect_error(h5_read(f, "s", start = 0.5, count = 5), "whole number")
  expect_error(h5_read(f, "s", start = 2, count = 1.5), "whole number")
  expect_error(h5_read(f, "s", start = c(1, 2.5)), "whole number")
  expect_equal(h5_read(f, "s", start = 3, count = 2), c("cc", "dd"))
})

local({
  #test_that("data frame columns must be plain vectors with one value per row", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # A matrix column used to make the writer read past the end of other columns
  df <- data.frame(m = I(matrix(1:6, 2)), x = c(10.5, 20.5))
  expect_error(h5_write(df, f, "d"), "column 'm'")
  expect_false(h5_exists(f, "d"))
})

local({
  #test_that("errors raised mid-write leave no HDF5 handles open", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # Compare with the count beforehand: some filter plugins leak IDs of their own
  n_open <- h5lite:::open_id_count()

  x <- "caf\xe9"
  Encoding(x) <- "bytes"
  expect_error(h5_write(x, f, "x"), "bytes")
  expect_false(h5_exists(f, "x"))
  expect_true(h5lite:::open_id_count() <= n_open)

  # Same for names, which are written by a different code path
  y <- c(1, 2)
  names(y) <- c("a", x)
  expect_error(h5_write(y, f, "y"), "bytes")
  expect_false(h5_exists(f, "y"))
  expect_true(h5lite:::open_id_count() <= n_open)

  # An error raised from inside C (here, a non-HDF5 file) is cleaned up too
  txt <- tempfile(fileext = ".h5")
  writeLines("not hdf5", txt)
  expect_error(h5_write(1, txt, "x"), "not a valid HDF5 file")
  expect_true(h5lite:::open_id_count() <= n_open)
  unlink(txt)
})


# ==============================================================================
# 2. Moving and deleting
# ==============================================================================
local({
  #test_that("a group cannot be moved into its own subtree", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(1:3, f, "g/d")
  expect_error(h5_move(f, "g", "g/x"),      "into itself")
  expect_error(h5_move(f, "/g/", "g/sub/g"), "into itself")
  expect_equal(h5_read(f, "g/d"), 1:3)

  # Moving onto its own name is a no-op
  expect_silent(h5_move(f, "g", "/g"))
  expect_equal(h5_read(f, "g/d"), 1:3)
})

local({
  #test_that("dimension scales follow their dataset", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # Moving a dataset moves its scales too
  h5_write(c(a = 1, b = 2), f, "v")
  h5_move(f, "v", "g/v")
  expect_equal(sort(h5_ls(f, scales = TRUE)), c("g", "g/v", "g/v_names"))

  # Writing to the old name must not touch the moved dataset's names
  h5_write(c(x = 3, y = 4), f, "v")
  expect_equal(names(h5_read(f, "g/v")), c("a", "b"))
  expect_equal(names(h5_read(f, "v")),   c("x", "y"))
})

local({
  #test_that("writing scales never overwrites unrelated objects", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(list(x_names = 1:3, x = c(a = 1, b = 2)), f, "g")
  expect_equal(h5_read(f, "g/x_names"), 1:3)
  expect_equal(names(h5_read(f, "g/x")), c("a", "b"))

  # The other order: writing x_names moves x's scale aside rather than deleting it
  h5_write(list(x = c(a = 1, b = 2), x_names = 1:3), f, "g2")
  expect_equal(h5_read(f, "g2/x_names"), 1:3)
  expect_equal(names(h5_read(f, "g2/x")), c("a", "b"))

  h5_create_group(f, "m_rownames")
  h5_write(matrix(1:4, 2, dimnames = list(c("r1", "r2"), NULL)), f, "m")
  expect_true(h5_is_group(f, "m_rownames"))
  expect_equal(rownames(h5_read(f, "m")), c("r1", "r2"))
})

local({
  #test_that("deleting or replacing a dataset removes its scales", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  m <- matrix(1:4, 2, dimnames = list(c("r1", "r2"), c("c1", "c2")))
  h5_write(m, f, "mat")
  h5_delete(f, "mat")
  expect_equal(h5_ls(f, scales = TRUE), character(0))

  h5_write(c(a = 1), f, "v")
  h5_write(1, f, "v")
  expect_equal(h5_ls(f, scales = TRUE), "v")

  h5_write(list(sub = c(p = 1, q = 2)), f, "grp")
  h5_delete(f, "grp")
  expect_equal(h5_ls(f, scales = TRUE), "v")
})

local({
  #test_that("deleting a dataset keeps scales that aren't named after it", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # Like a netCDF coordinate variable, "labels" is data in its own right
  h5_write(c(a = 1, b = 2), f, "x")
  h5_move(f, "x_names", "labels")
  h5_delete(f, "x")
  expect_true(h5_exists(f, "labels"))
  expect_equivalent(h5_read(f, "labels"), c("a", "b"))  # It keeps its CLASS attribute

  h5_write(c(c = 3, d = 4), f, "y")
  h5_move(f, "y_names", "g/ylabels")
  h5_write(5:6, f, "y")
  expect_equivalent(h5_read(f, "g/ylabels"), c("c", "d"))
  expect_null(names(h5_read(f, "y")))
})

local({
  #test_that("deleting a scale detaches it from its dataset", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  m <- matrix(1:4, 2, dimnames = list(c("r1", "r2"), c("c1", "c2")))
  h5_write(m, f, "mat")
  h5_delete(f, "mat_colnames")
  h5_write(c("zz", "yy"), f, "other")
  expect_equal(dimnames(h5_read(f, "mat")), list(c("r1", "r2"), NULL))
})


# ==============================================================================
# 3. Writing lists, data frames, and attributes
# ==============================================================================
local({
  #test_that("data frame column names must be unique and non-empty", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  dup <- data.frame(a = 1:3, a = c(10.5, 20.5, 30.5), check.names = FALSE)
  expect_error(h5_write(dup, f, "dup"), "column names")

  blank <- data.frame(1:3, b = 4:6)
  names(blank) <- c("", "b")
  expect_error(h5_write(blank, f, "blank"), "column names")

  expect_equal(h5_ls(f), character(0))
})

local({
  #test_that("a list cannot be written as an attribute", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(1:5, f, "x")
  expect_error(h5_write(list(a = 1), f, "x", attr = "meta"), "attribute")
  expect_true(h5_is_dataset(f, "x"))
  expect_equal(h5_read(f, "x"), 1:5)
})

local({
  #test_that("list elements must have unique, non-empty names", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(list(keep = 1:3), f, "g")

  expect_error(h5_write(list(1, 2, "a"),    f, "u"), "names")
  expect_error(h5_write(list(a = 1, 2),     f, "g"), "names")
  expect_error(h5_write(list(a = 1, a = 2), f, "g"), "names")
  bad <- list(1, 2)
  names(bad) <- c("a", NA)
  expect_error(h5_write(bad, f, "g"), "names")

  expect_equal(h5_read(f, "g"), list(keep = 1:3))
  expect_false(h5_exists(f, "u"))
})

local({
  #test_that("a failed overwrite leaves the original group intact", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(list(a = 1, b = 2, c = 3), f, "g")
  expect_error(h5_write(list(a = 99, b = factor(character(0))), f, "g"))
  expect_equal(h5_read(f, "g"), list(a = 1, b = 2, c = 3))
  expect_equal(sort(h5_ls(f)), c("g", "g/a", "g/b", "g/c"))
})


# ==============================================================================
# 4. Dates and times
# ==============================================================================
local({
  #test_that("POSIXct is stored as UTC, keeping fractional seconds", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  chicago <- as.POSIXct("2024-01-01 12:00:00", tz = "America/Chicago")
  h5_write(chicago, f, "chicago")
  expect_equal(h5_read(f, "chicago"), "2024-01-01T18:00:00Z")

  frac <- as.POSIXct(c("2024-01-01 12:00:00.75", "2024-01-01 12:00:01", NA), tz = "UTC")
  h5_write(frac, f, "frac")
  expect_equal(h5_read(f, "frac"), c("2024-01-01T12:00:00.75Z", "2024-01-01T12:00:01Z", NA))

  df <- data.frame(id = 1:2, when = as.POSIXct(c("2024-06-01 08:30:00", "2024-06-01 09:00:00"), tz = "Asia/Tokyo"))
  h5_write(df, f, "df")
  expect_equal(h5_read(f, "df")$when, c("2024-05-31T23:30:00Z", "2024-06-01T00:00:00Z"))
})

local({
  #test_that("POSIXlt is written like POSIXct", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(as.POSIXlt("2024-01-01 06:00:00", tz = "UTC"), f, "t")
  expect_true(h5_is_dataset(f, "t"))
  expect_equal(h5_read(f, "t"), "2024-01-01T06:00:00Z")
})


# ==============================================================================
# 5. Strings
# ==============================================================================
local({
  #test_that("fixed-length UTF-8 strings are truncated on character boundaries", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(c("éé", "a"), f, "s", as = "utf8[3]")
  res <- h5_read(f, "s")
  expect_true(all(validUTF8(res)))
  expect_equal(res, c("é", "a"))

  # Width is measured in UTF-8 bytes, even for Latin-1 input
  latin1 <- iconv("café", "UTF-8", "latin1")
  h5_write(c(latin1, "abcde"), f, "l")
  expect_equal(h5_read(f, "l"), c("café", "abcde"))
  h5_write(latin1, f, "l2", as = "utf8[]")
  expect_equal(h5_read(f, "l2"), "café")
})

local({
  #test_that("as = 'ascii' transliterates every element", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(c("café", "naïve", "été"), f, "s", as = "ascii")
  expect_equal(h5_read(f, "s"), c("cafe", "naive", "ete"))

  m <- matrix(c("à", "b", "ç", "d"), 2)
  h5_write(m, f, "m", as = "ascii[1]")
  expect_equal(h5_read(f, "m"), matrix(c("a", "b", "c", "d"), 2))
})


# ==============================================================================
# 6. Numeric ranges
# ==============================================================================
local({
  #test_that("values outside the target type's range are rejected", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  expect_error(h5_write(70000, f, "h",  as = "float16"),  "exceeds")
  expect_error(h5_write(1e39,  f, "s",  as = "float32"),  "exceeds")
  expect_error(h5_write(1e39,  f, "b",  as = "bfloat16"), "exceeds")
  expect_error(h5_write(2^63,  f, "i",  as = "int64"),    "exceeds")
  expect_error(h5_write(2^64,  f, "u",  as = "uint64"),   "exceeds")

  # -2^63 is bit64's NA, so it can't be stored as a value either
  expect_error(h5_write(-2^63, f, "i2", as = "int64"),    "exceeds")

  # The largest representable values still fit
  h5_write(c(-2^63 + 1024, 2^63 - 1024), f, "i64", as = "int64")
  expect_equal(h5_read(f, "i64"), c(-2^63 + 1024, 2^63 - 1024))
  h5_write(c(-Inf, Inf, 65504), f, "h16", as = "float16")
  expect_equal(h5_read(f, "h16"), c(-Inf, Inf, 65504))
})

local({
  #test_that("int64 NA reads back as NA", {
  if (!requireNamespace("bit64", quietly = TRUE)) exit_file("bit64 not installed")
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(bit64::as.integer64(c(1, NA, 3)), f, "i")
  expect_equal(h5_read(f, "i"), c(1, NA, 3))

  h5_write(data.frame(i = bit64::as.integer64(c(NA, 2))), f, "df")
  expect_equal(h5_read(f, "df")$i, c(NA, 2))
})
