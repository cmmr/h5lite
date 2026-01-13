# Atomic Vectors

Atomic vectors are the fundamental data structure in R. They include
**numeric** (integer and double), **logical**, **character**,
**complex**, and **raw** vectors. This vignette explains how `h5lite`
maps these R types to HDF5 datasets and provides guidance on controlling
storage types and compression.

``` r
library(h5lite)
file <- tempfile(fileext = ".h5")
```

## Basic Usage

Writing a vector to HDF5 is straightforward using
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md). The
package automatically creates the necessary dataset and handles
dimensions.

``` r
# Write a numeric vector
vec <- c(1.5, 2.3, 4.2, 5.1)
h5_write(vec, file, "data/numeric_vector")

# Read it back
res <- h5_read(file, "data/numeric_vector")
print(res)
#> [1] 1.5 2.3 4.2 5.1
```

## Scalars vs. 1D Arrays

In R, a “scalar” is simply a vector of length 1. However, HDF5
distinguishes between a **Scalar Dataspace** (a single value with no
dimensions) and a **Simple Dataspace** (an array) with dimensions `[1]`.

By default, `h5lite` treats length-1 vectors as 1D arrays to maintain
consistency with R’s vector behavior. To write a true HDF5 scalar, you
must wrap the value in [`I()`](https://rdrr.io/r/base/AsIs.html).

``` r
# 1. Default: 1D Array (Length 1)
h5_write(42, file, "structure/array_1d")

# 2. Explicit Scalar: Wrapped in I()
h5_write(I(42), file, "structure/scalar")

h5_str(file, "structure")
```

``` fansi
#> structure/
#> ├── array_1d <uint8 × 1>
#> └── scalar <uint8 scalar>
```

*Note: When reading data back into R, both storage formats appear as
standard R vectors of length 1.*

## Numeric and Logical Data

### Automatic Type Selection

`h5lite` attempts to map R types to the most efficient HDF5 equivalents
automatically (`as = "auto"`).

1.  **Numeric:** `h5lite` analyzes the range of your data and picks the
    smallest fitting HDF5 type (e.g., `uint8`, `int16`, `int32`,
    `float64`).
2.  **Logicals:** `h5lite` maps these to `uint8` (0 or 1) in HDF5 to
    save space.

### Handling Missing Values (NA)

A key challenge in HDF5 is that standard integer and boolean types do
not have a native representation for `NA` (missing values).

To ensure data safety, `h5lite` performs the following check:

- If an integer or logical vector contains `NA`, it is **automatically
  promoted to `float64`**.
- The `NA` values are stored as an `NaN` variant in the file.
- When read back,
  [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)
  restores them as `numeric` vectors with `NA`.

``` r
# Integer vector with NO missing values -> Automatic optimal type (uint8)
h5_write(c(1L, 2L, 3L), file, "safe/ints")
h5_typeof(file, "safe/ints")
#> [1] "uint8"

# Integer vector WITH missing values -> Promoted to float64
h5_write(c(1L, NA, 3L), file, "safe/ints_na")
h5_typeof(file, "safe/ints_na")
#> [1] "float64"
```

### Forcing Specific Types

If you know your data range fits into a smaller type (e.g., `int8`,
`uint16`), you can use the `as` argument to force a specific storage
type.

*Warning: If you force an integer type on data containing `NA` or values
outside the integer type’s range then `h5lite` will throw an error.*

``` r
# Store small integers as 8-bit signed integers
h5_write(c(10, -5, 100), file, "small_ints", as = "int8")

# Store logicals as 8-bit unsigned integers
h5_write(c(TRUE, FALSE), file, "bools", as = "uint8")
```

## Character Vectors (Strings)

HDF5 supports two primary methods for storing strings:
**Variable-Length** and **Fixed-Length**.

### Automatic Type Selection

By default (`as = "auto"`), `h5lite` chooses the most efficient string
representation:

- If the vector contains `NA`, it uses **Variable-Length UTF-8** (which
  natively supports missing values).
- If there are no missing values and the strings are relatively short
  and consistent in length, it uses **Fixed-Length UTF-8** to allow for
  compression and faster access.

### Variable-Length

You can explicitly request variable-length storage using `as = "utf8"`
or `as = "ascii"`.

- **Pros:** Most flexible; exact memory usage per string; supports `NA`
  (stored as NULL pointers).
- **Cons:** Cannot be compressed using standard HDF5 filters; slower to
  read/write for extreme dataset sizes.

``` r
# Variable length strings (handles NA)
h5_write(c("apple", "banana", NA), file, "strings/var")
```

### Fixed-Length

You can force fixed-length storage using the syntax `[n]`, where `n` is
the number of bytes.

- **Pros:** Fast; allows compression.
- **Cons:** Truncates strings longer than `n`; pads shorter strings;
  **does not support `NA`**.

``` r
# Fixed length strings (10 bytes per string)
h5_write(c("A", "B", "C"), file, "strings/fixed", as = "ascii[10]")

# Auto-detect max length (converts to fixed length based on longest string)
h5_write(c("short", "longer", "longest"), file, "strings/auto_fixed", as = "ascii[]")
```

## Compression

Compression in HDF5 requires the dataset to be “chunked”. `h5lite`
handles chunking parameters automatically when you enable compression.

You can enable compression using the `compress` argument:

- `compress = TRUE` (default): Uses zlib (deflate) level 5.
- `compress = 9`: Uses zlib level 9 (max compression, slower).

``` r
# Write a large vector with compression
x <- rep(rnorm(100), 100)
h5_write(x, file, "compressed_data", compress = TRUE)
```

## 64-bit Integers

R does not natively support 64-bit integers, but the `bit64` package
provides an `integer64` class. `h5lite` supports reading and writing
these types directly to HDF5 `int64`.

``` r
if (requireNamespace("bit64", quietly = TRUE)) {
  val <- bit64::as.integer64(c("9223372036854775807", "-9223372036854775807"))
  
  h5_write(val, file, "huge_ints")
  
  in_val <- h5_read(file, "huge_ints")
  print(class(in_val))
}
#> [1] "numeric"
```
