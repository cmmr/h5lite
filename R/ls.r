
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
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  
  .Call("C_h5_str", file, name, PACKAGE = "h5lite")
  invisible(NULL)
}
