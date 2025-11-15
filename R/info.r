#' List HDF5 Objects
#' 
#' Lists the names of objects (datasets and groups) within an HDF5 file.
#'
#' @param file Path to the HDF5 file.
#' @param name The group path to start listing from. Defaults to the root group "/".
#' @param recursive If \code{TRUE} (default), lists all objects found recursively 
#'   under \code{name}. If \code{FALSE}, lists only the immediate children of \code{name}.
#' @return A character vector of object names (relative paths).
#' @export
h5_ls <- function(file, name = "/", recursive = TRUE) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  
  .Call("C_h5_ls", file, name, recursive, PACKAGE = "h5lite")
}

#' List HDF5 Attributes
#' 
#' Lists the names of attributes attached to a specific HDF5 object.
#'
#' @param file Path to the HDF5 file.
#' @param name The path to the object (dataset or group) to query. 
#'   Use "/" for the file's root attributes.
#' @return A character vector of attribute names.
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
#' @return A string representing the HDF5 storage type.
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
#' h5_typeof(file, "integers") # "uint8"
#' h5_typeof(file, "doubles")  # "float16"
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
#' @return A string representing the HDF5 storage type.
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
#' @return Integer vector of dimensions, or \code{integer(0)} for scalars.
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
#' @return Integer vector of dimensions, or \code{integer(0)} for scalars.
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