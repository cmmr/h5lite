#' Get R Class of an HDF5 Object or Attribute
#'
#' Inspects an HDF5 object (or an attribute attached to it) and returns the R class
#' that `h5_read()` would produce.
#'
#' @details
#' This function determines the resulting R class by inspecting the storage metadata.
#'
#' \itemize{
#'   \item **Group** &rarr; `"list"`
#'   \item **Integer** &rarr; `"numeric"`
#'   \item **Floating Point** &rarr; `"numeric"`
#'   \item **String** &rarr; `"character"`
#'   \item **Complex** &rarr; `"complex"`
#'   \item **Enum** &rarr; `"factor"`
#'   \item **Opaque** &rarr; `"raw"`
#'   \item **Compound** &rarr; `"data.frame"`
#'   \item **Null** &rarr; `"NULL"`
#' }
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the object (group or dataset) to check.
#' @param attr The name of an attribute to check. If `NULL` (default), the function
#'   checks the class of the object itself.
#' @return A character string representing the R class (e.g., `"integer"`, `"numeric"`, 
#'   `"complex"`, `"character"`, `"factor"`, `"raw"`, `"list"`, `"NULL"`).
#'   Returns `NA_character_` for HDF5 types that `h5lite` cannot read.
#'
#' @seealso [h5_typeof()], [h5_read()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_write(1:10, file, "my_ints", as = "int32")
#' h5_class(file, "my_ints") # "numeric"
#' 
#' h5_write(mtcars, file, "mtcars")
#' h5_class(file, "mtcars") # "data.frame"
#' 
#' h5_write(c("a", "b", "c"), file, "strings")
#' h5_class(file, "strings") # "character"
#' 
#' h5_write(c(1, 2, 3), file, "my_floats", as = "float64")
#' h5_class(file, "my_floats") # "numeric"
#' 
#' unlink(file)
h5_class <- function (file, name, attr = NULL) {

  if (h5_is_group(file, name, attr))
    return("list")

  hdf5_type <- h5_typeof(file, name, attr)

  if (!is.character(hdf5_type)) return(NA_character_) # nocov
  if (startsWith(hdf5_type, "int"))      return("numeric")
  if (startsWith(hdf5_type, "uint"))     return("numeric")
  if (startsWith(hdf5_type, "float"))    return("numeric")
  if (startsWith(hdf5_type, "compound")) return("data.frame")
  if (startsWith(hdf5_type, "utf8"))     return("character")
  if (startsWith(hdf5_type, "ascii"))    return("character")
  if (startsWith(hdf5_type, "string"))   return("character") # nocov
  if (identical(hdf5_type, "enum"))      return("factor")
  if (identical(hdf5_type, "complex"))   return("complex")
  if (identical(hdf5_type, "opaque"))    return("raw")
  if (identical(hdf5_type, "null"))      return("NULL")

  NA_character_
}


#' Get HDF5 Storage Type of an Object or Attribute
#'
#' Returns the low-level HDF5 storage type of a dataset or an attribute
#' (e.g., "int8", "float64", "utf8", "ascii\[10\]"). This allows inspecting the 
#' file storage type before reading the data into R.
#'
#' @param file The path to the HDF5 file.
#' @param name Name of the dataset or object.
#' @param attr The name of an attribute to check. If `NULL` (default), the function
#'   returns the type of the object itself.
#' @return A character string representing the HDF5 storage type 
#'   (e.g., "float32", "uint32", "ascii\[10\]", "compound\[2\]").
#'
#' @seealso [h5_class()], [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_write(1L, file, "int32_val", as = "int32")
#' h5_typeof(file, "int32_val") # "int32"
#' 
#' h5_write(mtcars, file, "mtcars")
#' h5_typeof(file, "mtcars") # "compound[11]"
#' 
#' h5_write(c("a", "b", "c"), file, "strings")
#' h5_typeof(file, "strings") # "utf8[1]"
#' 
#' unlink(file)
h5_typeof <- function (file, name, attr = NULL) {

  file <- validate_strings(file, name, attr, must_exist = TRUE)

  if (is.null(attr)) { .Call("C_h5_typeof",      file, name,       PACKAGE = "h5lite") } 
  else               { .Call("C_h5_typeof_attr", file, name, attr, PACKAGE = "h5lite") }
}


#' Get Dimensions of an HDF5 Object or Attribute
#'
#' Returns the dimensions of a dataset or an attribute as an integer vector.
#' These dimensions match the R-style (column-major) interpretation.
#'
#' @param file The path to the HDF5 file.
#' @param name Name of the dataset or object.
#' @param attr The name of an attribute to check. If `NULL` (default), the function
#'   returns the dimensions of the object itself.
#' @return An integer vector of dimensions, or `integer(0)` for scalars.
#'
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_write(matrix(1:10, 2, 5), file, "matrix")
#' h5_dim(file, "matrix") # 2 5
#' 
#' h5_write(mtcars, file, "mtcars")
#' h5_dim(file, "mtcars") # 32 11
#' 
#' h5_write(I(TRUE), file, "my_bool")
#' h5_dim(file, "my_bool") # integer(0)
#' 
#' h5_write(1:10, file, "my_ints")
#' h5_dim(file, "my_ints") # 10
#' 
#' unlink(file)
h5_dim <- function (file, name, attr = NULL) {

  file <- validate_strings(file, name, attr, must_exist = TRUE)

  if (is.null(attr)) { .Call("C_h5_dim",      file, name,       PACKAGE = "h5lite") } 
  else               { .Call("C_h5_dim_attr", file, name, attr, PACKAGE = "h5lite") }
}


#' Check if an HDF5 File, Object, or Attribute Exists
#'
#' Safely checks if a file, an object within a file, or an attribute on an object exists.
#'
#' @details
#' This function provides a robust, error-free way to test for existence.
#'
#' \itemize{
#'   \item **Testing for a File:** If `name` is `/` and `attr` is `NULL`,
#'     the function checks if `file` is a valid, readable HDF5 file.
#'
#'   \item **Testing for an Object:** If `name` is a path (e.g., `/data/matrix`)
#'     and `attr` is `NULL`, the function checks if the specific object exists.
#'
#'   \item **Testing for an Attribute:** If `attr` is provided, the function checks
#'     if that attribute exists on the specified object `name`.
#' }
#'
#' @param file Path to the file.
#' @param name The full path of the object to check (e.g., `"/data/matrix"`).
#'   Defaults to `"/"` to test file validity.
#' @param attr The name of an attribute to check. If provided, the function tests
#'   for the existence of this attribute on `name`.
#' @param assert Logical. If `TRUE` and the target does not exist, the function
#'   will stop with an informative error message instead of returning `FALSE`.
#'   Defaults to `FALSE`.
#' @return A logical value: `TRUE` if the target exists and is valid, `FALSE` otherwise.
#' @seealso [h5_is_group()], [h5_is_dataset()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_exists(file) # FALSE
#' 
#' h5_create_file(file)
#' h5_exists(file) # TRUE
#' 
#' h5_exists(file, "missing_object") # FALSE
#' 
#' h5_write(1:10, file, "my_ints")
#' h5_exists(file, "my_ints") # TRUE
#' 
#' h5_exists(file, "my_ints", "missing_attr") # FALSE
#' 
#' h5_write(1:10, file, "my_ints", attr = "my_attr")
#' h5_exists(file, "my_ints", "my_attr") # TRUE
#' 
#' unlink(file)
h5_exists <- function (file, name = "/", attr = NULL, assert = FALSE) {
  
  if (assert) {
    file <- validate_strings(file, name, attr, must_exist = TRUE)
  }
  else {
    file <- tryCatch(
      validate_strings(file, name, attr, must_exist = TRUE),
      error = function(e) { return(NULL) }
    )
  }
  
  return(isTRUE(nzchar(file)))
}

#' Check if an HDF5 Object is a Group
#'
#' Checks if the object at a given path is a group.
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the object to check.
#' @param attr The name of an attribute. This parameter is included for consistency with other functions.
#'   Since attributes cannot be groups, providing this will always return `FALSE`. (Default: `NULL`)
#' @return A logical value: `TRUE` if the object exists and is a group,
#'   `FALSE` otherwise (if it is a dataset, or does not exist).
#' @seealso [h5_is_dataset()], [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_create_group(file, "grp")
#' h5_is_group(file, "grp") # TRUE
#' 
#' h5_write(1:10, file, "my_ints")
#' h5_is_group(file, "my_ints") # FALSE
#' 
#' unlink(file)
h5_is_group <- function (file, name, attr = NULL) {

  file <- validate_strings(file, name, attr)
  
  if (!is.null(attr))         return(FALSE)
  if (!h5_exists(file, name)) return(FALSE)

  # Call the C function to check if the object's type is H5O_TYPE_GROUP.
  .Call("C_h5_is_group", file, name, PACKAGE = "h5lite")
}

#' Check if an HDF5 Object is a Dataset
#'
#' Checks if the object at a given path is a dataset.
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the object to check.
#' @param attr The name of an attribute. If provided, the function returns `TRUE` if the attribute exists, 
#'   as all attributes are considered datasets in HDF5 context. (Default: `NULL`)
#' @return A logical value: `TRUE` if the object exists and is a dataset,
#'   `FALSE` otherwise (if it is a group, or does not exist).
#' @seealso [h5_is_group()], [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_write(1, file, "dset")
#' h5_is_dataset(file, "dset") # TRUE
#' 
#' h5_create_group(file, "grp")
#' h5_is_dataset(file, "grp") # FALSE
#' 
#' h5_write(1, file, "grp", attr = "my_attr")
#' h5_is_dataset(file, "grp", "my_attr") # TRUE
#' 
#' unlink(file)
h5_is_dataset <- function (file, name, attr = NULL) {

  file <- validate_strings(file, name, attr)
  
  if (!h5_exists(file, name, attr)) return(FALSE)
  if (!is.null(attr))               return(TRUE)
  
  # Call the C function to check if the object's type is H5O_TYPE_DATASET.
  .Call("C_h5_is_dataset", file, name, PACKAGE = "h5lite")
}

#' Get Names of an HDF5 Object
#'
#' Returns the names of the object.
#' * For **Groups**, it returns the names of the objects contained in the group (similar to `ls()`).
#' * For **Compound Datasets** (data.frames), it returns the column names.
#' * For other **Datasets**, it looks for a dimension scale and returns it if found.
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the object.
#' @param attr The name of an attribute. If provided, returns the names associated with the attribute
#'   (e.g., field names if the attribute is a compound type). (Default: `NULL`)
#' @return A character vector of names, or `NULL` if the object has no names.
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_write(data.frame(x=1, y=2), file, "df")
#' h5_names(file, "df") # "x" "y"
#' 
#' x <- 1:5
#' names(x) <- letters[1:5]
#' h5_write(x, file, "x")
#' h5_names(file, "x") # "a" "b" "c" "d" "e"
#' 
#' h5_write(mtcars[,c("mpg", "hp")], file, "dset")
#' h5_names(file, "dset") # "mpg" "hp"
#' 
#' unlink(file)
h5_names <- function (file, name = "/", attr = NULL) {

  file <- validate_strings(file, name, attr, must_exist = TRUE)

  if (h5_is_dataset(file, name, attr)) {
    res <- .Call("C_h5_names", file, name, attr, PACKAGE = "h5lite")
  }
  else {
    res <- h5_ls(file, name, recursive = FALSE, full.names = FALSE)
  }
  
  if (is.null(res)) res <- character(0)
  return (res)
}

#' List HDF5 Attributes
#' 
#' Lists the names of attributes attached to a specific HDF5 object.
#'
#' @param file The path to the HDF5 file.
#' @param name The path to the object (dataset or group) to query. 
#'   Use `/` for the file's root attributes.
#' @return A character vector of attribute names.
#' 
#' @seealso [h5_ls()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_write(1:10,          file, "data")
#' h5_write(I("meters"),   file, "data", attr = "unit")
#' h5_write(I(Sys.time()), file, "data", attr = "timestamp")
#' 
#' h5_attr_names(file, "data") # "unit" "timestamp"
#' 
#' unlink(file)
h5_attr_names <- function (file, name = "/") {
  file <- validate_strings(file, name, must_exist = TRUE)
  
  # Call the C function that iterates over attributes and returns their names.
  .Call("C_h5_attr_names", file, name, PACKAGE = "h5lite")
}


#' Get the Total Length of an HDF5 Object or Attribute
#'
#' Behaves like `length()` for R objects.
#' * For **Compound Datasets** (data.frames), this is the number of columns.
#' * For **Datasets** and **Attributes**, this is the product of all dimensions (total number of elements).
#' * For **Groups**, this is the number of objects directly contained in the group.
#' * Scalar datasets or attributes return 1.
#'
#' @param file The path to the HDF5 file.
#' @param name The full path of the object (group or dataset).
#' @param attr The name of an attribute to check. If provided, the length of the attribute is returned.
#' @return An integer representing the total length (number of elements).
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' h5_write(1:100, file, "my_vec")
#' h5_length(file, "my_vec") # 100
#' 
#' h5_write(mtcars, file, "my_df")
#' h5_length(file, "my_df") # 11 (ncol(mtcars))
#' 
#' h5_write(as.matrix(mtcars), file, "my_mtx")
#' h5_length(file, "my_mtx") # 352 (prod(dim(mtcars)))
#' 
#' h5_length(file, "/") # 3
#' 
#' unlink(file)
h5_length <- function (file, name, attr = NULL) {

  if (h5_is_dataset(file, name, attr)) {
    dims <- h5_dim(file, name, attr)
    res <- if (identical(dims, integer(0)))                     { 1L         }
           else if (h5_class(file, name, attr) == "data.frame") { dims[2]    }
           else                                                 { prod(dims) }
    return(as.integer(res))
  }
  else if (h5_is_group(file, name, attr)) {
    return(length(h5_ls(file, name, recursive = FALSE)))
  }

  return(NA_integer_)
}
