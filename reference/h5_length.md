# Get the Total Length of an HDF5 Object or Attribute

Returns the total number of elements in a dataset, attribute, or group.

- For **Datasets** and **Attributes**, this is the product of all
  dimensions (total number of elements).

- For **Groups**, this is the number of objects directly contained in
  the group (similar to [`length()`](https://rdrr.io/r/base/length.html)
  on a list).

- Scalar datasets or attributes return 1.

## Usage

``` r
h5_length(file, name, attr = NULL)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The full path of the object (group or dataset).

- attr:

  The name of an attribute to check. If provided, the length of the
  attribute is returned.

## Value

An integer representing the total length (number of elements).

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(1:100, file, "dset")
h5_length(file, "dset") # 100
#> [1] 100
unlink(file)
```
