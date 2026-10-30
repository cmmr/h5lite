#' Write an R Object to HDF5
#' 
#' Writes an R object to an HDF5 file, creating the file if it does not exist.
#' This function acts as a unified writer for datasets, groups (lists), and attributes.
#'
#' @param data The R object to write. Supported: `numeric`, `complex`, 
#'   `logical`, `character`, `factor`, `raw`, `matrix`, `data.frame`, `integer64`, 
#'   `POSIXt`, `NULL`, and nested `list`s.
#' @param file The path to the HDF5 file.
#' @param name The name of the dataset or group to write (e.g., "/data/matrix").
#' @param attr The name of an attribute to write.
#'   * If `NULL` (default), `data` is written as a dataset or group at the path `name`.
#'   * If provided (string), `data` is written as an attribute named `attr` attached to the object `name`.
#' @param as The target HDF5 data type. Defaults to `"auto"`.
#'   See the **Data Type Selection** section for a full list of valid options 
#'   (including `"int64"`, `"bfloat16"`, `"utf8[n]"`, etc.) and how to map 
#'   sub-components of `data`.
#' @param compress Compression configuration. Default is `"gzip"`. Pass a basic string 
#'   to specify the algorithm and level (e.g., `"none"`, `"gzip"`, `"zstd-7"`, `"lz4"`, 
#'   `"blosc1-lz4-9"`, `"blosc2-gzip-3"`, `"blosc2-zstd"`), or pass a `compress` object 
#'   created by [h5_compression()] for advanced pipeline control (including scale-offset 
#'   algorithms, Fletcher32 checksums, or Blosc2 pre-filters). See [h5_compression()] 
#'   for the complete list of available codecs and options.
#' 
#' @section Writing Scalars:
#' 
#' By default, `h5_write` saves single-element vectors as 1-dimensional arrays.
#' To write a true HDF5 scalar, wrap the value in `I()` to treat it "as-is."
#' 
#' #### Examples
#' ```
#' h5_write(I(5), file, "x") # Creates a scalar dataset
#' h5_write(5, file, "x")    # Creates a 1D array of length 1
#' ```
#' 
#' @section Data Type Selection (`as` Argument):
#' 
#' By default, `as = "auto"` will automatically select the most appropriate
#' data type for the given object. For numeric types, this will be the smallest
#' type that can represent all values in the vector. For character types, 
#' `h5lite` will use a ragged vs rectangular heuristic, favoring small file 
#' size over fast I/O. For R data types not mentioned below, see 
#' `vignette("data-types")` for information on their fixed mappings to HDF5 
#' data types.
#' 
#' ### Numeric and Logical Vectors
#' 
#' When writing a numeric or logical vector, you can specify one of the 
#' following storage types for it:
#' 
#' * **Floating Point:** `"float16"`, `"float32"`, `"float64"`, `"bfloat16"`
#' * **Signed Integer:** `"int8"`, `"int16"`, `"int32"`, `"int64"`
#' * **Unsigned Integer:** `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`
#' 
#' **NOTE:** `NA`, `NaN`, `Inf`, and `-Inf` must be stored as a floating point
#' type. Only `float64` keeps `NA` distinct from `NaN`; other floating point
#' types store `NA` as `NaN` (both are `NA` to `is.na()`). Values outside the
#' type's range are an error.
#' 
#' #### Examples
#' ```
#' h5_write(1:100, file, "big_ints", as = "int64")
#' h5_write(TRUE,  file, "my_bool",  as = "float32")
#' ```
#' 
#' ### Character Vectors
#' 
#' You can control whether character vectors are stored as variable or fixed
#' length strings, and whether to use UTF-8 or ASCII encoding.
#' 
#' * **Variable Length Strings:** `"utf8"`, `"ascii"`
#' * **Fixed Length Strings:**
#'     * `"utf8[]"` or `"ascii[]"` (length is set to the longest string)
#'     * `"utf8[n]"` or `"ascii[n]"` (where `n` is the length in bytes)
#' 
#' **NOTE:** Variable-length strings allow for `NA` values but cannot be 
#' compressed on disk. Fixed-length strings allow for compression but do not 
#' support `NA`.
#' 
#' #### Examples
#' ```
#' h5_write(letters[1:5],    file, "len10_strs", as = "utf8[10]")
#' h5_write(c('X', 'Y', NA), file, "var_chars",  as = "ascii")
#' ```
#' 
#' ### Lists, Data Frames, and Attributes
#' 
#' Provide a named vector to apply type mappings to sub-components of `data`. 
#' Set `"skip"` as the type to skip a specific component.
#' 
#' * **Specific Name:** `"col_name" = "type"` (e.g., `c(score = "float32")`)
#' * **Specific Attribute:** `"@@attr_name" = "type"`
#' * **Class-based:** `".integer" = "type"`, `".numeric" = "type"`
#' * **Class-based Attribute:** `"@@.character" = "type"`, `"@@.logical" = "type"`
#' * **Global Fallback:** `"." = "type"`
#' * **Global Attribute Fallback:** `"@@." = "type"`
#' 
#' #### Examples
#' ```
#' # To strip attributes when writing:
#' h5_write(data, file, 'no_attrs_obj', as = c('@@.' = "skip"))
#' 
#' # To only save the `hp` and `wt` columns:
#' h5_write(mtcars, file, 'my_df', as = c('hp' = "auto", 'wt' = "float32", '.' = "skip"))
#' ```
#' 
#' @section Dimension Scales:
#' `h5lite` automatically writes `names`, `row.names`, and `dimnames` as 
#' HDF5 dimension scales. Named vectors will generate an `<name>_names` 
#' dataset. A data.frame with row names will generate an `<name>_rownames` 
#' dataset (column names are saved internally in the original dataset). 
#' Matrices will generate `<name>_rownames` and `<name>_colnames` datasets. 
#' Arrays will generate `<name>_dimnames_1`, `<name>_dimnames_2`, etc.
#' If one of these names is already taken by something else, a free name
#' (e.g. `<name>_names_2`) is used instead. Special HDF5 metadata attributes
#' link the dimension scales to the dataset. `h5_move()` moves a dataset's
#' scales along with it, and `h5_delete()` deletes them with it.
#' 
#' @return Invisibly returns `file`. This function is called for its side effects.
#' @seealso [h5_read()], [h5_compression()], `vignette('compression')`
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
#' # Store values as 32-bit signed integers
#' h5_write(1:5, file, "small_ints", as = "int32")
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
h5_write <- function(data, file, name, attr = NULL, as = "auto", compress = "gzip") {
  
  file <- validate_strings(file, name, attr)

  if (!is.null(attr) && is_list_group(data))
    stop(call. = FALSE,
      "A list cannot be written as an attribute. Write it as a group, ",
      "or write each element as its own attribute.")

  if (!is.null(attr) && !h5_exists(file, name))
    stop("Cannot write attribute '", attr, "' to non-existent object '", name, "'.", call. = FALSE)

  # Prepare the 'as' map for objects and attributes. Attributes are only
  # configured by "@" keys; everything else applies to the object itself.
  # Example: obj_as  = c("@ready" = "logical", ".uint" = "uint16", "@." = "skip")
  #          attr_as = c("ready" = "logical",  "." = "skip")
  obj_as  <- validate_as(as)
  attr_as <- "auto"
  if (!is.null(names(obj_as))) {
    at <- obj_as[startsWith(names(obj_as), "@")]
    if (length(at) > 0) {
      names(at) <- substring(names(at), 2)
      attr_as   <- at
    }
  }

  # Writing one attribute directly: it is the object, so accept plain or "@" keys
  if (!is.null(attr) && !is.null(names(obj_as))) {
    obj_as <- c(obj_as[startsWith(names(obj_as), "@")], obj_as[!startsWith(names(obj_as), "@")])
    names(obj_as) <- sub("^@", "", names(obj_as))
    obj_as <- obj_as[!duplicated(names(obj_as))]
  }

  compress <- h5_compression(compress)

  # Write the data
  h5_create_group(file, name = "/")
  if (is_list_group(data)) {
    write_group(data, file, name, obj_as, attr_as, compress, dry = TRUE)
    replace_group(data, file, name, obj_as, attr_as, compress)
  } else {
    write_data(data, file, name, attr, obj_as, attr_as, compress, dry = TRUE)
    write_data(data, file, name, attr, obj_as, attr_as, compress, dry = FALSE)
  }
  
  invisible(file)
}



#' Write a list as the group `name`, replacing what is there only once the new
#' group has been written in full, so a failure leaves the original intact.
#' @noRd
#' @keywords internal
replace_group <- function(data, file, name, obj_as, attr_as, compress) {

  path <- abs_h5_path(name)

  # The root group can't be swapped out: clear it and write into it directly.
  if (path == "/") {
    for (child in h5_ls(file, "/", recursive = FALSE, full.names = TRUE, scales = TRUE))
      h5_delete(file, child, warn = FALSE)
    for (attr in h5_attr_names(file, "/"))
      h5_delete(file, "/", attr = attr, warn = FALSE)
    return(write_group(data, file, path, obj_as, attr_as, compress, dry = FALSE))
  }

  tmp <- paste0(path, ".h5lite-tmp")
  while (h5_exists(file, tmp)) tmp <- paste0(tmp, "_")

  tryCatch(
    expr  = write_group(data, file, tmp, obj_as, attr_as, compress, dry = FALSE),
    error = function(e) {
      h5_delete(file, tmp, warn = FALSE)
      stop(e)
    })

  h5_delete(file, path, warn = FALSE)
  h5_move(file, tmp, path)
}


#' Recursively write a list as a group
#' @noRd
#' @keywords internal
write_group <- function(data, file, name, obj_as, attr_as, compress, dry = FALSE) {

  is_root <- abs_h5_path(name) == "/"

  if (dry) {
    # Children are written by name, so names must be usable and distinct.
    nms <- names(data)
    if (length(data) > 0 && (
        is.null(nms) || anyNA(nms) || any(nms %in% c("", ".", "..")) ||
        any(grepl("/", nms, fixed = TRUE)) || anyDuplicated(nms) > 0 ))
      stop(call. = FALSE,
        "List elements must have unique, non-empty names that don't ",
        "contain '/' (writing '", name, "').")
  }
  else if (!is_root) {
    h5_delete(file, name, warn = FALSE)
    h5_create_group(file, name)
  }

  write_attributes(data, file, name, attr_as, dry = dry)

  # Recursively write children
  for (child_name in names(data)) {
    child_path <- if (is_root) paste0("/", child_name) else paste(name, child_name, sep = "/")
    child_data <- data[[child_name]]
    if (is_list_group(child_data)) {
      if (lookup_as(child_data, child_name, obj_as)$type == "skip") next
      write_group(child_data, file, child_path, obj_as, attr_as, compress, dry = dry)
    } else {
      write_data(child_data, file, child_path, attr = NULL, obj_as, attr_as, compress, dry = dry)
    }
  }
}

#' Write a single dataset or attribute
#' @noRd
#' @keywords internal
write_data <- function(data, file, name, attr, obj_as, attr_as, compress, dry = FALSE) {
  
  # Convert POSIXt vectors/columns to ISO 8601 character strings.
  if (inherits(data, "POSIXt")) {
    is_scalar <- inherits(data, "AsIs")
    data      <- posix_to_iso8601(data)
    if (is_scalar) data <- I(data)
  }
  else if (is.data.frame(data)) {
    for (i in seq_along(data))
      if (inherits(data[[i]], "POSIXt"))
        data[[i]] <- posix_to_iso8601(data[[i]])
  }

  assert_no_bytes_encoding(data)

  map_key <- if (is.null(attr)) basename(name) else attr
  data    <- factors_to_strings(data, map_key, obj_as)
  h5_type <- resolve_h5_type(data, map_key, obj_as)

  if (all(h5_type == "skip")) return (NULL)

  if (is.data.frame(data) && any(h5_type == "skip")) {
    df_attrs <- attributes(data)
    df_attrs <- df_attrs[setdiff(names(df_attrs), c("names", "row.names", "class"))]
    data     <- data[, h5_type != "skip", drop = FALSE]
    h5_type  <- h5_type[h5_type != "skip"]
    attributes(data)[names(df_attrs)] <- df_attrs
  }

  ascii <- which(startsWith(h5_type, "ascii"))
  if (is.data.frame(data)) { for (i in ascii) data[[i]] <- to_ascii(data[[i]]) }
  else if (length(ascii))  { data[] <- to_ascii(data) }

  dims <- validate_dims(data, warn = dry)

  if (is.null(attr)) {
    if (!dry) {
      compress <- protect_nonfinite(data, compress)
      h5_call(.Call("C_h5_write_dataset", file, name, data, h5_type, dims, compress, PACKAGE = "h5lite"))
    }
    
    write_attributes(data, file, name, attr_as, dry = dry)
  }
  else {
    
    if (!dry)
      h5_call(.Call("C_h5_write_attribute", file, name, attr, data, h5_type, dims, PACKAGE = "h5lite"))
  }
}

#' Format date-times as ISO 8601 strings in UTC, e.g. "2024-01-01T18:00:00Z".
#' Fractional seconds are kept, to the microsecond, only where present.
#' @noRd
#' @keywords internal
posix_to_iso8601 <- function(x) {
  secs  <- round(as.numeric(as.POSIXct(x)), 6)
  whole <- floor(secs)
  frac  <- secs - whole

  out <- format(as.POSIXct(whole, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%M:%S", tz = "UTC")

  has_frac <- !is.na(frac) & frac > 0
  if (any(has_frac))
    out[has_frac] <- paste0(out[has_frac], sub("0+$", "", substring(sprintf("%.6f", frac[has_frac]), 2)))

  out <- paste0(out, "Z")
  out[is.na(secs)] <- NA_character_
  names(out) <- names(x)
  out
}


#' Transliterate strings to ASCII, e.g. "café" -> "cafe"
#' @noRd
#' @keywords internal
to_ascii <- function(x) {

  # Converts from:      ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïðñòóôõöùúûüýÿ
  wanted   <- enc2utf8("AAAAAACEEEEIIIIDNOOOOOUUUUYaaaaaaceeeeiiiidnooooouuuuyy")
  unwanted <- enc2utf8(intToUtf8(c(
    192L, 193L, 194L, 195L, 196L, 197L, 199L, 200L, 201L, 202L, 203L,
    204L, 205L, 206L, 207L, 208L, 209L, 210L, 211L, 212L, 213L, 214L,
    217L, 218L, 219L, 220L, 221L, 224L, 225L, 226L, 227L, 228L, 229L,
    231L, 232L, 233L, 234L, 235L, 236L, 237L, 238L, 239L, 240L, 241L,
    242L, 243L, 244L, 245L, 246L, 249L, 250L, 251L, 252L, 253L, 255L )))

  x <- enc2utf8(x)
  x <- enc2utf8(chartr(unwanted, wanted, x))
  iconv(x, "UTF-8", "ASCII//TRANSLIT", "?")
}


#' Stop if any string to be written is marked as "bytes", which can't be
#' converted to UTF-8 (R would raise the error from inside C, mid-write).
#' @noRd
#' @keywords internal
assert_no_bytes_encoding <- function(data) {

  strs <- list(names(data), unlist(dimnames(data)), levels(data))
  if (is.character(data)) strs <- c(strs, list(data))
  if (is.data.frame(data))
    for (col in data)
      if (is.character(col) || is.factor(col)) strs <- c(strs, list(col, levels(col)))

  for (s in strs)
    if (is.character(s) && any(Encoding(s) == "bytes"))
      stop(call. = FALSE,
        "Strings marked with \"bytes\" encoding cannot be written to HDF5. ",
        "Convert them to UTF-8 first, for example with iconv().")
}


#' Write R attributes to HDF5
#' @noRd
#' @keywords internal
write_attributes <- function(data, file, name, attr_as, dry = FALSE) {

  attr_names <- names(attributes(data))
  attr_names <- setdiff(attr_names, c("class", "dim", "dimnames", "names", "row.names", "levels"))

  for (attr in attr_names) {
    attr_data <- base::attr(data, attr, exact = TRUE)
    if (is_list_group(attr_data)) next
    write_data(attr_data, file, name, attr, attr_as, attr_as, list("none", NULL, NULL), dry = dry)
  }
}


# --- Type Resolution Logic ---

#' Match a type name against `choices`, allowing unambiguous prefixes (e.g.
#' "utf" for "utf8"), except for "skip" and "null", which drop data and so must
#' be spelled out. Returns NA if there's no match.
#' @noRd
#' @keywords internal
match_type <- function(x, choices) {
  if (x %in% choices) return (x)
  hits <- choices[startsWith(choices, x) & !choices %in% c("skip", "null")]
  if (nzchar(x) && length(hits) == 1) hits else NA_character_
}

#' Look up the type `as` requests for an object or column called `name`.
#' Returns the type ("auto" if none), and whether it was requested by name
#' (or by an unnamed `as`) rather than by a class or global key.
#' @noRd
#' @keywords internal
lookup_as <- function(data, name, as_map) {

  if (is.null(names(as_map)))
    return (list(type = tolower(as_map[[1]]), exact = TRUE))

  # Type keys, e.g. ".integer", ".double", ".factor"
  cls <- if      (is.factor(data))               ".factor"
         else if (inherits(data, "integer64"))   ".integer64"
         else                                    paste0(".", storage.mode(data))
  num <- if (is.numeric(data) && !is.factor(data) && !inherits(data, "integer64")) ".numeric"

  for (key in c(name, cls, num, "."))
    if (key %in% names(as_map))
      return (list(type = tolower(as_map[[key]]), exact = identical(key, name)))

  list(type = "auto", exact = FALSE)
}


#' Convert factors (or factor columns) to character where `as` asks for a
#' string type, e.g. `as = c(grade = "ascii[1]")`.
#' @noRd
#' @keywords internal
factors_to_strings <- function(data, name, as_map) {

  as_strings <- function(x, key) {
    if (!is.factor(x)) return (x)
    type <- lookup_as(x, key, as_map)$type
    if (is.na(match_type(sub("\\[.*$", "", type), c("ascii", "utf8")))) return (x)
    res <- as.character(x)
    names(res) <- names(x)
    dim(res)   <- dim(x)
    res
  }

  if (is.data.frame(data)) { for (i in seq_along(data)) data[[i]] <- as_strings(data[[i]], names(data)[i]) }
  else                     { data <- as_strings(data, name) }
  data
}


#' Resolves the HDF5 type based on the 'as' map and data properties
#' @noRd
#' @keywords internal
#' @param data The R object.
#' @param name The name of the object (column name, dataset name, or attribute name).
#' @param as_map The processed 'as' argument (named vector).
resolve_h5_type <- function(data, name, as_map) {
  
  # Resolve type for *each* column
  if (is.data.frame(data)) {

    if (lookup_as(data, name, as_map)$type == "skip") return ("skip")

    if (ncol(data) == 0)
      stop("Cannot write a data.frame with zero columns: ", name, call. = FALSE)

    col_names <- names(data)
    if (anyNA(col_names) || any(col_names == "") || anyDuplicated(col_names) > 0)
      stop("Data frame column names must be unique and non-empty: ", name, call. = FALSE)

    # Each column becomes one compound member holding one value per row
    for (i in seq_along(data)) {
      if (!is.null(dim(data[[i]])))
        stop(call. = FALSE,
          "Data frame column '", col_names[i], "' is a matrix or array. ",
          "Split it into one column per vector before writing.")
      if (length(data[[i]]) != nrow(data))
        stop(call. = FALSE,
          "Data frame column '", col_names[i], "' has ", length(data[[i]]),
          " values, but the data frame has ", nrow(data), " rows.")
    }

    col_types <- character(ncol(data))
    for (i in seq_along(data)) {
      col_types[i] <- resolve_h5_type(data[[i]], col_names[i], as_map)
    }
    return(col_types)
  }
  
  look    <- lookup_as(data, name, as_map)
  h5_type <- look$type

  if (h5_type == "skip") return ("skip")

  # These types have a single HDF5 representation, so `as` can only skip them.
  # Asking for another type by name is an error; class or global keys meant
  # for other data are ignored.
  fixed <- if      (is.null(data))               "null"
           else if (is.raw(data))                "raw"
           else if (is.complex(data))            "complex"
           else if (inherits(data, "integer64")) "bit64"
           else if (inherits(data, "factor"))    "factor"

  if (!is.null(fixed)) {

    if (fixed == "factor") {
      if (!is.factor(data))
        stop("Non-factors with factor class cannot be written to HDF5.", call. = FALSE) # nocov
      if (!is.character(levels(data)))
        stop("Factors with non-character levels cannot be written to HDF5.", call. = FALSE) # nocov
      if (anyNA(data))
        stop("Factors with NA values cannot be written to HDF5 Enum types. Convert to character vector first.", call. = FALSE)
      if (nlevels(data) == 0)
        stop("Factors with no levels cannot be written to HDF5 Enum types.", call. = FALSE)
      if (any(levels(data) == ""))
        stop("Factor levels cannot be empty strings in HDF5 Enum types.", call. = FALSE)
      if (typeof(data) != "integer")
        stop("Factors with non-integer values cannot be written to HDF5 Enum types.", call. = FALSE) # nocov
    }

    allowed <- c("auto", fixed, if (fixed == "bit64") "int64")
    if (look$exact && is.na(match_type(h5_type, allowed)))
      stop(call. = FALSE,
        "Cannot store ", fixed, " data '", name, "' as '", h5_type, "'.",
        if (fixed == "factor") " Factors can be stored as an enum ('auto') or as strings ('utf8', 'ascii', ...).")

    return (fixed)
  }


  if (is.character(data)) {

    arg_errmsg <- paste("Invalid `as` argument for character vector:", h5_type)
    na_errmsg  <- paste("`NA` cannot be encoded by fixed length strings.")

    cset <- match_type(sub('\\[.*$', '', h5_type), c("auto", "ascii", "utf8"))
    if (is.na(cset) || !grepl("^[a-z0-9]*(\\[\\d*\\])?$", h5_type) || (cset == "auto" && grepl("[", h5_type, fixed = TRUE)))
      stop(arg_errmsg, call. = FALSE)

    # Auto-select: Always use UTF-8.
    # Choose fixed length when strings are short and consistent.
    if (cset == "auto") {
      if (length(data) > 0 && !anyNA(data)) {
        str_lens <- nchar(enc2utf8(data), type = "bytes")
        max_len  <- max(str_lens)
        mean_len <- mean(str_lens) + 16
        if (max_len < 4096 && max_len < mean_len * 4)
          return (paste0("utf8[", max_len, "]"))
      }
      return ("utf8")
    }
    
    # User-specified fixed length
    if (grepl("\\[\\d*\\]", h5_type)) {
      if (anyNA(data)) stop(na_errmsg, call. = FALSE)
      size <- as.integer(sub(".*\\[(\\d*)\\].*", "\\1", h5_type))
      if (is.na(size) || size < 1)
        size <- max(c(1L, nchar(enc2utf8(data), type = "bytes")))
      return (paste0(cset, "[", size, "]"))
    }
    
    # User-specified variable length
    return (cset)
  }
  

  if (is.numeric(data) || is.logical(data)) {
    
    choices <- c(
      "auto", "skip", 
      "bfloat16", "float16", "float32", "float64", 
      "int8", "int16", "int32", "int64",
      "uint8", "uint16", "uint32", "uint64")
    
    h5_type <- match_type(h5_type, choices)
    if (is.na(h5_type))
      stop("Invalid `as` argument for numeric vector: ", look$type, call. = FALSE)

    if (h5_type == "float64") return ("float64")
    
    if (h5_type == "auto") {
      
      if (anyNA(data))      return ("float64") # NA must use float64
      if (is.logical(data)) return ("uint8")

      if (is.double(data)) {

        if (any(data %% 1 > 0, na.rm = TRUE)) # Fractional values
          return ("float64")

        if (any(!is.finite(data))) { # NaN, Inf, or -Inf present
          rng <- range(c(1.0, data), na.rm = TRUE, finite = TRUE)
          if (rng[1] >= -2^24 && rng[2] <= 2^24) return ("float32")
          return ("float64")
        }
      }

      # Choose optimal data type for finite integers
      rng <- range(c(1, data), na.rm = TRUE, finite = TRUE)
      lo  <- rng[[1]]
      hi  <- rng[[2]]

      if (lo >= 0) { # Unsigned integer
        if (hi <= 2^8-1)  return ("uint8")
        if (hi <= 2^16-1) return ("uint16")
        if (hi <= 2^32-1) return ("uint32")
        if (hi <  2^53)   return ("uint64")
      }
      else { # Signed integer
        if (lo >= -2^7  && hi <= 2^7-1)  return ("int8")
        if (lo >= -2^15 && hi <= 2^15-1) return ("int16")
        if (lo >= -2^31 && hi <= 2^31-1) return ("int32")
        if (lo >  -2^53 && hi <  2^53)   return ("int64")
      }

      return ("float64")
    }
    
    # Sanity check user's requested HDF5 numeric type
    
    if (length(data) == 0) return(h5_type)
    if (any(!is.finite(data)) && !grepl("float", h5_type, fixed = TRUE))
      stop("Data contains NA/NaN/Inf; requires float type.", call. = FALSE)
    
    if (any(is.finite(data))) {
      val_range <- range(data, na.rm = TRUE, finite = TRUE)
      lo <- val_range[[1]]
      hi <- val_range[[2]]

      # Integer upper bounds are exclusive: 2^63-1 and 2^64-1 can't be
      # represented as doubles, and round up to 2^63 and 2^64. The int64 lower
      # bound is too, since -2^63 is bit64's NA.
      fits <- switch(h5_type,
        'int8'     = lo >= -2^7  && hi < 2^7,   'uint8'  = lo >= 0 && hi < 2^8,
        'int16'    = lo >= -2^15 && hi < 2^15,  'uint16' = lo >= 0 && hi < 2^16,
        'int32'    = lo >= -2^31 && hi < 2^31,  'uint32' = lo >= 0 && hi < 2^32,
        'int64'    = lo >  -2^63 && hi < 2^63,  'uint64' = lo >= 0 && hi < 2^64,
        'float16'  = max(abs(val_range)) <= 65504,
        'bfloat16' = max(abs(val_range)) <= 3.3895313892515355e38,
        'float32'  = max(abs(val_range)) <= 3.4028234663852886e38,
        TRUE )

      if (!fits)
        stop("Data range [", lo, ", ", hi, "] exceeds '", h5_type, "'", call. = FALSE)
    }
    
    return(h5_type)
  }
  
  stop("Cannot write data of class ", paste(class(data), collapse = "/"), " to HDF5.", call. = FALSE) # nocov
}


#' @noRd
#' @keywords internal
validate_dims <- function (data, warn = TRUE) {

  # If data is wrapped in I(), treat as a scalar (NULL dims), but ONLY if it's length 1.
  # This prevents accidentally writing a multi-element 'AsIs' vector as a scalar, which would cause data loss.
  if (inherits(data, 'AsIs')) {
    if (length(data) == 1) {
      return(NULL)
    } else if (warn) {
      warning("I() is ignored for objects that don't have exactly one value. Writing as a 1D array.", call. = FALSE)
    }
  }
  
  # Otherwise, infer dimensions from the object. A vector will have length, a matrix/array will have dim().
  if (is.null(dim(data))) length(data) else dim(data)
}


#' @noRd
#' @keywords internal
is_list_group <- function (data) {
  # A "list group" is a list that is not a data.frame (or a POSIXlt date-time,
  # which is a list internally but is written as a vector of strings).
  return (is.list(data) && !is.data.frame(data) && !inherits(data, "POSIXlt"))
}
