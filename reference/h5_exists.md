# Check if an HDF5 File or Object Exists

Safely checks if a file is a valid HDF5 file or if a specific object
(group or dataset) exists within a valid HDF5 file.

## Usage

``` r
h5_exists(file, name = "/")
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the object to check (e.g., `"/data/matrix"`).
  Defaults to `"/"`, which tests if the file itself is a valid HDF5
  file.

## Value

A logical value: `TRUE` if the file/object exists and is valid, `FALSE`
otherwise.

## Details

This function provides a robust, error-free way to test for existence.

- **Testing for a File:** If `name` is `/` (the default), the function
  checks if `file` is a valid, readable HDF5 file. It will return
  `FALSE` for non-existent files, non-HDF5 files, or corrupted files
  without raising an error.

- **Testing for an Object:** If `name` is a path (e.g., `/data/matrix`),
  the function first confirms the file is valid HDF5, and then checks if
  the specific object exists within it.

## See also

[`h5_exists_attr()`](https://cmmr.github.io/h5lite/reference/h5_exists_attr.md),
[`h5_is_group()`](https://cmmr.github.io/h5lite/reference/h5_is_group.md),
[`h5_is_dataset()`](https://cmmr.github.io/h5lite/reference/h5_is_dataset.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "my_data", 1:10)

# --- Test 1: Check for a specific object ---
h5_exists(file, "my_data") # TRUE
#> [1] TRUE
h5_exists(file, "nonexistent_data") # FALSE
#> [1] FALSE

# --- Test 2: Check for a valid HDF5 file ---
h5_exists(file) # TRUE
#> [1] TRUE
h5_exists(file, "/") # TRUE
#> [1] TRUE

# --- Test 3: Check invalid or non-existent files ---
h5_exists("not_a_real_file.h5") # FALSE
#> [1] FALSE

text_file <- tempfile()
writeLines("this is not hdf5", text_file)
h5_exists(text_file) # FALSE
#> [1] FALSE

# Check for an object in an invalid file (also FALSE)
h5_exists(text_file, "my_data") # FALSE
#> [1] FALSE

unlink(file)
unlink(text_file)
```
