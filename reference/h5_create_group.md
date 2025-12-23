# Create an HDF5 Group

Explicitly creates a new group (or nested groups) in an HDF5 file. This
is useful for creating an empty group structure.

## Usage

``` r
h5_create_group(file, name)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The full path of the group to create (e.g., "/g1/g2").

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_create_file(file)

# Create a nested group structure
h5_create_group(file, "/data/experiment/run1")
h5_ls(file, recursive = TRUE)
#> [1] "data"                 "data/experiment"      "data/experiment/run1"

unlink(file)
```
