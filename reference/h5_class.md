# Get R Class of an HDF5 Object

Inspects an HDF5 object and returns the R class that
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) or
[`h5_read_all()`](https://cmmr.github.io/h5lite/reference/h5_read_all.md)
would produce.

## Usage

``` r
h5_class(file, name, attrs = FALSE)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the object (group or dataset) to check.

- attrs:

  Controls attribute checking. If `TRUE` or a character vector
  containing `"class"`, the function will check for a `"class"` HDF5
  attribute on the object.

## Value

A character string representing the R class (e.g., `"numeric"`,
`"character"`, `"factor"`, `"raw"`, `"list"`). Returns `NA_character_`
for HDF5 types that `h5lite` cannot read.

## Details

This function determines the resulting R class by inspecting the
object's metadata.

- **Groups** are reported as `"list"`.

- **Datasets** (integers, floats) are reported as `"numeric"` (since
  `h5_read` always returns `double`).

- **String** datasets are reported as `"character"`.

- **Enum** datasets are reported as `"factor"`.

- **1-byte Opaque** datasets are reported as `"raw"`.

- Other HDF5 types (e.g., compound) are reported as `NA_character_`.

If `attrs` is set to `TRUE` or is a character vector containing
`"class"`, this function will first check for an HDF5 attribute on the
object named `"class"`. If a string attribute with this name exists, its
value (e.g., `"data.frame"`) will be returned, taking precedence over
the object's type.

## See also

[`h5_class_attr()`](https://cmmr.github.io/h5lite/reference/h5_class_attr.md),
[`h5_typeof()`](https://cmmr.github.io/h5lite/reference/h5_typeof.md),
[`h5_read_all()`](https://cmmr.github.io/h5lite/reference/h5_read_all.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Write various object types
h5_write(file, "integers", 1:5)
h5_write(file, "doubles", c(1.1, 2.2))
h5_write(file, "text", "hello")
h5_create_group(file, "my_group")

# Create a 'data.frame' structure (a group with a 'class' attribute)
df_list <- list(a = 1:2, b = c("x", "y"))
attr(df_list, "class") <- "data.frame"
h5_write_all(file, "my_df", df_list)

# Check R classes
h5_class(file, "integers")      # "numeric"
#> [1] "numeric"
h5_class(file, "doubles")       # "numeric"
#> [1] "numeric"
h5_class(file, "text")          # "character"
#> [1] "character"
h5_class(file, "my_group")      # "list"
#> [1] "list"

# Check 'class' attribute
h5_class(file, "my_df", attrs = FALSE) # "list" (it's a group)
#> [1] "list"
h5_class(file, "my_df", attrs = TRUE)  # "data.frame"
#> [1] "data.frame"

unlink(file)
```
