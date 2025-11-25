# Write an R Object to HDF5

Writes an R object to an HDF5 file, creating the file if it does not
exist. This function can write atomic vectors, matrices, arrays,
factors, `data.frame`s, and nested `list`s.

## Usage

``` r
h5_write(file, name, data, dtype = "auto", compress = TRUE, attrs = FALSE)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the dataset (e.g., "/data/matrix").

- data:

  The R object to write. Supported: `numeric`, `integer`, `logical`,
  `character`, `factor`, `raw`, `data.frame`, `NULL`, and nested
  `list`s.

- dtype:

  The target HDF5 data type. See details.

- compress:

  A logical or an integer from 0-9. If `TRUE`, compression level 5 is
  used. If `FALSE` or `0`, no compression is used. An integer `1-9`
  specifies the zlib compression level directly.

- attrs:

  Controls which R attributes of `data` are written to the HDF5 object.
  Can be `FALSE` (the default), `TRUE` (all attributes except `dim`), a
  character vector of attribute names to include (e.g.,
  `c("info", "version")`), or a character vector of names to exclude,
  prefixed with `-` (e.g., `c("-class")`).

## Value

Invisibly returns `file`. This function is called for its side effects.

## Writing Scalars

By default, `h5_write` saves single-element vectors as 1-dimensional
arrays. To write a true HDF5 scalar, wrap the value in
[`I()`](https://rdrr.io/r/base/AsIs.html) to treat it "as-is." For
example, `h5_write(file, "x", I(5))` will create a scalar dataset, while
`h5_write(file, "x", 5)` will create a 1D array of length 1.

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

## Data Type Selection (`dtype`)

The `dtype` argument controls the on-disk storage type **for numeric
data only**.

If `dtype` is set to `"auto"` (the default), `h5lite` will automatically
select the most space-efficient HDF5 type for numeric data that can
safely represent the full range of values. For example, writing `1:100`
will result in an 8-bit unsigned integer (`uint8`) dataset, which helps
minimize file size.

To override this behavior, you can specify an exact type. The input is
case-insensitive and allows for unambiguous partial matching. The full
list of supported values is:

- `"auto"`, `"float"`, `"double"`

- `"float16"`, `"float32"`, `"float64"`

- `"int8"`, `"int16"`, `"int32"`, `"int64"`

- `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`

- `"char"`, `"short"`, `"int"`, `"long"`, `"llong"`

- `"uchar"`, `"ushort"`, `"uint"`, `"ulong"`, `"ullong"`

Note: Types without a bit-width suffix (e.g., `"int"`, `"long"`) are
system- dependent and may have different sizes on different machines.
For maximum file portability, it is recommended to use types with
explicit bit-widths (e.g., `"int32"`).

For non-numeric data (`character`, `factor`, `raw`, `logical`), the
storage type is determined automatically and **cannot be changed** by
the `dtype` argument. R `logical` vectors are stored as 8-bit unsigned
integers (`uint8`), as HDF5 does not have a native boolean datatype.

## Attribute Round-tripping

To properly round-trip an R object, it is helpful to set `attrs = TRUE`.
This preserves important R metadata—such as the `names` of a named
vector, `row.names` of a `data.frame`, or the `class` of an object—as
HDF5 attributes.

**Limitation**: HDF5 has no direct analog for R's `dimnames`. Attempting
to write an object that has `dimnames` (e.g., a named matrix) with
`attrs = TRUE` will result in an error. You must either remove the
`dimnames` or set `attrs = FALSE`.

## See also

[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md),
[`h5_write_attr()`](https://cmmr.github.io/h5lite/reference/h5_write_attr.md),
[`vignette("atomic-vectors", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/atomic-vectors.md),
[`vignette("matrices", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/matrices.md),
[`vignette("data-frames", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/data-frames.md),
[`vignette("data-organization", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/data-organization.md),
[`vignette("attributes-in-depth", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/attributes-in-depth.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Write a simple vector (dtype is auto-detected as uint8)
h5_write(file, "vec1", 1:20)
h5_typeof(file, "vec1") # "uint8"
#> [1] "uint8"

# Write a matrix, letting h5_write determine dimensions
mat <- matrix(rnorm(12), nrow = 4, ncol = 3)
h5_write(file, "group/mat", mat)
h5_dim(file, "group/mat") # c(4, 3)
#> [1] 4 3

# Overwrite the first vector, forcing a 32-bit integer type
h5_write(file, "vec1", 101:120, dtype = "int32")
h5_typeof(file, "vec1") # "int32"
#> [1] "int32"

# Write a scalar value
h5_write(file, "scalar", I(3.14))

# Write a named vector and preserve its names by setting attrs = TRUE
named_vec <- c(a = 1, b = 2)
h5_write(file, "named_vector", named_vec, attrs = TRUE)

# Write a nested list, which creates groups and datasets
my_list <- list(
  config = list(version = 1.2, user = "test"),
  data = matrix(1:4, 2)
)
attr(my_list, "info") <- "Session data"
h5_write(file, "session_data", my_list)

h5_ls(file, recursive = TRUE)
#>  [1] "vec1"                        "scalar"                     
#>  [3] "named_vector"                "group"                      
#>  [5] "group/mat"                   "session_data"               
#>  [7] "session_data/config"         "session_data/config/version"
#>  [9] "session_data/config/user"    "session_data/data"          

unlink(file)
```
