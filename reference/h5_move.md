# Move or Rename an HDF5 Object

Moves or renames an object (dataset, group, etc.) within an HDF5 file.

## Usage

``` r
h5_move(file, from, to)
```

## Arguments

- file:

  Path to the HDF5 file.

- from:

  The current (source) path of the object (e.g., `"/group/data"`).

- to:

  The new (destination) path for the object (e.g., `"/group/data_new"`).

## Value

This function is called for its side-effect and returns `NULL`
invisibly.

## Details

This function provides an efficient, low-level wrapper for the HDF5
library's `H5Lmove` function. It is a metadata-only operation, meaning
the data itself is not read or rewritten. This makes it extremely fast,
even for very large datasets.

You can use this function to either rename an object within the same
group (e.g., `"data/old"` to `"data/new"`) or to move an object to a
different group (e.g., `"data/old"` to `"archive/old"`). The destination
parent group will be automatically created if it does not exist.

## See also

[`h5_create_group()`](https://cmmr.github.io/h5lite/reference/h5_create_group.md),
[`h5_delete()`](https://cmmr.github.io/h5lite/reference/h5_delete.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create a sample file structure
h5_write(file, "group1/dataset_a", 1:10)
h5_write(file, "group1/dataset_b", 2:20)
h5_create_group(file, "group2")

# --- Example 1: Rename a dataset ---

print(h5_ls(file, recursive = TRUE))
#> [1] "group1"           "group1/dataset_a" "group1/dataset_b" "group2"          
#> [1] "group1"           "group1/dataset_a" "group1/dataset_b" "group2"

h5_move(file, "group1/dataset_a", "group1/data_renamed")

print(h5_ls(file, recursive = TRUE))
#> [1] "group1"              "group1/dataset_b"    "group1/data_renamed"
#> [4] "group2"             
#> [1] "group1"              "group1/dataset_b"  "group1/data_renamed" "group2"


# --- Example 2: Move a dataset between groups ---

h5_move(file, "group1/dataset_b", "group2/data_moved")

print(h5_ls(file, recursive = TRUE))
#> [1] "group1"              "group1/data_renamed" "group2"             
#> [4] "group2/data_moved"  
#> [1] "group1"              "group1/data_renamed" "group2"
#> [4] "group2/data_moved"

# Clean up
unlink(file)
```
