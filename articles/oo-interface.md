# Object-Oriented Interface

``` r
library(h5lite)

# We'll use a temporary file for this guide.
file <- tempfile(fileext = ".h5")
```

## Introduction

While the standard `h5lite` functions
([`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md),
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md),
etc.) are powerful, they require you to pass the `file` path as the
first argument every time. When performing many operations on the same
file, this can become repetitive.

To streamline this workflow, `h5lite` provides an object-oriented (OO)
interface through the
[`h5_open()`](https://cmmr.github.io/h5lite/reference/h5_open.md)
function. This function creates a file **handle**—a special R object
that “remembers” the file path and maintains an internal state, such as
a current working directory.

This vignette provides a comprehensive guide to using the `h5` handle to
make your HDF5 interactions more efficient and expressive.

## 1. Creating a Handle

You create a handle with
[`h5_open()`](https://cmmr.github.io/h5lite/reference/h5_open.md). If
the file doesn’t exist, it will be created for you.

``` r
h <- h5_open(file)
print(h)
#> <h5 handle>
#>   File:  /tmp/RtmpvfEJOf/file285d1d751242.h5 
#>   WD:    / 
#>   Size:  195 bytes 
#>   Objects (root):  0
```

The `h` object is now your gateway to interacting with the HDF5 file.

## 2. Basic Operations as Methods

The primary benefit of the handle is that most `h5lite` functions are
available as **methods** on the handle object, without the `h5_` prefix.
The `file` argument is supplied automatically.

For example, instead of this:

``` r
h5_write(file, "dset1", 1:10)
h5_write(file, "dset2", letters[1:5])
h5_ls(file)
```

You can use the more concise handle-based methods:

``` r
h$write("dset1", 1:10)
h$write("dset2", letters[1:5])
h$ls()
#> [1] "dset1" "dset2"
```

This makes your code cleaner and easier to read, as the context (which
file you’re working on) is established once.

## 3. Navigation (`$cd()` and `$pwd()`)

A powerful feature of the handle is its ability to maintain an internal
“working directory.” This allows you to work with relative paths, which
is extremely useful for organizing complex files.

- `h$pwd()`: **P**rints the **w**orking **d**irectory.
- `h$cd(path)`: **C**hanges the **d**irectory. It understands absolute
  paths (starting with `/`) and relative paths (like `..` for parent).

Let’s create a nested structure and navigate it.

``` r
# Create a group
h$create_group("/data/raw")

# Check our current location (root)
h$pwd()
#> [1] "/"

# Change into the new group
h$cd("/data/raw")
h$pwd()
#> [1] "/data/raw"

# Now, any operation with a relative path is relative to "/data/raw"
h$write("sensor_a", rnorm(10))

# Let's see what's in the file
h$ls(recursive = TRUE)
#> [1] "sensor_a"

# We can navigate up with ".."
h$cd("..")
h$pwd()
#> [1] "/data"
```

## 4. Convenient Subsetting with `[[`

The `h5` handle also supports list-style subsetting with `[[` and `[[<-`
as a convenient shortcut for reading and writing.

### Reading and Writing Datasets

`h[["dset"]]` is a shortcut for `h$read("dset")`, and
`h[["dset"]] <- value` is a shortcut for `h$write("dset", value)`.

``` r
# Write a dataset using subsetting
h[["metadata/run_id"]] <- I("run-123")

# Read it back
run_id <- h[["metadata/run_id"]]
print(run_id)
#> [1] "run-123"
```

### Accessing Attributes with `@`

The `[[` methods have a special, powerful syntax for attribute access:
the `@` symbol. You can separate an object name and an attribute name
with `@` to directly read or write an attribute.

``` r
# Write an attribute to the 'sensor_a' dataset
h[["/data/raw/sensor_a@units"]] <- "volts"

# Read the attribute back
units <- h[["/data/raw/sensor_a@units"]]
print(units)
#> [1] "volts"

# You can even access attributes on the current working directory
h$cd("/data")
h[["@info"]] <- "This is the data group"
h$ls_attr(".")
#> [1] "info"
```

> **Important:** The `@` syntax is a special feature of the `[[` and
> `[[<-` methods **only**. It will not work with the standard `$read()`
> or `$write()` methods. You must use `$read_attr()` and `$write_attr()`
> for those.

## 5. Pass-by-Reference Behavior

Unlike most R objects, the `h5` handle is an **environment**. This means
it exhibits **pass-by-reference** semantics. This is a critical concept
to understand to avoid common mistakes.

When you copy a normal R object, you get an independent copy:

``` r
x <- c(1, 2, 3)
y <- x
y <- 99
print(x) # x is unchanged
#> [1] 1 2 3
```

When you copy an `h5` handle, both variables point to the **exact same
object**. Modifying one will affect the other.

``` r
h1 <- h5_open(file)
h1$cd("/") # Start at root

# This does NOT create a copy. h2 is just another name for h1.
h2 <- h1

# Change the directory using h2
h2$cd("/data")

# The working directory of h1 has also changed!
cat("h1 pwd:", h1$pwd(), "\n")
#> h1 pwd: /data
cat("h2 pwd:", h2$pwd(), "\n")
#> h2 pwd: /data
```

### Common Mistake and The Power

A common mistake is to pass a handle to a function expecting it to be a
copy, only to find the original handle has been modified.

However, this behavior is also very powerful. It allows you to write
helper functions that can modify the state of the handle (e.g., navigate
and write data) without needing to return the handle.

``` r
# A function to log data to a specific group
log_data <- function(handle, sensor_id, data) {
  # This function modifies the handle it receives
  original_wd <- handle$pwd()
  on.exit(handle$cd(original_wd)) # Go back to where we were on exit
  
  handle$cd("/data/raw")
  handle[[sensor_id]] <- data
  handle[[paste0(sensor_id, "@timestamp")]] <- Sys.time()
}

# Use the helper function
log_data(h, "sensor_b", rnorm(5))

# Check the result
h$ls("/data/raw", full.names = TRUE)
#> [1] "/data/raw/sensor_a" "/data/raw/sensor_b"
h$read_attr("/data/raw/sensor_b", "timestamp")
#> [1] "2025-12-09T02:18:20Z"
```

## 6. Closing the Handle

The `h5lite` package does not keep a persistent, open connection to the
HDF5 file. Each operation (read, write, etc.) opens the file, performs
its action, and closes it.

The purpose of the `$close()` method is not to close the file, but to
**invalidate the handle object**. After calling `$close()`, any further
attempt to use the handle will result in an error. This is a safety
mechanism to prevent you from accidentally using a handle that you
thought was “finished.”

``` r
h_to_close <- h5_open(file)
h_to_close$ls()
#> [1] "dset1"                "dset2"                "data"                
#> [4] "data/raw"             "data/raw/sensor_a"    "data/raw/sensor_b"   
#> [7] "data/metadata"        "data/metadata/run_id"

# Invalidate the handle
h_to_close$close()

# This will now throw an error
h_to_close$ls()
#> Error: This h5 file handle has been closed.
```

``` r
# Clean up the temporary file
unlink(file)
```
