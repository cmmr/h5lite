#' Helper to find the smallest fitting data type for numeric data
#' @param data The numeric or integer vector.
#' @return A string representing the best HDF5 data type.
#' @noRd
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

#' Helper to select R attributes for writing based on the 'attrs' argument
#' @param data The R object containing attributes.
#' @param attrs The `attrs` argument from `h5_write`.
#' @return A named list of attributes to be written.
#' @noRd
#' @keywords internal
get_attributes_to_write <- function(data, attrs) {
  all_attrs <- attributes(data)
  
  # Rule: Never write 'dim' as it's a native HDF5 dataset property.
  all_attrs$dim <- NULL
  
  if (is.logical(attrs)) {
    if (isTRUE(attrs)) {
      return(all_attrs) # Write all (except dim)
    } else {
      return(list()) # Write none
    }
  }
  
  if (is.character(attrs) && length(attrs) > 0) {
    is_exclusion <- startsWith(attrs, "-")
    
    if (all(is_exclusion)) {
      # Exclusion mode: start with all attributes and remove specified ones
      to_exclude <- substring(attrs, 2)
      return(all_attrs[!names(all_attrs) %in% to_exclude])
    } else if (all(!is_exclusion)) {
      # Inclusion mode: start with none and add specified ones
      return(all_attrs[names(all_attrs) %in% attrs])
    } else {
      stop("The 'attrs' argument cannot contain a mix of inclusive (e.g., 'a') and exclusive (e.g., '-b') names.")
    }
  }
  
  return(list()) # Default to writing no attributes
}

#' Helper to validate R attributes before writing them to HDF5
#' @param data The R object whose attributes will be checked.
#' @param attrs A logical indicating if attributes should be processed.
#' @return Invisibly returns `TRUE` if validation succeeds. Throws an error otherwise.
#' @noRd
#' @keywords internal
validate_attributes <- function(data, attrs) {  
  # If attrs is FALSE, there's nothing to do.
  if (is.logical(attrs) && !isTRUE(attrs)) return(invisible(TRUE))
  
  # Determine which attributes are candidates for writing
  attr_to_write <- get_attributes_to_write(data, attrs)
  
  if (length(attr_to_write) == 0) {
    return(invisible(TRUE))
  }
  
  for (attr_name in names(attr_to_write)) {
    attr_val <- attr_to_write[[attr_name]]
    # Attributes must be atomic vectors or factors. Lists, environments, etc., are not supported.
    if (!is.atomic(attr_val) && !is.factor(attr_val)) {
      stop("Attribute '", attr_name, "' cannot be written to HDF5 because its type ('", typeof(attr_val), "') is not supported. Only atomic vectors and factors can be written as attributes.")
    }
  }
  
  invisible(TRUE)
}

#' Recursively validate a list for h5_write_all
#' @noRd
#' @keywords internal
validate_write_all_recursive <- function(data, current_path, attrs_arg) {
  
  # It's a group (list)
  if (is.list(data) && !is.data.frame(data)) {
    # All list elements must be named to be written as groups/datasets.
    if (length(data) > 0) {
      list_names <- names(data)
      if (is.null(list_names) || any(list_names == "")) {
        stop("Validation failed for group '", current_path, "'. All elements in a list must be named.", call. = FALSE)
      }
    }
    
    # First, validate the attributes of the list itself, which will become group attributes.
    tryCatch({
      validate_attributes(data, TRUE)
    }, error = function(e) {
      stop("Validation failed for group '", current_path, "': ", e$message, call. = FALSE)
    })
    
    # Then, recursively validate each child element.
    for (name in names(data)) {
      child_path <- if (current_path == "/") name else paste(current_path, name, sep = "/")
      validate_write_all_recursive(data[[name]], child_path, attrs_arg)
    }
    
  } else { # It's a dataset
    # Check that the dataset itself is a writeable type.
    if (!is.atomic(data) && !is.factor(data)) {
      stop("Validation failed for dataset '", current_path, "'. Its type ('", 
           typeof(data), "') is not supported. Only atomic vectors and factors can be written.", call. = FALSE)
    }
    
    # Validate the attributes that will be written with this dataset.
    tryCatch({
      validate_attributes(data, attrs_arg)
    }, error = function(e) {
      stop("Validation failed for dataset '", current_path, "': ", e$message, call. = FALSE)
    })
  }
}

#' Recursively write a list for h5_write_all
#' @noRd
#' @keywords internal
write_all_recursive <- function(file, name, data, compress, attrs_arg) {
  
  # It's a group (list)
  if (is.list(data) && !is.data.frame(data)) {
    # Create the group. This is safe even if it exists.
    h5_create_group(file, name)
    
    # Write the attributes of the list itself to the group.
    group_attrs <- get_attributes_to_write(data, TRUE)
    group_attrs[['names']] <- NULL
    for (attr_name in names(group_attrs)) {
      h5_write_attr(file, name, attr_name, group_attrs[[attr_name]])
    }
    
    # Recursively write each child element.
    for (child_name in names(data)) {
      child_path <- if (name == "/") child_name else paste(name, child_name, sep = "/")
      write_all_recursive(file, child_path, data[[child_name]], compress, attrs_arg)
    }
    
  } else { # It's a dataset
    h5_write(file, name, data, compress = compress, attrs = attrs_arg)
  }
}

#' Write a List Recursively to HDF5
#' 
#' Writes a nested R list to an HDF5 file, creating a corresponding group
#' and dataset structure.
#'
#' @details
#' This function provides a way to save a complex, nested R list as an HDF5
#' hierarchy.
#' 
#' - R `list` objects are created as HDF5 groups.
#' - All other supported R objects (vectors, matrices, arrays, factors) are
#'   written as HDF5 datasets.
#' - Attributes of a list are written as HDF5 attributes on the corresponding group.
#' - The `attrs` argument controls how attributes of the datasets (non-list elements)
#'   are handled.
#' 
#' Before writing any data, `h5_write_all` performs a "dry run" to validate
#' that all objects and attributes within the list are of a writeable type. If
#' any part of the structure is invalid, the function will throw an error and
#' no data will be written to the file.
#'
#' @param file Path to the HDF5 file.
#' @param name The name of the top-level group to write the list into.
#' @param data The nested R `list` to write.
#' @param compress A logical or an integer from 0-9. This compression setting is
#'   applied to all datasets written during the recursive operation.
#' @param attrs Controls which R attributes are written for the **datasets** within
#'   the list. See [h5_write()] for details. This does not affect attributes on
#'   the lists/groups themselves, which are always written.
#' @return Invisibly returns \code{NULL}.
#' @seealso [h5_read_all()], [h5_write()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Create a nested list with attributes
#' my_list <- list(
#'   config = list(version = 1.2, user = "test"),
#'   data = list(
#'     matrix = matrix(1:4, 2),
#'     vector = 1:10
#'   )
#' )
#' attr(my_list$data, "info") <- "This is the data group"
#' 
#' h5_write_all(file, "session_data", my_list)
#' 
#' h5_ls(file, recursive = TRUE)
#' 
#' unlink(file)
h5_write_all <- function(file, name, data, compress = TRUE, attrs = TRUE) {
  if (!is.list(data) || is.data.frame(data)) {
    stop("'data' must be a list.", call. = FALSE)
  }
  
  # 1. Dry run: Validate the entire structure before writing anything.
  validate_write_all_recursive(data, name, attrs)
  
  # 2. Write: If validation passed, perform the recursive write.
  write_all_recursive(file, name, data, compress, attrs)
  
  invisible(NULL)
}

#' Write a Dataset to HDF5
#' 
#' Writes an R object to an HDF5 file as a dataset. The file is created if 
#' it does not exist. Handles dimension transposition automatically.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset (e.g., "/data/matrix").
#' @param data The R object to write. Supported: \code{numeric}, \code{integer},
#'   \code{logical}, \code{character}, \code{factor}, \code{raw}.
#' @param dtype The target HDF5 data type. See details.
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
#' @param attrs Controls which R attributes of `data` are written to the HDF5 dataset.
#'   Can be `FALSE` (the default, no attributes), `TRUE` (all attributes except `dim`),
#'   a character vector of attribute names to include (e.g., `c("info", "version")`),
#'   or a character vector of names to exclude, prefixed with `-` (e.g., `c("-class")`).
#'   Mixing inclusive and exclusive names is not allowed.
#' @return Invisibly returns \code{NULL}. This function is called for its side effects.
#' @seealso [h5_read()], [h5_write_all()], [h5_write_attr()]
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
                     dims = "auto",
                     compress = TRUE,
                     attrs = FALSE) {
  
  file  <- path.expand(file)
  
  # Perform a "dry run" to validate attributes before writing anything
  validate_attributes(data, attrs)
  
  dtype <- get_best_dtype(data, dtype)
  level <- if (isTRUE(compress)) 5L else as.integer(compress)
  
  if (identical(dims, "auto")) {
    dims <- if (is.null(dim(data))) length(data) else dim(data)
  }
  
  .Call("C_h5_write_dataset", file, name, data, dtype, dims, level, PACKAGE = "h5lite")
  
  # If validation passed and attrs is TRUE, write the attributes
  if (!is.logical(attrs) || isTRUE(attrs)) {
    attr_to_write <- get_attributes_to_write(data, attrs)
    
    for (attr_name in names(attr_to_write)) {
      h5_write_attr(file = file, name = name, attribute = attr_name, 
                    data = attr_to_write[[attr_name]])
    }
  }
  
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
#' @seealso [h5_write()], [h5_read_attr()]
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
