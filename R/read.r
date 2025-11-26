
#' Read an HDF5 Object
#' 
#' Reads a dataset or group from an HDF5 file into an R object.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset or group to read (e.g., `"/data/matrix"`).
#' @param attrs Controls which HDF5 attributes are read and attached to the R object.
#'   Can be `FALSE` (the default), `TRUE` (all attributes),
#'   a character vector of attribute names to include (e.g., `c("info", "version")`),
#'   or a character vector of names to exclude, prefixed with `-` (e.g., `c("-class")`).
#'   Non-existent attributes are silently skipped.
#' 
#' @section Reading Datasets:
#' When `name` points to a dataset, `h5_read` converts it to the corresponding
#' R object:
#' 
#' - **Numeric** datasets are read as `numeric` (double) to prevent overflow.
#' - **String** datasets are read as `character`.
#' - **Complex** datasets are read as `complex`.
#' - **Enum** datasets are read as `factor`.
#' - **1-byte Opaque** datasets are read as `raw`.
#' - **Compound** datasets are read as `data.frame`.
#' 
#' Dimensions are preserved and transposed to match R's column-major order.
#' 
#' @section Reading Groups:
#' If `name` points to a group, `h5_read` will read it recursively, creating a
#' corresponding nested R `list`. This makes it easy to read complex, structured
#' data in a single command.
#' 
#' - HDF5 **groups** are read as R `list`s.
#' - **Datasets** within the group are read into R objects as described above.
#' - HDF5 **attributes** on the group are attached as R attributes to the `list`.
#' - The elements in the returned list are **sorted alphabetically** by name.
#' 
#' @return An R object corresponding to the HDF5 object. This can be a
#'   `numeric`, `character`, `complex`, `factor`, `raw`, `data.frame`, a nested `list`,
#'   or `NULL` if the object has a null dataspace.
#' 
#' @seealso [h5_read_attr()], [h5_write()], [h5_ls()],
#'   `vignette("data-organization", package = "h5lite")` for reading lists,
#'   `vignette("attributes-in-depth", package = "h5lite")` for the `attrs` argument.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # --- Reading Datasets ---
#' h5_write(file, "my_matrix", matrix(1:4, 2))
#' h5_write(file, "my_factor", factor(c("a", "b")))
#' 
#' mat <- h5_read(file, "my_matrix")
#' fac <- h5_read(file, "my_factor")
#' 
#' # --- Reading Groups ---
#' h5_write(file, "/config/version", 1.2)
#' h5_write(file, "/config/user", "test")
#' h5_write_attr(file, "/config", "info", "settings")
#' 
#' # Read the 'config' group into a list
#' config_list <- h5_read(file, "config")
#' str(config_list)
#' 
#' # Read the entire file from the root
#' all_content <- h5_read(file, "/")
#' str(all_content)
#' 
#' # --- Round-tripping with Attributes ---
#' named_vec <- c(a = 1, b = 2)
#' h5_write(file, "named_vec", named_vec, attrs = TRUE)
#' 
#' # Read back with attrs = TRUE to restore names
#' vec_rt <- h5_read(file, "named_vec", attrs = TRUE)
#' all.equal(named_vec, vec_rt)
#' 
#' unlink(file)
h5_read <- function(file, name, attrs = FALSE) {
  
  file <- path.expand(file)
  if (!h5_exists(file, name)) {
    stop("Object '", name, "' does not exist in file '", file, "'.")
  }
  
  # If the object is a group, read it recursively into a list.
  if (h5_is_group(file, name)) {
    
    # Get all immediate children, sort them alphabetically for consistent list order.
    children   <- sort(h5_ls(file, name, recursive = FALSE, full.names = TRUE))
    # Recursively call h5_read on each child and name the resulting list elements.
    res        <- lapply(children, h5_read, file = file, attrs = attrs)
    names(res) <- if (length(res) == 0) NULL else basename(children)
    
  } else {
    # If it's a dataset, call the C function to read its data.
    res <- .Call("C_h5_read_dataset", file, name, PACKAGE = "h5lite")
  }
  
  # If attrs is not FALSE, read and attach HDF5 attributes as R attributes.
  if (!isFALSE(attrs)) {
    # Determine which attributes to read based on the 'attrs' argument.
    available_attrs <- h5_ls_attr(file, name)
    attrs_to_read <- get_attributes_to_read(available_attrs, attrs)
    
    for (attr_name in attrs_to_read) {
      attr_val <- h5_read_attr(file, name, attr_name)
      # Special case: R requires row.names to be integer or character, not double.
      # Since we read all numeric attributes as double, we must coerce row.names back to integer.
      if (attr_name == "row.names" && is.numeric(attr_val))
        attr_val <- as.integer(attr_val)
      attr(res, attr_name) <- attr_val
    }
  }
  
  return(res)
}


#' Read an HDF5 Attribute
#' 
#' Reads an attribute associated with an HDF5 object (dataset or group).
#' 
#' @details
#' - Numeric attributes are read as `numeric` (double).
#' - String attributes are read as `character`.
#' - Complex attributes are read as `complex`.
#' - `enum` attributes are read as `factor`.
#' - 1-byte `opaque` attributes are read as `raw`.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the object (dataset or group) the attribute is attached to.
#' @param attribute Name of the attribute to read.
#' @return A `numeric`, `character`, `complex`, `factor`, or `raw` vector/array.
#'   Returns `NULL` if the attribute has a null dataspace.
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
  
  # Call the C function to read the attribute's data.
  res <- .Call("C_h5_read_attribute", file, name, attribute, PACKAGE = "h5lite")
  
  return(res)
}

#' Helper to select HDF5 attributes for reading based on the 'attrs' argument
#' @param available_attrs A character vector of all attributes on the HDF5 object.
#' @param attrs The `attrs` argument from `h5_read`.
#' @return A character vector of attribute names to be read.
#' @noRd
#' @keywords internal
get_attributes_to_read <- function(available_attrs, attrs) {
  
  # If attrs is TRUE, return all available attributes.
  if (is.logical(attrs)) {
    if (isTRUE(attrs)) {
      return(available_attrs) # Read all
    } else {
      return(character(0)) # Read none
    }
  }
  
  # If attrs is a character vector, handle inclusion/exclusion logic.
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
