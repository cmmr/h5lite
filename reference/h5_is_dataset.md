# Check if an HDF5 Object is a Dataset

Checks if the object at a given path is a dataset.

## Usage

``` r
h5_is_dataset(file, name, attr = NULL)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The full path of the object to check.

- attr:

  The name of an attribute. If provided, the function returns `TRUE` if
  the attribute exists, as all attributes are considered datasets in
  HDF5 context. (Default: `NULL`)

## Value

A logical value: `TRUE` if the object exists and is a dataset, `FALSE`
otherwise (if it is a group, or does not exist).

## See also

[`h5_is_group()`](https://cmmr.github.io/h5lite/reference/h5_is_group.md),
[`h5_exists()`](https://cmmr.github.io/h5lite/reference/h5_exists.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(1, file, "dset")
h5_is_dataset(file, "dset") # TRUE
#> [1] TRUE
unlink(file)
```
