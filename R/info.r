#' List HDF5 Objects
#' 
#' Lists the names of objects (datasets and groups) within an HDF5 file or group.
#'
#' @param file Path to the HDF5 file.
#' @param name The group path to start listing from. Defaults to the root group "/".
#' @param recursive If \code{TRUE} (default), lists all objects found recursively 
#'   under \code{name}. If \code{FALSE}, lists only the immediate children.
#' @param full.names If \code{TRUE}, the full paths from the file's root are
#'   returned. If \code{FALSE} (the default), names are relative to \code{name}.
#' @return A character vector of object names. If `name` is `/` (the default),
#'   the paths are relative to the root of the file. If `name` is another group,
#'   the paths are relative to that group (unless `full.names = TRUE`).
#' 
#' @seealso [h5_ls_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Create some nested objects
#' h5_write(file, "g1/d1", 1)
#' h5_write(file, "g1/g2/d2", 2)
#' 
#' # List recursively from the root (default)
#' h5_ls(file) # c("g1", "g1/d1", "g1/g2", "g1/g2/d2")
#' 
#' # List recursively from a subgroup
#' h5_ls(file, name = "g1") # c("d1", "g2", "g2/d2")
#' 
#' unlink(file)
h5_ls <- function(file, name = "/", recursive = TRUE, full.names = FALSE) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  
  .Call("C_h5_ls", file, name, recursive, full.names, PACKAGE = "h5lite")
}

#' List HDF5 Attributes
#' 
#' Lists the names of attributes attached to a specific HDF5 object.
#'
#' @param file Path to the HDF5 file.
#' @param name The path to the object (dataset or group) to query. 
#'   Use "/" for the file's root attributes.
#' @return A character vector of attribute names.
#' 
#' @seealso [h5_ls()]
#' @export
h5_ls_attr <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  
  .Call("C_h5_ls_attr", file, name, PACKAGE = "h5lite")
}

#' Get HDF5 Object Type
#' 
#' Returns the low-level HDF5 storage type of a dataset (e.g., "INT", "FLOAT", "STRING").
#' This allows inspecting the file storage type before reading the data into R.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset.
#' @return A character string representing the HDF5 storage type (e.g., "float64", "int32", "STRING").
#' 
#' @seealso [h5_typeof_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Write integers
#' h5_write(file, "integers", 1:5)
#' # Write doubles
#' h5_write(file, "doubles", c(1.1, 2.2))
#' 
#' # Check types
#' h5_typeof(file, "integers") # "uint8" (auto-selected)
#' h5_typeof(file, "doubles")  # "float64" (auto-selected)
#' 
#' unlink(file)
h5_typeof <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  .Call("C_h5_typeof", file, name, PACKAGE = "h5lite")
}

#' Get HDF5 Attribute Type
#' 
#' Returns the low-level HDF5 storage type of an attribute.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the object attached to.
#' @param attribute Name of the attribute.
#' @return A character string representing the HDF5 storage type.
#' 
#' @seealso [h5_typeof()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "data", 1)
#' 
#' h5_write_attr(file, "data", "meta", "info", dims = NULL)
#' h5_typeof_attr(file, "data", "meta") # "STRING"
#' 
#' unlink(file)
h5_typeof_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  .Call("C_h5_typeof_attr", file, name, attribute, PACKAGE = "h5lite")
}

#' Get HDF5 Object Dimensions
#' 
#' Returns the dimensions of a dataset as an integer vector.
#' These dimensions match the R-style (column-major) interpretation.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset.
#' @return An integer vector of dimensions, or \code{integer(0)} for scalars.
#' 
#' @seealso [h5_dim_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' mat <- matrix(1:10, nrow = 2, ncol = 5)
#' h5_write(file, "matrix", mat)
#' 
#' # Check dims without reading the whole dataset
#' h5_dim(file, "matrix") # Returns c(2, 5)
#' 
#' unlink(file)
h5_dim <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  .Call("C_h5_dim", file, name, PACKAGE = "h5lite")
}

#' Get HDF5 Attribute Dimensions
#' 
#' Returns the dimensions of an attribute.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the object attached to.
#' @param attribute Name of the attribute.
#' @return An integer vector of dimensions, or \code{integer(0)} for scalars.
#' 
#' @seealso [h5_dim()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "data", 1)
#' 
#' h5_write_attr(file, "data", "vec_attr", 1:10)
#' h5_dim_attr(file, "data", "vec_attr") # 10
#' 
#' unlink(file)
h5_dim_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  .Call("C_h5_dim_attr", file, name, attribute, PACKAGE = "h5lite")
}

#' Check if an HDF5 Object Exists
#'
#' Checks for the existence of a dataset or group within an HDF5 file without
#' raising an error if it does not exist.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the object to check (e.g., "/data/matrix").
#' @return A logical value: `TRUE` if the object exists, `FALSE` otherwise.
#' @seealso [h5_exists_attr()], [h5_is_group()], [h5_is_dataset()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "my_data", 1:10)
#'
#' h5_exists(file, "my_data") # TRUE
#' h5_exists(file, "nonexistent_data") # FALSE
#'
#' unlink(file)
h5_exists <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) return(FALSE)
  .Call("C_h5_exists", file, name, PACKAGE = "h5lite")
}

#' Check if an HDF5 Attribute Exists
#'
#' Checks for the existence of an attribute on an HDF5 object without
#' raising an error if it does not exist.
#'
#' @param file Path to the HDF5 file.
#' @param name The path to the object (dataset or group).
#' @param attribute The name of the attribute to check.
#' @return A logical value: `TRUE` if the attribute exists, `FALSE` otherwise.
#' @seealso [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "my_data", 1)
#' h5_write_attr(file, "my_data", "units", "meters")
#'
#' h5_exists_attr(file, "my_data", "units") # TRUE
#' h5_exists_attr(file, "my_data", "nonexistent_attr") # FALSE
#'
#' unlink(file)
h5_exists_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) return(FALSE)
  .Call("C_h5_exists_attr", file, name, attribute, PACKAGE = "h5lite")
}

#' Check if an HDF5 Object is a Group
#'
#' Checks if the object at a given path is a group.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the object to check.
#' @return A logical value: `TRUE` if the object exists and is a group,
#'   `FALSE` otherwise (if it is a dataset, or does not exist).
#' @seealso [h5_is_dataset()], [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_create_group(file, "my_group")
#' h5_write(file, "my_dataset", 1)
#'
#' h5_is_group(file, "my_group") # TRUE
#' h5_is_group(file, "my_dataset") # FALSE
#' h5_is_group(file, "nonexistent") # FALSE
#'
#' unlink(file)
h5_is_group <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) return(FALSE)
  .Call("C_h5_is_group", file, name, PACKAGE = "h5lite")
}

#' Check if an HDF5 Object is a Dataset
#'
#' Checks if the object at a given path is a dataset.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the object to check.
#' @return A logical value: `TRUE` if the object exists and is a dataset,
#'   `FALSE` otherwise (if it is a group, or does not exist).
#' @seealso [h5_is_group()], [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_create_group(file, "my_group")
#' h5_write(file, "my_dataset", 1)
#'
#' h5_is_dataset(file, "my_dataset") # TRUE
#' h5_is_dataset(file, "my_group") # FALSE
#' h5_is_dataset(file, "nonexistent") # FALSE
#'
#' unlink(file)
h5_is_dataset <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) return(FALSE)
  .Call("C_h5_is_dataset", file, name, PACKAGE = "h5lite")
}

#' Display the Structure of an HDF5 Object
#'
#' Recursively prints a summary of an HDF5 group or dataset, similar to
#' \code{utils::str()}. It displays the nested structure, object types,
#' dimensions, and attributes.
#'
#' @details
#' This function provides a quick and convenient way to inspect the contents of
#' an HDF5 file. It works by first reading the target object and all its
#' children into a nested R list using \code{\link{h5_read_all}}, and then
#' calling \code{utils::str()} on the resulting R object.
#'
#' Because this function reads the data into memory, it may be slow or
#' memory-intensive for very large files or groups.
#'
#' @param file Path to the HDF5 file.
#' @param name The name of the group or dataset to display. Defaults to the root
#'   group "/".
#' @return This function is called for its side effect of printing to the
#'   console and returns \code{NULL} invisibly.
#' @seealso [h5_read_all()], [h5_ls()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#'
#' # Create a nested structure
#' h5_write(file, "/config/version", 1.2)
#' h5_write(file, "/data/matrix", matrix(1:4, 2, 2))
#'
#' # Display the structure of the entire file
#' h5_str(file)
#'
#' unlink(file)
h5_str <- function(file, name = "/") {
  obj <- h5_read_all(file, name, attrs = TRUE)
  utils::str(obj)
  invisible(NULL)
}
