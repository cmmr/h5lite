# Check if an HDF5 File, Object, or Attribute Exists

Safely checks if a file, an object within a file, or an attribute on an
object exists.

## Usage

``` r
h5_exists(file, name = "/", attr = NULL, assert = FALSE)
```

## Arguments

- file:

  Path to the file.

- name:

  The full path of the object to check (e.g., `"/data/matrix"`).
  Defaults to `"/"` to test file validity.

- attr:

  The name of an attribute to check. If provided, the function tests for
  the existence of this attribute on `name`.

- assert:

  Logical. If `TRUE` and the target does not exist, the function will
  stop with an informative error message instead of returning `FALSE`.
  Defaults to `FALSE`.

## Value

A logical value: `TRUE` if the target exists and is valid, `FALSE`
otherwise.

## Details

This function provides a robust, error-free way to test for existence.

- **Testing for a File:** If `name` is `/` and `attr` is `NULL`, the
  function checks if `file` is a valid, readable HDF5 file.

- **Testing for an Object:** If `name` is a path (e.g., `/data/matrix`)
  and `attr` is `NULL`, the function checks if the specific object
  exists.

- **Testing for an Attribute:** If `attr` is provided, the function
  checks if that attribute exists on the specified object `name`.

## See also

[`h5_is_group()`](https://cmmr.github.io/h5lite/reference/h5_is_group.md),
[`h5_is_dataset()`](https://cmmr.github.io/h5lite/reference/h5_is_dataset.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

h5_exists(file) # FALSE
#> [1] FALSE

h5_create_file(file)
h5_exists(file) # TRUE
#> [1] TRUE

h5_exists(file, "missing_object") # FALSE
#> [1] FALSE

h5_write(1:10, file, "my_ints")
h5_exists(file, "my_ints") # TRUE
#> [1] TRUE

h5_exists(file, "my_ints", "missing_attr") # FALSE
#> [1] FALSE

h5_write(1:10, file, "my_ints", attr = "my_attr")
h5_exists(file, "my_ints", "my_attr") # TRUE
#> [1] TRUE

unlink(file)
```
