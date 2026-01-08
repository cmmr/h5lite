

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


#' Sanity check the 'as' argument
#' Ensures a character vector and that multiple values are named.
#' @noRd
#' @keywords internal
validate_as <- function (as) {
  
  if (is.null(as))       return ("auto")
  if (!is.character(as)) stop('`as` must be a character vector.')
  
  if (length(as) > 1 && is.null(names(as)))
    stop("When `as` has multiple values, they must be named.")
  
  if (!is.null(names(as)) && (any(is.na(names(as))) || any(names(as) == "")))
    stop("The `as` argument's names cannot be NA or an empty string.")

  return (as)
}
