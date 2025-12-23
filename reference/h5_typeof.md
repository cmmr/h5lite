# Get HDF5 Storage Type of an Object or Attribute

Returns the low-level HDF5 storage type of a dataset or an attribute
(e.g., "int8", "float64", "string"). This allows inspecting the file
storage type before reading the data into R.

## Usage

``` r
h5_typeof(file, name, attr = NULL)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  Name of the dataset or object.

- attr:

  The name of an attribute to check. If `NULL` (default), the function
  returns the type of the object itself.

## Value

A character string representing the HDF5 storage type (e.g., "float32",
"uint32", "string").

## See also

[`h5_class()`](https://cmmr.github.io/h5lite/reference/h5_class.md),
[`h5_exists()`](https://cmmr.github.io/h5lite/reference/h5_exists.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(1L, file, "int32_val", as = "int32")
h5_typeof(file, "int32_val") # "int32"
#> [1] "int32"
unlink(file)
```
