# Get R Class of an HDF5 Attribute

Returns the R class that
[`h5_read_attr()`](https://cmmr.github.io/h5lite/reference/h5_read_attr.md)
would produce for a given HDF5 attribute.

## Usage

``` r
h5_class_attr(file, name, attribute)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the object the attribute is attached to.

- attribute:

  Name of the attribute.

## Value

A character string representing the R class (e.g., `"numeric"`,
`"character"`, `"factor"`, `"raw"`). Returns `NA_character_` for HDF5
types that `h5lite` cannot read.

## Details

This function maps the low-level HDF5 storage type of an attribute to
the resulting R class.

- **Integer/Float** attributes are reported as `"numeric"`.

- **String** attributes are reported as `"character"`.

- **Enum** attributes are reported as `"factor"`.

- **1-byte Opaque** attributes are reported as `"raw"`.

- Other HDF5 types are reported as `NA_character_`.

## See also

[`h5_class()`](https://cmmr.github.io/h5lite/reference/h5_class.md),
[`h5_typeof_attr()`](https://cmmr.github.io/h5lite/reference/h5_typeof_attr.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "data", 1)

# Write attributes of different types
h5_write_attr(file, "data", "int_attr", 10L) # 1D array of length 1
h5_write_attr(file, "data", "char_attr", I("info")) # scalar

# Check R class
h5_class_attr(file, "data", "int_attr")  # "numeric"
#> [1] "numeric"
h5_class_attr(file, "data", "char_attr") # "character"
#> [1] "character"

unlink(file)
```
