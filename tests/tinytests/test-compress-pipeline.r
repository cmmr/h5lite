# ==============================================================================
# Verifies that each compression setting actually builds the pipeline it
# advertises: the data shrinks, the expected filters are applied, and values
# survive the round trip. (test-compress.r only checks that writes succeed.)
# ==============================================================================

pipeline <- function(file, name) vapply(h5_inspect(file, name)$filters, `[[`, "", "name")
ratio    <- function(file, name) { i <- h5_inspect(file, name); i$uncompressed_size / i$storage_size }

# Highly compressible float64 data
compressible <- rep(c(1.5, 2.25, 3.125, 4.0625), 25000)


# ==============================================================================
# 1. Blosc codecs compress at their default levels
# ==============================================================================
local({
  #test_that("Blosc codecs without an explicit level still compress", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # Blosc treats clevel 0 as "store uncompressed", so a default level of 0
  # must never reach the filter.
  for (codec in c("blosc1", "blosc1-lz4", "blosc1-lz4-0", "blosc1-snappy",
                  "blosc2", "blosc2-lz4", "blosc2-lz4-0", "blosc2-ndlz")) {
    h5_write(compressible, f, codec, compress = codec)
    expect_true(ratio(f, codec) > 2, info = codec)
    expect_equal(h5_read(f, codec), compressible, info = codec)
  }
})

local({
  #test_that("Blosc2 ZFP accuracy mode compresses for tolerances below 1", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  set.seed(1)
  x <- cumsum(rnorm(1e5, sd = 0.01))

  for (codec in c("blosc2-zfp-acc-0.01", "blosc2-zfp-acc-0.001")) {
    h5_write(x, f, codec, compress = codec)
    expect_equal(pipeline(f, codec), "blosc2", info = codec)
    expect_true(ratio(f, codec) > 1.5, info = codec)
    expect_true(max(abs(h5_read(f, codec) - x)) <= 0.01, info = codec)
  }
})


# ==============================================================================
# 2. Gzip inside Blosc uses the Blosc filter
# ==============================================================================
local({
  #test_that("blosc1-gzip and blosc2-gzip use Blosc, not plain deflate", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(compressible, f, "b1_gzip", compress = "blosc1-gzip-5")
  expect_equal(pipeline(f, "b1_gzip"), "blosc")
  expect_equal(h5_read(f, "b1_gzip"), compressible)

  h5_write(compressible, f, "b2_gzip", compress = "blosc2-gzip-5")
  expect_equal(pipeline(f, "b2_gzip"), "blosc2")
  expect_equal(h5_read(f, "b2_gzip"), compressible)
})

local({
  #test_that("Unsupported Blosc2-ZFP data falls back to the default gzip pipeline", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # ZFP inside Blosc2 is float-only; integers get the standard fallback
  h5_write(1:1000, f, "b2_zfp_int", compress = "blosc2-zfp-rate-8", as = "int32")
  expect_equal(pipeline(f, "b2_zfp_int"), c("shuffle", "gzip"))
  expect_equal(h5_read(f, "b2_zfp_int"), 1:1000)
})


# ==============================================================================
# 3. Lossy filters never corrupt missing or non-finite values
# ==============================================================================
local({
  #test_that("float_rounding preserves NA and NaN", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  set.seed(1)
  x <- rnorm(1000, mean = 98.6, sd = 0.5)
  x[c(5, 500)] <- NA
  x[10]        <- NaN

  h5_write(x, f, "fr", compress = h5_compression("gzip", float_rounding = 2))
  y <- h5_read(f, "fr")

  expect_identical(is.na(y), is.na(x))
  expect_true(max(abs(y - x), na.rm = TRUE) <= 0.005 + 1e-9)
})

local({
  #test_that("ZFP preserves NA, NaN, and Inf", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  set.seed(1)
  x <- rnorm(1000)
  x[c(5, 500)] <- NA
  x[10]        <- NaN
  x[20]        <- Inf

  for (codec in c("zfp-acc-0.01", "zfp-prec-16", "zfp-rate-16", "blosc2-zfp-prec-16")) {
    h5_write(x, f, codec, compress = codec)
    y <- h5_read(f, codec)
    expect_identical(is.na(y), is.na(x), info = codec)
    expect_identical(is.infinite(y), is.infinite(x), info = codec)
    expect_true(max(abs(y - x)[is.finite(x)]) < 0.01, info = codec)
  }
})


# ==============================================================================
# 4. "none" and logical `compress` values
# ==============================================================================
local({
  #test_that("compress = 'none' applies no filters and no chunking", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(compressible, f, "none", compress = "none")
  info <- h5_inspect(f, "none")
  expect_equal(length(info$filters), 0)
  expect_equal(info$layout, "contiguous")
  expect_equal(h5_read(f, "none"), compressible)

  # Partial reads still work on contiguous storage
  expect_equal(h5_read(f, "none", start = 3, count = 4), compressible[3:6])

  # "none" plus a checksum or Scale-Offset still needs a chunked pipeline
  h5_write(1:1000, f, "none_checksum", compress = h5_compression("none", checksum = TRUE))
  expect_equal(pipeline(f, "none_checksum"), "fletcher32")

  h5_write(1:1000, f, "none_packed", compress = h5_compression("none", int_packing = TRUE))
  expect_equal(pipeline(f, "none_packed"), "scaleoffset")
  expect_equal(h5_read(f, "none_packed"), 1:1000)
})

local({
  #test_that("compress = TRUE / FALSE map to the default codec / none", {
  expect_equal(as.character(h5_compression(TRUE)),  "gzip")
  expect_equal(as.character(h5_compression(FALSE)), "none")

  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(compressible, f, "true", compress = TRUE)
  expect_equal(pipeline(f, "true"), c("shuffle", "gzip"))
})


# ==============================================================================
# 5. LZ4-HC honours the requested level
# ==============================================================================
local({
  #test_that("lz4 levels 1-12 reach the LZ4 filter unchanged", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  for (level in c(0, 1, 4, 12)) {
    nm <- paste0("lz4_", level)
    h5_write(compressible, f, nm, compress = paste0("lz4-", level))
    lz4 <- Filter(function(x) x$name == "lz4", h5_inspect(f, nm)$filters)[[1]]
    expect_equal(lz4$cd_values[[2]], level, info = nm)
  }
})


# ==============================================================================
# 6. print.inspect() formats large chunk dimensions without scientific notation
# ==============================================================================
local({
  #test_that("print.inspect shows full chunk dimensions", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  h5_write(compressible, f, "x")
  expect_stdout(print(h5_inspect(f, "x")), "Chunks:\\s+\\[100000\\]")
})
