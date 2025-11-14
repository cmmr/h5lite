# Create an HDF5 Group

Explicitly creates a new group (or nested groups) in an HDF5 file. This
is useful for creating an empty group structure.

## Usage

``` r
h5_create_group(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the group to create (e.g., "/g1/g2").

## Examples

``` r
file <- tempfile(fileext = ".h5")

h5_create_group(file, "/my/nested/group")
#> NULL

h5_ls(file)
#> [1] "my"              "my/nested"       "my/nested/group"
unlink(file)
```
