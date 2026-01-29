# Object-Oriented Interface

The `h5lite` package provides a convenient object-oriented interface for
interacting with HDF5 files. While the standard functions (e.g.,
`h5_read`, `h5_write`) are excellent for stateless, atomic operations,
the object-oriented handle is often more natural when performing
multiple operations on a single file or when navigating deep group
structures.

## Basic Usage

To use this interface, create a file handle using
[`h5_open()`](https://cmmr.github.io/h5lite/reference/h5_open.md). This
returns an `h5` object (specifically, an environment) that maintains a
reference to your file.

``` r
library(h5lite)

# Create a temporary file for this example
file <- tempfile(fileext = ".h5")

# Open the handle
h5 <- h5_open(file)

# The print method shows the file path and current internal working directory
print(h5)
#> <h5 handle>
#>   File:  /tmp/RtmpKbb2yf/file28fd4395bdeb.h5 
#>   WD:    / 
#>   Size:  195 bytes 
#>   Objects (root):  0
```

Once the handle is open, you can access standard `h5lite` functions as
methods of this object. The primary benefit is that you no longer need
to pass the `file` argument; it is handled implicitly.

``` r
# Write data using the handle
h5$write(1:10, "dataset1")
h5$write(matrix(1:9, 3, 3), "matrix_data")

# List contents
h5$ls()
#> [1] "dataset1"    "matrix_data"

# Read data back
my_data <- h5$read("dataset1")
print(my_data)
#>  [1]  1  2  3  4  5  6  7  8  9 10
```

Almost all standard functions map directly to methods by dropping the
`h5_` prefix:

- [`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
  $\rightarrow$`h5$write()`
- [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)
  $\rightarrow$`h5$read()`
- [`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md)
  $\rightarrow$`h5$ls()`
- [`h5_attr_names()`](https://cmmr.github.io/h5lite/reference/h5_attr_names.md)
  $\rightarrow$`h5$attr_names()`
- And so on (see **Method Reference** below).

## Navigation and Working Directories

A unique feature of the `h5` handle is the ability to maintain a
stateful “Working Directory” (WD) inside the HDF5 file. This functions
similarly to [`setwd()`](https://rdrr.io/r/base/getwd.html) in R or `cd`
in a shell.

By default, the WD is the root (`/`). You can change it using `$cd()`
and check it using `$pwd()`.

``` r
# Create a group structure
h5$create_group("simulations")

# Navigate into the group
h5$cd("simulations")
h5$pwd()
#> [1] "/simulations"

# Write data using relative paths (writes to /simulations/run1)
h5$write(rnorm(10), "run1")

# Verify the location
h5$ls()
#> [1] "run1"
```

Absolute paths (paths starting with `/`) always override the current
working directory:

``` r
# Writes to the root, ignoring the fact that we are in /simulations
h5$write(100, "/root_dataset")
```

You can also use `..` to navigate up the hierarchy:

``` r
h5$cd("..")
h5$pwd() # Now back at "/"
#> [1] "/"
```

## Reference Semantics

The object returned by `h5_open` is an **R environment**. This means it
follows “pass-by-reference” semantics, unlike most R objects which are
“pass-by-value”.

If you assign the handle to a new variable, you are creating a new
reference to the *same* handle. Modifying one will modify the other.

``` r
h5_alias <- h5

# Change directory in the alias
h5_alias$cd("simulations")

# The original handle is also updated
h5$pwd()
#> [1] "/simulations"
```

## Closing the Handle

When you are finished, you can close the handle using `$close()`.

**Note:** `h5lite` does not keep the actual HDF5 file lock open
persistently (it opens and closes the file for every read/write
operation to ensure safety). Therefore, `$close()` is a logical
operation: it clears the internal file path and working directory from
the handle, preventing further methods from being called on it.

``` r
h5$close()

# Further attempts to use the handle will result in an error:
# h5$ls() 
# Error: This h5 file handle has been closed.
```

## Method Reference

The following methods are available on the `h5` object:

| Method                    | Description                                   |
|:--------------------------|:----------------------------------------------|
| **I/O**                   |                                               |
| `$read(name, ...)`        | Read a dataset or attribute.                  |
| `$write(data, name, ...)` | Write a dataset or attribute.                 |
| **Navigation**            |                                               |
| `$cd(group)`              | Change the internal working directory.        |
| `$pwd()`                  | Print the current internal working directory. |
| **Structure**             |                                               |
| `$ls(name, ...)`          | List contents of a group.                     |
| `$create_group(name)`     | Create a new group.                           |
| `$delete(name)`           | Delete a group or dataset.                    |
| `$move(from, to)`         | Move/Rename an object.                        |
| `$names(name)`            | Get names of objects in a group.              |
| **Inspection**            |                                               |
| `$exists(name)`           | Check if an object exists.                    |
| `$dim(name)`              | Get dimensions of a dataset.                  |
| `$typeof(name)`           | Get the HDF5 type of an object.               |
| `$class(name)`            | Get the class (dataset/group) of an object.   |
| `$is_dataset(name)`       | Boolean check for dataset.                    |
| `$is_group(name)`         | Boolean check for group.                      |
| `$attr_names(name)`       | List attribute names.                         |
| `$str(name)`              | Display structure of an object.               |
