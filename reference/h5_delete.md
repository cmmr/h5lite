# Delete an HDF5 Dataset

Deletes a dataset from an HDF5 file.

## Usage

``` r
h5_delete(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the dataset to delete.

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "dset1", 1:10)
#> NULL
h5_write(file, "dset2", 1:5)
#> NULL
h5_ls(file)
#> [1] "dset1" "dset2"

h5_delete(file, "dset1")
#> NULL
h5_ls(file)
#> [1] "dset2"
unlink(file)
```
