# Read an HDF5 Object

Reads a dataset or group from an HDF5 file into an R object.

## Usage

``` r
h5_read(file, name, attrs = FALSE)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the dataset or group to read (e.g., `"/data/matrix"`).

- attrs:

  Controls which HDF5 attributes are read and attached to the R object.
  Can be `FALSE` (the default), `TRUE` (all attributes), a character
  vector of attribute names to include (e.g., `c("info", "version")`),
  or a character vector of names to exclude, prefixed with `-` (e.g.,
  `c("-class")`). Non-existent attributes are silently skipped.

## Value

A `numeric`, `character`, `factor`, `raw`, or `data.frame` if `name` is
a dataset. A nested `list` if `name` is a group.

## Reading Datasets

When `name` points to a dataset, `h5_read` converts it to the
corresponding R object:

- **Numeric** datasets are read as `numeric` (double) to prevent
  overflow.

- **String** datasets are read as `character`.

- **Enum** datasets are read as `factor`.

- **1-byte Opaque** datasets are read as `raw`.

- **Compound** datasets are read as `data.frame`.

Dimensions are preserved and transposed to match R's column-major order.

## Reading Groups

If `name` points to a group, `h5_read` will read it recursively,
creating a corresponding nested R `list`. This makes it easy to read
complex, structured data in a single command.

- HDF5 **groups** are read as R `list`s.

- **Datasets** within the group are read into R objects as described
  above.

- HDF5 **attributes** on the group are attached as R attributes to the
  `list`.

- The elements in the returned list are **sorted alphabetically** by
  name.

## See also

[`h5_read_attr()`](https://cmmr.github.io/h5lite/reference/h5_read_attr.md),
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md),
[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# --- Reading Datasets ---
h5_write(file, "my_matrix", matrix(1:4, 2))
h5_write(file, "my_factor", factor(c("a", "b")))

mat <- h5_read(file, "my_matrix")
fac <- h5_read(file, "my_factor")

# --- Reading Groups ---
h5_write(file, "/config/version", 1.2)
h5_write(file, "/config/user", "test")
h5_write_attr(file, "/config", "info", "settings")

# Read the 'config' group into a list
config_list <- h5_read(file, "config")
str(config_list)
#> List of 2
#>  $ user   : chr "test"
#>  $ version: num 1.2

# Read the entire file from the root
all_content <- h5_read(file, "/")
str(all_content)
#> List of 3
#>  $ config   :List of 2
#>   ..$ user   : chr "test"
#>   ..$ version: num 1.2
#>  $ my_factor: Factor w/ 2 levels "a","b": 1 2
#>  $ my_matrix: num [1:2, 1:2] 1 2 3 4

# --- Round-tripping with Attributes ---
named_vec <- c(a = 1, b = 2)
h5_write(file, "named_vec", named_vec, attrs = TRUE)

# Read back with attrs = TRUE to restore names
vec_rt <- h5_read(file, "named_vec", attrs = TRUE)
all.equal(named_vec, vec_rt)
#> [1] TRUE

unlink(file)
```
