# Get the Total Length of an HDF5 Object or Attribute

Behaves like [`length()`](https://rdrr.io/r/base/length.html) for R
objects.

- For **Compound Datasets** (data.frames), this is the number of
  columns.

- For **Datasets** and **Attributes**, this is the product of all
  dimensions (total number of elements).

- For **Groups**, this is the number of objects directly contained in
  the group.

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

h5_write(1:100, file, "my_vec")
h5_length(file, "my_vec") # 100
#> [1] 100

h5_write(mtcars, file, "my_df")
h5_length(file, "my_df") # 11 (ncol(mtcars))
#> [1] 11

h5_write(as.matrix(mtcars), file, "my_mtx")
h5_length(file, "my_mtx") # 352 (prod(dim(mtcars)))
#> [1] 352

h5_length(file, "/") # 3
#> [1] 3

unlink(file)
```
