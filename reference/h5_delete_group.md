# Delete an HDF5 Group

Deletes a group and all objects contained within it. This function will
not delete a dataset.

## Usage

``` r
h5_delete_group(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the group to delete (e.g., "/g1/g2").

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## See also

[`h5_delete_dataset()`](https://cmmr.github.io/h5lite/reference/h5_delete_dataset.md),
[`h5_delete_attr()`](https://cmmr.github.io/h5lite/reference/h5_delete_attr.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "/g1/g2/dset", 1:10)
print(h5_ls(file, recursive = TRUE)) # "g1" "g1/g2" "g1/g2/dset"
#> [1] "g1"         "g1/g2"      "g1/g2/dset"

h5_delete_group(file, "/g1")
print(h5_ls(file, recursive = TRUE)) # character(0)
#> character(0)
unlink(file)
```
