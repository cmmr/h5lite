#' Delete an HDF5 Dataset
#'
#' Deletes a dataset from an HDF5 file.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the dataset to delete.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "dset1", 1:10)
#' h5_write(file, "dset2", 1:5)
#' h5_ls(file)
#' 
#' h5_delete(file, "dset1")
#' h5_ls(file)
#' unlink(file)
h5_delete <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  .Call("C_h5_delete_link", file, name, PACKAGE = "h5lite")
}

#' Delete an HDF5 Group
#'
#' Deletes a group and all objects contained within it.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the group to delete (e.config. "/g1/g2").
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "/g1/g2/dset", 1:10)
#' h5_ls(file, recursive = TRUE) # "g1" "g1/g2" "g1/g2/dset"
#' 
#' h5_delete_group(file, "/g1")
#' h5_ls(file, recursive = TRUE) # character(0)
#' unlink(file)
h5_delete_group <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  .Call("C_h5_delete_link", file, name, PACKAGE = "h5lite")
}

#' Delete an HDF5 Attribute
#'
#' Deletes an attribute from an object.
#'
#' @param file Path to the HDF5 file.
#' @param name The path to the object (dataset or group).
#' @param attribute The name of the attribute to delete.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "data", 1)
#' h5_write_attr(file, "data", "attr1", 123, dims = NULL)
#' h5_ls_attr(file, "data") # "attr1"
#' 
#' h5_delete_attr(file, "data", "attr1")
#' h5_ls_attr(file, "data") # character(0)
#' unlink(file)
h5_delete_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  .Call("C_h5_delete_attr", file, name, attribute, PACKAGE = "h5lite")
}