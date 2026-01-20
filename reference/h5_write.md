# Write an R Object to HDF5

Writes an R object to an HDF5 file, creating the file if it does not
exist. This function acts as a unified writer for datasets, groups
(lists), and attributes.

## Usage

``` r
h5_write(data, file, name, attr = NULL, as = "auto", compress = TRUE)
```

## Arguments

- data:

  The R object to write. Supported: `numeric`, `complex`, `logical`,
  `character`, `factor`, `raw`, `matrix`, `data.frame`, `integer64`,
  `POSIXt`, `NULL`, and nested `list`s.

- file:

  The path to the HDF5 file.

- name:

  The name of the dataset or group to write (e.g., "/data/matrix").

- attr:

  The name of an attribute to write.

  - If `NULL` (default), `data` is written as a dataset or group at the
    path `name`.

  - If provided (string), `data` is written as an attribute named `attr`
    attached to the object `name`.

- as:

  The target HDF5 data type. Defaults to `"auto"`. See the **Data Type
  Selection** section for a full list of valid options (including
  `"int64"`, `"bfloat16"`, `"utf8[n]"`, etc.) and how to map
  sub-components of `data`.

- compress:

  Compression configuration.

  - `TRUE` (default): Enables compression (zlib level 5).

  - `FALSE` or `0`: Disables compression.

  - Integer `1-9`: Specifies the zlib compression level.

## Value

Invisibly returns `file`. This function is called for its side effects.

## Writing Scalars

By default, `h5_write` saves single-element vectors as 1-dimensional
arrays. To write a true HDF5 scalar, wrap the value in
[`I()`](https://rdrr.io/r/base/AsIs.html) to treat it "as-is."

### Examples

    h5_write(I(5), file, "x") # Creates a scalar dataset
    h5_write(5, file, "x")    # Creates a 1D array of length 1

## Data Type Selection (`as` Argument)

By default, `as = "auto"` will automatically select the most appropriate
data type for the given object. For numeric types, this will be the
smallest type that can represent all values in the vector. For character
types, `h5lite` will use a ragged vs rectangular heuristic, favoring
small file size over fast I/O. For R data types not mentioned below, see
[`vignette("data-types")`](https://cmmr.github.io/h5lite/articles/data-types.md)
for information on their fixed mappings to HDF5 data types.

### Numeric and Logical Vectors

When writing a numeric or logical vector, you can specify one of the
following storage types for it:

- **Floating Point:** `"float16"`, `"float32"`, `"float64"`,
  `"bfloat16"`

- **Signed Integer:** `"int8"`, `"int16"`, `"int32"`, `"int64"`

- **Unsigned Integer:** `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`

**NOTE:** `NA` values must be stored as `float64`. `NaN`, `Inf`, and
`-Inf` must be stored as a floating point type.

#### Examples

    h5_write(1:100, file, "big_ints", as = "int64")
    h5_write(TRUE,  file, "my_bool",  as = "float32")

### Character Vectors

You can control whether character vectors are stored as variable or
fixed length strings, and whether to use UTF-8 or ASCII encoding.

- **Variable Length Strings:** `"utf8"`, `"ascii"`

- **Fixed Length Strings:**

  - `"utf8[]"` or `"ascii[]"` (length is set to the longest string)

  - `"utf8[n]"` or `"ascii[n]"` (where `n` is the length in bytes)

**NOTE:** Variable-length strings allow for `NA` values but cannot be
compressed on disk. Fixed-length strings allow for compression but do
not support `NA`.

#### Examples

    h5_write(letters[1:5],    file, "len10_strs", as = "utf8[10]")
    h5_write(c('X', 'Y', NA), file, "var_chars",  as = "ascii")

### Lists, Data Frames, and Attributes

Provide a named vector to apply type mappings to sub-components of
`data`. Set `"skip"` as the type to skip a specific component.

- **Specific Name:** `"col_name" = "type"` (e.g.,
  `c(score = "float32")`)

- **Specific Attribute:** `"@attr_name" = "type"`

- **Class-based:** `".integer" = "type"`, `".numeric" = "type"`

- **Class-based Attribute:** `"@.character" = "type"`,
  `"@.logical" = "type"`

- **Global Fallback:** `"." = "type"`

- **Global Attribute Fallback:** `"@." = "type"`

#### Examples

    # To strip attributes when writing:
    h5_write(data, file, 'no_attrs_obj', as = c('@.' = "skip"))

    # To only save the `hp` and `wt` columns:
    h5_write(mtcars, file, 'my_df', as = c('hp' = "auto", 'wt' = "float32", '.' = "skip"))

## Dimension Scales

`h5lite` automatically writes `names`, `row.names`, and `dimnames` as
HDF5 dimension scales. Named vectors will generate an `<name>_names`
dataset. A data.frame with row names will generate an `<name>_rownames`
dataset (column names are saved internally in the original dataset).
Matrices will generate `<name>_rownames` and `<name>_colnames` datasets.
Arrays will generate `<name>_dimscale_1`, `<name>_dimscale_2`, etc.
Special HDF5 metadata attributes link the dimension scales to the
dataset. The dimension scales can be relocated with
[`h5_move()`](https://cmmr.github.io/h5lite/reference/h5_move.md)
without breaking the link.

## See also

[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# 1. Writing Basic Datasets
h5_write(1:10, file, "data/integers")
h5_write(rnorm(10), file, "data/floats")
h5_write(letters[1:5], file, "data/chars")

# 2. Writing Attributes
# Write an object first
h5_write(1:10, file, "data/vector")
# Attach an attribute to it using the 'attr' parameter
h5_write(I("My Description"), file, "data/vector", attr = "description")
h5_write(I(100), file, "data/vector", attr = "scale_factor")

# 3. Controlling Data Types
# Store values as 32-bit signed integers
h5_write(1:5, file, "small_ints", as = "int32")

# 4. Writing Complex Structures (Lists/Groups)
my_list <- list(
  meta    = list(id = 1, name = "Experiment A"),
  results = matrix(runif(9), 3, 3),
  valid   = I(TRUE)
)
h5_write(my_list, file, "experiment_1", as = c(id = "uint16"))

# 5. Writing Data Frames (Compound Datasets)
df <- data.frame(
  id    = 1:5,
  score = c(10.5, 9.2, 8.4, 7.1, 6.0),
  grade = factor(c("A", "A", "B", "C", "D"))
)
h5_write(df, file, "records/scores", as = c(grade = "ascii[1]"))

# 6. Fixed-Length Strings
h5_write(c("A", "B"), file, "fixed_str", as = "ascii[10]")

# 7. Review the file structure
h5_str(file)
#> /
#> ├── data/
#> │   ├── integers <uint8 × 10>
#> │   ├── floats <float64 × 10>
#> │   ├── chars <utf8[1] × 5>
#> │   └── vector <uint8 × 10>
#> │       ├── @description <utf8[14] scalar>
#> │       └── @scale_factor <uint8 scalar>
#> ├── small_ints <int32 × 5>
#> ├── experiment_1/
#> │   ├── meta/
#> │   │   ├── id <uint16 × 1>
#> │   │   └── name <utf8[12] × 1>
#> │   ├── results <float64 × 3 × 3>
#> │   └── valid <uint8 scalar>
#> ├── records/
#> │   └── scores <compound[3] × 5>
#> │       ├── $id <uint8>
#> │       ├── $score <float64>
#> │       └── $grade <enum>
#> └── fixed_str <ascii[10] × 2>

# 8. Clean up
unlink(file)
```
