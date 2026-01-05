#' Create an HDF5 Group
#' 
#' Explicitly creates a new group (or nested groups) in an HDF5 file.
#' This is useful for creating an empty group structure.
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the group to create (e.g., "/g1/g2").
#' @return Invisibly returns `NULL`. This function is called for its side effects.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_create_file(file)
#' 
#' # Create a nested group structure
#' h5_create_group(file, "/data/experiment/run1")
#' h5_ls(file, recursive = TRUE)
#' 
#' unlink(file)
h5_create_group <- function (file, name) {
  file <- validate_strings(file, name)
  # Call the C function, which handles creating parent groups automatically.
  .Call("C_h5_create_group", file, name, PACKAGE = "h5lite")
  invisible(NULL)
}


#' Create an HDF5 File
#'
#' Explicitly creates a new, empty HDF5 file.
#'
#' @details
#' This function is a simple wrapper around `h5_create_group(file, "/")`.
#' Its main purpose is to allow for explicit file creation in code.
#'
#' Note that calling this function is almost always **unnecessary**, as all
#' `h5lite` writing functions (like [h5_write()] or
#' [h5_create_group()]) will automatically create
#' the file if it does not exist.
#'
#' It is provided as a convenience for users who prefer to explicitly create
#' a file before writing data to it.
#'
#' @param file Path to the HDF5 file to be created.
#'
#' @section File Handling:
#' - If `file` does not exist, it will be created as a new, empty HDF5 file.
#' - If `file` already exists and is a valid HDF5 file, this function does
#'   nothing and returns successfully.
#' - If `file` exists but is **not** a valid HDF5 file (e.g., a text file),
#'   an error will be thrown and the file will not be modified.
#'
#' @return Invisibly returns `NULL`. This function is called for its side
#'   effects.
#' @seealso [h5_create_group()], [h5_write()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Explicitly create the file
#' h5_create_file(file)
#' 
#' if (file.exists(file)) {
#'   message("File created successfully.")
#' }
#' 
#' unlink(file)
h5_create_file <- function (file) {
  # Creating a file is equivalent to creating the root group '/'.
  h5_create_group(file = file, name = "/")
}


#' Move or Rename an HDF5 Object
#'
#' Moves or renames an object (dataset, group, etc.) within an HDF5 file.
#'
#' @details
#' This function provides an efficient, low-level wrapper for the HDF5
#' library's `H5Lmove` function. It is a metadata-only operation, meaning the
#' data itself is not read or rewritten. This makes it extremely fast, even
#' for very large datasets.
#'
#' You can use this function to either rename an object within the same group
#' (e.g., `"data/old"` to `"data/new"`) or to move an object to a
#' different group (e.g., `"data/old"` to `"archive/old"`). The destination
#' parent group will be automatically created if it does not exist.
#'
#' @param file The path to the HDF5 file.
#' @param from The current (source) path of the object (e.g., `"/group/data"`).
#' @param to The new (destination) path for the object (e.g., `"/group/data_new"`).
#'
#' @return This function is called for its side-effect and returns `NULL`
#'   invisibly.
#'
#' @seealso [h5_create_group()], [h5_delete()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(1:10, file, "group/dataset")
#' 
#' # Rename within the same group
#' h5_move(file, "group/dataset", "group/renamed")
#' h5_ls(file)
#' 
#' # Move to a new group (creates parent automatically)
#' h5_move(file, "group/renamed", "archive/dataset")
#' h5_ls(file, recursive = TRUE)
#' 
#' unlink(file)
h5_move <- function (file, from, to) {

  file <- validate_strings(file, from, must_exist = TRUE)
  assert_scalar_character(to)
  
  # Call the C function that wraps H5Lmove.
  .Call("C_h5_move", file, from, to, PACKAGE = "h5lite")
  invisible(NULL)
}


#' Delete an HDF5 Object or Attribute
#'
#' Deletes an object (dataset or group) or an attribute from an HDF5 file.
#' If the object or attribute does not exist, a warning is issued and the function returns
#' successfully (no error is raised).
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the object to delete (e.g., `"/data/dset"` or `"/groups/g1"`).
#' @param attr The name of the attribute to delete.
#'   * If `NULL` (the default), the object specified by `name` is deleted.
#'   * If a string is provided, the attribute named `attr` is removed from the object `name`.
#' @param warn Emit a warning if the name/attr does not exist. Default: `TRUE`
#'
#' @return Invisibly returns `NULL`. This function is called for its side effects.
#' @seealso [h5_create_group()], [h5_move()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_create_file(file)
#'
#' # Create some data and attributes
#' h5_write(matrix(1:10, 2, 5), file, "matrix")
#' h5_write("A note", file, "matrix", attr = "note")
#'
#' # Delete the attribute
#' h5_delete(file, "matrix", attr = "note")
#' h5_attr_names(file, "matrix") # Returns character(0)
#'
#' # Delete the dataset
#' h5_delete(file, "matrix")
#' h5_ls(file) # Returns character(0)
#'
#' # Cleaning up
#' unlink(file)
h5_delete <- function(file, name, attr = NULL, warn = TRUE) {

  file <- validate_strings(file, name, attr)
  assert_scalar_logical(warn)
  
  # Error if the file doesn't exist.
  if (!file.exists(file)) stop("File '", file, "' does not exist.")

  # Warn but do not error if the target doesn't exist.
  if (h5_exists(file, name, attr)) {
    if (is.null(attr)) { .Call("C_h5_delete",      file, name,       PACKAGE = "h5lite") }
    else               { .Call("C_h5_delete_attr", file, name, attr, PACKAGE = "h5lite") }
  }
  else if (isTRUE(warn)) {
    if (is.null(attr)) { warning("Object '", name, "' not found in file '", file, "'. Nothing to delete.") }
    else               { warning("Attribute '", attr, "' not found on object '", name, "'. Nothing to delete.")}
  }

  invisible(NULL)
}
