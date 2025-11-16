
#' Get HDF5 Object Type
#' 
#' Returns the low-level HDF5 storage type of a dataset (e.g., "int8", "float64", "string").
#' This allows inspecting the file storage type before reading the data into R.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset.
#' @return A character string representing the HDF5 storage type (e.g., "float32", "uint32", "string").
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
#' h5_typeof_attr(file, "data", "meta") # "string"
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

#' Check if an HDF5 File or Object Exists
#'
#' Safely checks if a file is a valid HDF5 file or if a specific object
#' (group or dataset) exists within a valid HDF5 file.
#'
#' @details
#' This function provides a robust, error-free way to test for existence.
#'
#' \itemize{
#'   \item **Testing for a File:** If `name` is `"/"` (the default),
#'     the function checks if `file` is a valid, readable HDF5 file.
#'     It will return `FALSE` for non-existent files, text files, or
#'     corrupted files without raising an error.
#'
#'   \item **Testing for an Object:** If `name` is a path (e.g., `"/data/matrix"`),
#'     the function first confirms the file is valid HDF5, and then checks
#'     if the specific object exists within it.
#' }
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the object to check (e.g., `"/data/matrix"`).
#'   Defaults to `"/"`, which tests if the file itself is a valid HDF5 file.
#' @return A logical value: `TRUE` if the file/object exists and is valid HDF5,
#'   `FALSE` otherwise.
#' @seealso [h5_exists_attr()], [h5_is_group()], [h5_is_dataset()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "my_data", 1:10)
#'
#' # --- Test 1: Check for a specific object ---
#' h5_exists(file, "my_data") # TRUE
#' h5_exists(file, "nonexistent_data") # FALSE
#'
#' # --- Test 2: Check for a valid HDF5 file ---
#' h5_exists(file) # TRUE
#' h5_exists(file, "/") # TRUE
#'
#' # --- Test 3: Check invalid or non-existent files ---
#' h5_exists("not_a_real_file.h5") # FALSE
#'
#' text_file <- tempfile()
#' writeLines("this is not hdf5", text_file)
#' h5_exists(text_file) # FALSE
#'
#' # Check for an object in an invalid file (also FALSE)
#' h5_exists(text_file, "my_data") # FALSE
#'
#' unlink(file)
#' unlink(text_file)
h5_exists <- function(file, name = "/") {
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
