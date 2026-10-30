# ==============================================================================
# Regression tests for wrong results and for errors on valid input.
# ==============================================================================


# ==============================================================================
# 1. Factors and NULL
# ==============================================================================
local({
  #test_that("factor levels must be non-empty strings", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  expect_error(h5_write(factor(c("", "a", "a")), f, "fa"), "empty")
  expect_false(h5_exists(f, "fa"))
})

local({
  #test_that("NULL datasets with attributes read back as NULL", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(NULL, f, "n")
  h5_write("m", f, "n", attr = "a")
  expect_null(h5_read(f, "n"))

  x <- 1:3
  attr(x, "units") <- "cm"
  h5_write(x, f, "x")
  expect_null(h5_read(f, "x", as = c(x = "null")))

  # Reading the whole file reaches both
  res <- h5_read(f)
  expect_null(res$n)
  expect_equal(attr(res$x, "units"), "cm")
})


# ==============================================================================
# 2. The root group and read-only files
# ==============================================================================
local({
  #test_that("a list can be written to the root group", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(list(old = 1), f, "/")
  h5_write("note", f, "/", attr = "info")

  h5_write(list(a = 1L, b = list(c = "x")), f, "/")
  expect_equal(h5_read(f), list(a = 1L, b = list(c = "x")))
  expect_equal(h5_attr_names(f, "/"), character(0))

  # The handle's default name is its working directory, here the root
  h5 <- h5_open(f)
  h5$write(list(z = 2L))
  expect_equal(h5_read(f), list(z = 2L))
})

local({
  #test_that("read-only HDF5 files can be opened", {
  f <- tempfile(fileext = ".h5")
  on.exit({ Sys.chmod(f, "0644"); unlink(f) })

  h5_write(1:3, f, "x")
  Sys.chmod(f, "0444")

  # Skip where the file stays writable (e.g. running as root). exit_file()
  # would skip the rest of this file too.
  if (file.access(f, 2) != 0) {
    expect_silent(h5_create_file(f))
    h5 <- h5_open(f)
    expect_equal(h5$read("x"), 1:3)
  }
})


# ==============================================================================
# 3. The `as` argument
# ==============================================================================
local({
  #test_that("an unnamed `as` applies to the object, not its attributes", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  x <- 1:10
  attr(x, "units") <- "cm"
  h5_write(x, f, "x", as = "int32")
  expect_equal(h5_typeof(f, "x"), "int32")
  expect_equal(h5_read(f, "x", attr = "units"), "cm")

  # Attribute types are set with "@" keys
  h5_write(x, f, "y", as = c(y = "int32", "@units" = "ascii[2]"))
  expect_equal(h5_typeof(f, "y", attr = "units"), "ascii[2]")
})

local({
  #test_that("`as` is honored for factors, raw, complex, and NULL", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # The documented example: store a factor column as fixed-length strings
  df <- data.frame(id = 1:3, grade = factor(c("A", "B", "A")))
  h5_write(df, f, "df", as = c(grade = "ascii[1]"))
  expect_equal(h5_read(f, "df")$grade, c("A", "B", "A"))

  h5_write(factor(c("lo", "hi")), f, "fac", as = "utf8")
  expect_equal(h5_typeof(f, "fac"), "utf8")
  expect_error(h5_write(factor("a"), f, "bad", as = "int32"), "factor")

  # "skip" works for every type
  h5_write(list(a = factor("z"), b = as.raw(1), c = 1i, d = NULL, e = 1, f = list(g = 1)),
           f, "lst", as = c(a = "skip", b = "skip", c = "skip", d = "skip", f = "skip"))
  expect_equal(h5_ls(f, "lst"), "e")

  h5_write(list(a = factor("z"), b = 1), f, "lst2", as = c(. = "skip"))
  expect_equal(h5_ls(f, "lst2"), character(0))
})

local({
  #test_that("'skip' and 'null' must be spelled out", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # A prefix used to match "skip", silently writing nothing
  expect_error(h5_write(1:3, f, "x", as = "s"),  "Invalid `as`")
  expect_error(h5_write("a", f, "y", as = "sk"), "Invalid `as`")
  expect_equal(h5_ls(f), character(0))

  # Other unambiguous prefixes still work
  h5_write("a", f, "z", as = "utf")
  expect_equal(h5_typeof(f, "z"), "utf8")

  h5_write(1:3, f, "n")
  expect_error(h5_read(f, "n", as = "n"), "Invalid `as`")
  expect_equal(h5_read(f, "n", as = "null"), NULL)
})

local({
  #test_that("attributes written directly use plain or '@' keys", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(1:3, f, "x")
  h5_write(I(5), f, "x", attr = "n1", as = "int32")
  h5_write(I(5), f, "x", attr = "n2", as = c(n2 = "int32"))
  h5_write(I(5), f, "x", attr = "n3", as = c("@n3" = "int32"))
  expect_equal(h5_typeof(f, "x", attr = "n1"), "int32")
  expect_equal(h5_typeof(f, "x", attr = "n2"), "int32")
  expect_equal(h5_typeof(f, "x", attr = "n3"), "int32")
})

local({
  #test_that("type-class keys only match numeric data when reading", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(c("ab", "cd"),   f, "s")
  h5_write(as.raw(1:3),     f, "r")
  h5_write(factor("lvl"),   f, "fac")
  h5_write(c("abcd", "wxyz"), f, "s4", as = "ascii[4]")
  expect_equal(h5_read(f, "s",   as = c(.int   = "null")), c("ab", "cd"))
  expect_equal(h5_read(f, "r",   as = c(.int8  = "null")), as.raw(1:3))
  expect_equal(h5_read(f, "fac", as = c(.uint8 = "null")), factor("lvl"))
  expect_equal(h5_read(f, "s4",  as = c(.int32 = "null")), c("abcd", "wxyz"))
})

local({
  #test_that("'auto' in a named `as` keeps the automatic type", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(1:3, f, "x")
  expect_true(is.integer(h5_read(f, "x", as = c(.uint8 = "auto"))))
  expect_true(is.integer(h5_read(f, "x", as = c(. = "auto"))))
})

local({
  #test_that("attributes read directly honor plain-name mappings", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(1:3, f, "x")
  h5_write(I(1L), f, "x", attr = "id")
  expect_true(is.logical(h5_read(f, "x", attr = "id", as = c(id = "logical"))))
  expect_true(is.logical(h5_read(f, "x", attr = "id", as = c("@id" = "logical"))))
})

local({
  #test_that("as = 'null' drops data frame columns", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(data.frame(x = 1:3, y = c(1.5, 2.5, 3.5)), f, "d")
  expect_equal(h5_read(f, "d", as = c(x = "null")), data.frame(y = c(1.5, 2.5, 3.5)))
})


# ==============================================================================
# 4. Partial reads
# ==============================================================================
local({
  #test_that("data frames take a single `start` value", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(head(mtcars), f, "df")
  expect_error(h5_read(f, "df", start = c(2, 1), count = 2), "single")
  expect_equal(nrow(h5_read(f, "df", start = 2, count = 2)), 2)
})

local({
  #test_that("`start` and `count` apply to each dataset in a group", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(list(a = 1:10, b = 11:20), f, "g")
  expect_equal(h5_read(f, "g", start = 2, count = 2), list(a = 2:3, b = 12:13))
})


# ==============================================================================
# 5. Information functions
# ==============================================================================
local({
  #test_that("h5_length matches length(), and is NA for missing objects", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(NULL, f, "n")
  h5_write(1:3, f, "x")
  h5_write(NULL, f, "x", attr = "empty")
  expect_equal(h5_length(f, "n"), 0)
  expect_equal(h5_length(f, "x", attr = "empty"), 0)
  expect_equal(h5_length(f, "nope"), NA_integer_)
  expect_equal(h5_length(f, "x", attr = "nope"), NA_integer_)
  expect_error(h5_length(tempfile(), "x"), "does not exist")
})

local({
  #test_that("h5_attr_names hides HDF5's dimension scale bookkeeping", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(c(a = 1, b = 2), f, "v")
  h5_write("note", f, "v", attr = "info")
  expect_equal(h5_attr_names(f, "v"), "info")
})

local({
  #test_that("h5_inspect reports filter parameters as unsigned values", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(rnorm(100), f, "z", compress = "zfp-acc-0.01")
  cd <- h5_inspect(f, "z")$filters[[1]]$cd_values
  expect_true(all(cd >= 0))
})


# ==============================================================================
# 6. Listing order and paths
# ==============================================================================
local({
  #test_that("lists keep their order; listings are sorted like sort()", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(list(x = 1, m = 2, d = 3), f, "l")
  expect_equal(names(h5_read(f, "l")), c("x", "m", "d"))

  for (n in c("zeta", "alpha", "mid")) h5_write(1, f, paste0("g/", n))
  expect_equal(h5_ls(f, "g"),    c("alpha", "mid", "zeta"))
  expect_equal(h5_names(f, "g"), c("alpha", "mid", "zeta"))
  expect_equal(h5_ls(f), sort(c("g", "g/alpha", "g/mid", "g/zeta", "l", "l/d", "l/m", "l/x")))

  # Mixed case and digits follow the locale, exactly as sort() does
  nms <- c("b", "B", "a", "x10", "x2", "_u")
  for (n in nms) h5_write(1, f, paste0("mc/", n))
  expect_equal(h5_ls(f, "mc"),    sort(nms))
  expect_equal(h5_names(f, "mc"), sort(nms))

  # Data frame columns keep their own order
  h5_write(data.frame(z = 1, a = 2), f, "df")
  expect_equal(h5_names(f, "df"), c("z", "a"))
})

local({
  #test_that("files from other software are sorted the same way", {
  ff <- "files/foreign.h5"
  if (file.exists(ff)) {
    res <- h5_ls(ff, scales = TRUE)
    expect_equal(res, sort(res))
  }
})

local({
  #test_that("full names are absolute paths", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(1, f, "grp/dset")
  expect_equal(h5_ls(f, "grp/", full.names = TRUE), "/grp/dset")
  expect_equal(h5_ls(f, "grp",  full.names = TRUE), "/grp/dset")
  expect_equal(h5_ls(f, "/",    full.names = TRUE), c("/grp", "/grp/dset"))
})

local({
  #test_that("names longer than 255 bytes are listed in full", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  long <- strrep("n", 300)
  h5_write(1, f, long)
  h5_write("v", f, long, attr = strrep("a", 300))
  out <- capture.output(h5_str(f, markup = FALSE))
  expect_true(any(grepl(long, out, fixed = TRUE)))
  expect_true(any(grepl(strrep("a", 300), out, fixed = TRUE)))
  expect_false(any(grepl("<Error>", out, fixed = TRUE)))
})

local({
  #test_that("failed calls don't print HDF5's internal error stack", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(1, f, "a")
  h5_write(2, f, "b")
  msgs <- capture.output(try(h5_move(f, "a", "b"), silent = TRUE), type = "message")
  expect_false(any(grepl("HDF5-DIAG", msgs)))
})


# ==============================================================================
# 7. The h5_open() handle
# ==============================================================================
local({
  #test_that("handle methods accept the same arguments as the functions", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5 <- h5_open(f)
  h5$write(matrix(1:20, 10), "m")
  h5$write(c(a = 1, b = 2), "v")

  expect_equal(h5$read("m", start = 2, count = 1), matrix(c(2L, 12L), 1))
  expect_equal(sort(h5$ls(scales = TRUE)), c("m", "v", "v_names"))
  expect_true(h5$exists())
  expect_false(h5$exists("nope"))
  expect_silent(h5$exists("nope", assert = FALSE))
  expect_true(h5$is_dataset("v"))
  expect_equal(h5$names("v"), c("a", "b"))
  expect_silent(capture.output(h5$str(members = FALSE, markup = FALSE)))
})

local({
  #test_that("absolute handle paths may contain '..'", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5 <- h5_open(f)
  h5$write(1L, "top")
  h5$create_group("g")
  expect_equal(h5$read("/g/../top"), 1L)
  h5$cd("/a/../g")
  expect_equal(h5$pwd(), "/g")
})

local({
  #test_that("a handle keeps working after the working directory changes", {
  dir <- tempfile()
  dir.create(dir)
  old <- setwd(dir)
  on.exit({ setwd(old); unlink(dir, recursive = TRUE) })

  h5 <- h5_open("rel.h5")
  h5$write(1:3, "x")
  setwd(tempdir())
  expect_equal(h5$read("x"), 1:3)
  expect_false(file.exists(file.path(tempdir(), "rel.h5")))
})


# ==============================================================================
# 8. Miscellaneous writing details
# ==============================================================================
local({
  #test_that("I() is handled consistently", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # The warning for a longer vector appears once
  w <- character(0)
  withCallingHandlers(h5_write(I(1:3), f, "v"), warning = function(e) {
    w <<- c(w, conditionMessage(e)); invokeRestart("muffleWarning") })
  expect_equal(length(w), 1)

  # A named scalar doesn't leave an unattached names dataset behind
  h5_write(I(c(a = 1)), f, "s")
  expect_equal(sort(h5_ls(f, scales = TRUE)), c("s", "v"))

  # A date-time wrapped in I() is a scalar, like any other value
  h5_write(I(as.POSIXct("2024-01-01", tz = "UTC")), f, "t")
  expect_equal(h5_dim(f, "t"), numeric(0))
})

local({
  #test_that("skipping a data frame column keeps the data frame's attributes", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  df <- data.frame(a = 1:2, b = 3:4)
  attr(df, "note") <- "hi"
  h5_write(df, f, "df", as = c(b = "skip"))
  expect_equal(h5_names(f, "df"), "a")
  expect_equal(h5_read(f, "df", attr = "note"), "hi")
})
