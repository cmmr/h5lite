# Delete an HDF5 Object or Attribute

Deletes an object (dataset or group) or an attribute from an HDF5 file.
If the object or attribute does not exist, a warning is issued and the
function returns successfully (no error is raised).

## Usage

``` r
h5_delete(file, name, attr = NULL, warn = TRUE)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The full path of the object to delete (e.g., `"/data/dset"` or
  `"/groups/g1"`).

- attr:

  The name of the attribute to delete.

  - If `NULL` (the default), the object specified by `name` is deleted.

  - If a string is provided, the attribute named `attr` is removed from
    the object `name`.

- warn:

  Emit a warning if the name/attr does not exist. Default: `TRUE`

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## See also

[`h5_create_group()`](https://cmmr.github.io/h5lite/reference/h5_create_group.md),
[`h5_move()`](https://cmmr.github.io/h5lite/reference/h5_move.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_create_file(file)

# Create some data and attributes
h5_write(matrix(1:10, 2, 5), file, "matrix")
h5_write("A note", file, "matrix", attr = "note")

# Delete the attribute
h5_delete(file, "matrix", attr = "note")
h5_attr_names(file, "matrix") # Returns character(0)
#> character(0)

# Delete the dataset
h5_delete(file, "matrix")
h5_ls(file) # Returns character(0)
#> character(0)

# Cleaning up
unlink(file)
```
