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

  The target HDF5 data type. Can be one of `"auto"`, `"float16"`,
  `"float32"`, `"float64"`, `"int8"`, `"int16"`, `"int32"`, `"int64"`,
  `"uint8"`, `"uint16"`, `"uint32"`, or `"uint64"`. The default,
  `"auto"`, selects the most space-efficient type for the data. See
  details below.

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## Writing Scalars

By default, `h5_write` saves single-element vectors as 1-dimensional
arrays. To write a true HDF5 scalar, wrap the value in
[`I()`](https://rdrr.io/r/base/AsIs.html) to treat it "as-is." For
example, `h5_write(file, "x", I(5))` will create a scalar dataset, while
`h5_write(file, "x", 5)` will create a 1D array of length 1.

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

## Data Type Selection (`dtype`)

The `dtype` argument controls the on-disk storage type and only applies
to `integer`, `numeric`, and `logical` vectors. For all other data types
(`character`, `complex`, `factor`, `raw`), the storage type is
determined automatically.

If `dtype` is set to `"auto"` (the default), `h5lite` will automatically
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

- `"auto"`

- `"float16"`, `"float32"`, `"float64"`

- `"int8"`, `"int16"`, `"int32"`, `"int64"`

- `"uint8"`, `"uint16"`, `"uint32"`, `"uint64"`

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
