
#' Write an R Object to HDF5
#' 
#' Writes an R object to an HDF5 file, creating the file if it does not exist.
#' This function can write atomic vectors, matrices, arrays, factors, `data.frame`s,
#' and nested `list`s.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset (e.g., "/data/matrix").
#' @param data The R object to write. Supported: `numeric`, `integer`, `complex`, 
#'   `logical`, `character`, `factor`, `raw`, `data.frame`, `NULL`, and nested `list`s.
#' @param dtype The target HDF5 data type. See details.
#' @param compress A logical or an integer from 0-9. If `TRUE`, 
#'   compression level 5 is used. If `FALSE` or `0`, no compression is used. 
#'   An integer `1-9` specifies the zlib compression level directly.
#' @param attrs Controls which R attributes of `data` are written to the HDF5 object.
#'   Can be `FALSE` (the default), `TRUE` (all attributes except `dim`),
#'   a character vector of attribute names to include (e.g., `c("info", "version")`),
#'   or a character vector of names to exclude, prefixed with `-` (e.g., `c("-class")`).
#' 
#' @section Writing Scalars:
#' By default, `h5_write` saves single-element vectors as 1-dimensional arrays.
#' To write a true HDF5 scalar, wrap the value in `I()` to treat it "as-is."
#' For example, `h5_write(file, "x", I(5))` will create a scalar dataset, while
#' `h5_write(file, "x", 5)` will create a 1D array of length 1.
#' 
#' @section Writing Lists:
#' If `data` is a `list` (but not a `data.frame`), `h5_write` will write it
#' recursively, creating a corresponding group and dataset structure.
#' 
#' - R `list` objects are created as HDF5 **groups**.
#' - All other supported R objects (vectors, matrices, arrays, factors, `data.frame`s)
#'   are written as HDF5 **datasets**.
#' - Attributes of a list are written as HDF5 attributes on the corresponding group.
#' - Before writing, a "dry run" is performed to validate that all objects and attributes
#'   within the list are of a writeable type. If any part of the
#'   structure is invalid, the function will throw an error and no data will be
#'   written.
#' 
#' @section Writing NULL:
#' If `data` is `NULL`, `h5_write` will create an HDF5 **null dataset**. This is
#' a dataset with a null dataspace, which contains no data.
#' 
#' @section Writing Data Frames:
#' `data.frame` objects are written as HDF5 **compound datasets**. This is a
#' native HDF5 table-like structure that is highly efficient and portable.
#' 
#' @section Writing Complex Numbers:
#' `h5lite` writes R `complex` objects using the native HDF5 `H5T_COMPLEX`
#' datatype class, which was introduced in HDF5 version 2.0.0. As a result,
#' HDF5 files containing complex numbers written by `h5lite` can only be read
#' by other HDF5 tools that support HDF5 version 2.0.0 or later.
#' 
#' @section Data Type Selection (`dtype`):
#' The `dtype` argument controls the on-disk storage type **for numeric data only**.
#'
#' If `dtype` is set to `"auto"` (the default), `h5lite` will automatically
#' select the most space-efficient HDF5 type for numeric data that can safely
#' represent the full range of values. For example, writing `1:100` will
#' result in an 8-bit unsigned integer (`uint8`) dataset, which helps minimize
#' file size.
#'
#' To override this behavior, you can specify an exact type. The input
#' is case-insensitive and allows for unambiguous partial matching. The full
#' list of supported values is:
#' - `"auto"`, `"float"`, `"double"`
#' - `"float16"`, `"float32"`, `"float64"`
#' - `"int8"`, `"int16"`, `"int32"`, `"int64"`
#' - `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`
#' - `"char"`, `"short"`, `"int"`, `"long"`, `"llong"`
#' - `"uchar"`, `"ushort"`, `"uint"`, `"ulong"`, `"ullong"`
#' 
#' Note: Types without a bit-width suffix (e.g., `"int"`, `"long"`) are system-
#' dependent and may have different sizes on different machines. For maximum file
#' portability, it is recommended to use types with explicit bit-widths (e.g., `"int32"`).
#'
#' For non-numeric data (`character`, `complex`, `factor`, `raw`, and `logical`), the 
#' storage type is determined automatically and **cannot be changed** by the `dtype` 
#' argument. R `logical` vectors are stored as 8-bit unsigned integers (`uint8`),
#' as HDF5 does not have a native boolean datatype.
#' 
#' @section Attribute Round-tripping:
#' To properly round-trip an R object, it is helpful to set `attrs = TRUE`. This
#' preserves important R metadata—such as the `names` of a named vector, `row.names`
#' of a `data.frame`, or the `class` of an object—as HDF5 attributes.
#' 
#' **Limitation**: HDF5 has no direct analog for R's `dimnames`.
#' Attempting to write an object that has `dimnames` (e.g., a named matrix)
#' with `attrs = TRUE` will result in an error. You must either remove the
#' `dimnames` or set `attrs = FALSE`.
#' 
#' @return Invisibly returns `file`. This function is called for its side effects.
#' @seealso [h5_read()], [h5_write_attr()],
#'   `vignette("atomic-vectors", package = "h5lite")`,
#'   `vignette("matrices", package = "h5lite")`,
#'   `vignette("data-frames", package = "h5lite")`,
#'   `vignette("data-organization", package = "h5lite")`,
#'   `vignette("attributes-in-depth", package = "h5lite")`
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
#' h5_write(file, "scalar", I(3.14))
#' 
#' # Write a named vector and preserve its names by setting attrs = TRUE
#' named_vec <- c(a = 1, b = 2)
#' h5_write(file, "named_vector", named_vec, attrs = TRUE)
#' 
#' # Write a nested list, which creates groups and datasets
#' my_list <- list(
#'   config = list(version = 1.2, user = "test"),
#'   data = matrix(1:4, 2)
#' )
#' attr(my_list, "info") <- "Session data"
#' h5_write(file, "session_data", my_list)
#' 
#' h5_ls(file, recursive = TRUE)
#' 
#' unlink(file)
h5_write <- function(file, name, data,
                     dtype = "auto",
                     compress = TRUE,
                     attrs = FALSE) {
  
  if (is_list_group(data)) {
    
    # 1. Dry run: Validate the entire structure before writing anything.
    validate_write_recursive(data, name, attrs)
    
    # 2. Write: If validation passed, perform the recursive write.
    write_recursive(file, name, data, compress, attrs)
    
  } else if (is.null(data)) {
    
    file <- path.expand(file)
    # For NULL, dims is irrelevant, level is 0, and dtype is "null"
    # This signals to C to create an H5S_NULL dataset.
    .Call("C_h5_write_dataset", file, name, data, "null", NULL, 0L, PACKAGE = "h5lite")
    
  }
  
  else {
    
    file  <- path.expand(file)
    level <- if (isTRUE(compress)) 5L else as.integer(compress)
    attrs <- validate_attrs(data, attrs)

    if (is.data.frame(data)) {

      # HDF5 compound types must have at least one member.
      if (ncol(data) == 0) {
        stop("Cannot write a data.frame with zero columns to HDF5.", call. = FALSE)
      }

      dtypes <- sapply(data, validate_dtype)
      .Call("C_h5_write_dataframe", file, name, data, dtypes, level, PACKAGE = "h5lite")

    } else {

      dims  <- validate_dims(data)
      dtype <- validate_dtype(data, dtype)
      .Call("C_h5_write_dataset", file, name, data, dtype, dims, level, PACKAGE = "h5lite")

      # Rule: Ignore user-added 'AsIs' class for scalars.
      if (inherits(data, 'AsIs') && is.null(dims) && !isFALSE(attrs))
        class(data) <- setdiff(class(data), "AsIs")
    }
    
    # If validation passed and attrs is TRUE, write the attributes
    attrs_to_write <- get_attributes_to_write(data, attrs)
    
    for (attr_name in names(attrs_to_write))
      h5_write_attr(file, name, attr_name, attrs_to_write[[attr_name]])
    
  }
  
  invisible(file)
}


#' Recursively write a list for h5_write
#' @noRd
#' @keywords internal
write_recursive <- function(file, name, data, compress, attrs) {
  
  # It's a group (list)
  if (is_list_group(data)) {
    
    # Create the group. This is safe even if it exists.
    h5_create_group(file, name)
    
    # Write the attributes of the list itself to the group.
    group_attrs <- get_attributes_to_write(data, attrs)
    group_attrs[['names']] <- NULL
    for (attr_name in names(group_attrs))
      h5_write_attr(file, name, attr_name, group_attrs[[attr_name]])
    
    # Recursively write each child element.
    for (child_name in names(data)) {
      child_path <- if (name == "/") child_name else paste(name, child_name, sep = "/")
      write_recursive(file, child_path, data[[child_name]], compress, attrs)
    }
    
  } else { # It's a dataset
    h5_write(file, name, data, compress = compress, attrs = attrs)
  }
}


#' Recursively validate a list for h5_write
#' @noRd
#' @keywords internal
validate_write_recursive <- function(data, current_path, attrs) {
  
  dtype <- tryCatch({
    validate_attrs(data, attrs)
    validate_dtype(data)
  }, error = function(e) {
    stop("Validation failed for '", current_path, "': ", e$message, call. = FALSE)
  })
  
  
  # It's a group (list)
  if (dtype == "group") {
    
    # All list elements must be named to be written as groups/datasets.
    if (length(data) > 0) {
      list_names <- names(data)
      if (is.null(list_names) || any(list_names == "")) {
        stop("Validation failed for group '", current_path, 
             "'. All elements in a list must be named.", call. = FALSE)
      }
    }
    
    # Then, recursively validate each child element.
    for (name in names(data)) {
      child_path <- paste(current_path, name, sep = "/")
      validate_write_recursive(data[[name]], child_path, attrs)
    }
    
  }
}


#' Helper to find the smallest fitting data type for numeric data
#' @param data The numeric or integer vector.
#' @return A string representing the best HDF5 data type.
#' @noRd
#' @keywords internal
validate_dtype <- function(data, dtype = "auto") {
  
  assert_valid_object(data)
  
  if (is.null(data))       return ("null")
  if (is.factor(data))     return ("factor")
  if (is.logical(data))    return ("uchar")
  if (is.raw(data))        return ("raw")
  if (is.data.frame(data)) return ("data.frame")
  if (is.character(data))  return ("character")
  if (is.list(data))       return ("group")
  if (is.complex(data))    return ("complex")
  
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
  # If data is empty, it has no non-finite values.
  if (length(data) == 0) return("double")
  
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


validate_dims <- function (data) {
  
  # If data is wrapped in I(), treat as a scalar (NULL dims) but ONLY if it's length 1.
  # This prevents accidentally writing a multi-element 'AsIs' vector as a scalar, which would cause data loss.
  if (inherits(data, 'AsIs')) {
    if (length(data) == 1) {
      return(NULL)
    } else {
      warning("I() wrapper ignored for vector of length > 1. Writing as a 1D array.")
    }
  }
  
  # Otherwise, infer dimensions from the object.
  if (is.null(dim(data))) length(data) else dim(data)
}


is_list_group <- function (data) {
  return (is.list(data) && !is.data.frame(data))
}


# Includes lists
assert_valid_object <- function (data) {
  
  # NULL
  if (is.null(data)) return (NULL)

  # logical, integer, numeric, complex, character, raw, factor
  if (is.atomic(data)) return (NULL)
  
  # list, data.frame
  if (is.list(data)) return (NULL)
  
  stop("Cannot map R type to HDF5 object: '", typeof(data), "'")
}


# Excludes lists
assert_valid_dataset <- function (data) {
  
  assert_valid_object(data)
  
  if (is_list_group(data))
    stop("Cannot map R type to HDF5 dataset: 'list'")
  
  invisible(NULL)
}
