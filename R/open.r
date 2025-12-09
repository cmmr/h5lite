
#' Create an HDF5 File Handle
#' 
#' Creates a file handle that provides a convenient, object-oriented interface
#' for interacting with and navigating a specific HDF5 file.
#'
#' @details
#' This function returns a special `h5` object that wraps the standard `h5lite`
#' functions. The primary benefit is that the `file` argument is pre-filled,
#' allowing for more concise and readable code when performing multiple
#' operations on the same file.
#'
#' For example, instead of writing:
#' ```r
#' h5_write(file, "dset1", 1:10)
#' h5_write(file, "dset2", 2:20)
#' h5_ls(file)
#' ```
#' You can create a handle and use its methods:
#' ```r
#' h5 <- h5_open("my_file.h5")
#' h5$write("dset1", 1:10)
#' h5$write("dset2", 2:20)
#' h5$ls()
#' ```
#'
#' @section Pass-by-Reference Behavior:
#' Unlike most R objects, the `h5` handle is an **environment**. This means it
#' is passed by reference. If you assign it to another variable (e.g.,
#' `h5_alias <- h5`), both variables point to the *same* handle. Modifying one
#' (e.g., by calling `h5_alias$close()`) will also affect the other.
#'
#' @section Interacting with the HDF5 File:
#' The `h5` object provides several ways to interact with the HDF5 file:
#'
#' \subsection{Standard `h5lite` Functions as Methods}{
#'   Most `h5lite` functions (e.g., `h5_read`, `h5_write`, `h5_ls`) are
#'   available as methods on the `h5` object, without the `h5_` prefix.
#'   The `file` argument is automatically supplied.
#'
#'   For example, `h5$write("dset", data)` is equivalent to
#'   `h5_write(file, "dset", data)`.
#'
#'   The available methods are: `read`, `read_attr`, `write`, `write_attr`,
#'   `class`, `class_attr`, `dim`, `dim_attr`, `exists`, `exists_attr`,
#'   `is_dataset`, `is_group`, `ls`, `ls_attr`, `str`, `typeof`, `typeof_attr`,
#'   `create_file`, `create_group`, `delete`, `delete_attr`, `move`.
#' }
#'
#' \subsection{Navigation (`$cd()`, `$pwd()`)}{
#'   The handle maintains an internal working directory to simplify
#'   path management.
#'   \itemize{
#'     \item{`h5$cd(group)`: Changes the handle's internal working directory.
#'       This is a stateful, pass-by-reference operation. It understands absolute
#'       paths (e.g., `"/new/path"`) and relative navigation (e.g., `"../other"`).
#'       The target group does not need to exist.
#'     }
#'     \item{`h5$pwd()`: Returns the current working directory.}
#'   }
#'   When you call a method like `h5$read("dset")`, the handle automatically
#'   prepends the current working directory to any relative path. If you provide
#'   an absolute path (e.g., `h5$read("/path/to/dset")`), the working directory
#'   is ignored.
#' }
#'
#' \subsection{Subsetting with `[[` and `[[<-`}{
#'   The `h5` handle also supports `[[` for reading and writing, providing a
#'   convenient, list-like syntax.
#'   \itemize{
#'     \item **Reading Datasets/Groups:** `h5[["my_dataset"]]` is a shortcut for `h5$read("my_dataset")`.
#'     \item **Writing Datasets/Groups:** `h5[["my_dataset"]] <- value` is a shortcut for `h5$write("my_dataset", value)`.
#'     \item **Accessing Attributes:** You can access attributes by separating the object name
#'       and attribute name with an `@` symbol. For example:
#'     - `h5[["my_dataset@@my_attribute"]]` reads an attribute.
#'     - `h5[["my_dataset@@my_attribute"]] <- "new value"` writes an attribute.
#'   }
#' }
#'
#' \subsection{Closing the Handle (`$close()`)}{
#' The `h5lite` package does not keep files persistently open. Each operation
#' opens, modifies, and closes the file. Therefore, the `h5$close()` method
#' does not perform any action on the HDF5 file itself.
#'
#' Its purpose is to invalidate the handle, preventing any further operations
#' from being called. After `h5$close()` is called, any subsequent method
#' call (e.g., `h5$ls()`) will throw an error.
#' }
#'
#' @param file Path to the HDF5 file. The file will be created if it does not
#'   exist.
#' @return An object of class `h5` with methods for interacting with the file.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5 <- h5_open(file)
#'
#' h5$write("a", 1:10)
#' h5$write("b", c("x", "y"))
#' h5$ls()
#'
#' # --- Subsetting for Read/Write ---
#' h5[["c"]] <- matrix(1:4, 2)
#' h5[["c@@units"]] <- "m/s"
#' print(h5[["c"]])
#' print(h5[["c@@units"]])
#'
#' # --- Navigation ---
#' h5$cd("/g1/g2")
#' h5$pwd() # "/g1/g2"
#' h5$write("d1", 1:5) # Writes to /g1/g2/d1
#' h5$cd("..")
#' h5$ls() # Lists 'g2'
#'
#' # Write and read using subsetting
#' h5[["c"]] <- matrix(1:4, 2)
#' h5[["c@units"]] <- "m/s"
#' print(h5[["c"]])
#' print(h5[["c@units"]])
#' 
#'
#' # Invalidate the handle
#' h5$close()
#' # try(h5$ls()) # This would now throw an error
#'
#' unlink(file)

h5_open <- function (file) {

  h5_create_file(file)
  
  env <- new.env(parent = emptyenv())
  env$.file <- file
  env$.wd <- "/"

  env$read         = function(name, attrs = FALSE) { h5_run(env, h5_read) }
  env$read_attr    = function(name, attribute) { h5_run(env, h5_read_attr) }
  env$write        = function(name, data, dtype = "auto", compress = TRUE, attrs = FALSE) { h5_run(env, h5_write) }
  env$write_attr   = function(name, attribute, data, dtype = "auto") { h5_run(env, h5_write_attr) }
  env$class        = function(name, attrs = FALSE) { h5_run(env, h5_class) }
  env$class_attr   = function(name, attribute) { h5_run(env, h5_class_attr) }
  env$dim          = function(name) { h5_run(env, h5_dim) }
  env$dim_attr     = function(name, attribute) { h5_run(env, h5_dim_attr) }
  env$exists       = function(name = ".") { h5_run(env, h5_exists) }
  env$exists_attr  = function(name, attribute) { h5_run(env, h5_exists_attr) }
  env$is_dataset   = function(name) { h5_run(env, h5_is_dataset) }
  env$is_group     = function(name) { h5_run(env, h5_is_group) }
  env$ls           = function(name = ".", recursive = TRUE, full.names = FALSE) { h5_run(env, h5_ls) }
  env$ls_attr      = function(name) { h5_run(env, h5_ls_attr) }
  env$str          = function(name = ".", attrs = TRUE) { h5_run(env, h5_str) }
  env$typeof       = function(name) { h5_run(env, h5_typeof) }
  env$typeof_attr  = function(name, attribute) { h5_run(env, h5_typeof_attr) }
  env$create_file  = function() { h5_run(env, h5_create_file) }
  env$create_group = function(name) { h5_run(env, h5_create_group) }
  env$delete       = function(name) { h5_run(env, h5_delete) }
  env$delete_attr  = function(name, attribute) { h5_run(env, h5_delete_attr) }
  env$move         = function(from, to) { h5_run(env, h5_move) }
  
  # Navigation methods
  env$cd = function(group = "/") {
    check_open(env)
    env$.wd <- normalize_path(env$.wd, group)
    invisible(env)
  }
  env$pwd = function() {
    check_open(env)
    env$.wd
  }
  
  # Control methods
  env$close = function () {
    check_open(env)
    env$.file <- NULL
    env$.wd <- NULL
    invisible(NULL)
  }

  structure(env, class = "h5")
}

check_open <- function(env) {
  if (is.null(env$.file))
    stop("This h5 file handle has been closed.", call. = FALSE)
}


h5_run <- function(env, func) {

  check_open(env) # Ensure the handle is not closed
  
  # Capture the arguments passed to the calling function (e.g., h5$read)
  args <- as.list(parent.frame())

  # Normalize paths for 'name', 'from', and 'to' arguments if they exist
  if (hasName(args, "name")) { args$name <- normalize_path(env$.wd, args$name) }
  if (hasName(args, "from")) { args$from <- normalize_path(env$.wd, args$from) }
  if (hasName(args, "to"))   { args$to   <- normalize_path(env$.wd, args$to)   }

  # Call the underlying h5lite function (e.g., h5_read) with the modified arguments
  args$file <- env$.file
  do.call(func, args, envir = parent.frame(n = 2))
}


normalize_path <- function(wd, path) {
  # An absolute path from the user overrides the working directory
  if (startsWith(path, "/")) {
    return(path)
  }
  
  # If path is absolute, start from root. Otherwise, start from current wd.
  start_dir <- if (startsWith(path, "/")) "/" else wd
  
  full_path <- file.path(start_dir, path, fsep = "/")
  
  # Split into components and process '..' and '.'
  parts <- strsplit(full_path, "/")[[1]]
  new_parts <- character(0)
  for (part in parts) {
    if (part == "" || part == ".") next
    if (part == "..") {
      if (length(new_parts) > 0) new_parts <- new_parts[-length(new_parts)]
    } else {
      new_parts <- c(new_parts, part)
    }
  }
  
  # Reconstruct the path
  if (length(new_parts) == 0) "/" else paste0("/", paste(new_parts, collapse = "/"))
}



#' @export
print.h5 <- function(x, ...) {
  if (is.null(x$.file)) {
    cat("<h5 handle for a closed file>\n")
  } else {
    size <- if (file.exists(x$.file)) file.size(x$.file) else NA
    n_objects <- if (file.exists(x$.file)) length(h5_ls(x$.file, recursive = FALSE)) else NA
    
    cat("<h5 handle>\n")
    cat("  File: ", x$.file, "\n")
    cat("  WD:   ", x$pwd(), "\n")
    if (!is.na(size)) {
      cat("  Size: ", format(structure(size, class = "object_size")), "\n")
    }
    if (!is.na(n_objects)) {
      cat("  Objects (root): ", n_objects, "\n")
    }
  }
  invisible(x)
}

#' @export
str.h5 <- function(object, ...) {
  object$str(...)
}

#' @export
as.character.h5 <- function(x, ...) {
  # Return the file path, or NULL if the handle is closed.
  x$.file
}

#' @export
`[[.h5` <- function(x, i) {
  if (!is.character(i) || length(i) != 1) {
    stop("Subsetting h5 objects with `[[` requires a single character name.", call. = FALSE)
  }

  # Explicitly check for an empty attribute name, which is invalid.
  if (endsWith(i, "@")) {
    stop("Invalid attribute subsetting syntax. Attribute name cannot be empty.", call. = FALSE)
  }

  parts <- strsplit(i, "@", fixed = TRUE)[[1]]

  if (length(parts) == 1) {
    # No '@', so it's a dataset/group read
    x$read(name = i)
  } else if (length(parts) == 2) {
    # Found '@', it's an attribute read
    obj_name  <- parts[1]
    attr_name <- parts[2]
    if (nchar(obj_name) == 0) {
      obj_name <- x$.wd # If object name is empty, use the current working directory
    }
    x$read_attr(name = obj_name, attribute = attr_name)
  } else {
    stop("Invalid subsetting syntax. Only one '@' is permitted for attribute access.", call. = FALSE) # nocov
  }
}

#' @export
`[[<-.h5` <- function(x, i, value) {
  if (!is.character(i) || length(i) != 1) {
    stop("Subsetting h5 objects with `[[<-` requires a single character name.", call. = FALSE)
  }

  # Explicitly check for an empty attribute name, which is invalid.
  if (endsWith(i, "@")) {
    stop("Invalid attribute subsetting syntax. Attribute name cannot be empty.", call. = FALSE)
  }
  
  parts <- strsplit(i, "@", fixed = TRUE)[[1]]
  
  if (length(parts) == 1) {
    # No '@', so it's a dataset/group write
    x$write(name = i, data = value)
  } else if (length(parts) == 2) {
    # Found '@', it's an attribute write
    obj_name  <- parts[1]
    attr_name <- parts[2]
    if (nchar(obj_name) == 0) {
      obj_name <- x$.wd # If object name is empty, use the current working directory
    }
    x$write_attr(name = obj_name, attribute = attr_name, data = value)
  } else {
    stop("Invalid subsetting syntax. Only one '@' is permitted for attribute access.", call. = FALSE) # nocov
  }

  x
}
