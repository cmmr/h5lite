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
[`vignette("matrices")`](https://cmmr.github.io/h5lite/articles/matrices.md)
and
[`vignette("data-frames")`](https://cmmr.github.io/h5lite/articles/data-frames.md).

## 1. General Usage: Writing and Reading Vectors

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
#> Listing contents of: /tmp/RtmpYC0H7c/file1bba532e4c15.h5
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

## 2. Handling Specific R Types

`h5lite` maps R’s atomic types to appropriate HDF5 types. This section
details how each type is handled, including storage details and the
handling of missing values.

### Numeric and Integer Vectors

A key feature of `h5lite` is its intelligent selection of on-disk data
types for numeric data. This is controlled by the `dtype` argument in
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md),
which defaults to `"auto"`.

When `dtype = "auto"`, `h5lite` inspects your data and chooses the most
space-efficient HDF5 integer type that can safely represent it (e.g.,
`uint8`, `int16`). This helps minimize file size without manual
intervention.

``` r
# These values fit in an 8-bit unsigned integer (0 to 255)
h5_write(file, "small_unsigned", 0:200)
h5_typeof(file, "small_unsigned")
#> [1] "uint8"

# Adding a negative value requires a signed type (int8)
h5_write(file, "small_signed", -100:100)
h5_typeof(file, "small_signed")
#> [1] "int8"
```

You can also override this behavior by specifying an exact type, which
is useful for ensuring compatibility with other software.

``` r
# Store a vector as 32-bit floating point numbers
h5_write(file, "float_data", c(1.1, 2.2, 3.3), dtype = "float32")
h5_typeof(file, "float_data")
#> [1] "float32"
```

#### Special Numeric Values (`NA`, `NaN`, `Inf`)

The HDF5 library uses the IEEE 754 standard for floating-point numbers,
which has native representations for `Inf`, `-Inf`, and `NaN` (Not a
Number).

If a numeric or integer vector contains any non-finite value (`NA`,
`NaN`, `Inf`, or `-Inf`), `h5lite` will automatically save the data
using a floating-point type (`double` / `float64`) to ensure these
special values are preserved perfectly. R’s `NA` for numeric types
(`NA_real_`) is a special type of `NaN` and is also restored correctly
on read.

``` r
# A vector containing all special numeric values
special_vals <- c(1, Inf, -Inf, NaN, NA, -1)

# The presence of non-finite values forces the dtype to float64
h5_write(file, "special_vals", special_vals)
h5_typeof(file, "special_vals")
#> [1] "float64"

# Reading the data back restores the values perfectly
read_vals <- h5_read(file, "special_vals")
all.equal(special_vals, read_vals)
#> [1] TRUE
```

### Complex Vectors

In R, `complex` is a distinct atomic type from `numeric`. `h5lite`
stores complex numbers using the native HDF5 `H5T_COMPLEX` type, which
ensures full precision and allows them to be read by other modern HDF5
tools.

Missing values (`NA_complex_`) are preserved perfectly during a
write/read cycle.

``` r
cplx_na <- c(1+1i, NA, 2+2i)
h5_write(file, "cplx_na", cplx_na)
all.equal(cplx_na, h5_read(file, "cplx_na"))
#> [1] TRUE
```

### Character Vectors

Character vectors are stored as variable-length UTF-8 encoded strings
(`H5T_STRING`). This is highly flexible and supports any text. `NA`
values are correctly written as null strings in HDF5 and are read back
as `NA_character_`.

``` r
char_na <- c("a", NA, "c")
h5_write(file, "char_na", char_na)
all.equal(char_na, h5_read(file, "char_na"))
#> [1] TRUE
```

### Logical Vectors

Since HDF5 has no native boolean type, `logical` vectors are handled
similarly to integer vectors to ensure consistent `NA` preservation.

- If a logical vector contains **no `NA` values**, it is stored
  efficiently as an 8-bit unsigned integer (`uint8`), where `FALSE` is 0
  and `TRUE` is 1.
- If a logical vector contains **any `NA` values**, it is automatically
  promoted and written as a `float64` dataset to correctly preserve
  `NA`. This is the same behavior as for integer vectors containing
  `NA`.

This ensures that missing values in logical vectors are handled
consistently with other numeric types.

``` r
# A logical vector with NA
logi_na <- c(TRUE, NA, FALSE)

# The presence of NA forces the dtype to float64
h5_write(file, "logi_na", logi_na)
h5_typeof(file, "logi_na")
#> [1] "float64"

# Reading it back restores the NA correctly
# Note: The result is a numeric vector (1, NA, 0), but is equal to the logical one.
all.equal(logi_na, h5_read(file, "logi_na"))
#> [1] "Modes: logical, numeric"              
#> [2] "target is logical, current is numeric"
```

### Factor Vectors

Factors are stored as a native HDF5 `enum` type, which robustly
preserves both the underlying integer values and the character labels.

However, **`NA` values are not supported for factors.** Attempting to
write a factor containing `NA`s will result in an error. This is because
the underlying integer representation of an `NA` does not match any of
the defined levels in the HDF5 `enum` type. If you need to preserve
`NA`s, you must first convert the factor to a character vector with
[`as.character()`](https://rdrr.io/r/base/character.html).

``` r
# Factor NA will cause an error
factor_na <- factor(c("a", NA, "b"))
h5_write(file, "factor_na", factor_na)
#> Error in h5_write(file, "factor_na", factor_na): Factors with NA values cannot be written to HDF5 Enum types. Convert to character vector first.
```

### Raw Vectors

Raw vectors are stored as an `opaque` HDF5 type, which is a “black box”
of bytes ideal for binary data. The `raw` type in R does not have an
`NA` value.

## 3. Scalars vs. 1D Arrays

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

## 4. Round-tripping Attributes

R objects can have metadata attached to them as attributes (e.g., the
`names` of a named vector). To preserve these during a write/read cycle,
you must set `attrs = TRUE`. For a more detailed discussion, see
[`vignette("attributes-in-depth")`](https://cmmr.github.io/h5lite/articles/attributes-in-depth.md).

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

When `attrs = TRUE`, `h5lite` extracts all R attributes (except `dim`,
which is handled by the HDF5 dataspace) and `h5_write_attr` saves them
as HDF5 attributes. The `h5_read` function re-attaches them, ensuring a
high-fidelity round-trip.

``` r
# Clean up the temporary file
unlink(file)
```
