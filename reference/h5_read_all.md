# Read an HDF5 Group or Dataset Recursively

Reads an HDF5 group and all its contents (subgroups and datasets) into a
nested R list. If the target `name` is a dataset, it is read directly.

## Usage

``` r
h5_read_all(file, name, attrs = TRUE)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the group or dataset to read (e.g., "/data").

- attrs:

  Controls which HDF5 attributes are read and attached to the returned R
  object(s). Defaults to `TRUE`. See
  [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) for
  more details.

## Value

A nested `list` representing the HDF5 group structure, or a single R
object if `name` points to a dataset.

## Details

When reading a group, the elements in the returned list are sorted
alphabetically by name, which may differ from their original creation
order.

## See also

[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create a nested structure
h5_write(file, "/config/version", 1.2)
h5_write(file, "/data/matrix", matrix(1:4, 2, 2))
h5_write(file, "/data/vector", 1:10)

# Read the entire 'data' group
data_group <- h5_read_all(file, "data")
str(data_group)
#> List of 2
#>  $ matrix: num [1:2, 1:2] 1 2 3 4
#>  $ vector: num [1:10] 1 2 3 4 5 6 7 8 9 10

# Read the entire file from the root
all_content <- h5_read_all(file, "/")
str(all_content)
#> List of 2
#>  $ config:List of 1
#>   ..$ version: num 1.2
#>  $ data  :List of 2
#>   ..$ matrix: num [1:2, 1:2] 1 2 3 4
#>   ..$ vector: num [1:10] 1 2 3 4 5 6 7 8 9 10

unlink(file)
```
