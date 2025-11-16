# Delete an HDF5 Attribute

Deletes an attribute from an object.

## Usage

``` r
h5_delete_attr(file, name, attribute)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The path to the object (dataset or group).

- attribute:

  The name of the attribute to delete.

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## See also

[`h5_delete_dataset()`](https://cmmr.github.io/h5lite/reference/h5_delete_dataset.md),
[`h5_delete_group()`](https://cmmr.github.io/h5lite/reference/h5_delete_group.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "data", 1)
h5_write_attr(file, "data", "attr1", "some info")
print(h5_ls_attr(file, "data")) # "attr1"
#> [1] "attr1"

h5_delete_attr(file, "data", "attr1")
print(h5_ls_attr(file, "data")) # character(0)
#> character(0)
unlink(file)
```
