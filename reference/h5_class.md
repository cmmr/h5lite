# Get R Class of an HDF5 Object or Attribute

Inspects an HDF5 object (or an attribute attached to it) and returns the
R class that
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) would
produce.

## Usage

``` r
h5_class(file, name, attr = NULL)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The full path of the object (group or dataset) to check.

- attr:

  The name of an attribute to check. If `NULL` (default), the function
  checks the class of the object itself.

## Value

A character string representing the R class (e.g., `"integer"`,
`"numeric"`, `"complex"`, `"character"`, `"factor"`, `"raw"`, `"list"`,
`"NULL"`). Returns `NA_character_` for HDF5 types that `h5lite` cannot
read.

## Details

This function determines the resulting R class by inspecting the storage
metadata.

- **Groups** are reported as `"list"`.

- **Integer** datasets/attributes are reported as `"numeric"`.

- **Floating Point** datasets/attributes are reported as `"numeric"`.

- **String** datasets/attributes are reported as `"character"`.

- **Complex** datasets/attributes are reported as `"complex"`.

- **Enum** datasets/attributes are reported as `"factor"`.

- **1-byte Opaque** datasets/attributes are reported as `"raw"`.

- **Compound** datasets/attributes are reported as `"data.frame"`.

- **Null** datasets/attributes (with a null dataspace) are reported as
  `"NULL"`.

## See also

[`h5_typeof()`](https://cmmr.github.io/h5lite/reference/h5_typeof.md),
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

h5_write(1:10, file, "my_ints", as = "int32")
h5_class(file, "my_ints") # "numeric"
#> [1] "numeric"

h5_write(mtcars, file, "mtcars")
h5_class(file, "mtcars") # "data.frame"
#> [1] "data.frame"

h5_write(c("a", "b", "c"), file, "strings")
h5_class(file, "strings") # "character"
#> [1] "character"

h5_write(c(1, 2, 3), file, "my_floats", as = "float64")
h5_class(file, "my_floats") # "numeric"
#> [1] "numeric"

unlink(file)
```
