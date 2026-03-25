

assert_scalar_logical <- function(...) {
  dots <- list(...)
  for (i in seq_along(dots)) {
    x <- dots[[i]]
    if (!(is.logical(x) && length(x) == 1 && !is.na(x)))
      stop("Argument `", match.call()[[i + 1]], "` must be a scalar logical.", call. = FALSE)
  }
}

assert_scalar_integer <- function(..., .null_ok = FALSE) {
  dots <- list(...)
  for (i in seq_along(dots)) {
    x <- dots[[i]]
    if (.null_ok && is.null(x)) next
    if (!(is.numeric(x) && length(x) == 1 && !is.na(x) && isTRUE(x %% 1 == 0)))
      stop("Argument `", match.call()[[i + 1]], "` must be a scalar integer.", call. = FALSE)
  }
}

assert_scalar_character <- function(...) {
  dots <- list(...)
  for (i in seq_along(dots)) {
    x <- dots[[i]]
    if (!(is.character(x) && length(x) == 1 && !is.na(x) && nzchar(trimws(x))))
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


#' Sanity check integer arguments for start and count
#' @noRd
#' @keywords internal
validate_start_count <- function (file, name, attr, start, count) {
  
  if (is.null(start) && is.null(count))
    return (invisible())
  
  if (is.null(start) && !is.null(count))
    stop('`start` must be provided if `count` is specified.', call. = FALSE)
  
  if (!is.null(attr))
    stop('`start` and `count` cannot be used on attributes.', call. = FALSE)
  
  if (!is.numeric(start)) stop ('`start` must be numeric', call. = FALSE)
  
  start <- as.numeric(start)
  
  if (length(start) <  1) stop ('`start` cannot be an empty vector', call. = FALSE)
  if (!isTRUE(all(start > 0))) stop ('`start` must be positive', call. = FALSE)
  
  # Allow count to be NULL in the parent frame, but enforce it as 1 for bounds checking here
  check_count <- count
  if (is.null(count)) {
    check_count <- 1
  } else {
    if (!is.numeric(count)) stop ('`count` must be numeric', call. = FALSE)
    check_count <- as.numeric(count)
    if (length(check_count) != 1) stop ('`count` must be a single numeric value', call. = FALSE)
    if (!isTRUE(all(check_count > 0))) stop ('`count` must be positive', call. = FALSE)
  }
  
  shape <- h5_dim(file, name, attr)
  if (length(shape) == 0) shape <- 1L # scalar
  
  N <- length(shape)
  n <- length(start)
  
  if (n > N) stop('`start` has more dimensions than the dataset', call. = FALSE)
  
  # Determine alignment: which dimensions in `shape` does `start` apply to?
  if (N >= 3) { full_map <- c(seq(N, 3L, by = -1L), 1L, 2L) }
  else        { full_map <- seq_len(N) }
  
  # Slice the map to match the number of values provided in `start`
  dim_map <- full_map[seq_len(n)]
  
  # Extract the specific dimension sizes that 'start' is targeting
  target_shape <- shape[dim_map]
  
  if (!isTRUE(all(target_shape >= start)))              stop('`start` is out of bounds', call. = FALSE)
  if (start[[n]] + check_count - 1 > target_shape[[n]]) stop('`count` is out of bounds', call. = FALSE)
  
  assign('start', start, pos = parent.frame())
  
  # Only overwrite count in the parent if it was actively provided
  if (!is.null(count)) {
    assign('count', check_count, pos = parent.frame())
  }
  
  return (invisible())
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
