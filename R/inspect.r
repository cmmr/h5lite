

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
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' compress <- h5_compression('lz4-9', int_packing = TRUE, checksum = TRUE)
#' h5_write(matrix(5001:5100, 10, 10), file, "packed_mtx", compress = compress)
#' h5_inspect(file, "packed_mtx")
#' #> <HDF5 Dataset Properties>
#' #>   Type:    uint16              Size:    200.00 B
#' #>   Layout:  chunked             Disk:    120.00 B
#' #>   Chunks:  [10 x 10]           Ratio:   1.67x
#' #>   Pipeline: scaleoffset -> lz4 -> fletcher32
#' 
#' mtx <- matrix(rnorm(1000), 100, 10)
#' h5_write(mtx, file, "float_mtx", compress = 'blosc2-zfp-prec-3')
#' res <- h5_inspect(file, "float_mtx")
#' print(res)
#' #> <HDF5 Dataset Properties>
#' #>   Type:    float64             Size:    7.81 KB
#' #>   Layout:  chunked             Disk:    1.49 KB
#' #>   Chunks:  [100 x 10]          Ratio:   5.23x
#' #>   Pipeline: blosc2 [zfp-prec]
#' 
#' # Print the raw cd_values for blosc2
#' dput(res$filters[[1]]$cd_values)
#' #> c(2L, 0L, 8L, 8000L, 3L, 0L, 34L, 2L, 100L, 10L, 3L)
#' 
#' unlink(file)
h5_inspect <- function(file, name) {
  file <- validate_strings(file, name, must_exist = TRUE)
  
  if (!h5_is_dataset(file, name)) {
    stop("Target must be a dataset to inspect its DCPL.")
  }
  
  res <- .Call("C_h5_inspect", file, name, PACKAGE = "h5lite")
  
  # Append the 'inspect' class while keeping 'list' for standard subsetting
  class(res) <- c("inspect", "list")
  
  return(res)
}




#' Print method for HDF5 inspect objects
#'
#' @rdname h5_inspect
#' @param x An object of class `inspect`.
#' @param ... Further arguments passed to or from other methods.
#' @export
print.inspect <- function(x, ...) {
  # Helper to format raw bytes nicely
  fmt_bytes <- function(b) {
    if (is.na(b) || b == 0) return("0 B")
    units <- c("B", "KB", "MB", "GB", "TB")
    idx <- max(1, min(5, floor(log(b, 1024)) + 1))
    sprintf("%.2f %s", b / (1024^(idx - 1)), units[idx])
  }
  
  cat("<HDF5 Dataset Properties>\n")
  
  # --- Row 1: Type & Size ---
  left_1 <- sprintf("  %-8s %s", "Type:", x$type)
  cat(sprintf("%-30s %-8s %s\n", left_1, "Size:", fmt_bytes(x$uncompressed_size)))
  
  # --- Row 2: Layout & Disk ---
  left_2 <- sprintf("  %-8s %s", "Layout:", x$layout)
  cat(sprintf("%-30s %-8s %s\n", left_2, "Disk:", fmt_bytes(x$storage_size)))
  
  # --- Row 3: Chunks & Ratio ---
  chunk_str <- if (is.null(x$chunk_dims)) "N/A" else paste0("[", paste(x$chunk_dims, collapse = " x "), "]")
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
      fname <- f$name
      
      # 1. Intercept Blosc (Version 1)
      if (fname == "blosc" && length(f$cd_values) >= 7) {
        shuffle  <- f$cd_values[6] # 0: None, 1: Byte, 2: Bit
        compcode <- f$cd_values[7]
        
        internal <- c()
        if (shuffle == 1) internal <- c(internal, "byteshuffle") # nocov
        if (shuffle == 2) internal <- c(internal, "bitshuffle")
        
        # 2. Intercept Blosc2
      } else if (fname == "blosc2" && length(f$cd_values) >= 7) {
        mask     <- f$cd_values[6] # Bitmask pre-filters
        compcode <- f$cd_values[7]
        
        internal <- c()
        if (bitwAnd(mask, 2) > 0) {
          internal <- c(internal, "bitshuffle")
        } else if (bitwAnd(mask, 1) > 0) {
          internal <- c(internal, "byteshuffle") # nocov
        }
        
        if (bitwAnd(mask, 4) > 0) internal <- c(internal, "delta")
        
        if (bitwAnd(mask, 8) > 0) {
          ndim <- if (length(f$cd_values) >= 8) f$cd_values[8] else 0
          meta_idx <- 8 + ndim + 1
          meta_val <- if (length(f$cd_values) >= meta_idx) f$cd_values[meta_idx] else "?"
          internal <- c(internal, sprintf("trunc(bits=%s)", meta_val))
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
      return(sprintf("%s [%s]", fname, paste(internal, collapse = " -> ")))
      
    }, FUN.VALUE = character(1))
    
    cat(paste(filter_names, collapse = " -> "), "\n")
  }
  
  invisible(x)
}
