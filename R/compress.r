
#' Define HDF5 Compression and Filter Settings
#' 
#' Constructs a comprehensive filter pipeline configuration to be passed 
#' as the `compress` argument to [h5_write()]. This function allows fine-grained 
#' control over chunking, pre-filters, compression algorithms, and data scaling.
#'
#' @param compress A string specifying the compression algorithm and optional level 
#'   (e.g., `"none"`, `"gzip"`, `"zstd-7"`, `"lz4"`, `"blosc1-lz4-9"`, 
#'   `"blosc2-gzip-3"`, `"blosc2-zstd"`). See the **Valid Compression Strings** 
#'   section below for an exhaustive list of supported formats. Default is `"gzip"`.
#' @param chunk_size An integer specifying the target chunk size in bytes. 
#'   Default is `1048576` (1 MB).
#' @param checksum A logical value indicating whether to apply the Fletcher32 
#'   checksum filter at the end of the pipeline to detect data corruption. Default is `FALSE`.
#' @param int_packing Control the HDF5 Scale-Offset filter for integer datasets. *(Note: 
#'   Incompatible with `szip`, `zfp`, `bshuf`, and Blosc2 pre-filters).*
#'   * `FALSE` (Default): Disabled.
#'   * `TRUE`: Automatically calculates and applies the mathematically optimal minimum 
#'     bit-width for each individual chunk.
#'   * Integer (e.g., `8`): Forces packing into exactly that many bits.
#' @param float_rounding Control the HDF5 Scale-Offset filter for floating-point
#'   datasets.*(Note: Incompatible with `szip`, `zfp`, `bshuf`, and Blosc2 pre-filters.
#'   Not applied to `float16`/`bfloat16` data.)*
#'   * `NULL` (Default): Disabled.
#'   * Integer (e.g., `3`): The number of base-10 decimal places of detail to preserve 
#'     before truncating and packing the values (e.g., `3.141`). Negative numbers 
#'     round to powers of 10.
#' @param blosc2_delta A logical value. If `TRUE` and a `blosc2` compressor is selected,
#'   applies the Blosc2 Delta pre-filter before compression. Default is `FALSE`.
#'   `"blosc2-ndlz"` and `"blosc2-zfp-..."` run no pre-filters.
#' @param blosc2_truncate An integer. If provided and a `blosc2` compressor is selected,
#'   applies the Blosc2 Truncate Precision pre-filter to floating-point data, keeping
#'   that many bits of each value's mantissa (`1` to `52`), or with a negative
#'   number dropping that many (`-1` to `-51`). Default is `NULL`. It is
#'   not applied to integers, data frames, `float16`/`bfloat16` data, data
#'   containing `NA` or `NaN`, or `float32` data when it would drop 23 bits or
#'   more (a `float32`'s whole mantissa). `"blosc2-ndlz"` and `"blosc2-zfp-..."`
#'   run no pre-filters.
#' 
#' @section Valid Compression Strings:
#' The `compress` argument accepts a highly specific string syntax to define both 
#' the codec and its operational level.
#' 
#' ### Native / Core Codecs
#' 
#' * `"none"`: No compression.
#' * `"gzip-[level]"`: Levels `1` to `9`. Default is `5`. (e.g., `"gzip"` or `"gzip-9"`).
#' * `"zstd-[level]"`: Levels `1` to `22`. Default is `3`. (e.g., `"zstd"` or `"zstd-7"`).
#' * `"lz4-[level]"`: Levels `0` to `12`. Default is `0`. Level `0` is standard LZ4. Levels `1+` trigger LZ4-HC.
#' 
#' ### Bitshuffle Pre-filter
#' Forces the native Bitshuffle pre-filter before compression.
#' 
#' * `"bshuf-lz4"`: Bitshuffle + LZ4.
#' * `"bshuf-zstd-[level]"`: Bitshuffle + Zstd (Levels `1` to `22`).
#' 
#' ### Blosc Meta-compressors
#' Blosc applies its own highly optimized bitshuffling and multi-threading.
#' 
#' * **Blosc2 (Recommended):** `"blosc2"` (blosclz), `"blosc2-lz4-[level]"`, `"blosc2-zstd-[level]"`, `"blosc2-gzip-[level]"`, `"blosc2-ndlz"`
#' * **Blosc1 (Legacy):**  `"blosc1"` (blosclz), `"blosc1-lz4-[level]"`, `"blosc1-zstd-[level]"`, `"blosc1-gzip-[level]"`, `"blosc1-snappy"`
#' 
#' ### ZFP (Lossy Floating-Point Compression)
#' ZFP can be run standalone (for integers and floats) or inside Blosc2 (floats only). Unlike `[level]`, `[tolerance]` and `[bits]` are required.
#' 
#' * **Accuracy Mode** (Absolute error tolerance): `"zfp-acc-[tolerance]"` or `"blosc2-zfp-acc-[tolerance]"` (e.g., `"zfp-acc-0.001"`).
#' * **Precision Mode** (Bits of precision): `"zfp-prec-[bits]"` or `"blosc2-zfp-prec-[bits]"` (e.g., `"zfp-prec-16"`).
#' * **Rate Mode** (Bits of storage per value): `"zfp-rate-[bits]"` or `"blosc2-zfp-rate-[bits]"` (e.g., `"zfp-rate-8"`).
#' * **Reversible Mode** (Standalone Lossless): `"zfp-rev"`.
#' 
#' ### Legacy Codecs
#' 
#' * `"szip-nn"`, `"szip-ec"`: SZIP Nearest Neighbor or Entropy Coding.
#' * `"bzip2-[level]"`: Levels `1` to `9`. Default is `9`. (e.g., `"bzip2-4"`).
#' * `"lzf"`, `"snappy"`: Fast, unconfigurable legacy compressors.
#' 
#' @section Automatic Shuffling:
#' 
#' To maximize compression ratios without requiring users to manually manage 
#' complex pipeline interactions, `h5_compression` automatically configures the 
#' optimal shuffling pre-filter based on the following strict hierarchy:
#' 
#' **1. Blosc's Internal Bitshuffle (Preferred)**
#' If a Blosc meta-compressor is selected (e.g., `"blosc2-zstd"`), the pipeline 
#' automatically enables Blosc's highly optimized, internal bitshuffle routine. 
#' This achieves peak compression performance without requiring the standalone 
#' Bitshuffle plugin to be installed.
#' 
#' **2. Explicit Bitshuffle Plugin**
#' If a standard codec is explicitly prefixed with `bshuf-` (e.g., `"bshuf-lz4"`), 
#' the pipeline delegates to the standalone Bitshuffle plugin.
#' 
#' **3. Native HDF5 Byte Shuffle (Fallback)**
#' If a standard compressor is selected (e.g., `"zstd-5"` or `"gzip"`), 
#' the pipeline safely falls back to the core HDF5 library's native byte shuffle 
#' filter. This guarantees improved compression while maintaining universal 
#' compatibility.
#' 
#' **4. Strict Mutual Exclusions (When Shuffling is Disabled)**
#' To prevent data corruption or wasted CPU cycles, all shuffling is 
#' **forcefully disabled** in the following scenarios:
#' 
#' * **Scale-Offset Active:** If `int_packing` or `float_rounding` is applied, 
#'   shuffling is disabled because scale-offset destroys the byte-alignment 
#'   that shuffling relies on.
#' * **ZFP & SZIP:** These algorithms perform mathematical compression directly 
#'   on numerical values and will corrupt if the bitstream is rearranged beforehand.
#' * **1-Byte Data:** Characters, booleans, and 8-bit integers cannot be meaningfully 
#'   shuffled, so the step is skipped.
#' 
#' @return An S3 object of class `compress` containing the parsed pipeline parameters.
#' @seealso [h5_write()], `vignette('compression')`
#' @export
#' @examples
#' # 1. Simple fast compression (Zstd level 7)
#' h5_compression("zstd-7")
#' 
#' # 2. Optimal integer packing (Scale-Offset)
#' h5_compression("gzip-9", int_packing = TRUE)
#' 
#' # 3. Complex Blosc2 Pipeline (Delta + Zstd)
#' h5_compression("blosc2-zstd-5", blosc2_delta = TRUE)
#' 
#' # 4. Lossy ZFP compression (Tolerance of 0.05)
#' h5_compression("zfp-acc-0.05")
#' 
#' # Pass the compress object directly to h5_write
#' file <- tempfile(fileext = ".h5")
#' cmp  <- h5_compression("gzip-9", checksum = TRUE)
#' h5_write(combn(1:10, 3), file, "sets", compress = cmp)
#' 
#' print(cmp)
#' 
#' h5_inspect(file, "sets")
#' 
#' # Clean up
#' unlink(file)
#' 
h5_compression <- function(
    compress = "gzip", chunk_size = 1024 * 1024, checksum = FALSE, 
    int_packing = FALSE, float_rounding = NULL,
    blosc2_delta = FALSE, blosc2_truncate = NULL ) {
  
  if (inherits(compress, 'compress'))           return(compress)
  if (isTRUE(compress))                          compress <- "gzip"
  if (is.numeric(compress) && compress %in% 1:9) compress <- paste0("gzip-", compress)
  if (!is.character(compress))                   compress <- "none"
  compress <- tolower(trimws(compress))
  
  # 1. Handle polymorphic int_packing
  if      (identical(int_packing, FALSE)) { int_packing <- NA_integer_ }
  else if (identical(int_packing, TRUE))  { int_packing <- 0L          }
  else if (!(is.numeric(int_packing) && isTRUE(int_packing %% 1 == 0)))
    stop("`int_packing` must be TRUE/FALSE or an integer.", call. = FALSE)

  assert_scalar_character(compress)
  assert_scalar_logical(checksum, blosc2_delta)
  assert_scalar_integer(chunk_size)
  assert_scalar_integer(float_rounding, blosc2_truncate, .null_ok = TRUE)

  # Check string format against known valid patterns
  if (!any(
      grepl('^(gzip|zstd|lz4|bshuf-zstd|bzip2)(\\-[0-9]+)?$',              compress),
      grepl('^(none|zfp-rev|bshuf-lz4|szip-ec|szip-nn|lzf|snappy)$',       compress),
      grepl('^blosc1(\\-(snappy|(lz4|gzip|zstd)(\\-[0-9]+)?))?$',          compress),
      grepl('^blosc2(\\-(ndlz|(lz4|gzip|zstd)(\\-[0-9]+)?))?$',            compress),
      grepl('^(blosc2\\-)?zfp\\-((prec|rate)\\-[0-9]+|acc\\-[0-9\\.]+)$',  compress) )) {
    stop("Invalid `compress` string: '", compress, "'.", call. = FALSE)
  }
  
  blosc <- switch(substr(compress, 1, 6), 'blosc1' = 1L, 'blosc2' = 2L, 0L)

  # Extract the base codec name
  codecs <- c(
    'gzip', 'none', 'bshuf-lz4', 'bshuf-zstd', 'lz4', 'zstd', 
    'bzip2', 'lzf', 'zfp-rev', 'zfp-prec', 'zfp-acc', 'zfp-rate', 
    'szip-ec', 'szip-nn', 'snappy', 'ndlz', 'blosclz')
  for (codec in codecs)
    if (isTRUE(grepl(codec, compress, fixed = TRUE))) break
  
  # Parse the level, applying sensible defaults
  level_str <- rev(strsplit(compress, "-")[[1]])[[1]]
  level <- suppressWarnings(as.numeric(level_str))
  
  if (is.na(level)) {
    level <- switch(codec, 'gzip' = 5, 'zstd' = 3, 'bshuf-zstd' = 3, 'bzip2' = 9, 'lz4' = 0, 0)
  } else {
    rng <- switch(codec, 
      'gzip' = c(1, 9), 'bzip2' = c(1, 9), 'lz4' = c(0, 12), 
      'zstd' = c(1, 22), 'bshuf-zstd' = c(1, 22), NULL)
    
    if (!is.null(rng) && (!isTRUE(level %% 1 == 0) || level < rng[[1]] || level > rng[[2]])) {
      stop(compress, " level must be an integer between ", rng[[1]]," and ", rng[[2]], ".", call. = FALSE)
    }
  }

  # A zero tolerance or rate has no meaning (and no logarithm for Blosc2)
  if (codec %in% c("zfp-acc", "zfp-rate") && !isTRUE(level > 0))
    stop("`", compress, "` needs a ", if (codec == "zfp-acc") "tolerance" else "rate",
         " greater than 0.", call. = FALSE)

  if (is.null(float_rounding))  float_rounding  <- NA
  if (is.null(blosc2_truncate)) blosc2_truncate <- NA

  # A float64 mantissa has 52 bits, all of which can't be dropped
  if (!is.na(blosc2_truncate) && (blosc2_truncate == 0 || blosc2_truncate < -51 || blosc2_truncate > 52))
    stop("`blosc2_truncate` must be between -51 and 52, and not 0.", call. = FALSE)

  for (var in c('int_packing', 'float_rounding'))
    if (!is.na(get(var))) {
      if (grepl('(szip|zfp|bshuf)', codec)) stop("`", var, "` is not compatible with `", codec, "`.",     call. = FALSE)
      if (!is.na(blosc2_truncate))          stop("`", var, "` is not compatible with `blosc2_truncate`.", call. = FALSE)
      if (isTRUE(blosc2_delta))             stop("`", var, "` is not compatible with `blosc2_delta`.",    call. = FALSE)
    }

  structure(
    .Data = compress,
    class = 'compress',
    codec          = as.character(codec),
    level          = as.double(level),
    blosc          = as.integer(blosc), 
    int_packing    = as.integer(int_packing),
    float_rounding = as.integer(float_rounding),
    chunk_size     = as.integer(chunk_size), 
    checksum       = as.logical(checksum),
    b2_delta       = as.logical(blosc2_delta), 
    b2_trunc       = as.integer(blosc2_truncate)
  )
}

#' Set the Number of Threads
#'
#' Sets how many threads `h5lite` uses for the work it can do in parallel.
#' Currently that is the Blosc and Blosc2 codecs (`"blosc1-..."` and
#' `"blosc2-..."`), which compress and decompress the blocks of each chunk in
#' parallel. Everything uses one thread unless you ask for more.
#'
#' @param n The number of threads, from `1` to `256`, or `0` to return to the
#'   default. If `NULL` (the default), the setting is left unchanged.
#'
#' @details
#' More threads help most when compression is slow, as with high Zstandard
#' levels, or when chunks are large. The setting applies to `h5lite` for the
#' rest of the R session.
#'
#' The default is one thread, or the value of the `H5LITE_NTHREADS`
#' environment variable if it is set. Calling `h5_threads()` overrides it.
#'
#' Threads need `hdf5lib` 2.2.0.1 or later. When `h5lite` is built with
#' `hdf5lib` 2.2.0.0, Blosc always uses one thread, whatever the setting.
#'
#' CRAN allows packages to use at most two threads in their examples, tests,
#' and vignettes.
#'
#' @return With `n = NULL`, the number of threads `h5lite` will use.
#'   Otherwise, the previous setting, invisibly (`0` if none had been made).
#' @seealso [h5_compression()], `vignette('compression')`
#' @export
#' @examples
#' h5_threads()      # 1
#'
#' old <- h5_threads(2)
#' file <- tempfile(fileext = ".h5")
#' h5_write(rnorm(1e5), file, "x", compress = "blosc2-zstd-5")
#'
#' h5_threads(old)   # Restore the previous setting
#' unlink(file)
h5_threads <- function(n = NULL) {

  if (is.null(n)) return (h5_call(.Call("C_h5_threads", NULL, PACKAGE = "h5lite")))

  assert_scalar_integer(n)
  if (n < 0 || n > 256)
    stop("`n` must be between 0 and 256.", call. = FALSE)

  invisible(h5_call(.Call("C_h5_threads", as.integer(n), PACKAGE = "h5lite")))
}


#' Drop lossy filters that would corrupt non-finite values
#'
#' ZFP and floating-point Scale-Offset cannot represent `NA`, `NaN`, or `Inf`:
#' they come back as arbitrary numbers. Blosc2's truncation zeroes the bits
#' that tell `NA` apart from `NaN`, and can turn `NA` into `Inf`. Data
#' containing them is written with the default gzip pipeline instead of ZFP,
#' and without `float_rounding` or `blosc2_truncate`. (hdf5lib 2.2.0.1's ZFP
#' refuses just the chunks holding them, but 2.2.0.0's compresses them anyway.)
#' @noRd
#' @keywords internal
protect_nonfinite <- function(data, compress) {

  if (!(is.numeric(data) || is.logical(data))) return(compress)

  if (startsWith(attr(compress, "codec"), "zfp") && !all(is.finite(data)))
    compress <- h5_compression(
      compress   = "gzip",
      chunk_size = attr(compress, "chunk_size"),
      checksum   = attr(compress, "checksum") )

  if (!is.na(attr(compress, "float_rounding")) && !all(is.finite(data)))
    attr(compress, "float_rounding") <- NA_integer_

  if (!is.na(attr(compress, "b2_trunc")) && anyNA(data))
    attr(compress, "b2_trunc") <- NA_integer_

  compress
}

#' @keywords internal
#' @export
print.compress <- function(x, ...) {
  
  codec <- attr(x, "codec")
  lvl   <- attr(x, "level")
  blosc <- attr(x, "blosc")
  ip    <- attr(x, "int_packing")
  fr    <- attr(x, "float_rounding")
  
  # Construct the codec, size, and checksum strings
  codec_str <- codec
  if (blosc > 0) codec_str <- paste0("blosc", blosc, "-", codec_str)
  if (grepl('(gzip|zstd|lz4|bzip2|zfp)', codec)) codec_str <- paste0(codec_str, "-", lvl)
  codec_str <- sub('lz4-0', 'lz4', codec_str)
  
  size_str     <- fmt_bytes(attr(x, "chunk_size"))
  checksum_str <- if (attr(x, "checksum")) "Fletcher32" else "None"
  
  # Determine Shuffle Filter Logic
  is_scaled <- !is.na(ip) || !is.na(fr)
  
  if      (codec == "none")        { shuffle_str <- "None"                            }
  else if (is_scaled)              { shuffle_str <- "None (Disabled by Scale-Offset)" }
  else if (grepl("^szip",  codec)) { shuffle_str <- "None (Incompatible with szip)"   }
  else if (grepl("^zfp",   codec)) { shuffle_str <- "None (Incompatible with zfp)"    }
  else if (grepl("^bshuf", codec)) { shuffle_str <- "Bitshuffle (Standalone Plugin)"  }
  else if (codec == "ndlz")        { shuffle_str <- "None (NDLZ works on raw bytes)"  }
  else if (blosc > 0)              { shuffle_str <- "Bitshuffle (Blosc Internal)"     }
  else                             { shuffle_str <- "Byte Shuffle (Native HDF5)"      }
  
  # Print Configuration
  cat("<HDF5 Compression Configuration>\n")
  cat(sprintf("  %-16s %s\n", "Codec:",      codec_str))
  cat(sprintf("  %-16s %s\n", "Shuffle:",    shuffle_str))
  cat(sprintf("  %-16s %s\n", "Chunk Size:", size_str))
  cat(sprintf("  %-16s %s\n", "Checksum:",   checksum_str))
  
  # Optional: Scale-Offset Modifiers
  if (!is.na(ip)) {
    val <- if (ip == 0) "Optimal (Auto)" else paste(ip, "bits")
    cat(sprintf("  %-16s %s\n", "Int Packing:", val))
  }
  
  if (!is.na(fr)) {
    cat(sprintf("  %-16s %s decimal places\n", "Float Rounding:", fr))
  }
  
  # Optional: Blosc2 Modifiers
  if (blosc == 2) {
    b2_d <- attr(x, "b2_delta")
    b2_t <- attr(x, "b2_trunc")
    if (isTRUE(b2_d)) cat(sprintf("  %-16s %s\n", "Blosc2 Delta:", "TRUE"))
    if (!is.na(b2_t)) cat(sprintf("  %-16s %s bits\n", "Blosc2 Trunc:", b2_t))
  }
  
  invisible(x)
}
