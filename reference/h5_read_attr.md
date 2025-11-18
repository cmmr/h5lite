# Read an HDF5 Attribute

Reads an attribute associated with an HDF5 object (dataset or group).

## Usage

``` r
h5_read_attr(file, name, attribute)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the object (dataset or group) the attribute is attached to.

- attribute:

  Name of the attribute to read.

## Value

A `numeric`, `character`, `factor`, or `raw` vector/array. Returns
`NULL` if the attribute has a null dataspace.

## Details

- Numeric attributes are read as `numeric` (double).

- String attributes are read as `character`.

- `enum` attributes are read as `factor`.

- 1-byte `opaque` attributes are read as `raw`.

## See also

[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md),
[`h5_write_attr()`](https://cmmr.github.io/h5lite/reference/h5_write_attr.md),
[`h5_ls_attr()`](https://cmmr.github.io/h5lite/reference/h5_ls_attr.md),
[`h5_exists_attr()`](https://cmmr.github.io/h5lite/reference/h5_exists_attr.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create a dataset to attach attributes to
h5_write(file, "dset", 1)

# Write attributes of different types
h5_write_attr(file, "dset", "a_string", "some metadata")
h5_write_attr(file, "dset", "a_vector", c(1.1, 2.2))

# Read them back
str_attr <- h5_read_attr(file, "dset", "a_string")
vec_attr <- h5_read_attr(file, "dset", "a_vector")

print(str_attr)
#> [1] "some metadata"
print(vec_attr)
#> [1] 1.1 2.2
unlink(file)
```
