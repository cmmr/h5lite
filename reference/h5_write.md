# Write a Dataset to HDF5

Writes an R object to an HDF5 file as a dataset. The file is created if
it does not exist. Handles dimension transposition automatically.

## Usage

``` r
h5_write(
  file,
  name,
  data,
  dtype = "auto",
  dims = length(data),
  compress = TRUE
)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the dataset (e.g., "/data/matrix").

- data:

  The R object to write. Supported: `numeric`, `integer`, `logical`,
  `character`, `raw`.

- dtype:

  The target HDF5 data type. Defaults to `typeof(data)`.

- dims:

  An integer vector specifying dimensions, or `NULL` for a scalar.
  Defaults to `dim(data)` if it exists, or `length(data)` otherwise.

- compress:

  A logical or an integer from 0-9. If `TRUE`, compression level 5 is
  used. If `FALSE` or `0`, no compression is used. An integer `1-9`
  specifies the zlib compression level directly.

## Details

The `dtype` argument controls the on-disk storage type **for numeric
data only**.

If `dtype` is set to `"auto"` (the default), `h5lite` will automatically
select the most space-efficient type for numeric data that can safely
represent the full range of values. For example, writing `1:100` will
result in an 8-bit unsigned integer (`uint8`) dataset, which helps
minimize file size.

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
