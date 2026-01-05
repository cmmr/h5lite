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
#' h5_write(1:10, file, "dset1")
#' h5_write(2:20, file, "dset2")
#' h5_ls(file)
#' ```
#' You can create a handle and use its methods. Note that the `file` argument
#' is omitted from the method calls:
#' ```r
#' h5 <- h5_open("my_file.h5")
#' h5$write(1:10, "dset1")
#' h5$write(2:20, "dset2")
#' h5$ls()
#' h5$close()
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
#'
#'   For example, `h5$write(data, "dset")` is equivalent to
#'   `h5_write(data, file, "dset")`.
#'
#'   The available methods are: `read`, `write`, `class`, `dim`, `exists`,
#'   `is_dataset`, `is_group`, `ls`, `names`, `str`, `typeof`, `create_group`,
#'   `attr_names`, `delete`, `move`.
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
#' 
#' # Open the handle
#' h5 <- h5_open(file)
#' 
#' # Write data (note: 'data' is the first argument, 'file' is implicit)
#' h5$write(1:5, "vector")
#' h5$write(matrix(1:9, 3, 3), "matrix")
#' 
#' # Create a group and navigate to it
#' h5$create_group("simulations")
#' h5$cd("simulations")
#' print(h5$pwd()) # "/simulations"
#' 
#' # Write data relative to the current working directory
#' h5$write(rnorm(10), "run1") # Writes to /simulations/run1
#' 
#' # Read data
#' dat <- h5$read("run1")
#' 
#' # List contents of current WD
#' h5$ls()
#' 
#' # Close the handle
#' h5$close()
#' unlink(file)
h5_open <- function (file) {
  
  h5_create_file(file)
  
  env        <- new.env(parent = emptyenv())
  env$.file  <- file
  env$.wd    <- "/"
  class(env) <- "h5"
  
  env$read         = function(name = ".", attr = NULL, as = "auto")                  { h5_run(env, h5_read)  }
  env$write        = function(data, name, attr = NULL, as = "auto", compress = TRUE) { h5_run(env, h5_write) }
  env$ls           = function(name = ".", recursive = TRUE, full.names = FALSE)      { h5_run(env, h5_ls)    }
  
  env$str          = function(name = ".", attrs = TRUE)       { h5_run(env, h5_str)          }
  env$class        = function(name, attr = NULL)              { h5_run(env, h5_class)        }
  env$dim          = function(name, attr = NULL)              { h5_run(env, h5_dim)          }
  env$exists       = function(name, attr = NULL)              { h5_run(env, h5_exists)       }
  env$typeof       = function(name, attr = NULL)              { h5_run(env, h5_typeof)       }
  env$delete       = function(name, attr = NULL, warn = TRUE) { h5_run(env, h5_delete)       }
  env$is_dataset   = function(name)                           { h5_run(env, h5_is_dataset)   }
  env$is_group     = function(name)                           { h5_run(env, h5_is_group)     }
  env$names        = function(name = ".")                     { h5_run(env, h5_names)        }
  env$attr_names   = function(name = ".")                     { h5_run(env, h5_attr_names)   }
  env$create_group = function(name)                           { h5_run(env, h5_create_group) }
  env$move         = function(from, to)                       { h5_run(env, h5_move)         }
  
  # Navigation methods
  env$cd = function(group = "/") {
    check_open(env)
    env$.wd <- normalize_path(env$.wd, group)
    return(invisible(NULL))
  }
  env$pwd = function() {
    check_open(env)
    return(env$.wd)
  }
  
  # Control methods
  env$close = function () {
    check_open(env)
    env$.file <- NULL
    env$.wd   <- NULL
    return(invisible(NULL))
  }
  
  return(env)
}

check_open <- function(env) {
  if (is.null(env$.file))
    stop("This h5 file handle has been closed.", call. = FALSE)
}


#' @noRd
#' @keywords internal
h5_run <- function(env, func) {
  
  check_open(env) # Ensure the handle is not closed
  
  # Capture the arguments passed to the calling function (e.g., h5$read)
  args <- as.list(parent.frame())
  
  # Normalize paths for 'name', 'from', and 'to' arguments if they exist
  if ("name" %in% names(args)) { args$name <- normalize_path(env$.wd, args$name) }
  if ("from" %in% names(args)) { args$from <- normalize_path(env$.wd, args$from) }
  if ("to"   %in% names(args)) { args$to   <- normalize_path(env$.wd, args$to)   }
  
  # Call the underlying h5lite function (e.g., h5_read) with the modified arguments
  args$file <- env$.file
  do.call(func, args, envir = parent.frame(n = 2))
}


#' @noRd
#' @keywords internal
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
