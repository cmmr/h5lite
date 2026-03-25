
.onLoad <- function(libname, pkgname) {
    # Register plugins and spin up Blosc thread pools once per session
    .Call("C_register_hdf5_filters", PACKAGE = "h5lite") # nocov
}

.onUnload <- function(libpath) {
    # Cleanly tear down threads and free memory to prevent Valgrind warnings
    .Call("C_destroy_hdf5_filters", PACKAGE = "h5lite") # nocov
}
