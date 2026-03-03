# Read an HDF5 Object or Attribute

Reads a dataset, a group, or a specific attribute from an HDF5 file into
an R object. Supports partial reading (hyperslabs) to load specific
subsets of data without loading the entire object into memory.

## Usage

``` r
h5_read(file, name = "/", attr = NULL, as = "auto", start = NULL, count = NULL)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The full path of the dataset or group to read (e.g.,
  `"/data/matrix"`).

- attr:

  The name of an attribute to read.

  - If `NULL` (default), the function reads the object specified by
    `name` (and attaches its attributes to the result).

  - If provided (string), the function reads *only* the specified
    attribute from `name`.

- as:

  The target R data type.

  - **Global:** `"auto"` (default), `"integer"`, `"double"`,
    `"logical"`, `"bit64"`, `"null"`.

  - **Specific:** A named vector mapping names or type classes to R
    types (see Section "Type Conversion").

- start:

  A numeric vector specifying the 1-based coordinate(s) for a partial
  read. Most often, this is a **single value** targeting the most
  logical structural unit (e.g., the row of a matrix, or the 2D matrix
  of a 3D array). If `NULL` (default), the entire dataset is read.

- count:

  A single numeric value specifying the number of elements or units to
  read. If `NULL` (default) and `start` is provided, `h5lite` reads
  exactly 1 unit and simplifies the resulting dimensions (see Section
  "Dimension Simplification").

## Value

An R object corresponding to the HDF5 object or attribute. Returns
`NULL` if the object is skipped via `as = "null"`.

## Note

The `@` prefix is **only** used to configure attached attributes when
reading a dataset (`attr = NULL`). If you are reading a specific
attribute directly (e.g., `h5_read(..., attr = "id")`), do **not** use
the `@` prefix in the `as` argument.

Partial reading (`start`/`count`) is currently only supported for
datasets, not attributes.

## Partial Reading (Hyperslabs)

You can read specific subsets of an n-dimensional dataset by utilizing
the `start` and `count` arguments.

**The "Smart" `start` Parameter**

`start` is designed to be intuitive. Most of the time, you only need to
provide a single value. This single value automatically targets the most
meaningful dimension of the dataset:

- **1D Vector:** `start` specifies the **element**.

- **2D Matrix / Data Frame:** `start` specifies the **row**.

- **3D Array:** `start` specifies the **2D matrix**.

The `count` parameter is a **single value** that determines how many of
those units to read sequentially. For example, `start = 5` and
`count = 3` on a matrix will read 3 complete rows starting at row 5
(automatically spanning all columns).

**Multi-Value `start` and N-Dimensional Arrays**

If you need to extract a specific block *inside* a structural unit, you
can provide a vector of values to `start`. To make indexing intuitive
across higher-order arrays, `start` maps its values to dimensions in the
following priority order, targeting the outermost blocks first and
specific rows/columns last:

- `N, N-1, ..., 3, 1 (Rows), 2 (Cols)`

For example, on a 3D array, `start = c(2, 5)` targets the 2nd matrix,
and the 5th row. The `count` argument always applies to the **last**
dimension specified in `start`.

**Dimension Simplification (Dropping)**

`h5lite` mimics R's native subsetting behavior regarding dimension
preservation:

- **Exact Indexing (`count = NULL`):** If you provide `start` but omit
  `count`, `h5lite` assumes you are targeting an exact point index. It
  will read 1 unit and **drop** the targeted dimension. (e.g., reading a
  specific row of a matrix will return a 1D vector).

- **Range Indexing (`count` provided):** If you explicitly provide
  `count` (even `count = 1`), `h5lite` assumes you are reading a range.
  The dataset's original structural geometry is **preserved**. (e.g.,
  reading `start = 5, count = 1` on a matrix will return a 1xN matrix).

## Type Conversion (`as`)

You can control how HDF5 data is converted to R types using the `as`
argument.

**1. Mapping by Name:**

- `as = c("data_col" = "integer")`: Reads the dataset/column named
  "data_col" as an integer.

- `as = c("@validated" = "logical")`: When reading a dataset, this
  forces the attached attribute "validated" to be read as logical.

**2. Mapping by HDF5 Type Class:** You can target specific HDF5 data
types using keys prefixed with a dot (`.`). Supported classes include:

- **Integer:** `.int`, `.int8`, `.int16`, `.int32`, `.int64`

- **Unsigned:** `.uint`, `.uint8`, `.uint16`, `.uint32`, `.uint64`

- **Floating Point:** `.float`, `.float16`, `.float32`, `.float64`

Example: `as = c(.uint8 = "logical", .int = "bit64")`

**3. Precedence & Attribute Config:**

- **Attributes vs Datasets:** Attribute type mappings take precedence
  over dataset mappings. If you specify
  `as = c(.uint = "logical", "@.uint" = "integer")`, unsigned integer
  datasets will be read as `logical`, but unsigned integer *attributes*
  will be read as `integer`.

- **Specific vs Generic:** Specific keys (e.g., `.uint32`) take
  precedence over generic keys (e.g., `.uint`), which take precedence
  over the global default (`.`).

## See also

[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# --- Setup: Write Test Data ---
h5_write(c(10L, 20L, 30L, 40L, 50L), file, "ints")

m <- matrix(1:50, nrow = 10, ncol = 5, dimnames = list(paste0("r", 1:10), paste0("c", 1:5)))
h5_write(m, file, "matrix_data")

arr <- array(1:24, dim = c(2, 3, 4))
h5_write(arr, file, "array_data")

# --- Standard Reading ---
# Read the entire dataset
x <- h5_read(file, "ints")

# --- Type Conversion ---
# Force integer dataset to be read as numeric (double)
x_dbl <- h5_read(file, "ints", as = "double")
class(x_dbl)
#> [1] "numeric"

# --- Partial Reading: Single-Value 'start' ---
# Vector: Start at 2nd element, read 3 elements
h5_read(file, "ints", start = 2, count = 3)
#> [1] 20 30 40

# Matrix: Start at row 5, read 3 complete rows (returns 3x5 matrix)
h5_read(file, "matrix_data", start = 5, count = 3)
#>    c1 c2 c3 c4 c5
#> r5  5 15 25 35 45
#> r6  6 16 26 36 46
#> r7  7 17 27 37 47

# 3D Array: Start at 2nd matrix, read 2 complete matrices (returns 2x3x2 array)
h5_read(file, "array_data", start = 2, count = 2)
#> , , 1
#> 
#>      [,1] [,2] [,3]
#> [1,]    7    9   11
#> [2,]    8   10   12
#> 
#> , , 2
#> 
#>      [,1] [,2] [,3]
#> [1,]   13   15   17
#> [2,]   14   16   18
#> 

# --- Partial Reading: Dimension Simplification ---
# Omit 'count' to extract an exact point index and drop the targeted dimension

# Matrix: Extract exactly row 5 (drops row dimension, returns a 1D vector)
h5_read(file, "matrix_data", start = 5)
#> c1 c2 c3 c4 c5 
#>  5 15 25 35 45 

# Matrix: Extract row 5, but preserve matrix structure (returns 1x5 matrix)
h5_read(file, "matrix_data", start = 5, count = 1)
#>    c1 c2 c3 c4 c5
#> r5  5 15 25 35 45

# --- Partial Reading: Multi-Value 'start' ---
# Matrix: Extract exactly row 5, column 2 (drops both dims, returns a scalar)
h5_read(file, "matrix_data", start = c(5, 2))
#> [1] 15

# 3D Array: Target matrix 2, row 1. (drops matrix and row dims, returns 1D vector of cols)
h5_read(file, "array_data", start = c(2, 1))
#> [1]  7  9 11

unlink(file)
```
