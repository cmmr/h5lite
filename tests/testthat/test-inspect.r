# test-inspect.r
library(testthat)

test_that("h5_inspect validates inputs and handles errors", {
  file <- tempfile(fileext = ".h5")
  
  # Create a group (not a dataset)
  h5_create_group(file, "my_group")
  
  # Ensure it throws the expected error when inspecting a group
  expect_error(
    h5_inspect(file, "my_group"), 
    "Target must be a dataset"
  )
  
  unlink(file)
})

test_that("h5_inspect handles uncompressed scalars and print formatting", {
  file <- tempfile(fileext = ".h5")
  
  # Rank-0 Scalar (Bypasses chunking and compression entirely)
  h5_write(I(42L), file, "scalar_val")
  res <- h5_inspect(file, "scalar_val")
  
  expect_s3_class(res, "inspect")
  expect_type(res, "list")
  expect_equal(res$layout, "contiguous") # Rank 0 defaults to contiguous
  expect_null(res$chunk_dims)
  expect_length(res$filters, 0)
  
  out <- capture.output(print(res))
  expect_true(any(grepl("None \\(Uncompressed\\)", out)))
  expect_true(any(grepl("Chunks:\\s+N/A", out)))
  
  # --- Mock Size Formatting to Hit 100% Coverage on fmt_bytes ---
  res$uncompressed_size <- 0
  res$storage_size      <- 500
  out_b <- capture.output(print(res))
  expect_true(any(grepl("0 B", out_b)))
  expect_true(any(grepl("500.00 B", out_b)))
  
  res$uncompressed_size <- 1024 * 15.5      # 15.5 KB
  res$storage_size      <- 1024^2 * 4.2     # 4.2 MB
  out_mb <- capture.output(print(res))
  expect_true(any(grepl("15.50 KB", out_mb)))
  expect_true(any(grepl("4.20 MB", out_mb)))
  
  res$uncompressed_size <- 1024^3 * 1.8     # 1.8 GB
  res$storage_size      <- 1024^4 * 2.1     # 2.1 TB
  out_tb <- capture.output(print(res))
  expect_true(any(grepl("1.80 GB", out_tb)))
  expect_true(any(grepl("2.10 TB", out_tb)))
  
  unlink(file)
})

test_that("h5_inspect detects standard compressors and fletcher32", {
  file <- tempfile(fileext = ".h5")
  dat <- matrix(rnorm(400), 20, 20)
  
  # Standard GZIP with Checksum
  opts <- h5_compression("gzip-6", checksum = TRUE)
  h5_write(dat, file, "gzip_chk", compress = opts)
  
  res <- h5_inspect(file, "gzip_chk")
  expect_equal(res$layout, "chunked")
  
  out <- capture.output(print(res))
  expect_true(any(grepl("gzip -> fletcher32", out)))
  
  unlink(file)
})

test_that("h5_inspect decodes SZIP variations", {
  file <- tempfile(fileext = ".h5")
  dat <- matrix(1L:2500L, 50, 50)
  
  h5_write(dat, file, "szip_ec", compress = "szip-ec")
  out_ec <- capture.output(print(h5_inspect(file, "szip_ec")))
  expect_true(any(grepl("szip-ec", out_ec)))
  
  h5_write(dat, file, "szip_nn", compress = "szip-nn")
  out_nn <- capture.output(print(h5_inspect(file, "szip_nn")))
  expect_true(any(grepl("szip-nn", out_nn)))
  
  unlink(file)
})

test_that("h5_inspect decodes Bitshuffle internal pipelines", {
  file <- tempfile(fileext = ".h5")
  dat <- matrix(1L:2500L, 50, 50)
  
  h5_write(dat, file, "bshuf_lz4", compress = "bshuf-lz4")
  out_lz4 <- capture.output(print(h5_inspect(file, "bshuf_lz4")))
  expect_true(any(grepl("bitshuffle -> lz4", out_lz4)))
  
  h5_write(dat, file, "bshuf_zstd", compress = "bshuf-zstd-3")
  out_zstd <- capture.output(print(h5_inspect(file, "bshuf_zstd")))
  expect_true(any(grepl("bitshuffle -> zstd", out_zstd)))
  
  unlink(file)
})

test_that("h5_inspect decodes Blosc1 and Blosc2 pre-filters", {
  file <- tempfile(fileext = ".h5")
  dat <- matrix(rnorm(2500), 50, 50)
  
  # Blosc1 (Legacy)
  h5_write(dat, file, "blosc1", compress = "blosc1-lz4-5")
  out_b1 <- capture.output(print(h5_inspect(file, "blosc1")))
  expect_true(any(grepl("blosc \\[.*shuffle -> lz4hc\\]", out_b1)))
  
  # Blosc2 with Delta filter
  opts_delta <- h5_compression("blosc2-zstd-5", blosc2_delta = TRUE)
  h5_write(dat, file, "b2_delta", compress = opts_delta)
  out_b2d <- capture.output(print(h5_inspect(file, "b2_delta")))
  expect_true(any(grepl("blosc2 \\[bitshuffle -> delta -> zstd\\]", out_b2d)))
  
  # Blosc2 with Truncate filter
  opts_trunc <- h5_compression("blosc2-ndlz", blosc2_truncate = 10)
  h5_write(dat, file, "b2_trunc", compress = opts_trunc)
  out_b2t <- capture.output(print(h5_inspect(file, "b2_trunc")))
  expect_true(any(grepl("trunc\\(bits=10\\)", out_b2t)))
  expect_true(any(grepl("ndlz", out_b2t)))
  
  unlink(file)
})

test_that("h5_inspect decodes ZFP standalone and Blosc2 modes", {
  file <- tempfile(fileext = ".h5")
  dat <- matrix(rnorm(2500), 50, 50)
  
  # Standalone ZFP Rate
  h5_write(dat, file, "zfp_rate", compress = "zfp-rate-16")
  out_rate <- capture.output(print(h5_inspect(file, "zfp_rate")))
  # Standalone ZFP does not get the bracket expansion
  expect_true(any(grepl("Pipeline: zfp", out_rate))) 
  
  # ZFP embedded inside Blosc2
  h5_write(dat, file, "b2_zfp", compress = "blosc2-zfp-prec-12")
  out_b2zfp <- capture.output(print(h5_inspect(file, "b2_zfp")))
  expect_true(any(grepl("blosc2 \\[zfp-prec\\]", out_b2zfp)))
  
  unlink(file)
})

test_that("h5_inspect detects Scale-Offset integer and float packing", {
  file <- tempfile(fileext = ".h5")
  
  # Integer Packing
  dat_int <- matrix(1L:1000L, 50, 20)
  opts_int <- h5_compression("gzip-5", int_packing = 16)
  h5_write(dat_int, file, "so_int", compress = opts_int)
  out_int <- capture.output(print(h5_inspect(file, "so_int")))
  expect_true(any(grepl("scaleoffset -> gzip", out_int)))
  
  # Float Rounding
  dat_flt <- matrix(rnorm(1000), 50, 20)
  opts_flt <- h5_compression("zstd-3", float_rounding = 3)
  h5_write(dat_flt, file, "so_flt", compress = opts_flt)
  out_flt <- capture.output(print(h5_inspect(file, "so_flt")))
  expect_true(any(grepl("scaleoffset -> zstd", out_flt)))
  
  unlink(file)
})

test_that("h5_inspect decodes legacy and unconfigurable compressors", {
  file <- tempfile(fileext = ".h5")
  dat <- matrix(1L:2500L, 50, 50)
  
  h5_write(dat, file, "lzf", compress = "lzf")
  expect_true(any(grepl("lzf", capture.output(print(h5_inspect(file, "lzf"))))))
  
  h5_write(dat, file, "snappy", compress = "snappy")
  expect_true(any(grepl("snappy", capture.output(print(h5_inspect(file, "snappy"))))))
  
  h5_write(dat, file, "bzip2", compress = "bzip2-4")
  expect_true(any(grepl("bzip2", capture.output(print(h5_inspect(file, "bzip2"))))))
  
  unlink(file)
})
