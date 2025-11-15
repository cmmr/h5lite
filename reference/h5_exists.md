# Check if an HDF5 Object Exists

Checks for the existence of a dataset or group within an HDF5 file
without raising an error if it does not exist.

## Usage

``` r
h5_exists(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the object to check (e.g., "/data/matrix").

## Value

A logical value: `TRUE` if the object exists, `FALSE` otherwise.

## See also

[`h5_exists_attr()`](https://cmmr.github.io/h5lite/reference/h5_exists_attr.md),
[`h5_is_group()`](https://cmmr.github.io/h5lite/reference/h5_is_group.md),
[`h5_is_dataset()`](https://cmmr.github.io/h5lite/reference/h5_is_dataset.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "my_data", 1:10)

h5_exists(file, "my_data") # TRUE
#> [1] TRUE
h5_exists(file, "nonexistent_data") # FALSE
#> [1] FALSE

unlink(file)
```
