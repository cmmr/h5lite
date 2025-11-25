# Data Organization

``` r
library(h5lite)

# We'll use a temporary file for this guide.
file <- tempfile(fileext = ".h5")
```

## Introduction

One of the most powerful features of `h5lite` is its ability to map R’s
nested `list` objects directly to the hierarchical structure of an HDF5
file. This allows you to save and load complex, organized data
structures with a single command.

This vignette explores: \* How
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
recursively saves a list. \* How
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)
recursively loads a file structure into a list. \* The important detail
of alphabetical ordering. \* How to manually manage the file structure
using `h5lite`’s organizational functions.

For an introduction to writing data, see
[`vignette("h5lite", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/h5lite.md).

## 1. Recursive Writing with Lists

When you pass a `list` to
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md), it
treats it as a blueprint for creating a file structure:

- The `list` itself becomes an HDF5 **group**.
- Named elements inside the `list` become datasets or sub-groups.

Let’s create a nested list representing a session’s data.

``` r
session_data <- list(
  metadata = list(
    user = "test",
    version = 1.2,
    timestamp = "2025-11-17"
  ),
  raw_data = matrix(rnorm(100), ncol = 10)
)

# We can even add an attribute to the top-level list
attr(session_data, "info") <- "This is the root group attribute"

# Write the entire structure in one call
h5_write(file, "session_1", session_data, attrs = TRUE)
```

We can now inspect the file with
[`h5_str()`](https://cmmr.github.io/h5lite/reference/h5_str.md) to see
the hierarchy that was created.

``` r
h5_str(file)
#> Listing contents of: /tmp/RtmpXLS50e/file249030038f7c.h5
#> Root group: /
#> ----------------------------------------------------------------
#> Type            Name
#> ----------------------------------------------------------------
#> Group        session_1
#> string[1]    session_1 @info
#> Group        session_1/metadata
#> string[1]    session_1/metadata/user
#> float64[1]   session_1/metadata/version
#> string[1]    session_1/metadata/timestamp
#> float64[10,10] session_1/raw_data
```

## Recursive Reading of Groups

Just as
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) can
write a list recursively,
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) can
read an HDF5 group recursively. When you read a group path, `h5lite`
traverses its contents and builds a nested R `list` that mirrors the
file structure.

``` r
# Read the 'session_1' group back into a list
read_data <- h5_read(file, "session_1", attrs = TRUE)

str(read_data)
#> List of 2
#>  $ metadata:List of 3
#>   ..$ timestamp: chr "2025-11-17"
#>   ..$ user     : chr "test"
#>   ..$ version  : num 1.2
#>  $ raw_data: num [1:10, 1:10] -1.40004 0.25532 -2.43726 -0.00557 0.62155 ...
#>  - attr(*, "info")= chr "This is the root group attribute"
```

### Important: HDF5 Group Ordering

A critical detail to remember is that HDF5 groups **do not preserve the
creation order** of their members. When
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) reads
a group, it returns the elements in the list sorted alphabetically by
name.

Our original `session_data$metadata` list had the order `user`,
`version`, `timestamp`. The read-back list has the order `timestamp`,
`user`, `version`.

To correctly compare a list that has been round-tripped, you should sort
the original list’s elements by name first.

``` r
# Sort the original list to match the expected read-back order
session_data$metadata <- session_data$metadata[order(names(session_data$metadata))]

# Now the comparison will succeed
all.equal(session_data, read_data)
#> [1] TRUE
```

## Manual File Organization

While recursive list writing is convenient, you often need to manage the
file structure manually. `h5lite` provides a suite of simple functions
for this.

### Creating Groups

You can pre-build a directory structure using
[`h5_create_group()`](https://cmmr.github.io/h5lite/reference/h5_create_group.md).
It works like `mkdir -p`, creating any necessary parent groups.

``` r
h5_create_group(file, "/archive/2024/run_01")
h5_ls(file, recursive = TRUE)
#> [1] "session_1"                    "session_1/metadata"          
#> [3] "session_1/metadata/user"      "session_1/metadata/version"  
#> [5] "session_1/metadata/timestamp" "session_1/raw_data"          
#> [7] "archive"                      "archive/2024"                
#> [9] "archive/2024/run_01"
```

### Moving and Renaming Objects

[`h5_move()`](https://cmmr.github.io/h5lite/reference/h5_move.md) allows
you to efficiently rename or move any object (group or dataset). This is
a fast metadata operation that does not rewrite any data.

``` r
# Let's move our session data into the archive
h5_move(file, from = "session_1", to = "/archive/2024/run_01/data")

h5_str(file)
#> Listing contents of: /tmp/RtmpXLS50e/file249030038f7c.h5
#> Root group: /
#> ----------------------------------------------------------------
#> Type            Name
#> ----------------------------------------------------------------
#> Group        archive
#> Group        archive/2024
#> Group        archive/2024/run_01
#> Group        archive/2024/run_01/data
#> string[1]    archive/2024/run_01/data @info
#> Group        archive/2024/run_01/data/metadata
#> string[1]    archive/2024/run_01/data/metadata/user
#> float64[1]   archive/2024/run_01/data/metadata/version
#> string[1]    archive/2024/run_01/data/metadata/timestamp
#> float64[10,10] archive/2024/run_01/data/raw_data
```

### Deleting Objects

Finally, you can remove any object using
[`h5_delete()`](https://cmmr.github.io/h5lite/reference/h5_delete.md).
The deletion is recursive, so if you target a group, everything inside
it will also be removed.

``` r
# Let's create a temporary group to delete
h5_write(file, "/tmp/deleteme", 1:10)
h5_ls(file, "/tmp")
#> [1] "deleteme"

# Delete just the dataset
h5_delete(file, "/tmp/deleteme")
h5_exists(file, "/tmp/deleteme") # FALSE
#> [1] FALSE

# Delete the now-empty group
h5_delete(file, "/tmp")
h5_exists(file, "/tmp") # FALSE
#> [1] FALSE
```

These organizational functions give you full control over the structure
of your HDF5 file, allowing you to build and manage complex data
hierarchies with simple, predictable commands.

``` r
# Clean up the temporary file
unlink(file)
```
