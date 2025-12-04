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
#' @section Vignettes:
#' The following vignettes provide detailed examples and explanations for common tasks:
#' \itemize{
#'   \item `vignette("h5lite")`: A general introduction to the package.
#'   \item `vignette("atomic-vectors")`: Details on writing atomic vectors and scalars.
#'   \item `vignette("matrices")`: Details on writing matrices and arrays.
#'   \item `vignette("data-frames")`: Details on writing `data.frame` objects.
#'   \item `vignette("data-organization")`: How to organize data using groups and lists.
#'   \item `vignette("attributes-in-depth")`: A deep dive into using attributes.
#'   \item `vignette("parallel-io")`: Guide for using h5lite in parallel environments.
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