# Write an Attribute to HDF5

Writes an R object as an attribute to an existing HDF5 object.

## Usage

``` r
h5_write_attr(
  file,
  name,
  attribute,
  data,
  dtype = typeof(data),
  dims = length(data)
)
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

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create a group/dataset first
h5_write(file, "my_dataset", 1:10)
#> NULL

# Write scalar attributes
h5_write_attr(file, "my_dataset", "version", "1.0", dims = NULL)
#> NULL
h5_write_attr(file, "my_dataset", "timestamp", 123456, dtype = "integer", dims = NULL)
#> NULL

# Write vector attributes
h5_write_attr(file, "my_dataset", "range", c(0, 100))
#> NULL

h5_ls_attr(file, "my_dataset")
#> [1] "version"   "timestamp" "range"    
unlink(file)
```
