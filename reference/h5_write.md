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

  The target HDF5 data type. Can be one of `"auto"`, `"float16"`,
  `"float32"`, `"float64"`, `"int8"`, `"int16"`, `"int32"`, `"int64"`,
  `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`, or `"skip"`. The
  default, `"auto"`, selects the most space-efficient type for the data.
  See details below.

- compress:

  A logical or an integer from 0-9. If `TRUE`, compression level 5 is
  used. If `FALSE` or `0`, no compression is used. An integer `1-9`
  specifies the zlib compression level directly.

## Value

Invisibly returns `file`. This function is called for its side effects.

## Writing Scalars

By default, `h5_write` saves single-element vectors as 1-dimensional
arrays. To write a true HDF5 scalar, wrap the value in
[`I()`](https://rdrr.io/r/base/AsIs.html) to treat it "as-is." For
example, `h5_write(I(5), file, "x")` will create a scalar dataset, while
`h5_write(5, file, "x")` will create a 1D array of length 1.

## Writing Lists

If `data` is a `list` (but not a `data.frame`), `h5_write` will write it
recursively, creating a corresponding group and dataset structure.

- R `list` objects are created as HDF5 **groups**.

- All other supported R objects (vectors, matrices, arrays, factors,
  `data.frame`s) are written as HDF5 **datasets**.

- Attributes of a list are written as HDF5 attributes on the
  corresponding group.

- Before writing, a "dry run" is performed to validate that all objects
  and attributes within the list are of a writeable type. If any part of
  the structure is invalid, the function will throw an error and no data
  will be written.

## Writing NULL

If `data` is `NULL`, `h5_write` will create an HDF5 **null dataset**.
This is a dataset with a null dataspace, which contains no data.

## Writing Data Frames

`data.frame` objects are written as HDF5 **compound datasets**. This is
a native HDF5 table-like structure that is highly efficient and
portable.

## Writing Complex Numbers

`h5lite` writes R `complex` objects using the native HDF5 `H5T_COMPLEX`
datatype class, which was introduced in HDF5 version 2.0.0. As a result,
HDF5 files containing complex numbers written by `h5lite` can only be
read by other HDF5 tools that support HDF5 version 2.0.0 or later.

## Writing Date-Time Objects

`POSIXt` objects are automatically converted to character strings in ISO
8601 format (`YYYY-MM-DDTHH:MM:SSZ`). This ensures that timestamps are
stored in a human-readable and unambiguous way. This conversion applies
to standalone `POSIXt` objects, as well as to columns within a
`data.frame`.

## Data Type Selection (`as` Argument)

The `as` argument controls the on-disk storage type and only applies to
`integer`, `numeric`, and `logical` vectors. For all other data types
(`character`, `complex`, `factor`, `raw`), the storage type is
determined automatically.

The `as` argument can be one of the following:

- **Global:** A single string, e.g., `"auto"` (default), `"float32"`,
  `"int64"`.

- **Specific:** A named vector mapping names or type classes to HDF5
  types. Matches `h5_read` behavior:

  - `"col_name" = "type"`: Specific dataset/column.

  - `"@attr_name" = "type"`: Specific attached attribute.

  - `".int" = "type"`: Class-based (e.g., .int, .double, .logical).

  - `"." = "type"`: Global default fallback.

If `as` is set to `"auto"` (the default), `h5lite` will automatically
select the most space-efficient HDF5 type based on the following rules:

1.  If the data contains fractional values (e.g., `1.5`), it is stored
    as `float64`.

2.  If the data contains `NA`, `NaN`, or `Inf`, it is stored using the
    smallest floating-point type (`float16`, `float32`, or `float64`)
    that can precisely represent all integer values in the vector.

3.  If the data contains only finite integers (this includes `logical`
    vectors, where `FALSE` is 0 and `TRUE` is 1), `h5lite` selects the
    smallest possible integer type (e.g., `uint8`, `int16`).

4.  If integer values exceed R's safe integer range (`+/- 2^53`), they
    are automatically stored as `float64` to preserve precision.

To override this automatic behavior, you can specify an exact type. The
full list of supported values is:

- `"auto"`, `"skip"`

- `"float16"`, `"float32"`, `"float64"`

- `"int8"`, `"int16"`, `"int32"`, `"int64"`

- `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`

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
h5_write("My Description", file, "data/vector", attr = "description")
h5_write(100, file, "data/vector", attr = "scale_factor")

# 3. Writing Complex Structures (Lists/Groups)
my_list <- list(
  meta = list(id = 1, name = "Experiment A"),
  results = matrix(runif(9), 3, 3),
  valid = TRUE
)
h5_write(my_list, file, "experiment_1")

# 4. Writing Data Frames (Compound Datasets)
df <- data.frame(
  id = 1:5,
  score = c(10.5, 9.2, 8.4, 7.1, 6.0),
  grade = factor(c("A", "A", "B", "C", "D"))
)
h5_write(df, file, "records/scores")

# 5. Controlling Data Types (Compression)
# Store integers as 8-bit unsigned
h5_write(1:5, file, "compressed/small_ints", as = "uint8")

unlink(file)
```
