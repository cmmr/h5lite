#' Read an HDF5 Object or Attribute
#'
#' Reads a dataset, a group, or a specific attribute from an HDF5 file into an R object.
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the dataset or group to read (e.g., `"/data/matrix"`).
#' @param attr The name of an attribute to read.
#'   * If `NULL` (default), the function reads the object specified by `name` (and attaches its attributes to the result).
#'   * If provided (string), the function reads *only* the specified attribute from `name`.
#' @param as The target R data type.
#'   * **Global:** `"auto"` (default), `"integer"`, `"double"`, `"logical"`, `"bit64"`, `"null"`.
#'   * **Specific:** A named vector mapping names or type classes to R types (see Section "Type Conversion").
#'
#' @section Type Conversion (`as`):
#' You can control how HDF5 data is converted to R types using the `as` argument.
#'
#' **1. Mapping by Name:**
#' \itemize{
#'   \item `as = c("data_col" = "integer")`: Reads the dataset/column named "data_col" as an integer.
#'   \item `as = c("@validated" = "logical")`: When reading a dataset, this forces the attached attribute "validated" to be read as logical.
#' }
#'
#' **2. Mapping by HDF5 Type Class:**
#' You can target specific HDF5 data types using keys prefixed with a dot (`.`).
#' Supported classes include:
#' \itemize{
#'   \item **Integer:** `.int`, `.int8`, `.int16`, `.int32`, `.int64`
#'   \item **Unsigned:** `.uint`, `.uint8`, `.uint16`, `.uint32`, `.uint64`
#'   \item **Floating Point:** `.float`, `.float16`, `.float32`, `.float64`
#' }
#' Example: `as = c(.uint8 = "logical", .int = "bit64")`
#'
#' **3. Precedence & Attribute Config:**
#' * **Attributes vs Datasets:** Attribute type mappings take precedence over dataset mappings.
#'   If you specify `as = c(.uint = "logical", "@.uint" = "integer")`, unsigned integer datasets
#'   will be read as `logical`, but unsigned integer *attributes* will be read as `integer`.
#' * **Specific vs Generic:** Specific keys (e.g., `.uint32`) take precedence over generic keys (e.g., `.uint`),
#'   which take precedence over the global default (`.`).
#'
#' @note
#' The `@` prefix is **only** used to configure attached attributes when reading a dataset (`attr = NULL`).
#' If you are reading a specific attribute directly (e.g., `h5_read(..., attr = "id")`), do **not** use
#' the `@` prefix in the `as` argument.
#'
#' @return An R object corresponding to the HDF5 object or attribute.
#'   Returns `NULL` if the object is skipped via `as = "null"`.
#' @seealso [h5_write()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # --- Write Data ---
#' h5_write(c(10L, 20L), file, "ints")
#' h5_write(I(TRUE),     file, "ints", attr = "ready")
#' h5_write(c(10.5, 18), file, "floats")
#' h5_write(I("meters"), file, "floats", attr = "unit")
#' 
#' # --- Read Data ---
#' # Read dataset
#' x <- h5_read(file, "ints")
#' print(x)
#' 
#' # Read dataset with attributes
#' y <- h5_read(file, "floats")
#' print(attr(y, "unit"))
#' 
#' # Read a specific attribute directly
#' unit <- h5_read(file, "floats", attr = "unit")
#' print(unit)
#' 
#' # --- Type Conversion Examples ---
#' 
#' # Force integer dataset to be read as numeric (double)
#' x_dbl <- h5_read(file, "ints", as = "double")
#' class(x_dbl)
#' 
#' # Force attached attribute to be read as logical
#' # Note the "@" prefix to target the attribute
#' # h5_read(file, "ints", as = c("@ready" = "logical"))
#' 
#' unlink(file)
h5_read <- function(file, name = "/", attr = NULL, as = "auto") {
  
  file   <- validate_strings(file, name, attr, must_exist = TRUE)
  obj_as <- validate_as(as)

  # Validate choices
  choices <- c("auto", "integer", "double", "logical", "bit64", "null")
  if (!missing(choices))
    for (i in seq_along(obj_as))
      obj_as[i] <- tryCatch(
        expr  = match.arg(tolower(obj_as[[i]]), choices),
        error = function (e) { 
          stop(
            call. = FALSE,
            "Invalid `as` argument: '", obj_as[[i]], "'\n", 
            "Valid options are: '", paste(collapse = "', '", choices), "'.") })

  # Prepare the 'as' map for attributes
  # Example: obj_as  = c("@ready" = "logical", ".uint" = "integer", "@." = "null")
  #          attr_as = c("ready" = "logical",  ".uint" = "integer", "."  = "null")
  attr_as <- obj_as
  if (!is.null(names(attr_as))) {
    attr_as <- attr_as[grepl("^[.@]", names(attr_as))] 
    if (length(attr_as) > 0) {
      attr_as <- attr_as[rev(order(names(attr_as)))]     
      names(attr_as) <- sub("^@", "", names(attr_as))
      attr_as <- attr_as[!duplicated(names(attr_as))]
    }
    if (is.null(attr_as) || length(attr_as) == 0) attr_as <- "auto"
  }

  # --- Perform Read Operation ---
  read_data(file, name, attr, obj_as, attr_as)
}


read_data <- function (file, name, attr = NULL, obj_as, attr_as) {
  
  # Case 1: Read Specific Attribute directly
  if (!is.null(attr))
    return(.Call("C_h5_read_attribute", file, name, attr, attr_as, PACKAGE = "h5lite"))
  
  # Case 2: Read Group (Recursive)
  if (h5_is_group(file, name)) {
    children <- sort(h5_ls(file, name, recursive = FALSE, full.names = TRUE))
    res      <- lapply(children, read_data, file = file, obj_as = obj_as, attr_as = attr_as)
    names(res) <- if (length(res) == 0) NULL else basename(children)
  }
  
  # Case 3: Read Dataset
  else {
    res <- .Call("C_h5_read_dataset", file, name, obj_as, basename(name), PACKAGE = "h5lite")
  }

  # --- Attach Attributes ---
  obj_attr_names <- h5_attr_names(file, name)
  obj_attr_names <- setdiff(obj_attr_names, c("DIMENSION_LIST", "REFERENCE_LIST"))
  for (attr in obj_attr_names)
    if (!is.na(h5_class(file, name, attr)))
      base::attr(res, attr) <- .Call("C_h5_read_attribute", file, name, attr, attr_as, PACKAGE = "h5lite")
  
  return(res)
}
