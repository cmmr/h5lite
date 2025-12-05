# Write an Attribute to HDF5

Writes an R object as an attribute to an existing HDF5 object.

## Usage

``` r
h5_write_attr(file, name, attribute, data, dtype = "auto")
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the object to attach the attribute to (e.g., "/data").

- attribute:

  The name of the attribute to create.

- data:

  The R object to write. Supported: `numeric`, `integer`, `complex`,
  `logical`, `character`, `raw`, `data.frame`, and `NULL`.

- dtype:

  The target HDF5 data type. Defaults to `typeof(data)`.

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
The full list of supported values for numeric data is:

- `"auto"`

- `"float16"`, `"float32"`, `"float64"`

- `"int8"`, `"int16"`, `"int32"`, `"int64"`

- `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`

For non-numeric data (`character`, `complex`, `factor`, `raw`,
`logical`), the storage type is determined automatically. For `logical`
attributes, `h5lite` follows the same rules as for integer data:

- If the vector contains no `NA` values, it is saved using an efficient
  integer type (e.g., `uint8`).

- If the vector contains any `NA` values, it is automatically promoted
  to a floating-point type (`float16`) to correctly preserve `NA`.

`data.frame` objects are written as HDF5 **compound attributes**, a
native table-like structure.

`NULL` objects are written as HDF5 **null attributes**, which contain no
data but can be used as placeholders.

`complex` objects are written using the native HDF5 `H5T_COMPLEX`
datatype class. HDF5 files containing complex attributes written by
`h5lite` can only be read by other HDF5 tools that support HDF5 version
2.0.0 or later.

To write a scalar attribute, wrap the value in
[`I()`](https://rdrr.io/r/base/AsIs.html) (e.g., `I("meters")`).
Otherwise, dimensions are inferred automatically.

## See also

[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md),
[`h5_read_attr()`](https://cmmr.github.io/h5lite/reference/h5_read_attr.md),
[`vignette("attributes-in-depth")`](https://cmmr.github.io/h5lite/articles/attributes-in-depth.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# First, create an object to attach attributes to
h5_write(file, "my_data", 1:10, compress = FALSE)

# Write a scalar string attribute
h5_write_attr(file, "my_data", "units", I("meters"))

# Write a numeric vector attribute
h5_write_attr(file, "my_data", "range", c(0, 100))

# List attributes to confirm they were written
h5_ls_attr(file, "my_data")
#> [1] "units" "range"

unlink(file)
```
