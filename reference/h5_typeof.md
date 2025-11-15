# Get HDF5 Object Type

Returns the low-level HDF5 storage type of a dataset (e.g., "INT",
"FLOAT", "STRING"). This allows inspecting the file storage type before
reading the data into R.

## Usage

``` r
h5_typeof(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the dataset.

## Value

A string representing the HDF5 storage type.

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Write integers
h5_write(file, "integers", 1:5)
#> NULL
# Write doubles
h5_write(file, "doubles", c(1.1, 2.2))
#> NULL

# Check types
h5_typeof(file, "integers") # "uint8"
#> [1] "uint8"
h5_typeof(file, "doubles")  # "float16"
#> [1] "float64"

unlink(file)
```
