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

  The R object to write. Supported: `numeric`, `integer`, `complex`,
  `logical`, `character`, `factor`, `raw`, `matrix`, `data.frame`,
  `NULL`, and nested `list`s.

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
  `"int64"`, `"bfloat16"`, `"utf8[n]"`, etc.) and how to map specific
  columns.

- compress:

  Compression configuration.

  - `TRUE` (default): Enables compression (zlib level 5).

  - `FALSE` or `0`: Disables compression.

  - Integer `1-9`: Specifies the zlib compression level.

## Value

Invisibly returns `file`. This function is called for its side effects.

## Data Type Selection (`as` Argument)

The `as` argument controls the on-disk storage type for integer, double,
logical, and character columns.

**1. Available Types**

- **Floating Point:** `"float16"`, `"float32"`, `"float64"`,
  `"bfloat16"`

- **Signed Integer:** `"int8"`, `"int16"`, `"int32"`, `"int64"`

- **Unsigned Integer:** `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`

- **Variable Length Strings:** `"utf8"`, `"ascii"`

- **Fixed Length Strings:**

  - `"utf8[]"` or `"ascii[]"` (auto-detects the longest string in the
    data)

  - `"utf8[n]"` or `"ascii[n]"` (where `n` is the length in bytes, e.g.,
    `"utf8[10]"`)

- **Other:** `"auto"`, `"skip"` (to skip a column/attribute of any R
  type)

*Strings:* Variable-length strings allow for `NA` values (via NULL
pointers) but cannot be compressed. Fixed-length strings allow for
compression but do not support `NA`.

**2. Automatic Selection (`as = "auto"`)**

|              |                          |                                               |
|--------------|--------------------------|-----------------------------------------------|
| **R Type**   | **HDF5 Type**            | **Notes**                                     |
| `integer`    | `H5T_STD_I32LE`          |                                               |
| `double`     | `H5T_IEEE_F64LE`         |                                               |
| `logical`    | `H5T_STD_U8LE`           | 1-bit storage efficiency.                     |
| `character`  | `H5T_C_S1`               | `H5T_CSET_UTF8 H5T_VARIABLE H5T_STR_NULLTERM` |
| `factor`     | `H5T_ENUM`               | Maps levels to integers.                      |
| `data.frame` | `H5T_COMPOUND`           | Native table-like structure.                  |
| `list`       | `H5O_TYPE_GROUP`         | Written to HDF5 recursively.                  |
| `complex`    | `H5T_COMPLEX_IEEE_F64LE` | Requires HDF5 \>= 2.0.0.                      |
| `raw`        | `H5T_OPAQUE`             | For binary data storage.                      |
| `NULL`       | `H5S_NULL`               | Null Dataspace                                |
| `integer64`  | `H5T_STD_I64LE`          | From the `bit64` R package.                   |
| `POSIXt`     | `H5T_C_S1`               | ISO 8601 string (`YYYY-MM-DDTHH:MM:SSZ`)      |

*NA Handling:* HDF5 integers do not support `NA`. If an R integer or
logical vector contains `NA`, `h5lite` automatically promotes it to
`float64` to preserve the `NA` value.

**3. Column/Class Mapping**

You can provide a named vector to map specific columns or classes:

- **Specific Name:** `"col_name" = "type"` (e.g.,
  `c(score = "float32")`)

- **Specific Attribute:** `"@attr_name" = "type"`

- **Class-based:** `".integer" = "type"`, `".numeric" = "type"`

- **Class-based Attribute:** `"@.character" = "type"`,
  `"@.logical" = "type"`

- **Global Fallback:** `"." = "type"`

- **Global Attribute Fallback:** `"@." = "type"`

*Numeric Class:* `".numeric"` targets both `integer` and `double` with a
lower priority than `".integer"` and `".double"`.

## Writing Scalars

By default, `h5_write` saves single-element vectors as 1-dimensional
arrays. To write a true HDF5 scalar, wrap the value in
[`I()`](https://rdrr.io/r/base/AsIs.html) to treat it "as-is." For
example, `h5_write(I(5), file, "x")` will create a scalar dataset, while
`h5_write(5, file, "x")` will create a 1D array of length 1.

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
# Store integers as 8-bit unsigned
h5_write(1:5, file, "compressed/small_ints", as = "uint8")

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
#> ├── data
#> │   ├── integers <int32 × 10>
#> │   ├── floats <float64 × 10>
#> │   ├── chars <utf8 × 5>
#> │   └── vector <int32 × 10>
#> │       ├── @description <utf8 scalar>
#> │       └── @scale_factor <float64 scalar>
#> ├── compressed
#> │   └── small_ints <uint8 × 5>
#> ├── experiment_1
#> │   ├── meta
#> │   │   ├── id <uint16 × 1>
#> │   │   └── name <utf8 × 1>
#> │   ├── results <float64 × 3 × 3>
#> │   └── valid <int scalar>
#> ├── fixed_str <ascii[10] × 2>
#> └── records
#>     └── scores <compound × 5 × 3>

# 8. Clean up
unlink(file)
```
