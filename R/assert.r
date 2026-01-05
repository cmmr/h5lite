

assert_scalar_logical <- function(...) {
  dots <- list(...)
  for (i in seq_along(dots)) {
    x <- dots[[i]]
    if (!(is.logical(x) && length(x) == 1 && !is.na(x)))
      stop("Argument `", match.call()[[i + 1]], "` must be a scalar logical.", call. = FALSE)
  }
}

assert_scalar_character <- function(...) {
  dots <- list(...)
  for (i in seq_along(dots)) {
    x <- dots[[i]]
    if (!(is.character(x) && length(x) == 1 && !is.na(x) && nzchar(x)))
      stop("Argument `", match.call()[[i + 1]], "` must be a scalar character.", call. = FALSE)
  }
}



#' Validates string inputs
#' @noRd
#' @keywords internal
#' @param file Path to the HDF5 file.
#' @param name The full path of the object (group or dataset).
#' @param attr The name of an attribute to check. If provided, the length of the attribute is returned.
#' @param must_exist Logical. If `TRUE`, the function will stop if the object does not exist.
#' @return The expanded path to the file.
validate_strings <- function (file, name = "/", attr = NULL, must_exist = FALSE) {

  assert_scalar_character(file, name)
  if (!is.null(attr)) assert_scalar_character(attr)

  file <- path.expand(file)

  if (must_exist) {

    # Check File Existence
    if (!file.exists(file)) stop("File '", file, "' does not exist.", call. = FALSE)
    
    # Check Object/Attribute Existence
    if (!.Call("C_h5_exists", file, name, attr, PACKAGE = "h5lite")) {
      if (is.null(attr)) { stop("Object '", name, "' does not exist in file '", file, "'.", call. = FALSE) } 
      else               { stop("Attribute '", attr, "' does not exist on object '", name, "'.", call. = FALSE) }
    }
  }

  return (file)
}
