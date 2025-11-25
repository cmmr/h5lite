

#' Create an HDF5 Group
#' 
#' Explicitly creates a new group (or nested groups) in an HDF5 file.
#' This is useful for creating an empty group structure.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the group to create (e.g., "/g1/g2").
#' @return Invisibly returns `NULL`. This function is called for its side effects.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_create_group(file, "/my/nested/group")
#' 
#' # List all objects recursively to see the full structure
#' h5_ls(file, recursive = TRUE)
#' unlink(file)
h5_create_group <- function(file, name) {
  file <- path.expand(file)
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
#' @return Invisibly returns `NULL`. This function is called for its side
#'   effects.
#' @seealso [h5_create_group()], [h5_write()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#'
#' # Explicitly create the file (optional)
#' h5_create_file(file)
#'
#' # Check that it exists
#' file.exists(file) # TRUE
#'
#' # Write to the file
#' h5_write(file, "data", 1:10)
#'
#' # Clean up
#' unlink(file)
h5_create_file <- function(file) {
  file <- path.expand(file)
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
#' @param file Path to the HDF5 file.
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
#'
#' # Create a sample file structure
#' h5_write(file, "group1/dataset_a", 1:10)
#' h5_write(file, "group1/dataset_b", 2:20)
#' h5_create_group(file, "group2")
#'
#' # --- Example 1: Rename a dataset ---
#'
#' print(h5_ls(file, recursive = TRUE))
#' #> [1] "group1"           "group1/dataset_a" "group1/dataset_b" "group2"
#'
#' h5_move(file, "group1/dataset_a", "group1/data_renamed")
#'
#' print(h5_ls(file, recursive = TRUE))
#' #> [1] "group1"              "group1/dataset_b"  "group1/data_renamed" "group2"
#'
#'
#' # --- Example 2: Move a dataset between groups ---
#'
#' h5_move(file, "group1/dataset_b", "group2/data_moved")
#'
#' print(h5_ls(file, recursive = TRUE))
#' #> [1] "group1"              "group1/data_renamed" "group2"
#' #> [4] "group2/data_moved"
#'
#' # Clean up
#' unlink(file)
h5_move <- function(file, from, to) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  
  if (!is.character(from) || length(from) != 1) {
    stop("'from' must be a single string.")
  }
  if (!is.character(to) || length(to) != 1) {
    stop("'to' must be a single string.")
  }
  
  .Call("C_h5_move", file, from, to, PACKAGE = "h5lite")
  invisible(NULL)
}
