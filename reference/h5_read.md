# Read an HDF5 Object or Attribute

Reads a dataset, a group, or a specific attribute from an HDF5 file into
an R object. Supports partial reading (hyperslabs) to load specific
subsets of data.

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

  An integer vector specifying the 1-based starting coordinates for a
  partial read. For example, `start = c(5, 2)` begins reading at the 5th
  row and 2nd column. Must be provided alongside `count`. If `NULL`
  (default), the entire dataset is read.

- count:

  A single integer specifying the number of elements to read. Must be
  provided alongside `start`. If `NULL` (default), the entire dataset is
  read.

## Value

An R object corresponding to the HDF5 object or attribute. Returns
`NULL` if the object is skipped via `as = "null"`.

## Note

The `@` prefix is **only** used to configure attached attributes when
reading a dataset (`attr = NULL`). If you are reading a specific
attribute directly (e.g., `h5_read(..., attr = "id")`), do **not** use
the `@` prefix in the `as` argument.

Partial reading (`start`/`count`) is only supported for datasets, not
attributes.

## Partial Reading (Hyperslabs)

You can read specific subsets of an n-dimensional dataset without
loading the entire object into memory by utilizing the `start` and
`count` arguments.

Both `start` and `count` must be provided together. Coordinates are
1-based and follow standard R array indexing.

The `count` parameter is always a **single integer** and is applied to
the *last* dimension specified in your `start` vector.

- **Example 1:** If you are reading from a 20x5 matrix, calling
  `start = 5` and `count = 3` will start at row 5 and extract 3 complete
  rows (automatically spanning all 5 columns).

- **Example 2:** Calling `start = c(5, 2)` and `count = 3` on the same
  matrix would start at row 5, column 2, and read 3 columns along that
  specific row.

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

m <- matrix(1:100, nrow = 20, ncol = 5)
h5_write(m, file, "matrix_data")

# --- Standard Reading ---
# Read the entire dataset
x <- h5_read(file, "ints")
print(x)
#> [1] 10 20 30 40 50

# --- Partial Reading (Hyperslabs) ---

# 1. Read a subset of a 1D vector
# Starts at the 2nd element and reads 3 elements total (returns 20, 30, 40)
sub_vec <- h5_read(file, "ints", start = 2, count = 3)
print(sub_vec)
#> [1] 20 30 40

# 2. Read complete rows from a Matrix
# Starts at row 5 and reads 3 rows (spanning all columns automatically)
sub_rows <- h5_read(file, "matrix_data", start = 5, count = 3)
print(sub_rows)
#>      [,1] [,2] [,3] [,4] [,5]
#> [1,]    5   25   45   65   85
#> [2,]    6   26   46   66   86
#> [3,]    7   27   47   67   87

# 3. Read a subset within a specific row
# Starts at row 5, column 2, and reads 3 elements along that row
sub_block <- h5_read(file, "matrix_data", start = c(5, 2), count = 3)
print(sub_block)
#>      [,1] [,2] [,3]
#> [1,]   25   45   65

# --- Type Conversion Example ---
# Force integer dataset to be read as numeric (double)
x_dbl <- h5_read(file, "ints", as = "double")
class(x_dbl)
#> [1] "numeric"

unlink(file)
```
