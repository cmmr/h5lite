# Read an Attribute from HDF5

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

A `numeric`, `character`, or `raw` vector/array.

## Details

- Numeric attributes are read as `numeric` (double).

- String attributes are read as `character`.

- 1-byte `OPAQUE` attributes are read as `raw`.

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create a dummy dataset
h5_write(file, "data", 1:5)
#> NULL

# Attach an attribute
h5_write_attr(file, "data", "unit", "meters", dims = NULL)
#> NULL

# Read the attribute
unit <- h5_read_attr(file, "data", "unit")
print(unit)
#> [1] "meters"

unlink(file)
```
