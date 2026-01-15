# Data Types & Compression

`h5lite` is designed to seamlessly map R’s diverse data structures to
HDF5’s portable format. This vignette explains the supported R data
types, how `h5lite` writes them to HDF5, and how you can precisely
control data types and compression when needed.

``` r
library(h5lite)
file <- tempfile(fileext = ".h5")
```

## Supported Data Types

`h5lite` supports reading and writing a wide range of R data types. The
table below lists the default mapping when writing to HDF5.

| R Data Type    | HDF5 Equivalent  | Description                                    |
|:---------------|:-----------------|:-----------------------------------------------|
| **Numeric**    | *variable*       | Selects optimal type: `uint8`, `float32`, etc. |
| **Logical**    | `H5T_STD_U8LE`   | Stored as 0 (FALSE) or 1 (TRUE) (`uint8`).     |
| **Character**  | `H5T_STRING`     | Variable or fixed-length UTF-8 strings.        |
| **Complex**    | `H5T_COMPLEX`    | Native HDF5 2.0+ complex numbers.              |
| **Raw**        | `H5T_OPAQUE`     | Raw bytes / binary data.                       |
| **Factor**     | `H5T_ENUM`       | Integer indices with label mapping.            |
| **integer64**  | `H5T_STD_I64LE`  | 64-bit signed integers via `bit64` package.    |
| **POSIXt**     | `H5T_STRING`     | ISO 8601 string (`YYYY-MM-DDTHH:MM:SSZ`).      |
| **List**       | `H5O_TYPE_GROUP` | Recursive container structure.                 |
| **Data Frame** | `H5T_COMPOUND`   | Table of mixed types.                          |
| **NULL**       | `H5S_NULL`       | Creates a placeholder.                         |

## Dimensions: Scalars, Vectors, and Arrays

Atomic data types (Integer, integer64, Double, Logical, Character,
Complex, Raw, and POSIXt) can be written to HDF5 as scalars, 1D vectors,
or N-dimensional arrays.

- **Scalars:** To write a single value as a true HDF5 scalar (0
  dimensions), you must wrap the value in
  [`I()`](https://rdrr.io/r/base/AsIs.html).
- **Vectors:** Standard R vectors are written as 1D arrays (Simple
  Dataspace with rank 1).
- **Arrays/Matrices:** R objects with `dim` attributes are written as
  N-dimensional datasets, preserving their shape.

``` r
# 1. Scalar (0 dims)
h5_write(I(42), file, "structure/scalar")

# 2. Vector (1 dim)
h5_write(c(1, 2, 3), file, "structure/vector")

# 3. Matrix (2 dims)
h5_write(matrix(1:9, 3, 3), file, "structure/matrix")
```

*For more complex dimensional structures, refer to
[`vignette('matrices')`](https://cmmr.github.io/h5lite/articles/matrices.md).*

## Numeric Data

R uses 32-bit integers and 64-bit doubles. When writing with
`as = "auto"`, `h5lite` analyzes the range of your data to select the
most compact HDF5 type.

- **Default:** Selects optimal type based on range of values.
- **With NA:** `float64` (`H5T_IEEE_F64LE`)
- **Fractional Values:** Double-precision vectors with fractional values
  default to `float64`.
- **Coercion:** You can override this using `int[8|16|32|64]`,
  `uint[8|16|32|64]`, `float[16|32|64]`, or `bfloat16`.

``` r
# Standard integers -> int32
h5_write(c(1L, 2L, 3L), file, "integers/clean")

# Integers with NA -> float64
h5_write(c(1L, NA, 3L), file, "integers/with_na")

# Force smaller type (int16)
h5_write(1:100, file, "integers/short", as = "int16")
```

## 64-bit Integers (`integer64`)

- **Default:** `int64` (`H5T_STD_I64LE`)
- **Coercion:** none

R does not natively support 64-bit integers, but `h5lite` supports
reading and writing them via the `bit64` package.

``` r
if (requireNamespace("bit64", quietly = TRUE)) {
  val <- bit64::as.integer64(c("9223372036854775807", "-9223372036854775807"))
  h5_write(val, file, "integers/int64")
}
```

## Double (Numeric) Data

R’s default numeric type is double-precision.

- **Default:** `float64` (`H5T_IEEE_F64LE`)
- **Coercion:** `int[8|16|32|64]`, `uint[8|16|32|64]`,
  `float[16|32|64]`, or `bfloat16`

``` r
data <- rnorm(10)

# Default (float64)
h5_write(data, file, "doubles/default")

# Single Precision (float32) - Saves 50% space
h5_write(data, file, "doubles/float32", as = "float32")
```

## Logical Data

- **Default:** `uint8` (`H5T_STD_U8LE`)
- **With NA:** `float64` (`H5T_IEEE_F64LE`)
- **Coercion:** `int[8|16|32|64]`, `uint[8|16|32|64]`,
  `float[16|32|64]`, or `bfloat16`

``` r
bools <- sample(c(TRUE, FALSE), 1000, replace = TRUE)

h5_write(bools, file, "logicals/packed")
```

HDF5 supports two methods for storing strings. By default
(`as = "auto"`), `h5lite` chooses the best approach:

- **Variable-Length:** Used if the vector contains `NA` or if string
  lengths are highly inconsistent.
- **Fixed-Length:** Used for short, consistent strings without `NA` to
  allow for compression.

### **Variable-Length:**

Explicitly requested with `as = "utf8"` or `as = "ascii"`.

- Compressible: **NO**
- Handles `NA`: **YES**

``` r
# UTF-8 variable length
h5_write(c("apple", "banana", NA), file, "strings/var_utf8")

# ASCII variable length
h5_write(c("A", "B", "C", NA), file, "strings/var_ascii", as = "ascii")
```

### **Fixed-Length:**

Use `as = "ascii[10]"`/`as = "utf8[10]"` (explicit size=10) or
`as = "ascii[]"`/`as = "utf8[]"` (auto-detect max length).

- Compressible: **YES**
- Handles `NA`: **NO**

``` r
# UTF-8 auto-detected fixed length
h5_write(c("apple", "banana"), file, "strings/fixed_utf8", as = "utf8[]")

# ASCII fixed length (1 byte)
h5_write(c("A", "B", "C"), file, "strings/fixed_ascii", as = "ascii[1]")
```

> **Technical Note:** `h5lite` uses `H5T_C_S1` for all strings, and
> `H5T_STR_NULLTERM` for all fixed length strings.

## Dates and Times (`POSIXt`)

R date-time objects (`POSIXct` / `POSIXlt`) are stored as **Strings** in
ISO 8601 format (`YYYY-MM-DDTHH:MM:SSZ`). This ensures maximum
portability with other languages and HDF5 tools that do not share R’s
specific epoch-based integer representation.

``` r
now <- Sys.time()
h5_write(now, file, "datetime/iso8601")
```

## Complex Data

R complex numbers are written using the new complex floating-point type
introduced in HDF5 2.0.0 (`H5T_COMPLEX_IEEE_F64LE`).

**Compatibility Warning:** This data type for complex numbers is a
feature specific to HDF5 version 2.0+. Datasets written with this type
generally cannot be read by HDF5 readers built against older versions of
the library (e.g., HDF5 1.10 or 1.12). Ensure that any downstream tools
or libraries used to read these files are updated to support HDF5 2.0
standards.

``` r
comp <- c(1+2i, 3+4i)
h5_write(comp, file, "complex_data")
```

## Raw Data

Raw vectors (bytes) are stored as HDF5 `OPAQUE` types. This is ideal for
storing binary blobs, images, or serialized objects where you need to
preserve the exact byte sequence without interpretation.

``` r
raw_vec <- as.raw(c(0x01, 0xFF, 0x1A))
h5_write(raw_vec, file, "binary_blob")
```

## Factors

R Factors are stored as HDF5 `ENUM` types. This maps the integer codes
to the factor levels (labels) efficiently within the file header,
ensuring the labels are preserved without duplicating string data for
every element.

``` r
fac <- factor(c("low", "high", "medium", "low"))
h5_write(fac, file, "categorical")
```

## Lists

R lists are mapped to HDF5 **Groups**. Since lists are recursive
containers, `h5lite` walks the list and creates a dataset (or subgroup)
for every element found. You can use `as = c("element_name" = "skip")`
to exclude specific items.

``` r
my_list <- list(data = 1:100, meta = list(valid = TRUE))
h5_write(my_list, file, "types/list")
```

## Data Frames

Data Frames are stored as HDF5 **Compound** types (tables). This ensures
that rows are kept together in memory. You can use the `as` argument to
specify the type of individual columns.

*For a comprehensive guide, see
[`vignette('data-frames')`](https://cmmr.github.io/h5lite/articles/data-frames.md).*

``` r
df <- data.frame(
  id = 1:5,
  score = c(10.5, 20.2, 15.0, 9.8, 30.1)
)

# 1. 'id' coerced to uint16
# 2. 'score' coerced to float32
h5_write(df, file, "types/dataframe", as = c(
  "id"    = "uint16",
  "score" = "float32"
))
```

## NULL

The `NULL` object in R is mapped to a dataset with a **NULL Dataspace**
(`H5S_NULL`). This creates a dataset that exists in the file structure
but contains no data elements and consumes no storage space.

``` r
h5_write(NULL, file, "placeholders/empty_slot")
```

## Compression

HDF5 supports transparent data compression using the zlib (deflate)
algorithm. You can control the compression intensity using the
`compress` argument.

- **`TRUE`**: Enables standard compression (Level 5).
- **`FALSE` / `0`**: Disables compression.
- **`1` - `9`**: Specific compression level (1 = fastest, 9 = most
  compressed).

``` r
# Maximum compression
h5_write(rnorm(1000), file, "data/max", compress = 9)
```

### The Shuffle Filter

When compression is enabled (level \> 0), `h5lite` automatically applies
the HDF5 **Byte Shuffle Filter** before the data is compressed. The
Shuffle Filter does not compress data itself; rather, it rearranges the
byte stream to make it more compressible by zlib.

It works by separating the bytes of each value by their significance.
For example, in a 4-byte integer array:

1.  All the 1st bytes (least significant) are grouped together.
2.  All the 2nd bytes are grouped together.
3.  And so on.

**Why this helps:** \* **Integers:** Small integers often have many
zero-padding bytes. The shuffle filter groups these zeros into long
runs, which zlib compresses extremely efficiently. This allows `int32`
data to compress nearly as well as `int8` data if the values are small.
\* **Doubles:** Floating point numbers often share the same exponent
bytes if they are in a similar range. The shuffle filter groups these
identical exponent bytes, creating repetitive patterns that zlib can
compress.
