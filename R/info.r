
#' Get R Class of an HDF5 Object
#'
#' Inspects an HDF5 object and returns the R class that `h5_read()` would produce.
#'
#' @details
#' This function determines the resulting R class by inspecting the object's
#' metadata.
#' \itemize{
#'   \item **Groups** are reported as `"list"`.
#'   \item **Datasets** (integers, floats) are reported as `"numeric"`
#'     (since `h5_read` always returns `double`).
#'   \item **String** datasets are reported as `"character"`.
#'   \item **Complex** datasets are reported as `"complex"`.
#'   \item **Enum** datasets are reported as `"factor"`.
#'   \item **1-byte Opaque** datasets are reported as `"raw"`.
#'   \item **Compound** datasets are reported as `"data.frame"`.
#'   \item **Null** datasets (with a null dataspace) are reported as `"NULL"`.
#' }
#'
#' If `attrs` is set to `TRUE` or is a character vector containing `"class"`,
#' this function will first check for an HDF5 attribute on the object named
#' `"class"`. If a string attribute with this name exists, its value
#' (e.g., `"data.frame"`) will be returned, taking precedence over
#' the object's type.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the object (group or dataset) to check.
#' @param attrs Controls attribute checking. If `TRUE` or a character
#'   vector containing `"class"`, the function will check for a `"class"`
#'   HDF5 attribute on the object.
#' @return A character string representing the R class (e.g., `"numeric"`, `"complex"`,
#'   `"character"`, `"factor"`, `"raw"`, `"list"`, `"NULL"`).
#'   Returns `NA_character_` for HDF5 types that `h5lite` cannot read.
#'
#' @seealso [h5_class_attr()], [h5_typeof()], [h5_read()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#'
#' # Write various object types
#' h5_write(file, "integers", 1:5)
#' h5_write(file, "doubles", c(1.1, 2.2))
#' h5_write(file, "text", "hello")
#' h5_create_group(file, "my_group")
#'
#' # Write a data.frame, which becomes a compound dataset
#' h5_write(file, "my_df", data.frame(a = 1:2, b = c("x", "y")))
#'
#' # Check R classes
#' h5_class(file, "integers")      # "numeric"
#' h5_class(file, "doubles")       # "numeric"
#' h5_class(file, "text")          # "character"
#' h5_class(file, "my_group")      # "list"
#'
#' # Check the data.frame
#' h5_class(file, "my_df") # "data.frame"
#' h5_class(file, "my_df", attrs = TRUE)  # "data.frame"
#'
#' unlink(file)
h5_class <- function(file, name, attrs = FALSE) {
  file <- path.expand(file)
  if (!h5_exists(file, name)) {
    stop("Object '", name, "' does not exist in file '", file, "'.")
  }
  
  # Determine if we should check for a "class" attribute on the HDF5 object.
  check_class_attr <- isTRUE(attrs) || (is.character(attrs) && "class" %in% attrs)
  
  if (check_class_attr) {
    # If a "class" attribute exists and is a string, its value takes precedence.
    if (h5_exists_attr(file, name, "class")) {
      if (h5_typeof_attr(file, name, "class") == "string") {
        class_val <- h5_read_attr(file, name, "class")
        return(class_val[1]) # Return first element in case it's an array
      }
    }
  }
  
  # If no "class" attribute was found, determine the class from the object's native type.
  if (h5_is_group(file, name)) {
    return("list")
  } else if (h5_is_dataset(file, name)) {
    # For datasets, map the underlying HDF5 storage type to an R class.
    hdf5_type <- h5_typeof(file, name)
    return(map_hdf5_type_to_r_class(hdf5_type))
  }
  
  # Fallback for unhandled HDF5 object types (e.g., named datatype).
  NA_character_
}


#' Get R Class of an HDF5 Attribute
#'
#' Returns the R class that `h5_read_attr()` would
#' produce for a given HDF5 attribute.
#'
#' @details
#' This function maps the low-level HDF5 storage type of an attribute to the
#' resulting R class.
#' \itemize{
#'   \item **Integer/Float** attributes are reported as `"numeric"`.
#'   \item **String** attributes are reported as `"character"`.
#'   \item **Complex** attributes are reported as `"complex"`.
#'   \item **Enum** attributes are reported as `"factor"`.
#'   \item **1-byte Opaque** attributes are reported as `"raw"`.
#'   \item **Null** attributes are reported as `"NULL"`.
#'   \item Other HDF5 types are reported as `NA_character_`.
#' }
#'
#' @param file Path to the HDF5 file.
#' @param name Name of the object the attribute is attached to.
#' @param attribute Name of the attribute.
#' @return A character string representing the R class (e.g., `"numeric"`, `"complex"`, `"NULL"`,
#'   `"character"`, `"factor"`, `"raw"`).
#'   Returns `NA_character_` for HDF5 types that `h5lite` cannot read.
#'
#' @seealso [h5_class()], [h5_typeof_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "data", 1)
#'
#' # Write attributes of different types
#' h5_write_attr(file, "data", "int_attr", 10L) # 1D array of length 1
#' h5_write_attr(file, "data", "char_attr", I("info")) # scalar
#'
#' # Check R class
#' h5_class_attr(file, "data", "int_attr")  # "numeric"
#' h5_class_attr(file, "data", "char_attr") # "character"
#'
#' unlink(file)
h5_class_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!h5_exists_attr(file, name, attribute)) {
    stop("Attribute '", attribute, "' does not exist on object '", name, "'.")
  }
  
  # Get the HDF5 storage type and map it to the corresponding R class.
  hdf5_type <- h5_typeof_attr(file, name, attribute)
  map_hdf5_type_to_r_class(hdf5_type)
}


#' Get HDF5 Object Type
#' 
#' Returns the low-level HDF5 storage type of a dataset (e.g., "int8", "float64", "string").
#' This allows inspecting the file storage type before reading the data into R.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset.
#' @return A character string representing the HDF5 storage type (e.g., "float32", "uint32", "string").
#' 
#' @seealso [h5_typeof_attr()], [h5_class()], [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' # Write integers
#' h5_write(file, "integers", 1:5)
#' # Write doubles
#' h5_write(file, "doubles", c(1.1, 2.2))
#' 
#' # Check types
#' h5_typeof(file, "integers") # "uint8" (auto-selected)
#' h5_typeof(file, "doubles")  # "float64" (auto-selected)
#' 
#' unlink(file)
h5_typeof <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  # Call the C function to get the low-level HDF5 type string.
  .Call("C_h5_typeof", file, name, PACKAGE = "h5lite")
}

#' Get HDF5 Attribute Type
#' 
#' Returns the low-level HDF5 storage type of an attribute.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the object attached to.
#' @param attribute Name of the attribute.
#' @return A character string representing the HDF5 storage type.
#' 
#' @seealso [h5_typeof()], [h5_class_attr()], [h5_exists_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "data", 1)
#' 
#' h5_write_attr(file, "data", "meta", I("info"))
#' h5_typeof_attr(file, "data", "meta") # "string"
#' 
#' unlink(file)
h5_typeof_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  # Call the C function to get the attribute's HDF5 type string.
  .Call("C_h5_typeof_attr", file, name, attribute, PACKAGE = "h5lite")
}

#' Get HDF5 Object Dimensions
#' 
#' Returns the dimensions of a dataset as an integer vector.
#' These dimensions match the R-style (column-major) interpretation.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the dataset.
#' @return An integer vector of dimensions, or `integer(0)` for scalars.
#' 
#' @seealso [h5_dim_attr()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' 
#' mat <- matrix(1:10, nrow = 2, ncol = 5)
#' h5_write(file, "matrix", mat)
#' 
#' # Check dims without reading the whole dataset
#' h5_dim(file, "matrix") # Returns c(2, 5)
#' 
#' unlink(file)
h5_dim <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  # Call the C function to get the dataset's dimensions.
  .Call("C_h5_dim", file, name, PACKAGE = "h5lite")
}

#' Get HDF5 Attribute Dimensions
#' 
#' Returns the dimensions of an attribute.
#' 
#' @param file Path to the HDF5 file.
#' @param name Name of the object attached to.
#' @param attribute Name of the attribute.
#' @return An integer vector of dimensions, or `integer(0)` for scalars.
#' 
#' @seealso [h5_dim()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "data", 1)
#' 
#' h5_write_attr(file, "data", "vec_attr", 1:10)
#' h5_dim_attr(file, "data", "vec_attr") # 10
#' 
#' unlink(file)
h5_dim_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) stop("File does not exist: ", file)
  # Call the C function to get the attribute's dimensions.
  .Call("C_h5_dim_attr", file, name, attribute, PACKAGE = "h5lite")
}

#' Check if an HDF5 File or Object Exists
#'
#' Safely checks if a file is a valid HDF5 file or if a specific object
#' (group or dataset) exists within a valid HDF5 file.
#'
#' @details
#' This function provides a robust, error-free way to test for existence.
#'
#' \itemize{
#'   \item **Testing for a File:** If `name` is `/` (the default),
#'     the function checks if `file` is a valid, readable HDF5 file.
#'     It will return `FALSE` for non-existent files, non-HDF5 files, or
#'     corrupted files without raising an error.
#'
#'   \item **Testing for an Object:** If `name` is a path (e.g., `/data/matrix`),
#'     the function first confirms the file is valid HDF5, and then checks
#'     if the specific object exists within it.
#' }
#'
#' @param file Path to the file.
#' @param name The full path of the object to check (e.g., `"/data/matrix"`).
#'   Defaults to `"/"`, which tests if the file itself is a valid HDF5 file.
#' @return A logical value: `TRUE` if the file/object exists and is valid,
#'   `FALSE` otherwise.
#' @seealso [h5_exists_attr()], [h5_is_group()], [h5_is_dataset()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "my_data", 1:10)
#'
#' # --- Test 1: Check for a specific object ---
#' h5_exists(file, "my_data") # TRUE
#' h5_exists(file, "nonexistent_data") # FALSE
#'
#' # --- Test 2: Check for a valid HDF5 file ---
#' h5_exists(file) # TRUE
#' h5_exists(file, "/") # TRUE
#'
#' # --- Test 3: Check invalid or non-existent files ---
#' h5_exists("not_a_real_file.h5") # FALSE
#'
#' text_file <- tempfile()
#' writeLines("this is not hdf5", text_file)
#' h5_exists(text_file) # FALSE
#'
#' # Check for an object in an invalid file (also FALSE)
#' h5_exists(text_file, "my_data") # FALSE
#'
#' unlink(file)
#' unlink(text_file)
h5_exists <- function(file, name = "/") {
  file <- path.expand(file)
  if (!file.exists(file)) return(FALSE)
  # Call the C function, which safely checks for file/object existence without raising HDF5 errors.
  .Call("C_h5_exists", file, name, PACKAGE = "h5lite")
}

#' Check if an HDF5 Attribute Exists
#'
#' Checks for the existence of an attribute on an HDF5 object without
#' raising an error if it does not exist.
#'
#' @param file Path to the HDF5 file.
#' @param name The path to the object (dataset or group).
#' @param attribute The name of the attribute to check.
#' @return A logical value: `TRUE` if the attribute exists, `FALSE` otherwise.
#' @seealso [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_write(file, "my_data", 1)
#' h5_write_attr(file, "my_data", "units", "meters")
#'
#' h5_exists_attr(file, "my_data", "units") # TRUE
#' h5_exists_attr(file, "my_data", "nonexistent_attr") # FALSE
#'
#' unlink(file)
h5_exists_attr <- function(file, name, attribute) {
  file <- path.expand(file)
  if (!file.exists(file)) return(FALSE)
  # Call the C function to safely check for attribute existence.
  .Call("C_h5_exists_attr", file, name, attribute, PACKAGE = "h5lite")
}

#' Check if an HDF5 Object is a Group
#'
#' Checks if the object at a given path is a group.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the object to check.
#' @return A logical value: `TRUE` if the object exists and is a group,
#'   `FALSE` otherwise (if it is a dataset, or does not exist).
#' @seealso [h5_is_dataset()], [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_create_group(file, "my_group")
#' h5_write(file, "my_dataset", 1)
#'
#' h5_is_group(file, "my_group") # TRUE
#' h5_is_group(file, "my_dataset") # FALSE
#' h5_is_group(file, "nonexistent") # FALSE
#'
#' unlink(file)
h5_is_group <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) return(FALSE)
  # Call the C function to check if the object's type is H5O_TYPE_GROUP.
  .Call("C_h5_is_group", file, name, PACKAGE = "h5lite")
}

#' Check if an HDF5 Object is a Dataset
#'
#' Checks if the object at a given path is a dataset.
#'
#' @param file Path to the HDF5 file.
#' @param name The full path of the object to check.
#' @return A logical value: `TRUE` if the object exists and is a dataset,
#'   `FALSE` otherwise (if it is a group, or does not exist).
#' @seealso [h5_is_group()], [h5_exists()]
#' @export
#' @examples
#' file <- tempfile(fileext = ".h5")
#' h5_create_group(file, "my_group")
#' h5_write(file, "my_dataset", 1)
#'
#' h5_is_dataset(file, "my_dataset") # TRUE
#' h5_is_dataset(file, "my_group") # FALSE
#' h5_is_dataset(file, "nonexistent") # FALSE
#'
#' unlink(file)
h5_is_dataset <- function(file, name) {
  file <- path.expand(file)
  if (!file.exists(file)) return(FALSE)
  # Call the C function to check if the object's type is H5O_TYPE_DATASET.
  .Call("C_h5_is_dataset", file, name, PACKAGE = "h5lite")
}


#' Helper function to map HDF5 storage types to R classes
#' @keywords internal
#' @noRd
map_hdf5_type_to_r_class <- function(hdf5_type) {
  switch(
    # Use fall-through for numeric types.
    hdf5_type,
    
    # All numeric types are read as "numeric" (double)
    "int8" = ,
    "int16" = ,
    "int32" = ,
    "int64" = ,
    "uint8" = ,
    "uint16" = ,
    "uint32" = ,
    "uint64" = ,
    "int" = ,
    "float16" = ,
    "float32" = ,
    "float64" = ,
    "float" = "numeric",
    
    # Null type
    "null" = "NULL",
    
    # String type
    "string" = "character",
    
    # Complex type
    "complex" = "complex",
    
    # Enum type
    "enum" = "factor",
    
    # Compound type
    "compound" = "data.frame",
    
    # Opaque type (h5lite reads 1-byte opaque as raw)
    "opaque" = "raw",
    
    # HDF5 types that h5lite cannot read
    "bitfield" = ,
    "reference" = ,
    "vlen" = ,
    "array" = ,
    "unknown" = NA_character_,
    
    # Default fallback
    NA_character_
  )
}
