# Getting Started with h5lite

``` r
library(h5lite)

# We'll use a temporary file for this guide.
file <- tempfile(fileext = ".h5")
```

## Introduction

The `h5lite` package provides a simple, lightweight, and user-friendly
interface for reading and writing HDF5 files. It is designed for R users
who want to save and load R objects (vectors, matrices, arrays) to an
HDF5 file without needing to understand the low-level details of the
HDF5 C API.

This guide will walk you through a common use case: simulating
experimental data, saving it to an HDF5 file along with metadata, and
then reading it back for analysis.

### What is an HDF5 File?

Think of an HDF5 file as a self-contained file system. It’s a single
file on disk that can hold an organized hierarchy of your data. The
three most important concepts are:

- **Groups:** These are like folders or directories. You use them to
  organize your data. Groups can contain other groups to create a nested
  structure.
- **Datasets:** These are like files in a file system. A dataset stores
  your actual data, such as a vector, matrix, or multi-dimensional
  array. Every dataset resides inside a group.
- **Attributes:** These are small, named pieces of metadata that you can
  attach to either groups or datasets. They are perfect for storing
  extra information like units, descriptions, or configuration
  parameters.

`h5lite` is designed to make working with this structure feel natural to
an R user.

## 1. Writing Datasets

The primary function for writing data is
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md). It
creates a **dataset** inside the HDF5 file and automatically handles:

- Creating the HDF5 file itself if it doesn’t exist.
- Creating parent **groups** as needed.
- Overwriting any existing dataset at the same path.

Let’s start by writing a matrix of simulated sensor readings to a
dataset.

``` r
# A 3x4 matrix of sensor data
sensor_data <- matrix(rnorm(12, mean = 25, sd = 0.5), nrow = 3, ncol = 4)

h5_write(file, "experiment_1/sensor_readings", sensor_data)
```

That’s it! You’ve just created an HDF5 file and stored a matrix in it.

> **Helpful Tip:** Notice the name `"experiment_1/sensor_readings"`.
> `h5lite` automatically created the group `experiment_1` before
> creating the dataset `sensor_readings` inside it.

### Specifying Data Types

By default (`dtype = "auto"`), `h5lite` automatically chooses the most
space-efficient data type that can safely store your numeric data. For
example, small integers are stored as `int8` or `uint8` instead of
`double` to save space.

You can override this by specifying a `dtype`. Let’s save some integer
identifiers, explicitly telling `h5lite` to use a 32-bit integer type.

``` r
trial_ids <- 1L:12L
h5_write(file, "experiment_1/trial_ids", trial_ids, dtype = "int32")
```

### Writing Scalars

By default, `h5_write` saves single-element vectors as 1-dimensional
arrays. To write a true HDF5 scalar, wrap the value in
[`I()`](https://rdrr.io/r/base/AsIs.html) to treat it “as-is”.

``` r
h5_write(file, "experiment_1/run_id", I("run-abc-123"))
```

## 2. Inspecting the File

Now that we’ve written some data, how do we see what’s in the file?

### Listing Objects

[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md) lists the
objects (groups and datasets) in the file. By default, it lists
everything recursively.

``` r
h5_ls(file)
#> [1] "experiment_1"                 "experiment_1/sensor_readings"
#> [3] "experiment_1/trial_ids"       "experiment_1/run_id"
```

To see only the top-level objects, use `recursive = FALSE`.

``` r
h5_ls(file, recursive = FALSE)
#> [1] "experiment_1"
```

### Getting a Structural Summary

For a more detailed, tree-like view of the file’s contents, similar to
R’s [`str()`](https://rdrr.io/r/utils/str.html) function, use
[`h5_str()`](https://cmmr.github.io/h5lite/reference/h5_str.md). It
recursively prints the structure, showing groups, datasets, dimensions,
and types. This is often the most convenient way to quickly inspect a
file.

``` r
h5_str(file)
#> Listing contents of: /tmp/RtmpHS0J6f/file1c3311e8d87b.h5
#> Root group: /
#> ----------------------------------------------------------------
#> Type            Name
#> ----------------------------------------------------------------
#> Group        experiment_1
#> float64[3,4] experiment_1/sensor_readings
#> int32[12]    experiment_1/trial_ids
#> string       experiment_1/run_id
```

### Checking Dimensions and Types

You can inspect a dataset’s properties without reading all of its data.
This is useful for very large datasets.

- [`h5_dim()`](https://cmmr.github.io/h5lite/reference/h5_dim.md)
  returns the dimensions in R’s standard, column-major order.
- [`h5_typeof()`](https://cmmr.github.io/h5lite/reference/h5_typeof.md)
  returns the underlying HDF5 storage type.

``` r
dim(sensor_data)
#> [1] 3 4
h5_dim(file, "experiment_1/sensor_readings")
#> [1] 3 4

h5_typeof(file, "experiment_1/trial_ids")
#> [1] "int32"
h5_typeof(file, "experiment_1/sensor_readings")
#> [1] "float64"
```

## 3. Reading Data

To read data back into R, use
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md). It
automatically handles transposing the data from HDF5’s row-major order
to R’s column-major order and restores the correct dimensions.

``` r
read_sensor_data <- h5_read(file, "experiment_1/sensor_readings")

print(read_sensor_data)
#>          [,1]     [,2]     [,3]     [,4]
#> [1,] 24.29998 24.99721 24.08909 24.85865
#> [2,] 25.12766 25.31078 24.87634 24.72315
#> [3,] 23.78137 25.57421 24.87790 25.31449

# Verify that the object is identical to the original
all.equal(sensor_data, read_sensor_data)
#> [1] TRUE
```

> **Safety First:** `h5lite` reads all numeric HDF5 types (integers,
> floats, etc.) into R’s `numeric` (double-precision) vectors. This is
> an intentional design choice to prevent integer overflow, a common bug
> when reading data from other systems.

## 4. Working with Metadata (Attributes)

Attributes are small pieces of metadata attached to datasets or groups.
They are perfect for storing things like units, configuration
parameters, or version info.

Let’s add some attributes to our `sensor_readings` dataset.

``` r
# Add a scalar string attribute for units
h5_write_attr(file, "experiment_1/sensor_readings", "units", I("celsius"))

# Add a numeric vector attribute for calibration coefficients
h5_write_attr(file, "experiment_1/sensor_readings", "calibration", c(1.02, -0.5))
```

You can list and read attributes using
[`h5_ls_attr()`](https://cmmr.github.io/h5lite/reference/h5_ls_attr.md)
and
[`h5_read_attr()`](https://cmmr.github.io/h5lite/reference/h5_read_attr.md).

``` r
h5_ls_attr(file, "experiment_1/sensor_readings")
#> [1] "units"       "calibration"

units <- h5_read_attr(file, "experiment_1/sensor_readings", "units")
print(units)
#> [1] "celsius"
```

## 5. Recursive I/O with Lists

For more complex data structures,
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) and
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)
seamlessly save and load nested R `list` objects.

- R `list` objects are written as HDF5 **groups**.
- Attributes on a `list` are saved as attributes on the corresponding
  group.
- All other objects inside the list (vectors, matrices, etc.) are saved
  as **datasets**.

This allows you to perform a “round-trip” for a complex R object,
preserving its structure and metadata.

``` r
# Create a nested list with attributes
my_list <- list(
  config = list(user = "test", version = 1.2),
  data = list(
    matrix = matrix(1:4, 2),
    vector = 1:10
  )
)
attr(my_list$data, "info") <- "This is the data group"
attr(my_list$data$matrix, "my_attr") <- "matrix attribute"

# Write the entire list. This creates a group called "session_data".
h5_write(file, "session_data", my_list, attrs = TRUE)

# Read the group back into a list
read_list <- h5_read(file, "session_data", attrs = TRUE)

# Verify the round-trip was successful
all.equal(my_list, read_list)
#> [1] TRUE
```

> **Helpful Tip:** HDF5 groups do not preserve the creation order of
> their members. When you read a group back with
> [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md), the
> elements in the resulting R `list` will always be sorted
> alphabetically by name. If you need to compare a read list with an
> original list, make sure to sort the original list by name first.

## 6. Handling Special R Types

`h5lite` has special support for some of R’s unique data types.

### Factors

When you write an R `factor`, `h5lite` automatically saves it as a
native HDF5 `enum` type, preserving both the integer values and the
character labels.

``` r
conditions <- as.factor(sample(c("control", "treatment_A", "treatment_B"), 12, replace = TRUE))

h5_write(file, "experiment_1/conditions", conditions)

# Let's check the on-disk type
h5_typeof(file, "experiment_1/conditions")
#> [1] "enum"

# Read it back - it's a perfect match!
read_conditions <- h5_read(file, "experiment_1/conditions")

identical(conditions, read_conditions)
#> [1] TRUE
```

### Raw Data

To store binary data, use an R `raw` vector. This stores the data as a
sequence of bytes.

``` r
binary_blob <- as.raw(c(0xDE, 0xAD, 0xBE, 0xEF))
h5_write(file, "experiment_1/binary_config", binary_blob)

read_blob <- h5_read(file, "experiment_1/binary_config")
identical(binary_blob, read_blob)
#> [1] TRUE
```

## 7. Managing File Contents

### Overwriting

`h5lite` follows an “overwrite-by-default” philosophy. If you write to
an existing path, the old data is replaced.

``` r
h5_read(file, "experiment_1/run_id")
#> [1] "run-abc-123"

# Overwrite with a new value
h5_write(file, "experiment_1/run_id", I("run-xyz-987"))

h5_read(file, "experiment_1/run_id")
#> [1] "run-xyz-987"
```

### Deleting Objects

You can explicitly delete objects (datasets or groups) and attributes.

``` r
# Delete a single dataset
h5_delete(file, "experiment_1/trial_ids")

# Delete an attribute
h5_delete_attr(file, "experiment_1/sensor_readings", "calibration")

# Delete an entire group (and all its contents)
h5_create_group(file, "old_data") # create a dummy group to delete
h5_delete(file, "old_data")

h5_ls(file, recursive = TRUE)
#>  [1] "experiment_1"                 "experiment_1/sensor_readings"
#>  [3] "experiment_1/run_id"          "experiment_1/conditions"     
#>  [5] "experiment_1/binary_config"   "session_data"                
#>  [7] "session_data/config"          "session_data/config/user"    
#>  [9] "session_data/config/version"  "session_data/data"           
#> [11] "session_data/data/matrix"     "session_data/data/vector"
```

``` r
# Clean up the temporary file
unlink(file)
```
