#' Read an HDF5 Object or Attribute
#'
#' Reads a dataset, a group, or a specific attribute from an HDF5 file into an R object.
#' Supports partial reading (hyperslabs) to load specific subsets of data without 
#' loading the entire object into memory.
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the dataset or group to read (e.g., `"/data/matrix"`).
#' @param attr The name of an attribute to read.
#'   * If `NULL` (default), the function reads the object specified by `name` (and attaches its attributes to the result).
#'   * If provided (string), the function reads *only* the specified attribute from `name`.
#' @param as The target R data type.
#'   * **Global:** `"auto"` (default), `"integer"`, `"double"`, `"logical"`, `"bit64"`, `"null"`.
#'   * **Specific:** A named vector mapping names or type classes to R types (see Section "Type Conversion").
#' @param start A numeric vector specifying the 1-based coordinate(s) for a partial read.
#'   Most often, this is a **single value** targeting the most logical structural unit 
#'   (e.g., the row of a matrix, or the 2D matrix of a 3D array). 
#'   If `NULL` (default), the entire dataset is read.
#' @param count A single numeric value specifying the number of elements or units to read.
#'   If `NULL` (default) and `start` is provided, `h5lite` reads exactly 1 unit and 
#'   simplifies the resulting dimensions (see Section "Dimension Simplification").
#'
#' @section Partial Reading (Hyperslabs):
#' You can read specific subsets of an n-dimensional dataset by utilizing the `start` 
#' and `count` arguments.
#' 
#' **The "Smart" `start` Parameter**
#' 
#' `start` is designed to be intuitive. Most of the time, you only need to provide a single value. 
#' This single value automatically targets the most meaningful dimension of the dataset:
#' 
#' * **1D Vector:** `start` specifies the **element**.
#' * **2D Matrix / Data Frame:** `start` specifies the **row**.
#' * **3D Array:** `start` specifies the **2D matrix**.
#' 
#' The `count` parameter is a **single value** that determines how many of those units 
#' to read sequentially. For example, `start = 5` and `count = 3` on a matrix will read 3 complete 
#' rows starting at row 5 (automatically spanning all columns).
#' 
#' **Multi-Value `start` and N-Dimensional Arrays**
#' 
#' If you need to extract a specific block *inside* a structural unit, you can provide a vector of 
#' values to `start`. To make indexing intuitive across higher-order arrays, `start` maps 
#' its values to dimensions in the following priority order, targeting the outermost blocks first 
#' and specific rows/columns last:
#' 
#' * `N, N-1, ..., 3, 1 (Rows), 2 (Cols)`
#' 
#' For example, on a 3D array, `start = c(2, 5)` targets the 2nd matrix, and the 5th row. 
#' The `count` argument always applies to the **last** dimension specified in `start`.
#' 
#' **Dimension Simplification (Dropping)**
#' 
#' `h5lite` mimics R's native subsetting behavior regarding dimension preservation:
#' 
#' * **Exact Indexing (`count = NULL`):** If you provide `start` but omit `count`, `h5lite` 
#'   assumes you are targeting an exact point index. It will read 1 unit and **drop** the 
#'   targeted dimension. (e.g., reading a specific row of a matrix will return a 1D vector).
#' * **Range Indexing (`count` provided):** If you explicitly provide `count` (even `count = 1`), 
#'   `h5lite` assumes you are reading a range. The dataset's original structural geometry is 
#'   **preserved**. (e.g., reading `start = 5, count = 1` on a matrix will return a 1xN matrix).
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
#' 
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
#' Partial reading (`start`/`count`) is currently only supported for datasets, not attributes.
#'
#' @return An R object corresponding to the HDF5 object or attribute.
#'   Returns `NULL` if the object is skipped via `as = "null"`.
#' 
#' @seealso [h5_write()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # --- Setup: Write Test Data ---
#' h5_write(c(10L, 20L, 30L, 40L, 50L), file, "ints")
#' 
#' m <- matrix(1:50, nrow = 10, ncol = 5, dimnames = list(paste0("r", 1:10), paste0("c", 1:5)))
#' h5_write(m, file, "matrix_data")
#' 
#' arr <- array(1:24, dim = c(2, 3, 4))
#' h5_write(arr, file, "array_data")
#' 
#' # --- Standard Reading ---
#' # Read the entire dataset
#' x <- h5_read(file, "ints")
#' 
#' # --- Type Conversion ---
#' # Force integer dataset to be read as numeric (double)
#' x_dbl <- h5_read(file, "ints", as = "double")
#' class(x_dbl)
#' 
#' # --- Partial Reading: Single-Value 'start' ---
#' # Vector: Start at 2nd element, read 3 elements
#' h5_read(file, "ints", start = 2, count = 3)
#' 
#' # Matrix: Start at row 5, read 3 complete rows (returns 3x5 matrix)
#' h5_read(file, "matrix_data", start = 5, count = 3)
#' 
#' # 3D Array: Start at 2nd matrix, read 2 complete matrices (returns 2x3x2 array)
#' h5_read(file, "array_data", start = 2, count = 2)
#' 
#' # --- Partial Reading: Dimension Simplification ---
#' # Omit 'count' to extract an exact point index and drop the targeted dimension
#' 
#' # Matrix: Extract exactly row 5 (drops row dimension, returns a 1D vector)
#' h5_read(file, "matrix_data", start = 5)
#' 
#' # Matrix: Extract row 5, but preserve matrix structure (returns 1x5 matrix)
#' h5_read(file, "matrix_data", start = 5, count = 1)
#' 
#' # --- Partial Reading: Multi-Value 'start' ---
#' # Matrix: Extract exactly row 5, column 2 (drops both dims, returns a scalar)
#' h5_read(file, "matrix_data", start = c(5, 2))
#' 
#' # 3D Array: Target matrix 2, row 1. (drops matrix and row dims, returns 1D vector of cols)
#' h5_read(file, "array_data", start = c(2, 1))
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


read_data <- function (file, name, attr = NULL, obj_as, attr_as, start = NULL, count = NULL) {
  
  is_auto_count <- !is.null(start) && is.null(count)
  c_count       <- if (is_auto_count) 1 else count
  
  # Case 1: Read Specific Attribute directly
  if (!is.null(attr)) {
    return(.Call("C_h5_read_attribute", file, name, attr, attr_as, PACKAGE = "h5lite"))
  }
  
  # Case 2: Read Group (Recursive)
  if (h5_is_group(file, name)) {
    children <- sort(h5_ls(file, name, recursive = FALSE, full.names = TRUE))
    res      <- lapply(children, read_data, file = file, obj_as = obj_as, attr_as = attr_as, start = start, count = count)
    names(res) <- if (length(res) == 0) NULL else basename(children)
  }
  
  # Case 3: Read Dataset
  else {
    res <- .Call("C_h5_read_dataset", file, name, obj_as, basename(name), start, c_count, PACKAGE = "h5lite")
    
    # Surgically drop fully specified dimensions
    if (!is.null(start) && !inherits(res, "data.frame")) {
      dims <- dim(res)
      
      if (!is.null(dims)) {
        N <- length(dims)
        n_start <- length(start)
        
        if (N >= 3) {
          full_map <- c(seq(N, 3L, by = -1L), 1L, 2L)
        } else {
          full_map <- seq_len(N)
        }
        dim_map <- full_map[seq_len(n_start)]
        
        dims_to_drop <- integer(0)
        
        # 1. Any targeted dimension BEFORE the last one is a point index and must be dropped
        if (n_start > 1) {
          dims_to_drop <- dim_map[1:(n_start - 1)]
        }
        # 2. The final targeted dimension is also a point index if count was automatically inferred
        if (is_auto_count) {
          dims_to_drop <- c(dims_to_drop, dim_map[n_start])
        }
        
        if (length(dims_to_drop) > 0) {
          new_dims <- dims[-dims_to_drop]
          dnames <- dimnames(res)
          
          if (!is.null(dnames)) {
            new_dnames <- dnames[-dims_to_drop]
            if (all(sapply(new_dnames, is.null))) new_dnames <- NULL
          } else {
            new_dnames <- NULL
          }
          
          # Apply the new shape
          if (length(new_dims) <= 1) {
            dim(res) <- NULL # Simplify to vector or scalar
            
            if (length(new_dims) == 1) {
              # Retain names for 1D vectors, pulling from the surviving dimnames
              if (!is.null(new_dnames)) names(res) <- new_dnames[[1]]
            } else if (length(new_dims) == 0) {
              # Explicitly unnamed for fully simplified scalar (count = NULL)
              names(res) <- NULL
            }
          } else {
            dim(res) <- new_dims
            if (!is.null(new_dnames)) dimnames(res) <- new_dnames
          }
        }
      } else if (is_auto_count && length(res) == 1) {
        # Catch 1D vectors that were natively read as a point index (count = NULL)
        names(res) <- NULL
      }
    }
  }
  
  # --- Attach Attributes ---
  obj_attr_names <- h5_attr_names(file, name)
  obj_attr_names <- setdiff(obj_attr_names, c("DIMENSION_LIST", "REFERENCE_LIST"))
  for (attr in obj_attr_names)
    if (!is.na(h5_class(file, name, attr)))
      base::attr(res, attr) <- .Call("C_h5_read_attribute", file, name, attr, attr_as, PACKAGE = "h5lite")
  
  return(res)
}
