#' Delete an HDF5 Dataset
#'
#' Deletes a dataset from an HDF5 file. This function will not delete a group.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the dataset to delete.
#'
#' @return Invisibly returns \code{NULL}. This function is called for its side effects.
#' @seealso [h5_delete_attr()], [h5_delete_group()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "dset1", 1:10)
#' h5_write(file, "dset2", 1:5)
#' print(h5_ls(file))
#'
#' h5_delete(file, "dset1")
#' print(h5_ls(file))
#' unlink(file)
h5_delete <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  # TODO: Add a check to ensure 'name' is a dataset, not a group.
  .Call("C_h5_delete_link", file, name, PACKAGE = "h5lite")
  invisible(NULL)
}

#' Delete an HDF5 Group
#'
#' Deletes a group and all objects contained within it.
#' This function will not delete a dataset.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the group to delete (e.g., "/g1/g2").
#'
#' @return Invisibly returns \code{NULL}. This function is called for its side effects.
#' @seealso [h5_delete()], [h5_delete_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "/g1/g2/dset", 1:10)
#' print(h5_ls(file, recursive = TRUE)) # "g1" "g1/g2" "g1/g2/dset"
#'
#' h5_delete_group(file, "/g1")
#' print(h5_ls(file, recursive = TRUE)) # character(0)
#' unlink(file)
h5_delete_group <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  # TODO: Add a check to ensure 'name' is a group, not a dataset.
  .Call("C_h5_delete_link", file, name, PACKAGE = "h5lite")
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
#' @seealso [h5_delete()], [h5_delete_group()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "data", 1)
#' h5_write_attr(file, "data", "attr1", "some info")
#' print(h5_ls_attr(file, "data")) # "attr1"
#'
#' h5_delete_attr(file, "data", "attr1")
#' print(h5_ls_attr(file, "data")) # character(0)
#' unlink(file)
h5_delete_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  .Call("C_h5_delete_attr", file, name, attribute, PACKAGE = "h5lite")
  invisible(NULL)
}
