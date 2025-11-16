#' Helper to select HDF5 attributes for reading based on the 'attrs' argument
#' @param available_attrs A character vector of all attributes on the HDF5 object.
#' @param attrs The `attrs` argument from `h5_read`.
#' @return A character vector of attribute names to be read.
#' @noRd
#' @keywords internal
get_attributes_to_read <- function(available_attrs, attrs) {
  
  if (is.logical(attrs)) {
    if (isTRUE(attrs)) {
      return(available_attrs) # Read all
    } else {
      return(character(0)) # Read none
    }
  }
  
  if (is.character(attrs) && length(attrs) > 0) {
    is_exclusion <- startsWith(attrs, "-")
    
    if (all(is_exclusion)) {
      # Exclusion mode: start with all attributes and remove specified ones
      to_exclude <- substring(attrs, 2)
      return(available_attrs[!available_attrs %in% to_exclude])
    } else if (all(!is_exclusion)) {
      # Inclusion mode: start with none and add specified ones that exist
      return(intersect(attrs, available_attrs))
    } else {
      stop("The 'attrs' argument cannot contain a mix of inclusive (e.g., 'a') and exclusive (e.g., '-b') names.")
    }
  }
  
  return(character(0)) # Default to reading no attributes
}


#' Read an HDF5 Dataset
#' 
#' Reads a dataset from an HDF5 file and returns it as an R object.
#' 
#' @details
#' * Numeric datasets are read as \code{numeric} (double) to prevent overflow.
#' * String datasets are read as \code{character}.
#' * \code{enum} datasets are read as \code{factor}.
#' * 1-byte \code{opaque} datasets are read as \code{raw}.
#' 
#' Dimensions are preserved and transposed to match R's column-major order.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset (e.g., "/data/matrix").
#' @param attrs Controls which HDF5 attributes are read and attached to the returned R object.
#'   Can be `FALSE` (the default, no attributes), `TRUE` (all attributes),
#'   a character vector of attribute names to include (e.g., `c("info", "version")`),
#'   or a character vector of names to exclude, prefixed with `-` (e.g., `c("-class")`).
#'   Non-existent attributes are silently skipped.
#' @return A \code{numeric}, \code{character}, \code{factor}, or \code{raw} vector/array.
#' 
#' @seealso [h5_read_attr()], [h5_write()], [h5_ls()], [h5_is_dataset()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Write a matrix
#' mat <- matrix(1:12, nrow = 3, ncol = 4)
#' h5_write(file, "example_matrix", mat)
#' # Write a factor
#' fac <- factor(c("a", "b", "a", "c"))
#' h5_write(file, "example_factor", fac)
#' 
#' # Read it back
#' mat2 <- h5_read(file, "example_matrix")
#' fac2 <- h5_read(file, "example_factor")
#' 
#' # Print and verify
#' print(mat2)
#' all.equal(mat, mat2)
#' 
#' print(fac2)
#' all.equal(fac, fac2)
#' 
#' unlink(file)
h5_read <- function(file, name, attrs = FALSE) {
  file <- path.expand(file)
  if (!h5_exists(file, name)) {
    stop("Object '", name, "' does not exist in file '", file, "'.")
  }
  if (!h5_is_dataset(file, name)) {
    stop("Object '", name, "' is a group, not a dataset. Use h5_read_all() to read a group.")
  }

  res <- .Call("C_h5_read_dataset", file, name, PACKAGE = "h5lite")
  
  # The C code may return a list of the form list(data=..., levels=...)
  # for enum types, which we must construct into a factor.
  if (is.list(res) && !is.null(res$'.h5_factor')) {
    res <- factor(res$data, levels = seq_along(res$levels), labels = res$levels)
  }
  
  # If attrs is not FALSE, read and attach attributes
  if (!is.logical(attrs) || isTRUE(attrs)) {
    available_attrs <- h5_ls_attr(file, name)
    attrs_to_read <- get_attributes_to_read(available_attrs, attrs)
    
    for (attr_name in attrs_to_read) {
      attr_val <- h5_read_attr(file, name, attr_name)
      attr(res, attr_name) <- attr_val
    }
  }
  
  return(res)
}


#' Read an HDF5 Group or Dataset Recursively
#' 
#' Reads an HDF5 group and all its contents (subgroups and datasets) into a
#' nested R list. If the target `name` is a dataset, it is read directly.
#'
#' @details
#' When reading a group, the elements in the returned list are sorted
#' alphabetically by name, which may differ from their original creation order.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the group or dataset to read (e.g., "/data").
#' @param attrs Controls which HDF5 attributes are read and attached to the returned R object(s).
#'   Defaults to `TRUE`. See [h5_read()] for more details.
#' @return A nested `list` representing the HDF5 group structure, or a single
#'   R object if `name` points to a dataset.
#' 
#' @seealso [h5_read()], [h5_write_all()], [h5_is_group()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Create a nested structure
#' h5_write(file, "/config/version", 1.2)
#' h5_write(file, "/data/matrix", matrix(1:4, 2, 2))
#' h5_write(file, "/data/vector", 1:10)
#' 
#' # Read the entire 'data' group
#' data_group <- h5_read_all(file, "data")
#' str(data_group)
#' 
#' # Read the entire file from the root
#' all_content <- h5_read_all(file, "/")
#' str(all_content)
#' 
#' unlink(file)
h5_read_all <- function(file, name, attrs = TRUE) {
  file <- path.expand(file)
  if (!h5_exists(file, name)) {
    stop("Object '", name, "' does not exist in file '", file, "'.")
  }
  
  if (h5_is_group(file, name)) {
    children <- h5_ls(file, name, recursive = FALSE, full.names = TRUE)
    
    res <- lapply(children, h5_read_all, file = file, attrs = attrs)
    names(res) <- basename(children)
    
    # If the group was empty, lapply returns list() but with names = character(0).
    # We set names to NULL to match the behavior of a newly created list().
    if (length(res) == 0) {
      names(res) <- NULL
    }
    
    # Also read attributes of the group itself and attach them to the list
    if (!is.logical(attrs) || isTRUE(attrs)) {
      available_attrs <- h5_ls_attr(file, name)
      attrs_to_read <- get_attributes_to_read(available_attrs, attrs)
      
      for (attr_name in attrs_to_read) {
        attr(res, attr_name) <- h5_read_attr(file, name, attr_name)
      }
    }
    
    return(res)
  } else {
    return(h5_read(file, name, attrs = attrs))
  }
}


#' Read an HDF5 Attribute
#' 
#' Reads an attribute associated with an HDF5 object (dataset or group).
#' 
#' @details
#' * Numeric attributes are read as \code{numeric} (double).
#' * String attributes are read as \code{character}.
#' * \code{enum} attributes are read as \code{factor}.
#' * 1-byte \code{opaque} attributes are read as \code{raw}.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the object (dataset or group) the attribute is attached to.
#' @param attribute Name of the attribute to read.
#' @return A \code{numeric}, \code{character}, \code{factor}, or \code{raw} vector/array.
#' 
#' @seealso [h5_read()], [h5_write_attr()], [h5_ls_attr()], [h5_exists_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Create a dataset to attach attributes to
#' h5_write(file, "dset", 1)
#' 
#' # Write attributes of different types
#' h5_write_attr(file, "dset", "a_string", "some metadata")
#' h5_write_attr(file, "dset", "a_vector", c(1.1, 2.2))
#' 
#' # Read them back
#' str_attr <- h5_read_attr(file, "dset", "a_string")
#' vec_attr <- h5_read_attr(file, "dset", "a_vector")
#' 
#' print(str_attr)
#' print(vec_attr)
#' unlink(file)
h5_read_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!h5_exists(file, name)) {
    stop("Object '", name, "' does not exist in file '", file, "'.")
  }
  if (!h5_exists_attr(file, name, attribute)) {
    stop("Attribute '", attribute, "' does not exist on object '", name, "'.")
  }
  
  res <- .Call("C_h5_read_attribute", file, name, attribute, PACKAGE = "h5lite")
  
  # The C code may return a list of the form list(data=..., levels=...)
  # for enum types, which we must construct into a factor.
  if (is.list(res) && !is.null(res$'.h5_factor')) {
    res <- factor(res$data, levels = seq_along(res$levels), labels = res$levels)
  }
  
  return(res)
}
