# Delete an HDF5 Object

Deletes an object (dataset or group) from an HDF5 file. If the object is
a group, all objects contained within it will be deleted recursively.

## Usage

``` r
h5_delete(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the object to delete (e.g., `"/data/dset"` or
  `"/groups/g1"`).

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## See also

[`h5_delete_attr()`](https://cmmr.github.io/h5lite/reference/h5_delete_attr.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "/g1/d1", 1:10)
h5_write(file, "d2", 1:5)
print(h5_ls(file, recursive = TRUE))
#> [1] "g1"    "g1/d1" "d2"   

# Delete a dataset
h5_delete(file, "d2")
print(h5_ls(file, recursive = TRUE))
#> [1] "g1"    "g1/d1"

# Delete a group (and its contents)
h5_delete(file, "g1")
print(h5_ls(file, recursive = TRUE))
#> character(0)
unlink(file)
```
