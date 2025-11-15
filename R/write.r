#' Helper to find the smallest fitting data type for numeric data
#' @param data The numeric or integer vector.
#' @return A string representing the best HDF5 data type.
#' @keywords internal
get_best_dtype <- function(data, dtype) {
  
  if (is.factor(data))   return ("factor")
  if (is.logical(data))  return ("uchar")
  if (!is.numeric(data)) return (typeof(data))

  # Validate dtype against the list of supported types in the C code
  supported_dtypes <- c("auto", "float", "double",  
                        "float16", "float32", "float64", 
                        "int8", "int16", "int32", "int64", 
                        "uint8", "uint16", "uint32", "uint64", 
                        "char", "short", "int", "long", "llong", 
                        "uchar", "ushort", "uint", "ulong", "ullong" )
  
  dtype <- match.arg(tolower(dtype), supported_dtypes)
  if (dtype != "auto") return(dtype)

  # NA, NaN, Inf, or fractional components require double data type.
  if (any(!is.finite(data)) || (is.double(data) && any(data %% 1 != 0))) {
    return("double")
  }
  
  # It's integer data. Find the range.
  val_range <- range(data)
  min_val <- val_range[1]
  max_val <- val_range[2]
  
  # R's doubles can precisely represent integers up to 2^53.
  # This is our effective upper bound for integer checks.
  max_safe_int <- 2^53
  
  if (min_val >= 0) {
    # Unsigned integers
    if (max_val <= 255) "uint8"
    else if (max_val <= 65535) "uint16"
    else if (max_val <= 4294967295) "uint32"
    else if (max_val <= max_safe_int) "uint64"
    else "float64" # Too large, store as double
  } else {
    # Signed integers
    if (min_val >= -128 && max_val <= 127) "int8"
    else if (min_val >= -32768 && max_val <= 32767) "int16"
    else if (min_val >= -2147483648 && max_val <= 2147483647) "int32"
    else if (min_val >= -max_safe_int && max_val <= max_safe_int) "int64"
    else "float64" # Too large, store as double
  }
}

#' Write a Dataset to HDF5
#' 
#' Writes an R object to an HDF5 file as a dataset. The file is created if 
#' it does not exist. Handles dimension transposition automatically.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset (e.g., "/data/matrix").
#' @param data The R object to write. Supported: \code{numeric}, \code{integer},
#'   \code{logical}, \code{character}, \code{raw}.
#' @param dtype The target HDF5 data type. Defaults to \code{typeof(data)}.
#' @details
#' The `dtype` argument controls the on-disk storage type **for numeric data only**.
#'
#' If `dtype` is set to `"auto"` (the default), `h5lite` will automatically
#' select the most space-efficient type for numeric data that can safely
#' represent the full range of values. For example, writing `1:100` will
#' result in an 8-bit unsigned integer (`uint8`) dataset, which helps minimize
#' file size.
#'
#' To override this for numeric data, you can specify an exact type. The input
#' is case-insensitive and allows for unambiguous partial matching. The full
#' list of supported values is:
#' * `"auto"`, `"float"`, `"double"`
#' * `"float16"`, `"float32"`, `"float64"`
#' * `"int8"`, `"int16"`, `"int32"`, `"int64"`
#' * `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`
#' * `"char"`, `"short"`, `"int"`, `"long"`, `"llong"`
#' * `"uchar"`, `"ushort"`, `"uint"`, `"ulong"`, `"ullong"`
#' 
#' Note: Types without a bit-width suffix (e.g., `"int"`, `"long"`) are system-
#' dependent and may have different sizes on different machines. For maximum file
#' portability, it is recommended to use types with explicit widths (e.g., `"int32"`).
#'
#' For non-numeric data (`character`, `factor`, `raw`, `logical`), the storage
#' type is determined automatically and **cannot be changed** by the `dtype`
#' argument. R `logical` vectors are stored as 8-bit unsigned integers (`uint8`),
#' as HDF5 does not have a native boolean datatype.
#'
#' @param dims An integer vector specifying dimensions, or \code{NULL} for a scalar.
#'   Defaults to \code{dim(data)} if it exists, or \code{length(data)} otherwise.
#' @param compress A logical or an integer from 0-9. If `TRUE`, 
#'   compression level 5 is used. If `FALSE` or `0`, no compression is used. 
#'   An integer `1-9` specifies the zlib compression level directly.
#' @return Invisibly returns \code{NULL}. This function is called for its side effects.
#' @seealso [h5_write_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Write a simple vector (dtype is auto-detected as uint8)
#' h5_write(file, "vec1", 1:20)
#' h5_typeof(file, "vec1") # "uint8"
#' 
#' # Write a matrix, letting h5_write determine dimensions
#' mat <- matrix(rnorm(12), nrow = 4, ncol = 3)
#' h5_write(file, "group/mat", mat)
#' h5_dim(file, "group/mat") # c(4, 3)
#' 
#' # Overwrite the first vector, forcing a 32-bit integer type
#' h5_write(file, "vec1", 101:120, dtype = "int32")
#' h5_typeof(file, "vec1") # "int32"
#' 
#' # Write a scalar value
#' h5_write(file, "scalar", 3.14, dims = NULL)
#' 
#' unlink(file)
h5_write <- function(file, name, data,
                     dtype = "auto",
                     dims = length(data),
                     compress = TRUE) {
  
  file  <- path.expand(file)
  dtype <- get_best_dtype(data, dtype)
  level <- if (isTRUE(compress)) 5L else as.integer(compress)
  if (missing(dims) && !is.null(dim(data))) dims <- dim(data)
  
  .Call("C_h5_write_dataset", file, name, data, dtype, dims, level, PACKAGE = "h5lite")
  invisible(NULL)
}

#' Write an Attribute to HDF5
#' 
#' Writes an R object as an attribute to an existing HDF5 object.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the object to attach the attribute to (e.g., "/data").
#' @param attribute The name of the attribute to create.
#' @param data The R object to write. Supported: \code{numeric}, \code{integer},
#'   \code{logical}, \code{character}, \code{raw}.
#' @param dtype The target HDF5 data type. Defaults to \code{typeof(data)}.
#' @details The `dtype` argument controls the on-disk storage type **for numeric
#'   data only**.
#'
#' If `dtype` is set to `"auto"` (the default), `h5lite` will automatically
#' select the most space-efficient type for numeric data that can safely
#' represent the full range of values. For example, writing `1:100` will
#' result in an 8-bit unsigned integer (`uint8`) attribute.
#' 
#' To override this for numeric data, you can specify an exact type. The input
#' is case-insensitive and allows for unambiguous partial matching. The full
#' list of supported values is:
#' * `"auto"`, `"float"`, `"double"`
#' * `"float16"`, `"float32"`, `"float64"`
#' * `"int8"`, `"int16"`, `"int32"`, `"int64"`
#' * `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`
#' * `"char"`, `"short"`, `"int"`, `"long"`, `"llong"`
#' * `"uchar"`, `"ushort"`, `"uint"`, `"ulong"`, `"ullong"`
#' 
#' Note: Types without a bit-width suffix (e.g., `"int"`, `"long"`) are system-
#' dependent and may have different sizes on different machines. For maximum file
#' portability, it is recommended to use types with explicit widths (e.g., `"int32"`).
#'
#' For non-numeric data (`character`, `factor`, `raw`, `logical`), the storage
#' type is determined automatically and **cannot be changed** by the `dtype`
#' argument. R `logical` vectors are stored as 8-bit unsigned integers (`uint8`),
#' as HDF5 does not have a native boolean datatype.
#' 
#' @param dims An integer vector specifying dimensions, or \code{NULL} for a scalar.
#'   Defaults to \code{dim(data)} or \code{length(data)}.
#' @return Invisibly returns \code{NULL}. This function is called for its side effects.
#' @seealso [h5_write()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # First, create an object to attach attributes to
#' h5_write(file, "my_data", 1:10)
#' 
#' # Write a scalar string attribute
#' h5_write_attr(file, "my_data", "units", "meters", dims = NULL)
#' 
#' # Write a numeric vector attribute
#' h5_write_attr(file, "my_data", "range", c(0, 100))
#' 
#' # List attributes to confirm they were written
#' h5_ls_attr(file, "my_data")
#' 
#' unlink(file)
h5_write_attr <- function(file, name, attribute, data, 
                          dtype = "auto", 
                          dims = length(data)) {
  
  file <- path.expand(file)
  if (!file.exists(file)) {
    stop("File must exist to write attributes: ", file)
  }
  
  dtype <- get_best_dtype(data, dtype)
  
  if (missing(dims) && !is.null(dim(data))) dims <- dim(data)
  
  .Call("C_h5_write_attribute", file, name, attribute, data, dtype, dims, PACKAGE = "h5lite")
  invisible(NULL)
}

#' Create an HDF5 Group
#' 
#' Explicitly creates a new group (or nested groups) in an HDF5 file.
#' This is useful for creating an empty group structure.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the group to create (e.g., "/g1/g2").
#' @return Invisibly returns \code{NULL}. This function is called for its side effects.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_create_group(file, "/my/nested/group")
#' 
#' # List all objects recursively to see the full structure
#' h5_ls(file, recursive = TRUE)
#' unlink(file)
h5_create_group <- function(file, name) {
  file <- path.expand(file)
  .Call("C_h5_create_group", file, name, PACKAGE = "h5lite")
  invisible(NULL)
}
