#' h5lite: A Simple and Lightweight HDF5 Interface
#'
#' @description
#' The `h5lite` package provides a simple, lightweight, and user-friendly 
#' interface for reading and writing HDF5 files. It is designed for R users 
#' who want to save and load common R objects (vectors, matrices, arrays, 
#' factors, and data.frames) to an HDF5 file without needing to understand 
#' the low-level details of the HDF5 C API.
#'
#' @section Key Features:
#' \itemize{
#'   \item **Simple API:** Use familiar functions like [h5_read()] and [h5_write()].
#'   \item **Automatic Handling:** Dimensions, data types, and group creation are handled automatically.
#'   \item **Safe by Default:** Numeric data is read as `double` to prevent integer overflow.
#'   \item **Easy Installation:** The required HDF5 library is bundled with the package.
#' }
#'
#' @seealso
#' Useful links:
#' * <https://cmmr.github.io/h5lite/>
#' * Report bugs at <https://github.com/cmmr/h5lite/issues>
#'
#' Key functions: [h5_read()], [h5_write()], [h5_ls()], [h5_str()]
#'
#' @keywords internal
#' @aliases h5lite-package
"_PACKAGE"

## usethis namespace: start
#' @useDynLib h5lite, .registration = TRUE
## usethis namespace: end
NULL