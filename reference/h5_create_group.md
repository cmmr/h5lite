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

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## Examples

``` r
file <- tempfile(fileext = ".h5")

h5_create_group(file, "/my/nested/group")

# List all objects recursively to see the full structure
h5_ls(file, recursive = TRUE)
#> [1] "my"              "my/nested"       "my/nested/group"
unlink(file)
```
