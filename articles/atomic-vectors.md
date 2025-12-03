# Working with Atomic Vectors

``` r
library(h5lite)

# We'll use a temporary file for this guide.
file <- tempfile(fileext = ".h5")
```

## Introduction

Atomic vectors are the fundamental data structure in R. They are
1-dimensional and all their elements must be of the same type (e.g.,
`numeric`, `character`, `logical`). `h5lite` is designed to make saving
and loading these vectors as simple as possible.

This vignette explores how `h5lite` handles different atomic types, with
a special focus on its automatic data type selection for numeric data
and the distinction between vectors and scalars.

For details on other data structures, see
[`vignette("matrices", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/matrices.md)
and
[`vignette("data-frames", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/data-frames.md).

## 1. Writing and Reading Vectors

The [`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
function is your primary tool for saving data. Let’s write a few
different types of vectors.

``` r
# A simple integer vector
h5_write(file, "trial_ids", 1:10)

# A character vector
h5_write(file, "sample_names", c("A1", "A2", "B1", "B2"))

# A logical vector
h5_write(file, "qc_pass", c(TRUE, TRUE, FALSE, TRUE))
```

You can inspect the contents of the file with
[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md) and
[`h5_str()`](https://cmmr.github.io/h5lite/reference/h5_str.md).

``` r
h5_ls(file)
#> [1] "trial_ids"    "sample_names" "qc_pass"
h5_str(file)
#> Listing contents of: /tmp/Rtmp53KHsP/file1b3b43565691.h5
#> Root group: /
#> ----------------------------------------------------------------
#> Type            Name
#> ----------------------------------------------------------------
#> uint8[10]    trial_ids
#> string[4]    sample_names
#> uint8[4]     qc_pass
```

Reading the data back is just as easy with
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md).

``` r
ids <- h5_read(file, "trial_ids")
print(ids)
#>  [1]  1  2  3  4  5  6  7  8  9 10

qc <- h5_read(file, "qc_pass")
print(qc)
#> [1] 1 1 0 1
```

> **Safety First:** Notice that both the integer and logical vectors
> were read back as R `numeric` (double-precision) vectors. This is an
> intentional design choice to prevent integer overflow, a common bug
> when reading data from other systems where an integer might be larger
> than R’s 32-bit integer limit.

## Handling Scalars

In HDF5, there is a distinction between a **scalar** (a single value
with no dimensions) and a **1D array of length 1**. By default,
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
saves all single-element R vectors as 1D arrays.

To write a true HDF5 scalar, you must wrap the value in
[`I()`](https://rdrr.io/r/base/AsIs.html) to treat it “as-is”.

``` r
# This creates a 1D array of length 1
h5_write(file, "version_array", 1.2)

# This creates a true scalar dataset
h5_write(file, "version_scalar", I(1.2))

# Let's inspect the dimensions
h5_dim(file, "version_array")
#> [1] 1
h5_dim(file, "version_scalar")
#> integer(0)
```

While [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)
will read both of these back into an R vector of length 1, creating true
scalars is a best practice for storing single-value metadata, as it
correctly represents the data’s structure in the file.

## Advanced Details: Automatic Data Type Selection

A key feature of `h5lite` is its automatic and intelligent selection of
on-disk data types for numeric data. This is controlled by the `dtype`
argument in
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) and
[`h5_write_attr()`](https://cmmr.github.io/h5lite/reference/h5_write_attr.md),
which defaults to `"auto"`.

### How `dtype = "auto"` Works

When you write a numeric vector, the C-level function `validate_dtype`
inspects the range of your data and chooses the most space-efficient
HDF5 integer type that can safely represent it.

1.  **Check for Floating-Point Data**: If the vector contains `NA`,
    `NaN`, `Inf`, or any fractional values, it is saved as a `double`
    (`float64`).
2.  **Check for Unsigned Integers**: If all values are non-negative, it
    finds the smallest unsigned integer type that fits.
3.  **Check for Signed Integers**: If the vector contains negative
    values, it finds the smallest signed integer type that fits.

Let’s see this in action.

``` r
# These values fit in an 8-bit unsigned integer (0 to 255)
h5_write(file, "small_unsigned", 0:200)
h5_typeof(file, "small_unsigned")
#> [1] "uint8"

# Adding a negative value requires a signed type
h5_write(file, "small_signed", -100:100)
h5_typeof(file, "small_signed")
#> [1] "int8"

# Larger values require a wider type (e.g., 16-bit)
h5_write(file, "medium_int", 0:30000)
h5_typeof(file, "medium_int")
#> [1] "uint16"

# Fractional values default to double
h5_write(file, "doubles", c(1.1, 2.2))
h5_typeof(file, "doubles")
#> [1] "float64"
```

This behavior helps minimize file size without requiring manual
intervention.

### Overriding Data Types

You can force a specific on-disk type by setting the `dtype` argument.
This is useful for ensuring compatibility with other software that
expects a specific numeric type.

``` r
# Store a vector as 32-bit floating point numbers
h5_write(file, "float_data", c(1.1, 2.2, 3.3), dtype = "float32")
h5_typeof(file, "float_data")
#> [1] "float32"
```

### Technical Mapping of Other R Types

For non-numeric vectors, the mapping is fixed:

- **`character`**: Stored as a variable-length UTF-8 encoded string
  (`H5T_STRING`). This is highly flexible and supports any text.
- **`logical`**: Stored as an 8-bit unsigned integer (`uint8`), where
  `FALSE` is 0 and `TRUE` is 1. HDF5 has no native boolean type, so this
  is a standard convention.
- **`factor`**: Stored as a native HDF5 `enum` type, which preserves
  both the underlying integer values and the character labels. This is
  the most robust way to save factors.
- **`raw`**: Stored as an `opaque` HDF5 type, which is a “black box” of
  bytes. This is ideal for binary data.

## Round-tripping Attributes

R objects can have metadata attached to them as attributes (e.g., the
`names` of a named vector). To preserve these during a write/read cycle,
you must set `attrs = TRUE`. For a more detailed discussion, see
[`vignette("attributes-in-depth", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/attributes-in-depth.md).

``` r
named_vec <- c(a = 1, b = 2, c = 3)
attr(named_vec, "info") <- "My special vector"

# Write without attributes
h5_write(file, "vec_no_attrs", named_vec, attrs = FALSE)
read_no_attrs <- h5_read(file, "vec_no_attrs")
str(read_no_attrs) # Names and info are lost
#>  num [1:3] 1 2 3

# Write WITH attributes
h5_write(file, "vec_with_attrs", named_vec, attrs = TRUE)

# Inspect the HDF5 attributes created
h5_ls_attr(file, "vec_with_attrs")
#> [1] "names" "info"

# Read back with attributes
read_with_attrs <- h5_read(file, "vec_with_attrs", attrs = TRUE)
str(read_with_attrs)
#>  Named num [1:3] 1 2 3
#>  - attr(*, "names")= chr [1:3] "a" "b" "c"
#>  - attr(*, "info")= chr "My special vector"

# Verify the round-trip
all.equal(named_vec, read_with_attrs)
#> [1] TRUE
```

When `attrs = TRUE`, the `get_attributes_to_write` helper function
extracts all R attributes (except `dim`, which is handled by the HDF5
dataspace) and `h5_write_attr` saves them as HDF5 attributes. The
`h5_read` function re-attaches them, ensuring a high-fidelity
round-trip.

``` r
# Clean up the temporary file
unlink(file)
```
