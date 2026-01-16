# Create an HDF5 File Handle

Creates a file handle that provides a convenient, object-oriented
interface for interacting with and navigating a specific HDF5 file.

## Usage

``` r
h5_open(file)
```

## Arguments

- file:

  Path to the HDF5 file. The file will be created if it does not exist.

## Value

An object of class `h5` with methods for interacting with the file.

## Details

This function returns a special `h5` object that wraps the standard
`h5lite` functions. The primary benefit is that the `file` argument is
pre-filled, allowing for more concise and readable code when performing
multiple operations on the same file.

For example, instead of writing:

    h5_write(1:10, file, "dset1")
    h5_write(2:20, file, "dset2")
    h5_ls(file)

You can create a handle and use its methods. Note that the `file`
argument is omitted from the method calls:

    h5 <- h5_open("my_file.h5")
    h5$write(1:10, "dset1")
    h5$write(2:20, "dset2")
    h5$ls()
    h5$close()

## Pass-by-Reference Behavior

Unlike most R objects, the `h5` handle is an **environment**. This means
it is passed by reference. If you assign it to another variable (e.g.,
`h5_alias <- h5`), both variables point to the *same* handle. Modifying
one (e.g., by calling `h5_alias$close()`) will also affect the other.

## Interacting with the HDF5 File

The `h5` object provides several ways to interact with the HDF5 file:

### Standard `h5lite` Functions as Methods

Most `h5lite` functions (e.g., `h5_read`, `h5_write`, `h5_ls`) are
available as methods on the `h5` object, without the `h5_` prefix.

For example, `h5$write(data, "dset")` is equivalent to
`h5_write(data, file, "dset")`.

The available methods are: `attr_names`, `cd`, `class`, `close`,
`create_group`, `delete`, `dim`, `exists`, `is_dataset`, `is_group`,
`length`, `ls`, `move`, `names`, `pwd`, `read`, `str`, `typeof`,
`write`.

### Navigation (`$cd()`, `$pwd()`)

The handle maintains an internal working directory to simplify path
management.

- `h5$cd(group)`: Changes the handle's internal working directory. This
  is a stateful, pass-by-reference operation. It understands absolute
  paths (e.g., `"/new/path"`) and relative navigation (e.g.,
  `"../other"`). The target group does not need to exist.

- `h5$pwd()`: Returns the current working directory.

When you call a method like `h5$read("dset")`, the handle automatically
prepends the current working directory to any relative path. If you
provide an absolute path (e.g., `h5$read("/path/to/dset")`), the working
directory is ignored.

### Closing the Handle (`$close()`)

The `h5lite` package does not keep files persistently open. Each
operation opens, modifies, and closes the file. Therefore, the
`h5$close()` method does not perform any action on the HDF5 file itself.

Its purpose is to invalidate the handle, preventing any further
operations from being called. After `h5$close()` is called, any
subsequent method call (e.g., `h5$ls()`) will throw an error.

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Open the handle
h5 <- h5_open(file)

# Write data (note: 'data' is the first argument, 'file' is implicit)
h5$write(1:5, "vector")
h5$write(matrix(1:9, 3, 3), "matrix")

# Create a group and navigate to it
h5$create_group("simulations")
h5$cd("simulations")
print(h5$pwd()) # "/simulations"
#> [1] "/simulations"

# Write data relative to the current working directory
h5$write(rnorm(10), "run1") # Writes to /simulations/run1

# Read data
dat <- h5$read("run1")

# List contents of current WD
h5$ls()
#> [1] "run1"

# Close the handle
h5$close()
unlink(file)
```
