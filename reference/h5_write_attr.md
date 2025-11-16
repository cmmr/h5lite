# Write an Attribute to HDF5

Writes an R object as an attribute to an existing HDF5 object.

## Usage

``` r
h5_write_attr(file, name, attribute, data, dtype = "auto", dims = length(data))
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the object to attach the attribute to (e.g., "/data").

- attribute:

  The name of the attribute to create.

- data:

  The R object to write. Supported: `numeric`, `integer`, `logical`,
  `character`, `raw`.

- dtype:

  The target HDF5 data type. Defaults to `typeof(data)`.

- dims:

  An integer vector specifying dimensions, or `NULL` for a scalar.
  Defaults to `dim(data)` or `length(data)`.

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## Details

The `dtype` argument controls the on-disk storage type **for numeric
data only**.

If `dtype` is set to `"auto"` (the default), `h5lite` will automatically
select the most space-efficient type for numeric data that can safely
represent the full range of values. For example, writing `1:100` will
result in an 8-bit unsigned integer (`uint8`) attribute.

To override this for numeric data, you can specify an exact type. The
input is case-insensitive and allows for unambiguous partial matching.
The full list of supported values is:

- `"auto"`, `"float"`, `"double"`

- `"float16"`, `"float32"`, `"float64"`

- `"int8"`, `"int16"`, `"int32"`, `"int64"`

- `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`

- `"char"`, `"short"`, `"int"`, `"long"`, `"llong"`

- `"uchar"`, `"ushort"`, `"uint"`, `"ulong"`, `"ullong"`

Note: Types without a bit-width suffix (e.g., `"int"`, `"long"`) are
system- dependent and may have different sizes on different machines.
For maximum file portability, it is recommended to use types with
explicit widths (e.g., `"int32"`).

For non-numeric data (`character`, `factor`, `raw`, `logical`), the
storage type is determined automatically and **cannot be changed** by
the `dtype` argument. R `logical` vectors are stored as 8-bit unsigned
integers (`uint8`), as HDF5 does not have a native boolean datatype.

## See also

[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md),
[`h5_read_attr()`](https://cmmr.github.io/h5lite/reference/h5_read_attr.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# First, create an object to attach attributes to
h5_write(file, "my_data", 1:10)

# Write a scalar string attribute
h5_write_attr(file, "my_data", "units", "meters", dims = NULL)

# Write a numeric vector attribute
h5_write_attr(file, "my_data", "range", c(0, 100))

# List attributes to confirm they were written
h5_ls_attr(file, "my_data")
#> [1] "units" "range"

unlink(file)
```
