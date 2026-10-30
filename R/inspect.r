
#' Inspect HDF5 Dataset Creation Properties
#'
#' Retrieves the Dataset Creation Property List (DCPL) details including storage 
#' layout, chunk dimensions, and a detailed list of all applied filters.
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the dataset to inspect.
#' @return An object of class `inspect` (a named list) containing:
#'   \item{layout}{A string indicating storage layout (e.g., "chunked", "contiguous").}
#'   \item{chunk_dims}{A numeric vector of chunk dimensions, or `NULL` if not chunked.}
#'   \item{filters}{A list describing each filter applied.}
#'
#' @details
#' ZFP can't compress chunks with no dimension longer than one (such as a
#' single value) or more than four. It then declines the whole dataset: every
#' chunk is stored uncompressed, and `print()` shows the filter as
#' `zfp (declined: stored uncompressed)`. With `hdf5lib` 2.2.0.1 or later,
#' Blosc2's ZFP codecs likewise decline chunks of fewer than four values, shown
#' as, e.g., `blosc2 [zfp-acc] (declined: stored uncompressed)`.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' compress <- h5_compression('lz4-9', int_packing = TRUE, checksum = TRUE)
#' h5_write(matrix(5001:5100, 10, 10), file, "packed_mtx", compress = compress)
#' h5_inspect(file, "packed_mtx")
#' 
#' mtx <- matrix(rnorm(1000), 100, 10)
#' h5_write(mtx, file, "float_mtx", compress = 'blosc2-zfp-prec-3')
#' res <- h5_inspect(file, "float_mtx")
#' print(res)
#' 
#' # Print the raw cd_values for blosc2
#' dput(res$filters[[1]]$cd_values)
#' 
#' unlink(file)
h5_inspect <- function(file, name) {
  file <- validate_strings(file, name, must_exist = TRUE)
  
  if (!h5_is_dataset(file, name)) {
    stop("Target must be a dataset to inspect its DCPL.")
  }
  
  res <- h5_call(.Call("C_h5_inspect", file, name, PACKAGE = "h5lite"))
  
  # Append the 'inspect' class while keeping 'list' for standard subsetting
  class(res) <- c("inspect", "list")
  
  return(res)
}


# Helper to format raw bytes nicely
fmt_bytes <- function(b) {
  if (is.na(b) || b == 0) return("0 B")
  units <- c("B", "KB", "MB", "GB", "TB", "PB", "EB")
  idx   <- max(1, min(7, floor(log(b, 1024)) + 1))
  sprintf("%.2f %s", b / (1024^(idx - 1)), units[idx])
}



#' Print method for HDF5 inspect objects
#'
#' @keywords internal
#' @param x An object of class `inspect`.
#' @param ... Further arguments passed to or from other methods.
#' @export
print.inspect <- function(x, ...) {
  
  cat("<HDF5 Dataset Properties>\n")
  
  # --- Row 1: Type & Size ---
  left_1 <- sprintf("  %-8s %s", "Type:", x$type)
  cat(sprintf("%-30s %-8s %s\n", left_1, "Size:", fmt_bytes(x$uncompressed_size)))
  
  # --- Row 2: Layout & Disk ---
  left_2 <- sprintf("  %-8s %s", "Layout:", x$layout)
  cat(sprintf("%-30s %-8s %s\n", left_2, "Disk:", fmt_bytes(x$storage_size)))
  
  # --- Row 3: Chunks & Ratio ---
  chunk_str <- if (is.null(x$chunk_dims)) "N/A" else paste0("[", paste(format(x$chunk_dims, scientific = FALSE, trim = TRUE), collapse = " x "), "]")
  left_3 <- sprintf("  %-8s %s", "Chunks:", chunk_str)
  
  ratio <- "N/A"
  if (x$storage_size > 0 && x$uncompressed_size > 0) {
    ratio <- sprintf("%.2fx", x$uncompressed_size / x$storage_size)
  }
  cat(sprintf("%-30s %-8s %s\n", left_3, "Ratio:", ratio))
  
  # --- Row 4: The Pipeline ---
  cat("  Pipeline: ")
  if (length(x$filters) == 0) {
    cat("None (Uncompressed)\n")
  } else {
    filter_names <- vapply(x$filters, function(f) {
      fname    <- f$name
      declined <- FALSE

      # 1. Intercept Blosc (Version 1)
      if (fname == "blosc" && length(f$cd_values) >= 7) {
        shuffle  <- f$cd_values[6] # 0: None, 1: Byte, 2: Bit
        compcode <- f$cd_values[7]
        
        internal <- c()
        if (shuffle == 1) internal <- c(internal, "byteshuffle") # nocov
        if (shuffle == 2) internal <- c(internal, "bitshuffle")
        
        # 2. Intercept Blosc2
      } else if (fname == "blosc2" && length(f$cd_values) >= 7) {
        cd       <- f$cd_values
        compcode <- cd[7]
        declined <- cd[5] == 255 # The level hdf5lib records for data ZFP can't take

        # hdf5lib packs its pre-filter bitmask and the truncation bits into
        # cd_values[0] (0xB21.....). Earlier versions (2) kept the bitmask in
        # cd_values[5] and the bits after the chunk shape, or for chunks
        # without one in bits 8-15 of cd_values[5]. Other writers (1) only
        # record the last pre-filter, as a Blosc2 filter code.
        if (cd[1] %/% 2^24 == 0xB2) {
          mask <- cd[1] %/% 2^16 %% 16
          bits <- cd[1] %/% 2^8  %% 256
        } else if (cd[1] == 1) {
          mask <- switch(as.character(cd[6]), "1" = 1, "2" = 2, "3" = 4, "4" = 8, 0)
          bits <- NA
        } else {
          ndim <- if (length(cd) >= 8) cd[8] else 0
          mask <- cd[6] %% 256
          bits <- if (length(cd) >= 9 + ndim) cd[9 + ndim] %% 256 else cd[6] %/% 256 %% 256
        }

        # In the order Blosc2 runs them
        internal <- c()
        if (bitwAnd(mask, 8) > 0) {
          if (isTRUE(bits > 127)) bits <- bits - 256 # Blosc2 reads a signed byte
          internal <- c(internal, if (is.na(bits)) "trunc" else sprintf("trunc(bits=%s)", bits))
        }

        if (bitwAnd(mask, 4) > 0) internal <- c(internal, "delta")

        if (bitwAnd(mask, 2) > 0) {
          internal <- c(internal, "bitshuffle")
        } else if (bitwAnd(mask, 1) > 0) {
          internal <- c(internal, "byteshuffle") # nocov
        }

        # 3. Intercept Bitshuffle
      } else if (fname == "bitshuffle" && length(f$cd_values) >= 5) {
        comp <- f$cd_values[5]
        if (comp == 2) {
          return("bitshuffle -> lz4")
        } else if (comp == 3) {
          return("bitshuffle -> zstd")
        }
        return("bitshuffle") # nocov
        
        # 4. Intercept SZIP
      } else if (fname == "szip" && length(f$cd_values) >= 1) {
        mask <- f$cd_values[1]
        if (bitwAnd(mask, 32) > 0) {
          return("szip-nn")
        } else if (bitwAnd(mask, 4) > 0) {
          return("szip-ec")
        }
        return("szip") # nocov

        # 5. Intercept ZFP that declined the dataset: chunks it can't compress
        #    get no ZFP header (at most 2 values), so it refuses every chunk
      } else if (fname == "zfp" && length(f$cd_values) <= 2) {
        return("zfp (declined: stored uncompressed)")

      } else {
        # Not a dynamically expanded filter, return normal name
        return(fname)
      }
      
      # Decode the internal compressor code (Applies to Blosc and Blosc2)
      codec <- switch(as.character(compcode),
                      "0"  = "blosclz",
                      "1"  = "lz4",
                      "2"  = "lz4hc", 
                      "3"  = "snappy",
                      "4"  = "gzip",
                      "5"  = "zstd",
                      "32" = "ndlz",
                      "33" = "zfp-acc",
                      "34" = "zfp-prec",
                      "35" = "zfp-rate",
                      "36" = "openhtj2k",
                      "37" = "grok",
                      "38" = "openzl",
                      paste0("codec-", compcode))
      
      internal <- c(internal, codec)
      out <- sprintf("%s [%s]", fname, paste(internal, collapse = " -> "))
      if (declined) out <- paste(out, "(declined: stored uncompressed)")
      return(out)
      
    }, FUN.VALUE = character(1))
    
    cat(paste(filter_names, collapse = " -> "), "\n")
  }
  
  invisible(x)
}
