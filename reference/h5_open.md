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

    h5_write(file, "dset1", 1:10)
    h5_write(file, "dset2", 2:20)
    h5_ls(file)

You can create a handle and use its methods:

    h5 <- h5_open("my_file.h5")
    h5$write("dset1", 1:10)
    h5$write("dset2", 2:20)
    h5$ls()

## Pass-by-Reference Behavior

Unlike most R objects, the `h5` handle is an **environment**. This means
it is passed by reference. If you assign it to another variable (e.g.,
`h5_alias <- h5`), both variables point to the *same* handle. Modifying
one (e.g., by calling `h5_alias$close()`) will also affect the other.

## Interacting with the HDF5 File

The `h5` object provides several ways to interact with the HDF5 file:

### Standard `h5lite` Functions as Methods

Most `h5lite` functions (e.g., `h5_read`, `h5_write`, `h5_ls`) are
available as methods on the `h5` object, without the `h5_` prefix. The
`file` argument is automatically supplied.

For example, `h5$write("dset", data)` is equivalent to
`h5_write(file, "dset", data)`.

The available methods are: `read`, `read_attr`, `write`, `write_attr`,
`class`, `class_attr`, `dim`, `dim_attr`, `exists`, `exists_attr`,
`is_dataset`, `is_group`, `ls`, `ls_attr`, `str`, `typeof`,
`typeof_attr`, `create_file`, `create_group`, `delete`, `delete_attr`,
`move`.

### Navigation (`$cd()`, `$pwd()`)

The handle maintains an internal working directory (`_wd`) to simplify
path management.

- `h5$cd(group)`: Changes the handle's internal working directory. This
  is a stateful, pass-by-reference operation. It understands absolute
  paths (e.g., `"/new/path"`) and relative navigation (e.g.,
  `"../other"`). The target group does not need to exist.

- `h5$pwd()`: Returns the current working directory.

When you call a method like `h5$read("dset")`, the handle automatically
prepends the current working directory to any relative path. If you
provide an absolute path (e.g., `h5$read("/path/to/dset")`), the working
directory is ignored.

### Subsetting with `[[` and `[[<-`

The `h5` handle also supports `[[` for reading and writing, providing a
convenient, list-like syntax.

- **Reading Datasets/Groups:** `h5[["my_dataset"]]` is a shortcut for
  `h5$read("my_dataset")`.

- **Writing Datasets/Groups:** `h5[["my_dataset"]] <- value` is a
  shortcut for `h5$write("my_dataset", value)`.

- **Accessing Attributes:** You can access attributes by separating the
  object name and attribute name with an `@` symbol. For example: -
  `h5[["my_dataset@my_attribute"]]` reads an attribute. -
  `h5[["my_dataset@my_attribute"]] <- "new value"` writes an attribute.

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
h5 <- h5_open(file)

h5$write("a", 1:10)
h5$write("b", c("x", "y"))
h5$ls()
#> [1] "a" "b"

# --- Subsetting for Read/Write ---
h5[["c"]] <- matrix(1:4, 2)
h5[["c@units"]] <- "m/s"
print(h5[["c"]])
#>      [,1] [,2]
#> [1,]    1    3
#> [2,]    2    4
print(h5[["c@units"]])
#> [1] "m/s"

# --- Navigation ---
h5$cd("/g1/g2")
h5$pwd() # "/g1/g2"
#> [1] "/g1/g2"
h5$write("d1", 1:5) # Writes to /g1/g2/d1
h5$cd("..")
h5$ls() # Lists 'g2'
#> [1] "g2"    "g2/d1"

# Write and read using subsetting
h5[["c"]] <- matrix(1:4, 2)
h5[["c@units"]] <- "m/s"
print(h5[["c"]])
#>      [,1] [,2]
#> [1,]    1    3
#> [2,]    2    4
print(h5[["c@units"]])
#> [1] "m/s"


# Invalidate the handle
h5$close()
# try(h5$ls()) # This would now throw an error

unlink(file)
```
