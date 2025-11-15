# Check if an HDF5 Object is a Dataset

Checks if the object at a given path is a dataset.

## Usage

``` r
h5_is_dataset(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the object to check.

## Value

A logical value: `TRUE` if the object exists and is a dataset, `FALSE`
otherwise (if it is a group, or does not exist).

## See also

[`h5_is_group()`](https://cmmr.github.io/h5lite/reference/h5_is_group.md),
[`h5_exists()`](https://cmmr.github.io/h5lite/reference/h5_exists.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_create_group(file, "my_group")
h5_write(file, "my_dataset", 1)

h5_is_dataset(file, "my_dataset") # TRUE
#> [1] TRUE
h5_is_dataset(file, "my_group") # FALSE
#> [1] FALSE
h5_is_dataset(file, "nonexistent") # FALSE
#> [1] FALSE

unlink(file)
```
