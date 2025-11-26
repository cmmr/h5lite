#' Delete an HDF5 Object
#'
#' Deletes an object (dataset or group) from an HDF5 file.
#' If the object is a group, all objects contained within it will be deleted
#' recursively.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the object to delete (e.g., `"/data/dset"` or `"/groups/g1"`).
#'
#' @return Invisibly returns \code{NULL}. This function is called for its side effects.
#' @seealso [h5_delete_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "/g1/d1", 1:10)
#' h5_write(file, "d2", 1:5)
#' print(h5_ls(file, recursive = TRUE))
#'
#' # Delete a dataset
#' h5_delete(file, "d2")
#' print(h5_ls(file, recursive = TRUE))
#'
#' # Delete a group (and its contents)
#' h5_delete(file, "g1")
#' print(h5_ls(file, recursive = TRUE))
#' unlink(file)
h5_delete <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  
  # Warn but do not error if the object doesn't exist, to allow for idempotent deletion.
  if (!h5_exists(file, name)) {
    warning("Object '", name, "' not found. Nothing to delete.")
    return(invisible(NULL))
  }
  
  # Call the C function to perform the deletion.
  .Call("C_h5_delete", file, name, PACKAGE = "h5lite")
  invisible(NULL)
}

#' Delete an HDF5 Attribute
#'
#' Deletes an attribute from an object.
#'
#' @param file Path to the HDF5 file.
#' @param name The path to the object (dataset or group).
#' @param attribute The name of the attribute to delete.
#'
#' @return Invisibly returns \code{NULL}. This function is called for its side effects.
#' @seealso [h5_delete()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "data", 1)
#' h5_write_attr(file, "data", "attr1", I("some info"))
#' print(h5_ls_attr(file, "data")) # "attr1"
#'
#' h5_delete_attr(file, "data", "attr1")
#' print(h5_ls_attr(file, "data")) # character(0)
#' unlink(file)
h5_delete_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  
  # Warn but do not error if the attribute doesn't exist.
  if (!h5_exists_attr(file, name, attribute)) {
    warning("Attribute '", attribute, "' not found on object '", name, "'. Nothing to delete.")
    return(invisible(NULL))
  }
  
  # Call the C function to delete the attribute.
  .Call("C_h5_delete_attr", file, name, attribute, PACKAGE = "h5lite")
  invisible(NULL)
}
