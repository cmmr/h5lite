# Delete an HDF5 Dataset

Deletes a dataset from an HDF5 file. This function will not delete a
group.

## Usage

``` r
h5_delete_dataset(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the dataset to delete.

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## See also

[`h5_delete_attr()`](https://cmmr.github.io/h5lite/reference/h5_delete_attr.md),
[`h5_delete_group()`](https://cmmr.github.io/h5lite/reference/h5_delete_group.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "dset1", 1:10)
h5_write(file, "dset2", 1:5)
print(h5_ls(file))
#> [1] "dset1" "dset2"

h5_delete_dataset(file, "dset1")
print(h5_ls(file))
#> [1] "dset2"
unlink(file)
```
