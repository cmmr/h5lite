# Write a List Recursively to HDF5

Writes a nested R list to an HDF5 file, creating a corresponding group
and dataset structure.

## Usage

``` r
h5_write_all(file, name, data, compress = TRUE, attrs = TRUE)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The name of the top-level group to write the list into.

- data:

  The nested R `list` to write.

- compress:

  A logical or an integer from 0-9. This compression setting is applied
  to all datasets written during the recursive operation.

- attrs:

  Controls which R attributes are written for the **datasets** within
  the list. See
  [`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
  for details. This does not affect attributes on the lists/groups
  themselves, which are always written.

## Value

Invisibly returns `NULL`.

## Details

This function provides a way to save a complex, nested R list as an HDF5
hierarchy.

- R `list` objects are created as HDF5 groups.

- All other supported R objects (vectors, matrices, arrays, factors) are
  written as HDF5 datasets.

- Attributes of a list are written as HDF5 attributes on the
  corresponding group.

- The `attrs` argument controls how attributes of the datasets (non-list
  elements) are handled.

Before writing any data, `h5_write_all` performs a "dry run" to validate
that all objects and attributes within the list are of a writeable type.
If any part of the structure is invalid, the function will throw an
error and no data will be written to the file.

## See also

[`h5_read_all()`](https://cmmr.github.io/h5lite/reference/h5_read_all.md),
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create a nested list with attributes
my_list <- list(
  config = list(version = 1.2, user = "test"),
  data = list(
    matrix = matrix(1:4, 2),
    vector = 1:10
  )
)
attr(my_list$data, "info") <- "This is the data group"

h5_write_all(file, "session_data", my_list)

h5_ls(file, recursive = TRUE)
#> [1] "session_data"                "session_data/config"        
#> [3] "session_data/config/user"    "session_data/config/version"
#> [5] "session_data/data"           "session_data/data/matrix"   
#> [7] "session_data/data/vector"   

unlink(file)
```
