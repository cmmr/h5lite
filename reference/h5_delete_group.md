# Delete an HDF5 Group

Deletes a group and all objects contained within it.

## Usage

``` r
h5_delete_group(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the group to delete (e.config. "/g1/g2").

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "/g1/g2/dset", 1:10)
#> NULL
h5_ls(file, recursive = TRUE) # "g1" "g1/g2" "g1/g2/dset"
#> [1] "g1"         "g1/g2"      "g1/g2/dset"

h5_delete_group(file, "/g1")
#> NULL
h5_ls(file, recursive = TRUE) # character(0)
#> character(0)
unlink(file)
```
