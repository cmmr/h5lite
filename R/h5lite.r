#' Read a Dataset from HDF5
#' 
#' Reads a dataset from an HDF5 file and returns it as an R object.
#' 
#' @details
#' * Numeric datasets are read as \code{numeric} (double) to prevent overflow.
#' * String datasets are read as \code{character}.
#' * 1-byte \code{OPAQUE} datasets are read as \code{raw}.
#' 
#' Dimensions are preserved and transposed to match R's column-major order.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset (e.g., "/data/matrix").
#' @return A \code{numeric}, \code{character}, or \code{raw} vector/array.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Write a matrix
#' mat <- matrix(1:12, nrow = 3, ncol = 4)
#' h5_write(file, "example_matrix", mat)
#' 
#' # Read it back
#' mat2 <- h5_read(file, "example_matrix")
#' print(mat2)
#' 
#' # Verify equality
#' all.equal(mat, mat2)
#' 
#' unlink(file)
h5_read <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) {
    stop("File does not exist: ", file)
  }
  res <- .Call("C_h5_read_dataset", file, name, PACKAGE = "h5lite")
  
  # The C code may return a list of the form list(data=..., levels=...)
  # for ENUM types, which we must construct into a factor.
  if (is.list(res) && !is.null(res$'.h5_factor')) {
    res <- factor(res$data, levels = seq_along(res$levels), labels = res$levels)
  }
  
  return(res)
}

#' Read an Attribute from HDF5
#' 
#' Reads an attribute associated with an HDF5 object (dataset or group).
#' 
#' @details
#' * Numeric attributes are read as \code{numeric} (double).
#' * String attributes are read as \code{character}.
#' * 1-byte \code{OPAQUE} attributes are read as \code{raw}.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the object (dataset or group) the attribute is attached to.
#' @param attribute Name of the attribute to read.
#' @return A \code{numeric}, \code{character}, or \code{raw} vector/array.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Create a dummy dataset
#' h5_write(file, "data", 1:5)
#' 
#' # Attach an attribute
#' h5_write_attr(file, "data", "unit", "meters", dims = NULL)
#' 
#' # Read the attribute
#' unit <- h5_read_attr(file, "data", "unit")
#' print(unit)
#' 
#' unlink(file)
h5_read_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  
  res <- .Call("C_h5_read_attribute", file, name, attribute, PACKAGE = "h5lite")
  
  # The C code may return a list of the form list(data=..., levels=...)
  # for ENUM types, which we must construct into a factor.
  if (is.list(res) && !is.null(res$'.h5_factor')) {
    res <- factor(res$data, levels = seq_along(res$levels), labels = res$levels)
  }
  
  return(res)
}

#' Write a Dataset to HDF5
#' 
#' Writes an R object to an HDF5 file as a dataset. The file is created if 
#' it does not exist. Handles dimension transposition automatically.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset (e.g., "/data/matrix").
#' @param data The R object to write. Supported: \code{numeric}, \code{integer},
#'   \code{logical}, \code{character}, \code{raw}.
#' @param dtype The target HDF5 data type. Defaults to \code{typeof(data)}.
#'   Options: "double", "integer", "logical", "character", "opaque", "float", etc.
#' @param dims An integer vector specifying dimensions, or \code{NULL} for a scalar.
#'   Defaults to \code{dim(data)} if it exists, or \code{length(data)} otherwise.
#' @param compress A logical or an integer from 0-9. If `TRUE` (default), 
#'   compression level 5 is used. If `FALSE` or `0`, no compression is used. 
#'   An integer `1-9` specifies the zlib compression level directly.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # 1. Write a vector as a double
#' h5_write(file, "vec_double", c(1.5, 2.5, 3.5))
#'
#' # 2. Write integers with compression
#' h5_write(file, "vec_int_compressed", 1:1000, dtype = "integer", compress = TRUE)
#' 
#' # 3. Write integers, enforcing integer storage on disk (uncompressed)
#' h5_write(file, "vec_int", 1:10, dtype = "integer")
#' 
#' # 4. Write a 3D array (uncompressed)
#' arr <- array(1:24, dim = c(2, 3, 4))
#' h5_write(file, "3d_array", arr)
#' 
#' # 5. Write a raw vector (as 1-byte OPAQUE)
#' h5_write(file, "raw_data", as.raw(c(0x01, 0xFF, 0x10)), dtype = "opaque")
#' 
#' # Verify types
#' h5_ls(file, recursive = TRUE)
#' h5_typeof(file, "raw_data") # "OPAQUE"
#' 
#' unlink(file)
h5_write <- function(file, name, data, 
                     dtype = typeof(data), 
                     dims = length(data),
                     compress = TRUE) {
  
  file <- path.expand(file)
  
  level <- if (is.logical(compress)) {
    if (compress) 5L else 0L
  } else {
    as.integer(compress)
  }
  
  # If data is a factor, ensure dtype is "factor" to trigger ENUM logic in C
  if (is.factor(data)) {
    dtype <- "factor"
  }
  
  # Smartly detect dimensions from matrix/array if dims not provided
  if (missing(dims) && !is.null(dim(data))) {
    dims <- dim(data)
  }
  
  .Call("C_h5_write_dataset", file, name, data, dtype, dims, level, PACKAGE = "h5lite")
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
#' @param dims An integer vector specifying dimensions, or \code{NULL} for a scalar.
#'   Defaults to \code{dim(data)} or \code{length(data)}.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Create a group/dataset first
#' h5_write(file, "my_dataset", 1:10)
#' 
#' # Write scalar attributes
#' h5_write_attr(file, "my_dataset", "version", "1.0", dims = NULL)
#' h5_write_attr(file, "my_dataset", "timestamp", 123456, dtype = "integer", dims = NULL)
#' 
#' # Write vector attributes
#' h5_write_attr(file, "my_dataset", "range", c(0, 100))
#' 
#' h5_ls_attr(file, "my_dataset")
#' unlink(file)
h5_write_attr <- function(file, name, attribute, data, 
                          dtype = typeof(data), 
                          dims = length(data)) {
  
  file <- path.expand(file)
  if (!file.exists(file)) {
    stop("File must exist to write attributes: ", file)
  }
  
  # If data is a factor, ensure dtype is "factor" to trigger ENUM logic in C
  if (is.factor(data)) {
    dtype <- "factor"
  }
  
  if (missing(dims) && !is.null(dim(data))) {
    dims <- dim(data)
  }
  
  .Call("C_h5_write_attribute", file, name, attribute, data, dtype, dims, PACKAGE = "h5lite")
}

#' Create an HDF5 Group
#' 
#' Explicitly creates a new group (or nested groups) in an HDF5 file.
#' This is useful for creating an empty group structure.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the group to create (e.g., "/g1/g2").
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_create_group(file, "/my/nested/group")
#' 
#' h5_ls(file)
#' unlink(file)
h5_create_group <- function(file, name) {
  file <- path.expand(file)
  .Call("C_h5_create_group", file, name, PACKAGE = "h5lite")
}

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
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Create nested structure
#' h5_write(file, "group1/data1", 1)
#' h5_write(file, "group1/subgroup/data2", 2)
#' h5_write(file, "group2/data3", 3)
#' 
#' # List everything (Recursive)
#' h5_ls(file)
#' 
#' # List top level only
#' h5_ls(file, recursive = FALSE)
#' 
#' # List inside a specific group
#' h5_ls(file, "group1")
#' 
#' unlink(file)
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
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "data", 1)
#' 
#' h5_write_attr(file, "data", "a1", 1, dims = NULL)
#' h5_write_attr(file, "data", "a2", 2, dims = NULL)
#' 
#' h5_ls_attr(file, "data")
#' unlink(file)
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
#' h5_write(file, "integers", 1:5, dtype = "integer")
#' # Write doubles
#' h5_write(file, "doubles", c(1.1, 2.2))
#' 
#' # Check types
#' h5_typeof(file, "integers") # "INT"
#' h5_typeof(file, "doubles")  # "DOUBLE"
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
