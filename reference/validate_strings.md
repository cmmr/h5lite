# Validates string inputs

Validates string inputs

## Usage

``` r
validate_strings(file, name, attr = NULL, must_exist = FALSE)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The full path of the object (group or dataset).

- attr:

  The name of an attribute to check. If provided, the length of the
  attribute is returned.

- must_exist:

  Logical. If `TRUE`, the function will stop if the object does not
  exist.

## Value

The expanded path to the file.
