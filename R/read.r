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