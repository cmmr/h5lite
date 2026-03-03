#' Read an HDF5 Object or Attribute
#'
#' Reads a dataset, a group, or a specific attribute from an HDF5 file into an R object.
#' Supports partial reading (hyperslabs) to load specific subsets of data.
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the dataset or group to read (e.g., `"/data/matrix"`).
#' @param attr The name of an attribute to read.
#'   * If `NULL` (default), the function reads the object specified by `name` (and attaches its attributes to the result).
#'   * If provided (string), the function reads *only* the specified attribute from `name`.
#' @param as The target R data type.
#'   * **Global:** `"auto"` (default), `"integer"`, `"double"`, `"logical"`, `"bit64"`, `"null"`.
#'   * **Specific:** A named vector mapping names or type classes to R types (see Section "Type Conversion").
#' @param start An integer vector specifying the 1-based starting coordinates for a partial read.
#'   For example, `start = c(5, 2)` begins reading at the 5th row and 2nd column.
#'   Must be provided alongside `count`. If `NULL` (default), the entire dataset is read.
#' @param count A single integer specifying the number of elements to read.
#'   Must be provided alongside `start`. If `NULL` (default), the entire dataset is read.
#'
#' @section Partial Reading (Hyperslabs):
#' You can read specific subsets of an n-dimensional dataset without loading the entire object 
#' into memory by utilizing the `start` and `count` arguments.
#' 
#' Both `start` and `count` must be provided together. Coordinates are 1-based and follow 
#' standard R array indexing. 
#' 
#' The `count` parameter is always a **single integer** and is applied to the *last* dimension 
#' specified in your `start` vector. 
#' 
#' * **Example 1:** If you are reading from a 20x5 matrix, calling `start = 5` and `count = 3` 
#'   will start at row 5 and extract 3 complete rows (automatically spanning all 5 columns).
#' * **Example 2:** Calling `start = c(5, 2)` and `count = 3` on the same matrix would start 
#'   at row 5, column 2, and read 3 columns along that specific row.
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
#' Partial reading (`start`/`count`) is only supported for datasets, not attributes.
#'
#' @return An R object corresponding to the HDF5 object or attribute.
#'   Returns `NULL` if the object is skipped via `as = "null"`.
#' @seealso [h5_write()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # --- Setup: Write Test Data ---
#' h5_write(c(10L, 20L, 30L, 40L, 50L), file, "ints")
#' 
#' m <- matrix(1:100, nrow = 20, ncol = 5)
#' h5_write(m, file, "matrix_data")
#' 
#' # --- Standard Reading ---
#' # Read the entire dataset
#' x <- h5_read(file, "ints")
#' print(x)
#' 
#' # --- Partial Reading (Hyperslabs) ---
#' 
#' # 1. Read a subset of a 1D vector
#' # Starts at the 2nd element and reads 3 elements total (returns 20, 30, 40)
#' sub_vec <- h5_read(file, "ints", start = 2, count = 3)
#' print(sub_vec)
#' 
#' # 2. Read complete rows from a Matrix
#' # Starts at row 5 and reads 3 rows (spanning all columns automatically)
#' sub_rows <- h5_read(file, "matrix_data", start = 5, count = 3)
#' print(sub_rows)
#' 
#' # 3. Read a subset within a specific row
#' # Starts at row 5, column 2, and reads 3 elements along that row
#' sub_block <- h5_read(file, "matrix_data", start = c(5, 2), count = 3)
#' print(sub_block)
#' 
#' # --- Type Conversion Example ---
#' # Force integer dataset to be read as numeric (double)
#' x_dbl <- h5_read(file, "ints", as = "double")
#' class(x_dbl)
#' 
#' unlink(file)
h5_read <- function(file, name = "/", attr = NULL, as = "auto", start = NULL, count = NULL) {
  
  file   <- validate_strings(file, name, attr, must_exist = TRUE)
  obj_as <- validate_as(as)
  
  validate_start_count(file, name, attr, start, count)
  
  
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
  read_data(file, name, attr, obj_as, attr_as, start, count)
}


read_data <- function (file, name, attr = NULL, obj_as, attr_as, start = start, count = count) {
  
  # Case 1: Read Specific Attribute directly
  if (!is.null(attr))
    return(.Call("C_h5_read_attribute", file, name, attr, attr_as, PACKAGE = "h5lite"))
  
  # Case 2: Read Group (Recursive)
  if (h5_is_group(file, name)) {
    children <- sort(h5_ls(file, name, recursive = FALSE, full.names = TRUE))
    res      <- lapply(children, read_data, file = file, obj_as = obj_as, attr_as = attr_as, start = start, count = count)
    names(res) <- if (length(res) == 0) NULL else basename(children)
  }
  
  # Case 3: Read Dataset
  else {
    res <- .Call("C_h5_read_dataset", file, name, obj_as, basename(name), start, count, PACKAGE = "h5lite")
  }

  # --- Attach Attributes ---
  obj_attr_names <- h5_attr_names(file, name)
  obj_attr_names <- setdiff(obj_attr_names, c("DIMENSION_LIST", "REFERENCE_LIST"))
  for (attr in obj_attr_names)
    if (!is.na(h5_class(file, name, attr)))
      base::attr(res, attr) <- .Call("C_h5_read_attribute", file, name, attr, attr_as, PACKAGE = "h5lite")
  
  return(res)
}
