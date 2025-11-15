#' Read a Dataset from HDF5
#' 
#' Reads a dataset from an HDF5 file and returns it as an R object.
#' 
#' @details
#' * Numeric datasets are read as \code{numeric} (double) to prevent overflow.
#' * String datasets are read as \code{character}.
#' * \code{ENUM} datasets are read as \code{factor}.
#' * 1-byte \code{OPAQUE} datasets are read as \code{raw}.
#' 
#' Dimensions are preserved and transposed to match R's column-major order.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset (e.g., "/data/matrix").
#' @return A \code{numeric}, \code{character}, \code{factor}, or \code{raw} vector/array.
#' 
#' @seealso [h5_read_attr()]
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
#' * \code{ENUM} datasets are read as \code{factor}.
#' * 1-byte \code{OPAQUE} attributes are read as \code{raw}.
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the object (dataset or group) the attribute is attached to.
#' @param attribute Name of the attribute to read.
#' @return A \code{numeric}, \code{character}, \code{factor}, or \code{raw} vector/array.
#' 
#' @seealso [h5_read()]
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
  if (!file.exists(file)) stop("File does not exist: ", file)
  
  res <- .Call("C_h5_read_attribute", file, name, attribute, PACKAGE = "h5lite")
  
  # The C code may return a list of the form list(data=..., levels=...)
  # for ENUM types, which we must construct into a factor.
  if (is.list(res) && !is.null(res$'.h5_factor')) {
    res <- factor(res$data, levels = seq_along(res$levels), labels = res$levels)
  }
  
  return(res)
}
