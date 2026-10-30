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

# Needs hdf5lib 2.2.0.1, which converts the cd_values h5lite passes to its new
# Blosc2 layout. Restore once h5lite requires it.
# local({
#   #test_that("Blosc2 gets its pre-filters and truncation bits in cd_values[0]", {
#   f <- tempfile(fileext = ".h5")
#   on.exit(unlink(f))
#
#   # hdf5lib's layout: 0xB2100001 + (bitmask << 16) + (bits << 8). Slots 4-6
#   # hold the level, the last pre-filter (2 = bitshuffle), and the codec, as
#   # the reference filter keeps them, so h5py with hdf5plugin can append.
#   cmp <- h5_compression("blosc2-zstd-5", blosc2_delta = TRUE, blosc2_truncate = -5)
#   h5_write(matrix(compressible + 1e-9, 100), f, "x", compress = cmp)
#   cd <- h5_inspect(f, "x")$filters[[1]]$cd_values
#   expect_equal(cd[1], 0xB2100001 + (8 + 4 + 2) * 2^16 + 251 * 2^8)
#   expect_equal(cd[5:7], c(3, 2, 5))
# })

# Needs hdf5lib 2.2.0.1, which declines Blosc2's ZFP codecs on chunks of under
# 4 values and compresses chunks of over 4 dimensions. Restore once h5lite
# requires it.
# local({
#   #test_that("Blosc2's ZFP codecs store chunks of under 4 values uncompressed", {
#   f <- tempfile(fileext = ".h5")
#   on.exit(unlink(f))
#
#   # ZFP can't fill a block from them, so hdf5lib records level 255, which
#   # makes Blosc2 refuse each chunk
#   x <- c(1.5, 2.25, 3.125)
#   h5_write(x, f, "x", compress = "blosc2-zfp-acc-0.01")
#   info <- h5_inspect(f, "x")
#   expect_identical(h5_read(f, "x"), x)
#   expect_equal(info$filters[[1]]$cd_values[5], 255)
#   expect_equal(info$storage_size, info$uncompressed_size)
#   expect_stdout(print(info), "Pipeline: blosc2 \\[zfp-acc\\] \\(declined: stored uncompressed\\)")
#
#   # Chunks of more than 4 dimensions are compressed as one long row
#   set.seed(1)
#   arr <- array(cumsum(rnorm(4^5, sd = 0.01)), rep(4, 5))
#   h5_write(arr, f, "arr5d", compress = "blosc2-zfp-acc-0.01")
#   info <- h5_inspect(f, "arr5d")
#   expect_true(info$storage_size < info$uncompressed_size / 2)
#   expect_true(max(abs(h5_read(f, "arr5d") - arr)) <= 0.01)
#   expect_false(any(grepl("declined", capture.output(print(info)))))
# })

local({
  #test_that("NDLZ gets no pre-filters or truncation bits", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # NDLZ runs no pre-filters, and took truncation bits of 8 for 8x8 cells
  x <- matrix(compressible + 1e-9, 100)
  cmp <- h5_compression("blosc2-ndlz", blosc2_delta = TRUE, blosc2_truncate = 8)
  h5_write(x, f, "x", compress = cmp)
  cd <- h5_inspect(f, "x")$filters[[1]]$cd_values
  # Needs hdf5lib 2.2.0.1's new cd_values layout. Restore once h5lite
  # requires it.
  # expect_equal(cd[1], 0xB2100001 + 4 * 2^8) # The default 4x4 cells
  expect_equal(cd[6], 0)
  expect_identical(h5_read(f, "x"), x)
})

local({
  #test_that("blosc2_truncate skips float32 data whose whole mantissa it would drop", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  x <- seq(0, 1, length.out = 1000) / 3
  h5_write(x, f, "ref", as = "float32", compress = "none")
  for (bits in c(-30, -10))
    h5_write(x, f, paste0("f32_", -bits), as = "float32",
             compress = h5_compression("blosc2-lz4", blosc2_truncate = bits))
  h5_write(x, f, "f64_30", compress = h5_compression("blosc2-lz4", blosc2_truncate = -30))

  # A float32 has 23 mantissa bits, so dropping 30 leaves it whole (hdf5lib
  # would refuse it); dropping 10 truncates, and float64 can lose 30
  expect_identical(h5_read(f, "f32_30"), h5_read(f, "ref"))
  expect_false(identical(h5_read(f, "f32_10"), h5_read(f, "ref")))
  expect_false(identical(h5_read(f, "f64_30"), x))
})

local({
  #test_that("Blosc2 compresses Scale-Offset output at any chunk rank", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # Scale-Offset changes each chunk's size, so hdf5lib now compresses it as
  # plain Blosc2 instead of refusing every chunk with two or more dimensions
  m <- matrix(1:20000 %% 300L, 200)
  h5_write(m, f, "so",    compress = h5_compression("none",       int_packing = TRUE))
  h5_write(m, f, "so_b2", compress = h5_compression("blosc2-lz4", int_packing = TRUE))
  expect_identical(h5_read(f, "so_b2"), m)
  expect_equal(pipeline(f, "so_b2"), c("scaleoffset", "blosc2"))
  # Needs hdf5lib 2.2.0.1: 2.2.0.0 won't run Blosc2 on Scale-Offset output with
  # 2 or more dimensions. Restore once h5lite requires it.
  # expect_true(h5_inspect(f, "so_b2")$storage_size < h5_inspect(f, "so")$storage_size)
})

local({
  #test_that("print.inspect reads Blosc2 lists from earlier hdf5lib and other writers", {
  fake <- function(cd) structure(
    list(type = "float64", uncompressed_size = 8000, storage_size = 4000,
         layout = "chunked", chunk_dims = 1000,
         filters = list(list(name = "blosc2", cd_values = cd))),
    class = c("inspect", "list"))

  # Earlier hdf5lib (2): the bitmask in slot 5, and the bits in its second
  # byte (1-D chunks) or after the chunk shape
  expect_stdout(print(fake(c(2, 0, 8, 8000, 5, 10 + 251 * 256, 5))),
                "blosc2 \\[trunc\\(bits=-5\\) -> bitshuffle -> zstd\\]")
  expect_stdout(print(fake(c(2, 0, 8, 8000, 5, 14, 1, 2, 10, 100, 10))),
                "blosc2 \\[trunc\\(bits=10\\) -> delta -> bitshuffle -> lz4\\]")

  # The reference filter (1): only the last pre-filter, as a filter code
  expect_stdout(print(fake(c(1, 0, 8, 8000, 5, 3, 5))), "blosc2 \\[delta -> zstd\\]")
  expect_stdout(print(fake(c(1, 0, 8, 8000, 5, 4, 5))), "blosc2 \\[trunc -> zstd\\]")
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

local({
  #test_that("ZFP stores chunks it can't compress unfiltered", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # ZFP compresses chunks with 1 to 4 dimensions longer than one. For others,
  # hdf5lib records parameters ({version, 0}) that make it refuse every chunk,
  # so HDF5 stores each one unfiltered. (It used to record none.)
  set.seed(1)
  cases <- list(
    value  = rnorm(1),
    arr5d  = array(rnorm(32),  rep(2, 5)),
    chunks = array(rnorm(4^5), rep(4, 5)) ) # Eight 2x2x2x4x4 chunks

  for (codec in c("zfp-acc-0.01", "zfp-prec-16")) {
    for (nm in names(cases)) {
      id <- paste0(codec, "_", nm)
      h5_write(cases[[nm]], f, id, compress = h5_compression(codec, chunk_size = 1024))
      info <- h5_inspect(f, id)
      zfp  <- info$filters[[1]]

      # Lossy ZFP would not return these values exactly
      expect_identical(h5_read(f, id), cases[[nm]], info = id)
      expect_equal(pipeline(f, id), "zfp", info = id)
      # Needs hdf5lib 2.2.0.1, which records {version, 0} for chunks ZFP
      # declines. Restore once h5lite requires it.
      # expect_equal(zfp$cd_values[-1], 0, info = id)
      # Any compressed chunk would change the total
      expect_equal(info$storage_size, info$uncompressed_size, info = id)
      expect_stdout(print(info), "Pipeline: zfp \\(declined: stored uncompressed\\)", info = id)
    }
  }

  # Chunks with 1 to 4 dimensions longer than one are still compressed
  h5_write(array(rnorm(256), rep(4, 4)), f, "arr4d", compress = "zfp-acc-0.01")
  info <- h5_inspect(f, "arr4d")
  expect_true(length(info$filters[[1]]$cd_values) > 2)
  expect_true(info$storage_size < info$uncompressed_size / 2)
  expect_false(any(grepl("declined", capture.output(print(info)))))
})

local({
  #test_that("float_rounding is skipped for 2-byte floats", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # HDF5's Scale-Offset filter can't handle them, so the write used to fail
  for (as in c("float16", "bfloat16")) {
    h5_write(c(1.25, 2.5, 3.75), f, as, as = as, compress = h5_compression(float_rounding = 1))
    expect_equal(pipeline(f, as), c("shuffle", "gzip"), info = as)
    expect_equal(h5_read(f, as), c(1.25, 2.5, 3.75), info = as)
  }
})

local({
  #test_that("blosc2_truncate only rounds floats, and keeps NA", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  trunc <- h5_compression("blosc2-zstd", blosc2_truncate = 10)

  # Truncation zeroes low bits of any 4- or 8-byte item, so integers and
  # data frame records must not get it
  ints <- 1:2000 * 1000L
  h5_write(ints, f, "uint32", compress = trunc)
  h5_write(ints, f, "int32",  compress = trunc, as = "int32")
  h5_write(as.numeric(ints), f, "int64", compress = trunc, as = "int64")
  expect_equal(h5_read(f, "uint32"), ints)
  expect_equal(h5_read(f, "int32"),  ints)
  expect_equal(h5_read(f, "int64"),  ints)

  df <- data.frame(a = ints, b = rev(ints))
  h5_write(df, f, "df", compress = trunc, as = c(a = "int32", b = "int32"))
  expect_equal(h5_read(f, "df"), df)

  # NA would lose the bits that set it apart from NaN, or become Inf. (Blosc
  # leaves buffers under 128 bytes alone, so write more than that.)
  x <- rep(c(1.5, NA, 2.5, NaN, Inf, -Inf), 100)
  h5_write(x, f, "nonfinite", compress = trunc)
  expect_identical(h5_read(f, "nonfinite"), x)

  # Floats are still truncated
  h5_write(compressible + 1e-9, f, "float", compress = trunc)
  expect_true(any(h5_read(f, "float") != compressible + 1e-9))
})


# Needs hdf5lib 2.2.0.1, whose ZFP refuses just the chunks holding NA, NaN, or
# Inf; until then h5_write() uses gzip for such data. Restore once h5lite
# requires it.
# local({
#   #test_that("ZFP stores only the chunks with non-finite values uncompressed", {
#   f <- tempfile(fileext = ".h5")
#   on.exit(unlink(f))
#
#   set.seed(1)
#   x <- cumsum(rnorm(1e5, sd = 0.01))
#   x[c(10, 50000)] <- NA
#   x[99999]        <- Inf
#
#   # 64 KB chunks: 13 chunks, 3 of which hold a non-finite value
#   for (codec in c("zfp-acc-0.01", "blosc2-zfp-acc-0.01")) {
#     h5_write(x, f, codec, compress = h5_compression(codec, chunk_size = 64 * 1024))
#     y <- h5_read(f, codec)
#     expect_equal(pipeline(f, codec), if (startsWith(codec, "zfp")) "zfp" else "blosc2", info = codec)
#     expect_identical(is.na(y), is.na(x), info = codec)
#     expect_identical(is.infinite(y), is.infinite(x), info = codec)
#     expect_true(max(abs(y - x)[is.finite(x)]) <= 0.01, info = codec)
#     expect_true(ratio(f, codec) > 1.5, info = codec)
#   }
# })

# Needs hdf5lib 2.2.0.1, whose ZFP refuses chunks holding NaN (2.2.0.0's
# corrupts them). Restore once h5lite requires it.
# local({
#   #test_that("a filter that fails when the dataset closes is never silent", {
#   f <- tempfile(fileext = ".h5")
#   on.exit(unlink(f))
#
#   # Call the writer directly, bypassing h5_write()'s own checks. A small
#   # dataset sits in HDF5's chunk cache until the dataset is closed, so a
#   # filter that rejects the chunk only fails then.
#   x <- c(1.5, NaN, 2.5, 3.5)
#   res <- tryCatch(
#     expr = {
#       h5lite:::h5_call(.Call("C_h5_write_dataset", f, "z", x, "float64", length(x),
#                              h5_compression("zfp-acc-0.01"), PACKAGE = "h5lite"))
#       h5_read(f, "z")
#     },
#     error = function(e) "error")
#   expect_true(identical(res, "error") || isTRUE(all.equal(res, x, tolerance = 0.01)))
# })

local({
  #test_that("h5_threads() sets the number of threads", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  expect_error(h5_threads(-1))
  expect_error(h5_threads(1.5))
  expect_error(h5_threads(257))

  # H5LITE_NTHREADS sets the default, so clear it for the counts below and
  # restore it afterwards. An empty value counts as unset; clearing it with
  # Sys.setenv() rather than Sys.unsetenv() lets tinytest record the original
  # value to restore. (CRAN allows at most 2 threads.)
  env <- Sys.getenv("H5LITE_NTHREADS", unset = NA)
  on.exit(if (is.na(env)) Sys.unsetenv("H5LITE_NTHREADS") else Sys.setenv(H5LITE_NTHREADS = env), add = TRUE)
  on.exit(h5_threads(0), add = TRUE)
  Sys.setenv(H5LITE_NTHREADS = "")

  expect_equal(h5_threads(), 1L)
  expect_equal(h5_threads(2), 0L)   # The previous setting; 0 means none
  expect_equal(h5_threads(), 2L)

  # Data round-trips with threads in both Blosc versions
  for (codec in c("blosc1-zstd-5", "blosc2-zstd-5")) {
    h5_write(compressible, f, codec, compress = h5_compression(codec, chunk_size = 256 * 1024))
    expect_equal(h5_read(f, codec), compressible, info = codec)
  }

  expect_equal(h5_threads(0), 2L)
  expect_equal(h5_threads(), 1L)

  # H5LITE_NTHREADS sets the default, which h5_threads() overrides
  Sys.setenv(H5LITE_NTHREADS = 2)
  expect_equal(h5_threads(), 2L)
  expect_equal(h5_threads(1), 0L)
  expect_equal(h5_threads(), 1L)
  expect_equal(h5_threads(0), 1L)
  expect_equal(h5_threads(), 2L)   # Back to the default

  # The default applies to the next read or write
  h5_write(compressible, f, "env", compress = h5_compression("blosc2-zstd-5", chunk_size = 256 * 1024))
  expect_equal(h5_read(f, "env"), compressible)

  # Values that aren't positive whole numbers are ignored
  for (val in c("abc", "0", "-2")) {
    Sys.setenv(H5LITE_NTHREADS = val)
    expect_equal(h5_threads(), 1L, info = val)
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

local({
  #test_that("print.inspect finds Blosc2's truncation bits for 1-D chunks", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))

  # hdf5lib records chunk geometry only for 2-D and larger chunks
  for (bits in c(10, -5)) {
    trunc <- h5_compression("blosc2-zstd", blosc2_truncate = bits)
    h5_write(compressible, f, "v", compress = trunc)
    h5_write(matrix(compressible, 100), f, "m", compress = trunc)
    pattern <- sprintf("trunc\\(bits=%d\\)", bits)
    expect_stdout(print(h5_inspect(f, "v")), pattern, info = bits)
    expect_stdout(print(h5_inspect(f, "m")), pattern, info = bits)
  }
})
