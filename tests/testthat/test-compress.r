library(testthat)
library(h5lite)

# ==============================================================================
# 1. R-Level: h5_compression() Argument Parsing & Defaults
# ==============================================================================
test_that("h5_compression parses inputs and applies defaults", {
  
  # Base object checks
  expect_s3_class(h5_compression(), "compress")
  
  # Identity checks (inherits 'compress')
  fs <- h5_compression("zstd-5")
  expect_equal(h5_compression(fs), fs)
  
  # Numeric & Null conversions
  expect_equal(as.character(h5_compression(5)), "gzip-5")
  expect_equal(as.character(h5_compression(NULL)), "none")
  
  # Codec defaults
  expect_equal(attr(h5_compression("zstd"), "level"), 3)
  expect_equal(attr(h5_compression("gzip"), "level"), 5)
  expect_equal(attr(h5_compression("lz4"), "level"), 0)
  expect_equal(attr(h5_compression("bzip2"), "level"), 9)
  
  # int_packing logic
  expect_equal(attr(h5_compression(int_packing = TRUE), "int_packing"), 0L)
  expect_equal(attr(h5_compression(int_packing = 8), "int_packing"), 8L)
  expect_true(is.na(attr(h5_compression(int_packing = FALSE), "int_packing")))
  
  # float_rounding logic
  expect_equal(attr(h5_compression(float_rounding = 3), "float_rounding"), 3L)
  expect_true(is.na(attr(h5_compression(), "float_rounding")))
})


# ==============================================================================
# 2. R-Level: h5_compression() Error Triggers (stop() cases)
# ==============================================================================
test_that("h5_compression triggers all boundary and type errors", {
  
  # Type mismatches
  expect_error(h5_compression(chunk_size = 1.23), "must be a scalar integer")
  expect_error(h5_compression(int_packing = "yes"), "must be TRUE/FALSE or an integer")
  expect_error(h5_compression(int_packing = 1.5), "must be TRUE/FALSE or an integer")
  expect_error(h5_compression("invalid-codec"), "Invalid `compress` string")
  
  # Level boundaries
  expect_error(h5_compression("gzip-10"), "level must be an integer between")
  expect_error(h5_compression("zstd-25"), "level must be an integer between")
  expect_error(h5_compression("lz4-15"), "level must be an integer between")
  expect_error(h5_compression("bzip2-0"), "level must be an integer between")
  
  # Mutually exclusive filters (Scale-Offset Conflicts)
  expect_error(h5_compression("szip-nn", int_packing = TRUE), "not compatible with `szip-nn`")
  expect_error(h5_compression("zfp-rate-8", float_rounding = 3), "not compatible with `zfp-rate`")
  expect_error(h5_compression("bshuf-lz4", int_packing = TRUE), "not compatible with `bshuf-lz4`")
  
  # Blosc modifier conflicts
  expect_error(
    h5_compression("blosc2-zstd", float_rounding = 2, blosc2_truncate = 16), 
    "not compatible with `blosc2_truncate`"
  )
  expect_error(
    h5_compression("blosc2-zstd", float_rounding = 2, blosc2_delta = TRUE), 
    "not compatible with `blosc2_delta`"
  )
})


# ==============================================================================
# 3. C-Level: apply_compression() Valid Codec & Pipeline Applications
# ==============================================================================
test_that("apply_compression succeeds for all standard codecs", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))
  
  v_int <- 1:100
  
  # Base HDF5 Algorithms (triggers native H5Pset_shuffle due to type_size > 1)
  expect_silent(h5_write(v_int, f, "gzip", compress = h5_compression("gzip-9")))
  expect_silent(h5_write(v_int, f, "zstd", compress = h5_compression("zstd-22"))) 
  expect_silent(h5_write(v_int, f, "lz4_fast", compress = h5_compression("lz4-0")))
  expect_silent(h5_write(v_int, f, "lz4_hc", compress = h5_compression("lz4-9")))
  
  # SZIP
  expect_silent(h5_write(v_int, f, "szip_nn", compress = h5_compression("szip-nn")))
  expect_silent(h5_write(v_int, f, "szip_ec", compress = h5_compression("szip-ec")))
  
  # Standalone Bitshuffle
  expect_silent(h5_write(v_int, f, "bshuf_lz4", compress = h5_compression("bshuf-lz4")))
  expect_silent(h5_write(v_int, f, "bshuf_zstd", compress = h5_compression("bshuf-zstd-5")))
})

test_that("apply_compression succeeds for Blosc architectures", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))
  
  v_int <- 1:100
  
  # Legacy Blosc
  expect_silent(h5_write(v_int, f, "blosc1", compress = h5_compression("blosc1-lz4-5")))
  
  # Blosc2 inner codecs
  expect_silent(h5_write(v_int, f, "b2_zstd", compress = h5_compression("blosc2-zstd-5")))
  expect_silent(h5_write(v_int, f, "b2_lz4", compress = h5_compression("blosc2-lz4-9")))
  expect_silent(h5_write(v_int, f, "b2_gzip", compress = h5_compression("blosc2-gzip-5")))
  expect_silent(h5_write(v_int, f, "b2_ndlz", compress = h5_compression("blosc2-ndlz")))
  
  # Blosc2 Modifiers
  expect_silent(h5_write(v_int, f, "b2_delta", 
                         compress = h5_compression("blosc2-zstd-5", blosc2_delta = TRUE)))
  
  expect_silent(h5_write(rnorm(100), f, "b2_trunc", 
                         compress = h5_compression("blosc2-zstd-5", blosc2_truncate = 16)))
})

test_that("apply_compression succeeds for all ZFP modes", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))
  
  v_float <- rnorm(100)
  
  # Standalone ZFP
  expect_silent(h5_write(v_float, f, "zfp_rev", compress = h5_compression("zfp-rev")))
  expect_silent(h5_write(v_float, f, "zfp_rate", compress = h5_compression("zfp-rate-16")))
  expect_silent(h5_write(v_float, f, "zfp_prec", compress = h5_compression("zfp-prec-16")))
  expect_silent(h5_write(v_float, f, "zfp_acc", compress = h5_compression("zfp-acc-0.001")))
  
  # Blosc2 ZFP
  expect_silent(h5_write(v_float, f, "b2_zfp_rate", compress = h5_compression("blosc2-zfp-rate-16")))
  expect_silent(h5_write(v_float, f, "b2_zfp_prec", compress = h5_compression("blosc2-zfp-prec-16")))
  expect_silent(h5_write(v_float, f, "b2_zfp_acc", compress = h5_compression("blosc2-zfp-acc-0.001")))
})


# ==============================================================================
# 4. C-Level: Defensive Fallbacks & Edge Cases
# ==============================================================================
test_that("apply_compression safely degrades un-chunkable or invalid data", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))
  
  # 1. Rank 0 (Scalar Bypass)
  expect_silent(h5_write(I(5), f, "scalar", compress = h5_compression("gzip-5")))
  
  # 2. Checksum Application
  expect_silent(h5_write(1:100, f, "checksum", 
                         compress = h5_compression("none", checksum = TRUE)))
  
  # 3. Scale-Offset Application (Directly valid)
  expect_silent(h5_write(1:100, f, "so_int", 
                         compress = h5_compression("gzip-5", int_packing = TRUE)))
  expect_silent(h5_write(rnorm(100), f, "so_float", 
                         compress = h5_compression("gzip-5", float_rounding = 3)))
  
  # 4. SZIP Constraints (No R-level hacking required for these)
  fs_szip <- h5_compression("szip-nn")
  # Non-numeric string -> falls back to gzip
  expect_silent(h5_write(letters[1:10], f, "szip_char", compress = fs_szip)) 
  # Dim < 32 but >= 2 -> chunk adjusted to 14
  expect_silent(h5_write(1:15, f, "szip_15", compress = fs_szip)) 
  # Dim = 1 -> chunk adjusted to gzip fallback
  expect_silent(h5_write(1, f, "szip_1", compress = fs_szip)) 
  
  # 5. ZFP Constraints (No R-level hacking required)
  fs_zfp <- h5_compression("zfp-rev")
  fs_b2_zfp <- h5_compression("blosc2-zfp-rate-8")
  
  # Standalone not numeric -> gzip
  expect_silent(h5_write(letters[1:10], f, "zfp_char", compress = fs_zfp)) 
  # Standalone size != 4 or 8 (RAW is 1 byte) -> gzip
  expect_silent(h5_write(as.raw(1:10), f, "zfp_raw", compress = fs_zfp)) 
  # Blosc-ZFP applied to integers -> gzip fallback
  expect_silent(h5_write(1:100, f, "b2_zfp_int", compress = fs_b2_zfp)) 
})

test_that("apply_compression defensive C-level modifier fallbacks trigger", {
  f <- tempfile(fileext = ".h5")
  on.exit(unlink(f))
  
  # To test the C-level defensive downgrades (like preventing scaled data from 
  # hitting SZIP/ZFP), we must intentionally hack an R S3 object to bypass the 
  # R-level `stop()` checks we validated in Test Block 2.
  
  # Hack 1: Force szip + Scale-Offset to trigger the `is_scaled` fallback to GZIP
  fs_hack_szip <- h5_compression("szip-ec")
  attr(fs_hack_szip, "float_rounding") <- 2L
  expect_silent(h5_write(rnorm(100), f, "hack_szip", compress = fs_hack_szip))
  
  # Hack 2: Force zfp + Scale-Offset to trigger the `is_scaled` fallback to GZIP
  fs_hack_zfp <- h5_compression("zfp-rate-16")
  attr(fs_hack_zfp, "float_rounding") <- 2L
  expect_silent(h5_write(rnorm(100), f, "hack_zfp", compress = fs_hack_zfp))
})

# ==============================================================================
# 5. R-Level: print.compress() Code Coverage
# ==============================================================================
test_that("print.compress evaluates base configuration and unit math", {
  
  # Base output and 0-byte (B) edge case + Checksum
  c_base <- h5_compression("none", chunk_size = 500, checksum = TRUE)
  expect_output(print(c_base), "<HDF5 Compression Configuration>")
  expect_output(print(c_base), "Codec:\\s+none")
  expect_output(print(c_base), "Shuffle:\\s+None")
  expect_output(print(c_base), "Chunk Size:\\s+500.00 B")
  expect_output(print(c_base), "Checksum:\\s+Fletcher32")
  
  # KB size conversion
  c_kb <- h5_compression("gzip-5", chunk_size = 2048)
  expect_output(print(c_kb), "Chunk Size:\\s+2.00 KB")
  
  # MB size conversion (default 1048576)
  c_mb <- h5_compression("lz4-0")
  expect_output(print(c_mb), "Chunk Size:\\s+1.00 MB")
  
  # GB size conversion
  c_gb <- h5_compression("zstd-5", chunk_size = 1024^3)
  expect_output(print(c_gb), "Chunk Size:\\s+1.00 GB")
  
  # Force NA level to test `if (!is.na(lvl))` bypass
  c_na <- c_base
  attr(c_na, "level") <- NA
  expect_output(print(c_na), "Codec:\\s+none\n")
})

test_that("print.compress evaluates shuffle exclusion hierarchy", {
  
  # 1. is_scaled (Highest priority override)
  c_scaled <- h5_compression("gzip-5", int_packing = TRUE)
  expect_output(print(c_scaled), "Shuffle:\\s+None \\(Disabled by Scale-Offset\\)")
  
  # 2. SZIP
  c_szip <- h5_compression("szip-nn")
  expect_output(print(c_szip), "Shuffle:\\s+None \\(Incompatible with szip\\)")
  
  # 3. ZFP
  c_zfp <- h5_compression("zfp-rate-16")
  expect_output(print(c_zfp), "Shuffle:\\s+None \\(Incompatible with zfp\\)")
  
  # 4. Standalone Bitshuffle
  c_bshuf <- h5_compression("bshuf-lz4")
  expect_output(print(c_bshuf), "Shuffle:\\s+Bitshuffle \\(Standalone Plugin\\)")
  
  # 5. Blosc Internal Bitshuffle
  c_blosc <- h5_compression("blosc1-lz4-5")
  expect_output(print(c_blosc), "Shuffle:\\s+Bitshuffle \\(Blosc Internal\\)")
  
  # 6. Native Fallback
  c_native <- h5_compression("gzip-9")
  expect_output(print(c_native), "Shuffle:\\s+Byte Shuffle \\(Native HDF5\\)")
})

test_that("print.compress evaluates modifiers correctly", {
  
  # Int Packing: Optimal / Auto (0L)
  c_ip_auto <- h5_compression("gzip-5", int_packing = TRUE)
  expect_output(print(c_ip_auto), "Int Packing:\\s+Optimal \\(Auto\\)")
  
  # Int Packing: Manual Bits
  c_ip_man <- h5_compression("gzip-5", int_packing = 8)
  expect_output(print(c_ip_man), "Int Packing:\\s+8 bits")
  
  # Float Rounding
  c_fr <- h5_compression("gzip-5", float_rounding = 3)
  expect_output(print(c_fr), "Float Rounding:\\s+3 decimal places")
  
  # Blosc2 Modifiers
  c_b2 <- h5_compression("blosc2-zstd-5", blosc2_delta = TRUE, blosc2_truncate = 16)
  expect_output(print(c_b2), "Codec:\\s+blosc2-zstd-5")
  expect_output(print(c_b2), "Blosc2 Delta:\\s+TRUE")
  expect_output(print(c_b2), "Blosc2 Trunc:\\s+16 bits")
  
  # Blosc2 without modifiers (covers the nested if bypasses)
  c_b2_bare <- h5_compression("blosc2-zstd-5")
  # Assert it prints normally without throwing errors for missing attributes
  expect_output(print(c_b2_bare), "Codec:\\s+blosc2-zstd-5")
})
