
#' Write an R Object to HDF5
#' 
#' Writes an R object to an HDF5 file, creating the file if it does not exist.
#' This function can write atomic vectors, matrices, arrays, factors, `data.frame`s,
#' and nested `list`s.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset (e.g., "/data/matrix").
#' @param data The R object to write. Supported: `numeric`, `integer`, `complex`, 
#'   `logical`, `character`, `factor`, `raw`, `matrix`, `data.frame`, `NULL`,
#'   and nested `list`s.
#' @param dtype The target HDF5 data type. Can be one of `"auto"`, `"float16"`,
#'   `"float32"`, `"float64"`, `"int8"`, `"int16"`, `"int32"`, `"int64"`, `"uint8"`,
#'   `"uint16"`, `"uint32"`, or `"uint64"`. The default, `"auto"`, selects the
#'   most space-efficient type for the data. See details below.
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
#' @section Writing Date-Time Objects:
#' `POSIXt` objects are automatically converted to character strings in
#' ISO 8601 format (`YYYY-MM-DDTHH:MM:SSZ`). This ensures that timestamps are
#' stored in a human-readable and unambiguous way. This conversion applies to
#' standalone `POSIXt` objects, as well as to columns within a `data.frame`.
#' 
#' @section Data Type Selection (`dtype`):
#' The `dtype` argument controls the on-disk storage type and only applies to
#' `integer`, `numeric`, and `logical` vectors. For all other data types
#' (`character`, `complex`, `factor`, `raw`), the storage type is determined
#' automatically.
#' 
#' If `dtype` is set to `"auto"` (the default), `h5lite` will automatically
#' select the most space-efficient HDF5 type based on the following rules:
#' 1.  If the data contains fractional values (e.g., `1.5`), it is stored as
#'     `float64`.
#' 2.  If the data contains `NA`, `NaN`, or `Inf`, it is stored using the
#'     smallest floating-point type (`float16`, `float32`, or `float64`) that
#'     can precisely represent all integer values in the vector.
#' 3.  If the data contains only finite integers (this includes `logical`
#'     vectors, where `FALSE` is 0 and `TRUE` is 1), `h5lite` selects the
#'     smallest possible integer type (e.g., `uint8`, `int16`).
#' 4.  If integer values exceed R's safe integer range (`+/- 2^53`), they are
#'     automatically stored as `float64` to preserve precision.
#'
#' To override this automatic behavior, you can specify an exact type. The full
#' list of supported values is:
#' - `"auto"`
#' - `"float16"`, `"float32"`, `"float64"`
#' - `"int8"`, `"int16"`, `"int32"`, `"int64"`
#' - `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`
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
#'   `vignette("atomic-vectors")`,
#'   `vignette("matrices")`,
#'   `vignette("data-frames")`,
#'   `vignette("data-organization")`,
#'   `vignette("attributes-in-depth")`
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
  
  # Automatically convert POSIXt to ISO 8601 character strings for clarity.
  if (inherits(data, "POSIXt")) {
    data <- format(data, format = "%Y-%m-%dT%H:%M:%OSZ")
  }
  
  # If data is a list (but not a data.frame), handle it as a group structure.
  if (is_list_group(data)) {
    
    # 1. Dry run: Validate the entire structure before writing anything.
    validate_write_recursive(data, name, attrs)
    
    # 2. Write: If validation passed, perform the recursive write.
    write_recursive(file, name, data, compress, attrs)
  
  # If data is NULL, write a special HDF5 null dataset.
  } else if (is.null(data)) {
    
    file <- path.expand(file)
    # For NULL, dims is irrelevant, level is 0, and dtype is "null".
    # This combination signals to the C code to create an H5S_NULL dataset.
    .Call("C_h5_write_dataset", file, name, data, "null", NULL, 0L, PACKAGE = "h5lite")
    
  }
  
  # Otherwise, handle as a single dataset (vector, matrix, data.frame, etc.).
  else {
    
    file  <- path.expand(file)
    level <- if (isTRUE(compress)) 5L else as.integer(compress)
    # Validate attributes before writing the main data.
    attrs <- validate_attrs(data, attrs)

    if (is.data.frame(data)) {

      # HDF5 compound types must have at least one member.
      if (ncol(data) == 0) {
        stop("Cannot write a data.frame with zero columns to HDF5.", call. = FALSE)
      }
      
      # Automatically convert POSIXt columns to ISO 8601 character strings.
      for (j in seq_along(data)) {
        if (inherits(data[[j]], "POSIXt")) {
          data[[j]] <- format(data[[j]], format = "%Y-%m-%dT%H:%M:%OSZ")
        }
      }
      
      # Get the best dtype for each column and call the compound writer.
      dtypes <- sapply(data, validate_dtype)
      .Call("C_h5_write_dataframe", file, name, data, dtypes, level, PACKAGE = "h5lite")

    } else {
      
      # For atomic vectors/arrays, validate dimensions and data type.
      dims  <- validate_dims(data)
      dtype <- validate_dtype(data, dtype)
      .Call("C_h5_write_dataset", file, name, data, dtype, dims, level, PACKAGE = "h5lite")

      # Rule: Ignore user-added 'AsIs' class for scalars after writing.
      # This prevents the class from being written as an HDF5 attribute if attrs=TRUE.
      if (inherits(data, 'AsIs') && is.null(dims) && !isFALSE(attrs))
        class(data) <- setdiff(class(data), "AsIs")
    }
    
    # If attributes are to be written, get them and write them one by one.
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
  
  # If the current object is a list, treat it as a group.
  if (is_list_group(data)) {
    
    # Create the group. This is safe even if it exists.
    h5_create_group(file, name)
    
    # Write the R attributes of the list object as HDF5 attributes on the group.
    group_attrs <- get_attributes_to_write(data, attrs)
    group_attrs[['names']] <- NULL # 'names' are the children, not a group attribute.
    for (attr_name in names(group_attrs))
      h5_write_attr(file, name, attr_name, group_attrs[[attr_name]])
    
    # Recursively write each child element.
    for (child_name in names(data)) {
      child_path <- if (name == "/") child_name else paste(name, child_name, sep = "/")
      write_recursive(file, child_path, data[[child_name]], compress, attrs)
    }
    
  } else { # Otherwise, it's a dataset. Write it directly.
    h5_write(file, name, data, compress = compress, attrs = attrs)
  }
}


#' Recursively validate a list for h5_write
#' @noRd
#' @keywords internal
validate_write_recursive <- function(data, current_path, attrs) {
  
  # First, validate the current object itself.
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


#' Validates or selects the HDF5 data type for an R object.
#'
#' This function acts as a dispatcher. It identifies non-numeric R types that have
#' a fixed HDF5 mapping (e.g., `character` -> `string`). For numeric, integer,
#' and logical data, it either validates a user-provided `dtype` or automatically
#' selects the most space-efficient type that can safely represent the data.
#'
#' @param data The R object to be written.
#' @param dtype The user-provided `dtype` string (e.g., "auto", "int32").
#' @return A string representing the validated or selected HDF5 data type.
#' @noRd
#' @keywords internal
validate_dtype <- function(data, dtype = "auto") {
  
  assert_valid_object(data)
  
  if (is.null(data))       return ("null")
  if (is.factor(data))     return ("factor")
  if (is.raw(data))        return ("raw")
  if (is.data.frame(data)) return ("data.frame")
  if (is.character(data))  return ("character")
  if (is.list(data))       return ("group")
  if (is.complex(data))    return ("complex")
  
  # POSIXt objects are numeric but should be treated as standard doubles
  # without special integer type selection.
  if (inherits(data, "POSIXt")) return ("float64")
  
  # For numeric/logical data, validate the user's 'dtype' argument.
  supported_dtypes <- c(
    "auto", "float16", "float32", "float64", 
    "int8", "int16", "int32", "int64",
    "uint8", "uint16", "uint32", "uint64")
  
  dtype <- match.arg(tolower(dtype), supported_dtypes)

  if (dtype == "auto") select_best_dtype(data)
  else                 sanity_check_dtype(data, dtype)
}

#' Automatically select the most space-efficient HDF5 data type for numeric data.
#'
#' This function analyzes the range and properties of numeric, integer, or logical
#' data to choose the smallest HDF5 type that will not cause data loss.
#'
#' - If the data contains non-integer values, it defaults to `float64`.
#' - If the data contains `NA`, `NaN`, or `Inf`, it selects the smallest floating-point
#'   type (`float16`, `float32`, `float64`) that can still represent all integer
#'   values in the data's range without loss of precision.
#' - For finite integer data, it selects the smallest fitting signed or unsigned
#'   integer type (e.g., `uint8`, `int16`).
#' - It correctly handles the limitation that R's `double` type can only precisely
#'   represent integers up to `2^53 - 1`.
#'
#' @param data The numeric, integer, or logical vector.
#' @return A string representing the optimal HDF5 data type.
#' @noRd
select_best_dtype <- function (data) {

  # If data is empty, default to uint8.
  if (length(data) == 0) return("uint8")
  
  # All values are NA/NaN/Inf
  if (!any(is.finite(data))) return ("float16")
  
  # Values have fractional part.
  if (is.double(data) && any(data %% 1 != 0, na.rm = TRUE)) {
      return ("float64")
  }
  
  # It's integer data. Find the range.
  val_range <- range(data, na.rm = TRUE, finite = TRUE)
  min_val <- val_range[1]
  max_val <- val_range[2]
  
  # If NA/NaN/Inf are present, use the smallest float that can encode the integer range.
  if (any(!is.finite(data))) {
    if      (min_val >= -2^11 && max_val <= 2^11) { return ("float16") }
    else if (min_val >= -2^24 && max_val <= 2^24) { return ("float32") }
    else                                          { return ("float64") }
  }
  
  # R's doubles can precisely represent integers up to 2^53 - 1.
  # This is our effective upper bound for integer checks.

  if (min_val >= 0) { # Unsigned integers
    if      (max_val <= 2^8-1)  "uint8"
    else if (max_val <= 2^16-1) "uint16"
    else if (max_val <= 2^32-1) "uint32"
    else if (max_val <= 2^53-1) "uint64"
    else "float64" # Too large, store as float64
  }
  else { # Signed integers
    if      (min_val >= -2^7  && max_val <= 2^7-1)  "int8"
    else if (min_val >= -2^15 && max_val <= 2^15-1) "int16"
    else if (min_val >= -2^31 && max_val <= 2^31-1) "int32"
    else if (min_val >= -2^53 && max_val <= 2^53-1) "int64"
    else "float64" # Too large, store as float64
  }
  
}

#' Sanity-checks a user-specified `dtype` against the data's range.
#'
#' This function verifies that the data can be safely stored in the user-requested
#' HDF5 data type without overflow.
#'
#' - It checks if the minimum and maximum values of the data fit within the
#'   range of the specified `dtype`.
#' - It ensures that if the data contains `NA`, `NaN`, or `Inf`, the `dtype` is a
#'   floating-point type, as integer types cannot represent these special values.
#'
#' @param data The R object to be written.
#' @param dtype The user-specified HDF5 data type string (e.g., "uint8", "float32").
#' @return The validated `dtype` string if the check passes. Throws an error otherwise.
#' @noRd
sanity_check_dtype <- function (data, dtype) {
  
  if (length(data) == 0) return(dtype)

  if (any(!is.finite(data)) && !startsWith(dtype, "float"))
    stop("Data contains NA, NaN, or Inf, which can only be stored as a ",
        "floating-point type ('float16', 'float32' or 'float64'). ",
        "The specified dtype '", dtype, "' is not supported for these values.",
          call. = FALSE)
    
    if (any(is.finite(data)) && dtype != "float64") {
      
      type_ranges <- list(
        int8    = c(-2^7,  2^7-1),  uint8  = c(0, 2^8-1),   
        int16   = c(-2^15, 2^15-1), uint16 = c(0, 2^16-1),
        int32   = c(-2^31, 2^31-1), uint32 = c(0, 2^32-1),  
        int64   = c(-2^63, 2^63-1), uint64 = c(0, 2^64-1),
        float16 = c(-65504,  65504),
        float32 = c(-3.4e38, 3.4e38) )
      
      val_range <- range(data, na.rm = TRUE, finite = TRUE)
      min_val <- val_range[1]
      max_val <- val_range[2]

      range_limits <- type_ranges[[dtype]]
      if (min_val < range_limits[1] || max_val > range_limits[2]) {
        stop("The specified dtype '", dtype, "' cannot represent the data range [",
             min_val, ", ", max_val, "]. Please choose a larger type.", call. = FALSE)
      }
    }
    
    return(dtype)
}


validate_dims <- function (data) {
  
  # If data is wrapped in I(), treat as a scalar (NULL dims), but ONLY if it's length 1.
  # This prevents accidentally writing a multi-element 'AsIs' vector as a scalar, which would cause data loss.
  if (inherits(data, 'AsIs')) {
    if (length(data) == 1) {
      return(NULL)
    } else {
      warning("I() wrapper ignored for vector of length > 1. Writing as a 1D array.")
    }
  }
  
  # Otherwise, infer dimensions from the object. A vector will have length, a matrix/array will have dim().
  if (is.null(dim(data))) length(data) else dim(data)
}


is_list_group <- function (data) {
  # A "list group" is a list that is not a data.frame.
  return (is.list(data) && !is.data.frame(data))
}


# Checks if an object is of a type that h5lite can potentially write. Includes lists.
assert_valid_object <- function (data) {
  
  # NULL
  if (is.null(data)) return (NULL)

  # logical, integer, numeric, complex, character, raw, factor
  if (is.atomic(data)) return (NULL)
  
  # list, data.frame
  if (is.list(data)) return (NULL)
  
  stop("Cannot map R type to HDF5 object: '", typeof(data), "'")
}


# Checks if an object can be written as a single HDF5 dataset. Excludes lists.
assert_valid_dataset <- function (data) {
  
  assert_valid_object(data)
  
  if (is_list_group(data))
    stop("Cannot map R type to HDF5 dataset: 'list'")
  
  invisible(NULL)
}
