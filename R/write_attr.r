

#' Write an Attribute to HDF5
#' 
#' Writes an R object as an attribute to an existing HDF5 object.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the object to attach the attribute to (e.g., "/data").
#' @param attribute The name of the attribute to create.
#' @param data The R object to write. Supported: `numeric`, `integer`,
#'   `complex`, `logical`, `character`, `raw`, `data.frame`, and `NULL`.
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
#' list of supported values for numeric data is:
#' * `"auto"`
#' * `"float16"`, `"float32"`, `"float64"`
#' * `"int8"`, `"int16"`, `"int32"`, `"int64"`
#' * `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`
#'
#' For non-numeric data (`character`, `complex`, `factor`, `raw`, `logical`), the
#' storage type is determined automatically. For `logical` attributes, `h5lite`
#' follows the same rules as for integer data:
#' - If the vector contains no `NA` values, it is saved using an efficient integer
#'   type (e.g., `uint8`).
#' - If the vector contains any `NA` values, it is automatically promoted to a
#'   floating-point type (`float16`) to correctly preserve `NA`.
#' 
#' `data.frame` objects are written as HDF5 **compound attributes**, a native
#' table-like structure.
#' 
#' `NULL` objects are written as HDF5 **null attributes**, which contain no data
#' but can be used as placeholders.
#'
#' `complex` objects are written using the native HDF5 `H5T_COMPLEX` datatype
#' class. HDF5 files containing complex attributes written by `h5lite` can only
#' be read by other HDF5 tools that support HDF5 version 2.0.0 or later.
#' 
#' To write a scalar attribute, wrap the value in `I()` (e.g., `I("meters")`).
#' Otherwise, dimensions are inferred automatically.
#'
#' @return Invisibly returns \code{NULL}. This function is called for its side effects.
#' @seealso [h5_write()], [h5_read_attr()],
#'   `vignette("attributes-in-depth")`
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # First, create an object to attach attributes to
#' h5_write(file, "my_data", 1:10, compress = FALSE)
#' 
#' # Write a scalar string attribute
#' h5_write_attr(file, "my_data", "units", I("meters"))
#' 
#' # Write a numeric vector attribute
#' h5_write_attr(file, "my_data", "range", c(0, 100))
#' 
#' # List attributes to confirm they were written
#' h5_ls_attr(file, "my_data")
#' 
#' unlink(file)
h5_write_attr <- function(file, name, attribute, data, dtype = "auto") {
  
  file <- path.expand(file)
  dims <- validate_dims(data)
  
  if (!file.exists(file)) {
    stop("File must exist to write attributes: ", file)
  }
  
  assert_valid_dataset(data)
  
  if (is.data.frame(data)) {
    # HDF5 compound types must have at least one member.
    if (ncol(data) == 0) {
      stop("Cannot write a data.frame with zero columns as an HDF5 attribute.", call. = FALSE)
    }
    dtypes <- sapply(data, validate_dtype)
    .Call("C_h5_write_attribute", file, name, attribute, data, dtypes, NULL, PACKAGE = "h5lite")
  } else {
    dtype <- validate_dtype(data, dtype)
    .Call("C_h5_write_attribute", file, name, attribute, data, dtype, dims, PACKAGE = "h5lite")
  }
  
  invisible(NULL)
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
validate_attrs <- function(data, attrs) { 
  
  # If attrs is FALSE, there's nothing to do.
  if (is.logical(attrs) && !isTRUE(attrs)) return (attrs)
  
  # Determine which attributes are candidates for writing
  attrs_to_write <- get_attributes_to_write(data, attrs)
  
  if (length(attrs_to_write) == 0) {
    return (attrs)
  }
  
  for (attr_name in names(attrs_to_write)) {
    attr_val <- attrs_to_write[[attr_name]]
    # Attributes must be atomic vectors or factors. Lists, environments, etc., are not supported.
    if (!is.atomic(attr_val) && !is.factor(attr_val)) {
      stop("Attribute '", attr_name, "' cannot be written to HDF5 because its type ('", typeof(attr_val), "') is not supported. Only atomic vectors and factors can be written as attributes.")
    }
  }
  
  return (attrs)
}
