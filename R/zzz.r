
# Whether this load's filters have been destroyed (by unloading or at exit)
filter_state <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) { # nocov start
    # Register the compression plugins once per session
    .Call("C_register_hdf5_filters", PACKAGE = "h5lite")
    filter_state$destroyed <- FALSE

    # R doesn't run .onUnload() as it exits. hdf5lib then frees Blosc's worker
    # threads from HDF5's atexit handler, but on Windows the process has
    # already killed them by then, and waiting for them hangs R. So free them
    # while R is still shutting down.
    reg.finalizer(filter_state, function(e) destroy_filters(), onexit = TRUE)
} # nocov end

.onUnload <- function(libpath) {
    destroy_filters() # nocov
}

# Free Blosc's worker threads and cached contexts, and unregister the filters
destroy_filters <- function() { # nocov start
    if (isFALSE(filter_state$destroyed)) {
        filter_state$destroyed <- TRUE
        .Call("C_destroy_hdf5_filters", PACKAGE = "h5lite")
    }
} # nocov end


#' Evaluate a .Call(), closing any HDF5 handles an error leaves open
#'
#' An R error raised inside a C function skips that function's cleanup. Since
#' h5lite never keeps handles open between calls, anything still open after an
#' error is a leak, which on Windows also locks the file until R exits.
#' @noRd
#' @keywords internal
#' @param expr A `.Call()` expression, evaluated lazily.
h5_call <- function(expr) {
  tryCatch(
    expr  = expr,
    error = function(e) {
      .Call("C_h5_close_all", PACKAGE = "h5lite")
      stop(e)
    })
}

#' Number of HDF5 files and objects currently open (0 between calls)
#' @noRd
#' @keywords internal
open_id_count <- function() {
  .Call("C_h5_open_id_count", PACKAGE = "h5lite")
}
