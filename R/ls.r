#' List HDF5 Objects
#' 
#' Lists the names of objects (datasets and groups) within an HDF5 file or group.
#'
#' @param file The path to the HDF5 file.
#' @param name The group path to start listing from. Defaults to the root group (`/`).
#' @param recursive If `TRUE` (default), lists all objects found recursively
#'   under `name`. If `FALSE`, lists only the immediate children.
#' @param full.names If `TRUE`, the full paths from the file's root are
#'   returned. If `FALSE` (the default), names are relative to `name`.
#' @param scales If `TRUE`, also returns datasets that are dimensions scales for
#'   other datasets.
#' 
#' @return A character vector of object names. If `name` is `/` (the default),
#'   the paths are relative to the root of the file. If `name` is another group,
#'   the paths are relative to that group (unless `full.names = TRUE`).
#' 
#' @seealso [h5_attr_names()], [h5_str()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_create_group(file, "foo/bar")
#' h5_write(1:5, file, "foo/data")
#' 
#' # List everything recursively
#' h5_ls(file)
#' 
#' # List only top-level objects
#' h5_ls(file, recursive = FALSE)
#' 
#' # List relative to a sub-group
#' h5_ls(file, "foo")
#' 
#' unlink(file)
h5_ls <- function(file, name = "/", recursive = TRUE, full.names = FALSE, scales = FALSE) {

  file <- validate_strings(file, name, must_exist = TRUE)
  assert_scalar_logical(recursive, full.names, scales)
  
  # Call the C function that performs a recursive or non-recursive listing.
  .Call("C_h5_ls", file, name, recursive, full.names, scales, PACKAGE = "h5lite")
}

#' Display the Structure of an HDF5 Object
#'
#' Recursively prints a summary of an HDF5 group or dataset, similar to
#' the structure of `h5ls -r`. It displays the nested structure, object types,
#' dimensions, and attributes.
#'
#' @details
#' This function provides a quick and convenient way to inspect the contents of
#' an HDF5 file. It performs a recursive traversal of the file from the C-level
#' and prints a formatted summary to the R console.
#'
#' This function **does not read any data** into R. It only inspects the
#' metadata (names, types, dimensions) of the objects in the file, making it
#' fast and memory-safe for arbitrarily large files.
#'
#' @param file The path to the HDF5 file.
#' @param name The name of the group or dataset to display. Defaults to the root
#'   group "/".
#' @param attrs Set to `FALSE` to only groups and datasets. The default (`TRUE`)
#'   shows attributes as well.
#' @return This function is called for its side-effect of printing to the
#'   console and returns \code{NULL} invisibly.
#' @seealso [h5_ls()], [h5_attr_names()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(list(x = 1:10, y = matrix(1:9, 3, 3)), file, "group")
#' h5_write("metadata", file, "group", attr = "info")
#' 
#' # Print structure
#' h5_str(file)
#' 
#' unlink(file)
h5_str <- function(file, name = "/", attrs = TRUE) {
  
  file <- validate_strings(file, name, must_exist = TRUE)
  assert_scalar_logical(attrs)
  
  # Call the C function that recursively visits objects and prints a summary.
  .Call("C_h5_str", file, name, isTRUE(attrs), PACKAGE = "h5lite")
  invisible(NULL)
}
