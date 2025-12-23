# Read an HDF5 Object or Attribute

Reads a dataset, a group, or a specific attribute from an HDF5 file into
an R object.

## Usage

``` r
h5_read(file, name = "/", attr = NULL, as = "auto")
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

## Value

An R object corresponding to the HDF5 object or attribute. Returns
`NULL` if the object is skipped via `as = "null"`.

## Note

The `@` prefix is **only** used to configure attached attributes when
reading a dataset (`attr = NULL`). If you are reading a specific
attribute directly (e.g., `h5_read(..., attr = "id")`), do **not** use
the `@` prefix in the `as` argument.

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

# --- Write Data ---
h5_write(c(10L, 20L), file, "ints")
h5_write(I(TRUE),     file, "ints", attr = "ready")
h5_write(c(10.5, 18), file, "floats")
h5_write(I("meters"), file, "floats", attr = "unit")

# --- Read Data ---
# Read dataset
x <- h5_read(file, "ints")
print(x)
#> [1] 10 20
#> attr(,"ready")
#> [1] 1

# Read dataset with attributes
y <- h5_read(file, "floats")
print(attr(y, "unit"))
#> [1] "meters"

# Read a specific attribute directly
unit <- h5_read(file, "floats", attr = "unit")
print(unit)
#> [1] "meters"

# --- Type Conversion Examples ---

# Force integer dataset to be read as numeric (double)
x_dbl <- h5_read(file, "ints", as = "double")
class(x_dbl)
#> [1] "numeric"

# Force attached attribute to be read as logical
# Note the "@" prefix to target the attribute
# h5_read(file, "ints", as = c("@ready" = "logical"))

unlink(file)
```
