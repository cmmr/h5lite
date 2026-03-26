
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
#'   datasets.*(Note: Incompatible with `szip`, `zfp`, `bshuf`, and Blosc2 pre-filters).*
#'   * `NULL` (Default): Disabled.
#'   * Integer (e.g., `3`): The number of base-10 decimal places of detail to preserve 
#'     before truncating and packing the values (e.g., `3.141`). Negative numbers 
#'     round to powers of 10.
#' @param blosc2_delta A logical value. If `TRUE` and a `blosc2` compressor is selected, 
#'   applies the Blosc2 Delta pre-filter before compression. Default is `FALSE`.
#' @param blosc2_truncate An integer. If provided and a `blosc2` compressor is selected, 
#'   applies the Blosc2 Truncate Precision pre-filter to floating-point data, preserving 
#'   exactly the specified number of uncompressed bits. Default is `NULL`.
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

  if (is.null(float_rounding))  float_rounding  <- NA
  if (is.null(blosc2_truncate)) blosc2_truncate <- NA

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
