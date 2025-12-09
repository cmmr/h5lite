# Create an HDF5 File

Explicitly creates a new, empty HDF5 file.

## Usage

``` r
h5_create_file(file)
```

## Arguments

- file:

  Path to the HDF5 file to be created.

## Value

Invisibly returns `NULL`. This function is called for its side effects.

## Details

This function is a simple wrapper around `h5_create_group(file, "/")`.
Its main purpose is to allow for explicit file creation in code.

Note that calling this function is almost always **unnecessary**, as all
`h5lite` writing functions (like
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) or
[`h5_create_group()`](https://cmmr.github.io/h5lite/reference/h5_create_group.md))
will automatically create the file if it does not exist.

It is provided as a convenience for users who prefer to explicitly
create a file before writing data to it.

## File Handling

- If `file` does not exist, it will be created as a new, empty HDF5
  file.

- If `file` already exists and is a valid HDF5 file, this function does
  nothing and returns successfully.

- If `file` exists but is **not** a valid HDF5 file (e.g., a text file),
  an error will be thrown and the file will not be modified.

## See also

[`h5_create_group()`](https://cmmr.github.io/h5lite/reference/h5_create_group.md),
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Explicitly create the file (optional)
h5_create_file(file)

# Check that it exists
file.exists(file) # TRUE
#> [1] TRUE

# Write to the file
h5_write(file, "data", 1:10)

# Clean up
unlink(file)
```
