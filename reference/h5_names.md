# Get Names of an HDF5 Object

Returns the names of the object.

- For **Groups**, it returns the names of the objects contained in the
  group (similar to [`ls()`](https://rdrr.io/r/base/ls.html)).

- For **Compound Datasets** (data.frames), it returns the column names.

- For other **Datasets**, it looks for a dimension scale and returns it
  if found.

## Usage

``` r
h5_names(file, name = "/", attr = NULL)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The full path of the object.

- attr:

  The name of an attribute. If provided, returns the names associated
  with the attribute (e.g., field names if the attribute is a compound
  type). (Default: `NULL`)

## Value

A character vector of names, or `NULL` if the object has no names.

## Examples

``` r
file <- tempfile(fileext = ".h5")

h5_write(data.frame(x=1, y=2), file, "df")
h5_names(file, "df") # "x" "y"
#> [1] "x" "y"

x <- 1:5
names(x) <- letters[1:5]
h5_write(x, file, "x")
h5_names(file, "x") # "a" "b" "c" "d" "e"
#> [1] "a" "b" "c" "d" "e"

h5_write(mtcars[,c("mpg", "hp")], file, "dset")
h5_names(file, "dset") # "mpg" "hp"
#> [1] "mpg" "hp" 

unlink(file)
```
