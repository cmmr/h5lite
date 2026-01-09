#' Write an R Object to HDF5
#' 
#' Writes an R object to an HDF5 file, creating the file if it does not exist.
#' This function acts as a unified writer for datasets, groups (lists), and attributes.
#'
#' @param data The R object to write. Supported: `numeric`, `integer`, `complex`, 
#'   `logical`, `character`, `factor`, `raw`, `matrix`, `data.frame`, `NULL`,
#'   and nested `list`s.
#' @param file The path to the HDF5 file.
#' @param name The name of the dataset or group to write (e.g., "/data/matrix").
#' @param attr The name of an attribute to write.
#'   * If `NULL` (default), `data` is written as a dataset or group at the path `name`.
#'   * If provided (string), `data` is written as an attribute named `attr` attached to the object `name`.
#' @param as The target HDF5 data type. Defaults to `"auto"`.
#'   See the **Data Type Selection** section for a full list of valid options 
#'   (including `"int64"`, `"bfloat16"`, `"utf8[n]"`, etc.) and how to map 
#'   specific columns.
#' @param compress Compression configuration.
#'   * `TRUE` (default): Enables compression (zlib level 5).
#'   * `FALSE` or `0`: Disables compression.
#'   * Integer `1-9`: Specifies the zlib compression level.
#' 
#' @section Data Type Selection (`as` Argument):
#' The `as` argument controls the on-disk storage type for integer, double, 
#' logical, and character columns. 
#' 
#' **1. Available Types**
#' 
#' * **Floating Point:** `"float16"`, `"float32"`, `"float64"`, `"bfloat16"`
#' * **Signed Integer:** `"int8"`, `"int16"`, `"int32"`, `"int64"`
#' * **Unsigned Integer:** `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`
#' * **Variable Length Strings:** `"utf8"`, `"ascii"`
#' * **Fixed Length Strings:**
#'     * `"utf8[]"` or `"ascii[]"` (auto-detects the longest string in the data)
#'     * `"utf8[n]"` or `"ascii[n]"` (where `n` is the length in bytes, e.g., `"utf8[10]"`)
#' * **Other:** `"auto"`, `"skip"` (to skip a column/attribute of any R type)
#' 
#' *Strings:* Variable-length strings allow for `NA` values (via NULL pointers) 
#' but cannot be compressed. Fixed-length strings allow for compression but do 
#' not support `NA`.
#' 
#' **2. Automatic Selection (`as = "auto"`)**
#' 
#' \tabular{lll}{
#'   \strong{R Type} \tab \strong{HDF5 Type} \tab \strong{Notes} \cr
#'   `integer`    \tab `H5T_STD_I32LE`  \tab  \cr
#'   `double`     \tab `H5T_IEEE_F64LE` \tab  \cr
#'   `logical`    \tab `H5T_STD_U8LE`   \tab 1-bit storage efficiency. \cr
#'   `character`  \tab `H5T_C_S1`       \tab `H5T_CSET_UTF8 H5T_VARIABLE H5T_STR_NULLTERM` \cr
#'   `factor`     \tab `H5T_ENUM`       \tab Maps levels to integers. \cr
#'   `data.frame` \tab `H5T_COMPOUND`   \tab Native table-like structure. \cr
#'   `list`       \tab `H5O_TYPE_GROUP` \tab Written to HDF5 recursively. \cr
#'   `complex`    \tab `H5T_COMPLEX_IEEE_F64LE` \tab Requires HDF5 >= 2.0.0. \cr
#'   `raw`        \tab `H5T_OPAQUE`     \tab For binary data storage. \cr
#'   `NULL`       \tab `H5S_NULL`       \tab Null Dataspace \cr
#'   `integer64`  \tab `H5T_STD_I64LE`  \tab From the `bit64` R package. \cr
#'   `POSIXt`     \tab `H5T_C_S1`       \tab ISO 8601 string (`YYYY-MM-DDTHH:MM:SSZ`) \cr
#' }
#' 
#' *NA Handling:* HDF5 integers do not support `NA`. If an R integer or logical 
#' vector contains `NA`, `h5lite` automatically promotes it to `float64` to 
#' preserve the `NA` value.
#' 
#' **3. Column/Class Mapping**
#' 
#' You can provide a named vector to map specific columns or classes:
#' 
#' * **Specific Name:** `"col_name" = "type"` (e.g., `c(score = "float32")`)
#' * **Specific Attribute:** `"@@attr_name" = "type"`
#' * **Class-based:** `".integer" = "type"`, `".numeric" = "type"`
#' * **Class-based Attribute:** `"@@.character" = "type"`, `"@@.logical" = "type"`
#' * **Global Fallback:** `"." = "type"`
#' * **Global Attribute Fallback:** `"@@." = "type"`
#' 
#' *Numeric Class:* `".numeric"` targets both `integer` and `double` with a 
#' lower priority than `".integer"` and `".double"`.
#' 
#' @section Writing Scalars:
#' By default, `h5_write` saves single-element vectors as 1-dimensional arrays.
#' To write a true HDF5 scalar, wrap the value in `I()` to treat it "as-is."
#' For example, `h5_write(I(5), file, "x")` will create a scalar dataset, while
#' `h5_write(5, file, "x")` will create a 1D array of length 1.
#' 
#' @section Dimension Scales:
#' `h5lite` automatically writes `names`, `row.names`, and `dimnames` as 
#' HDF5 dimension scales. Named vectors will generate an `<name>_names` 
#' dataset. A data.frame with row names will generate an `<name>_rownames` 
#' dataset (column names are saved internally in the original dataset). 
#' Matrices will generate `<name>_rownames` and `<name>_colnames` datasets. 
#' Arrays will generate `<name>_dimscale_1`, `<name>_dimscale_2`, etc. 
#' Special HDF5 metadata attributes link the dimension scales to the dataset. 
#' The dimension scales can be relocated with `h5_move()` without breaking the 
#' link.
#' 
#' 
#' @return Invisibly returns `file`. This function is called for its side effects.
#' @seealso [h5_read()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # 1. Writing Basic Datasets
#' h5_write(1:10, file, "data/integers")
#' h5_write(rnorm(10), file, "data/floats")
#' h5_write(letters[1:5], file, "data/chars")
#' 
#' # 2. Writing Attributes
#' # Write an object first
#' h5_write(1:10, file, "data/vector")
#' # Attach an attribute to it using the 'attr' parameter
#' h5_write(I("My Description"), file, "data/vector", attr = "description")
#' h5_write(I(100), file, "data/vector", attr = "scale_factor")
#' 
#' # 3. Controlling Data Types
#' # Store integers as 8-bit unsigned
#' h5_write(1:5, file, "compressed/small_ints", as = "uint8")
#' 
#' # 4. Writing Complex Structures (Lists/Groups)
#' my_list <- list(
#'   meta    = list(id = 1, name = "Experiment A"),
#'   results = matrix(runif(9), 3, 3),
#'   valid   = I(TRUE)
#' )
#' h5_write(my_list, file, "experiment_1", as = c(id = "uint16"))
#' 
#' # 5. Writing Data Frames (Compound Datasets)
#' df <- data.frame(
#'   id    = 1:5,
#'   score = c(10.5, 9.2, 8.4, 7.1, 6.0),
#'   grade = factor(c("A", "A", "B", "C", "D"))
#' )
#' h5_write(df, file, "records/scores", as = c(grade = "ascii[1]"))
#' 
#' # 6. Fixed-Length Strings
#' h5_write(c("A", "B"), file, "fixed_str", as = "ascii[10]")
#' 
#' # 7. Review the file structure
#' h5_str(file)
#' 
#' # 8. Clean up
#' unlink(file)
h5_write <- function(data, file, name, attr = NULL, as = "auto", compress = TRUE) {
  
  file <- validate_strings(file, name, attr)
  
  if (!is.null(attr) && !h5_exists(file, name))
    stop("Cannot write attribute '", attr, "' to non-existent object '", name, "'.", call. = FALSE)

  # Prepare the 'as' map for objects and attributes
  # Example: obj_as  = c("@ready" = "logical", ".uint" = "integer", "@." = "null")
  #          attr_as = c("ready" = "logical",  ".uint" = "integer", "."  = "null")
  obj_as  <- validate_as(as)
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

  # Write the data
  h5_create_group(file, name = "/")
  if (is_list_group(data)) {
    write_group(data, file, name, obj_as, attr_as, compress, dry = TRUE)
    write_group(data, file, name, obj_as, attr_as, compress, dry = FALSE)
  } else {
    write_data(data, file, name, attr, obj_as, attr_as, compress, dry = TRUE)
    write_data(data, file, name, attr, obj_as, attr_as, compress, dry = FALSE)
  }
  
  invisible(file)
}

#' Recursively write a list as a group
#' @noRd
#' @keywords internal
write_group <- function(data, file, name, obj_as, attr_as, compress = TRUE, dry = FALSE) {

  if (!dry) h5_delete(file, name, warn = FALSE)
  if (!dry) h5_create_group(file, name)
  
  write_attributes(data, file, name, attr_as, dry = dry)
  
  # Recursively write children
  for (child_name in names(data)) {
    child_path <- paste(name, child_name, sep = "/")
    child_data <- data[[child_name]]
    if (is_list_group(child_data)) {
      write_group(child_data, file, child_path, obj_as, attr_as, compress, dry = dry)
    } else {
      write_data(child_data, file, child_path, attr = NULL, obj_as, attr_as, compress, dry = dry)
    }
  }
}

#' Write a single dataset or attribute
#' @noRd
#' @keywords internal
write_data <- function(data, file, name, attr, obj_as, attr_as, compress = FALSE, dry = FALSE) {
  
  # Convert POSIXt vectors/columns to ISO 8601 character strings.
  if (inherits(data, "POSIXt")) {
    data <- format(data, format = "%Y-%m-%dT%H:%M:%OSZ")
  }
  else if (is.data.frame(data)) {
    for (i in seq_along(data))
      if (inherits(data[[i]], "POSIXt"))
        data[[i]] <- format(data[[i]], format = "%Y-%m-%dT%H:%M:%OSZ")
  }

  map_key <- if (is.null(attr)) basename(name) else attr
  h5_type <- resolve_h5_type(data, map_key, obj_as)
  
  if (all(h5_type == "skip")) return (NULL)
  
  if (is.data.frame(data) && any(h5_type == "skip")) {
    data    <- data[, h5_type != "skip", drop = FALSE]
    h5_type <- h5_type[h5_type != "skip"]
  }
  
  for (i in which(startsWith(h5_type, "ascii"))) {
    
    # Converts from:      ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïðñòóôõöùúûüýÿ
    wanted   <- enc2utf8("AAAAAACEEEEIIIIDNOOOOOUUUUYaaaaaaceeeeiiiidnooooouuuuyy")
    unwanted <- enc2utf8(intToUtf8(c(
      192L, 193L, 194L, 195L, 196L, 197L, 199L, 200L, 201L, 202L, 203L, 
      204L, 205L, 206L, 207L, 208L, 209L, 210L, 211L, 212L, 213L, 214L, 
      217L, 218L, 219L, 220L, 221L, 224L, 225L, 226L, 227L, 228L, 229L, 
      231L, 232L, 233L, 234L, 235L, 236L, 237L, 238L, 239L, 240L, 241L, 
      242L, 243L, 244L, 245L, 246L, 249L, 250L, 251L, 252L, 253L, 255L )))
    
    data[[i]] <- enc2utf8(data[[i]])
    data[[i]] <- enc2utf8(chartr(unwanted, wanted, data[[i]]))
    data[[i]] <- iconv(data[[i]], "UTF-8", "ASCII//TRANSLIT", "?")
  }
  
  dims <- validate_dims(data)

  if (is.null(attr)) {
    level <- if (isTRUE(compress)) 5L else as.integer(compress)
    
    if (!dry)
      .Call("C_h5_write_dataset", file, name, data, h5_type, dims, level, PACKAGE = "h5lite")
    
    write_attributes(data, file, name, attr_as, dry = dry)
  }
  else {
    
    if (!dry)
      .Call("C_h5_write_attribute", file, name, attr, data, h5_type, dims, PACKAGE = "h5lite")
  }
}

#' Write R attributes to HDF5
#' @noRd
#' @keywords internal
write_attributes <- function(data, file, name, attr_as, dry = FALSE) {

  attr_names <- names(attributes(data))
  attr_names <- setdiff(attr_names, c("class", "dim", "dimnames", "names", "row.names"))

  for (attr in attr_names) {
    attr_data <- base::attr(data, attr, exact = TRUE)
    if (is_list_group(attr_data)) next
    write_data(attr_data, file, name, attr, attr_as, attr_as, dry = dry)
  }
}


# --- Type Resolution Logic ---

#' Resolves the HDF5 type based on the 'as' map and data properties
#' @noRd
#' @keywords internal
#' @param data The R object.
#' @param name The name of the object (column name, dataset name, or attribute name).
#' @param as_map The processed 'as' argument (named vector).
resolve_h5_type <- function(data, name, as_map) {
  
  # Resolve type for *each* column
  if (is.data.frame(data)) {

    if (ncol(data) == 0)
      stop("Cannot write a data.frame with zero columns: ", name, call. = FALSE)
    
    col_types <- character(ncol(data))
    col_names <- names(data)
    for (i in seq_along(data)) {
      col_types[i] <- resolve_h5_type(data[[i]], col_names[i], as_map)
    }
    return(col_types)
  }
  
  if (is.null(data))               return ("null")
  if (is.raw(data))                return ("raw")
  if (is.complex(data))            return ("complex")
  if (inherits(data, "integer64")) return ("bit64")
  if (inherits(data, "factor")) {
    
    if (!is.factor(data))
      stop("Non-factors with factor class cannot be written to HDF5.", call. = FALSE) # nocov
    if (!is.character(levels(data)))
      stop("Factors with non-character levels cannot be written to HDF5.", call. = FALSE) # nocov
    if (anyNA(data))
      stop("Factors with NA values cannot be written to HDF5 Enum types. Convert to character vector first.", call. = FALSE)
    if (typeof(data) != "integer")
      stop("Factors with non-integer values cannot be written to HDF5 Enum types.", call. = FALSE) # nocov
    
    return ("factor")
  }
  
  
  if (is.null(names(as_map))) {
    h5_type <- tolower(as_map)
    
  } else {
  
    # Generate type keys for lookup (e.g., .integer, .double)
    mode <- paste0(".", storage.mode(data))
    if (is.numeric(data)) { keys <- c(name, mode, ".numeric", ".") }
    else                  { keys <- c(name, mode,             ".") }
    
    h5_type <- "auto"
    for (key in keys) {
      if (key %in% names(as_map)) {
        h5_type <- tolower(as_map[[key]])
        break
      }
    }
    
  }
  
  
  if (is.character(data)) {

    arg_errmsg <- paste("Invalid `as` argument for character vector:", h5_type)
    na_errmsg  <- paste("`NA` cannot be encoded by fixed length strings.")
    
    h5_type <- tolower(h5_type)
    size    <- NULL
    
    # Auto-select fixed length
    if (endsWith(h5_type, "[]")) {
      h5_type <- sub('[]', '', h5_type, fixed = TRUE)
      size    <- max(c(1L, nchar(data, type = "bytes")))
      if (is.na(size)) stop(na_errmsg, call. = FALSE)
    }
    
    # See if length is provided
    else {
      parts <- strsplit(h5_type, "[^a-z0-9]")[[1]]
      
      if (length(parts) == 1) {
        h5_type <- parts[[1]]
      }
      
      else if (length(parts) == 2) {
        h5_type <- parts[[1]]
        size    <- parts[[2]]
        
        if (anyNA(data)) stop(na_errmsg, call. = FALSE)
        
        size <- try(suppressWarnings(as.integer(size)), silent = TRUE)
        if (!inherits(size, "integer") || is.na(size) || size < 1)
          stop(arg_errmsg, call. = FALSE)
      }
      
      else {
        stop(arg_errmsg, call. = FALSE)
      }
    }
    
    cset <- tryCatch(
      expr  = match.arg(h5_type, c("auto", "ascii", "skip", "utf8")), 
      error = function (e) { stop(arg_errmsg, call. = FALSE) })
    
    if (cset == "skip") return ("skip")
    if (cset == "auto") return ("utf8")
    
    h5_type <- ifelse(is.null(size), cset, paste0(cset, "[", size, "]"))
    return (h5_type)
  }
  

  if (is.numeric(data) || is.logical(data)) {
    
    choices <- c(
      "auto", "skip", 
      "bfloat16", "float16", "float32", "float64", 
      "int8", "int16", "int32", "int64",
      "uint8", "uint16", "uint32", "uint64")
    
    h5_type <- match.arg(tolower(h5_type), choices)
    
    if (h5_type == "skip") return ("skip")
    
    if (h5_type == "auto") {
      if (is.double(data))  return ("float64")
      if (anyNA(data))      return ("float64")
      if (is.logical(data)) return ("uint8")
      return ("int32")
    }
    
    # Sanity check user's requested HDF5 numeric type
    
    if (length(data) == 0) return(h5_type)
    if (any(!is.finite(data)) && !startsWith(h5_type, "float"))
      stop("Data contains NA/NaN/Inf; requires float type.", call. = FALSE)
    
    if (any(is.finite(data)) && h5_type != "float64") {
      type_ranges <- list(
        'int8'    = c(-2^7,  2^7-1),  'uint8'  = c(0, 2^8-1),   
        'int16'   = c(-2^15, 2^15-1), 'uint16' = c(0, 2^16-1),
        'int32'   = c(-2^31, 2^31-1), 'uint32' = c(0, 2^32-1),  
        'int64'   = c(-2^63, 2^63-1), 'uint64' = c(0, 2^64-1),
        'float16' = c(-65504,  65504),
        'float32' = c(-3.4e38, 3.4e38) )
      val_range <- range(data, na.rm = TRUE, finite = TRUE)
      rng <- type_ranges[[h5_type]]
      if (!is.null(rng) && (val_range[1] < rng[1] || val_range[2] > rng[2])) {
        stop("Data range [", val_range[1], ", ", val_range[2], "] exceeds '", h5_type, "'", call. = FALSE)
      }
    }
    
    return(h5_type)
  }
  
  stop("Cannot write data of class ", paste(class(data), collapse = "/"), " to HDF5.", call. = FALSE) # nocov
}


#' @noRd
#' @keywords internal
validate_dims <- function (data) {
  
  # If data is wrapped in I(), treat as a scalar (NULL dims), but ONLY if it's length 1.
  # This prevents accidentally writing a multi-element 'AsIs' vector as a scalar, which would cause data loss.
  if (inherits(data, 'AsIs')) {
    if (length(data) == 1) {
      return(NULL)
    } else {
      warning("I() wrapper ignored for vector of length > 1. Writing as a 1D array.")
    }
  }
  
  # Otherwise, infer dimensions from the object. A vector will have length, a matrix/array will have dim().
  if (is.null(dim(data))) length(data) else dim(data)
}


#' @noRd
#' @keywords internal
is_list_group <- function (data) {
  # A "list group" is a list that is not a data.frame.
  return (is.list(data) && !is.data.frame(data))
}
