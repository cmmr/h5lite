# Get HDF5 Object Type

Returns the low-level HDF5 storage type of a dataset (e.g., "int8",
"float64", "string"). This allows inspecting the file storage type
before reading the data into R.

## Usage

``` r
h5_typeof(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the dataset.

## Value

A character string representing the HDF5 storage type (e.g., "float32",
"uint32", "string").

## See also

[`h5_typeof_attr()`](https://cmmr.github.io/h5lite/reference/h5_typeof_attr.md),
[`h5_class()`](https://cmmr.github.io/h5lite/reference/h5_class.md),
[`h5_exists()`](https://cmmr.github.io/h5lite/reference/h5_exists.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Write integers
h5_write(file, "integers", 1:5)
# Write doubles
h5_write(file, "doubles", c(1.1, 2.2))

# Check types
h5_typeof(file, "integers") # "uint8" (auto-selected)
#> [1] "uint8"
h5_typeof(file, "doubles")  # "float64" (auto-selected)
#> [1] "float64"

unlink(file)
```
