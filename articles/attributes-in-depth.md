# Attributes In-Depth

``` r
library(h5lite)

# We'll use a temporary file for this guide.
file <- tempfile(fileext = ".h5")

# Create a dataset to work with
h5_write(file, "my_data", 1:10)
```

## Introduction

In HDF5, **attributes** are small, named pieces of metadata that can be
attached to datasets or groups. They are distinct from **datasets**,
which are designed to hold primary data.

This vignette provides a deep dive into working with attributes in
`h5lite`, covering: \* Basic attribute I/O. \* The powerful `attrs`
argument for round-tripping R object attributes. \* Important
limitations and special cases.

For an introduction to writing datasets, see
[`vignette("h5lite", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/h5lite.md).

## Basic Attribute I/O

The core functions for direct attribute manipulation are
[`h5_write_attr()`](https://cmmr.github.io/h5lite/reference/h5_write_attr.md),
[`h5_read_attr()`](https://cmmr.github.io/h5lite/reference/h5_read_attr.md),
and
[`h5_ls_attr()`](https://cmmr.github.io/h5lite/reference/h5_ls_attr.md).

Let’s add some metadata to our `my_data` dataset.

``` r
# Write a scalar string attribute
h5_write_attr(file, "my_data", "units", I("meters/sec"))

# Write a numeric vector attribute
h5_write_attr(file, "my_data", "quality_flags", c(1, 1, 0, 1))

# List the attributes on the object
h5_ls_attr(file, "my_data")
#> [1] "units"         "quality_flags"

# Read one of the attributes back
units <- h5_read_attr(file, "my_data", "units")
print(units)
#> [1] "meters/sec"
```

## Automatic Round-tripping with the `attrs` Argument

While
[`h5_write_attr()`](https://cmmr.github.io/h5lite/reference/h5_write_attr.md)
is useful for manual metadata, the real power comes from the `attrs`
argument in
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) and
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md). This
allows for high-fidelity round-trips of R objects by preserving their
R-level attributes.

Consider a named vector with a custom attribute.

``` r
named_vec <- c(a = 1, b = 2, c = 3)
attr(named_vec, "info") <- "My special vector"

# Write the vector, telling h5lite to save its attributes
h5_write(file, "named_vec", named_vec, attrs = TRUE)

# Inspect the HDF5 attributes that were created
h5_ls_attr(file, "named_vec")
#> [1] "names" "info"
```

When we read it back with `attrs = TRUE`, `h5lite` re-attaches the HDF5
attributes as R attributes.

``` r
read_vec <- h5_read(file, "named_vec", attrs = TRUE)

# The object is perfectly restored
all.equal(named_vec, read_vec)
#> [1] TRUE
str(read_vec)
#>  Named num [1:3] 1 2 3
#>  - attr(*, "names")= chr [1:3] "a" "b" "c"
#>  - attr(*, "info")= chr "My special vector"
```

### Fine-Grained Control with Character Vectors

The `attrs` argument also accepts a character vector to specify exactly
which attributes to include or exclude.

- **Inclusion list**: `attrs = c("names", "info")` will only write/read
  those specific attributes.
- **Exclusion list**: `attrs = c("-class", "-dim")` will write/read all
  attributes *except* the ones listed.

``` r
# Write the vector, but only include the 'names' attribute
h5_write(file, "selective_vec", named_vec, attrs = c("names"))

# Only the 'names' attribute was written
h5_ls_attr(file, "selective_vec")
#> [1] "names"
```

## Limitations and Special Cases

There are a few important rules and limitations to be aware of when
working with attributes.

### Limitation: List Attributes

More generally, `h5lite` cannot write any R attribute that is a `list`.
HDF5 attributes are designed to hold simple, atomic data, not nested
structures.

When using `attrs = TRUE` or
[`h5_write_attr()`](https://cmmr.github.io/h5lite/reference/h5_write_attr.md),
you can write attributes that are: \* Atomic vectors (`numeric`,
`integer`, `character`, `logical`, `raw`) \* `factor`s \* `data.frame`s
(which become compound attributes) \* `NULL`

Attempting to write an object that has a `list` attribute will result in
an error.

``` r
my_vec <- 1:3
attr(my_vec, "bad_attr") <- list(a = 1, b = 2)
h5_write(file, "my_vec_list_attr", my_vec, attrs = TRUE)
#> Error in validate_attrs(data, attrs): Attribute 'bad_attr' cannot be written to HDF5 because its type ('list') is not supported. Only atomic vectors and factors can be written as attributes.
```

### Limitation: `dimnames`

R stores the `dimnames` of a matrix or array as a `list` attribute. As
explained above, `h5lite` **cannot** write list-like attributes.
Attempting to write a named matrix with `attrs = TRUE` will fail.

See
[`vignette("matrices", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/matrices.md)
for more details on this specific case.

``` r
named_matrix <- matrix(1:4, 2, dimnames = list(c("r1", "r2"), c("c1", "c2")))

# This fails because the 'dimnames' attribute is a list
h5_write(file, "named_matrix", named_matrix, attrs = TRUE)
#> Error in validate_attrs(data, attrs): Attribute 'dimnames' cannot be written to HDF5 because its type ('list') is not supported. Only atomic vectors and factors can be written as attributes.
```

**Workaround:** Either remove the `dimnames` before writing, or write
with `attrs = FALSE` (the default), which will save the matrix data but
discard the names.

#### Data Frames:

Unlike matrices, the attributes of a `data.frame` can be safely
round-tripped with `h5lite`. This is because its key metadata is stored
in a format that `h5lite` can handle. See
[`vignette("data-frames", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/data-frames.md)
for more on working with data frames.

- The column names are stored in the `names` attribute, which is a
  character vector.
- The row names are stored in the `row.names` attribute, which is either
  a character or integer vector.

Since neither of these are `list` attributes (like the `dimnames` of a
matrix), they can be written to HDF5 without issue. As a result, you can
reliably use `attrs = TRUE` to preserve the structure of a `data.frame`
during a write/read cycle.

``` r
# Create a data.frame with non-default row names
df <- data.frame(
  x = 1:3, 
  y = c("a", "b", "c"),
  row.names = c("row1", "row2", "row3")
)

# Write with attrs = TRUE to preserve names
h5_write(file, "my_df", df, attrs = TRUE)

# Read it back
read_df <- h5_read(file, "my_df", attrs = TRUE)

# The data.frame is perfectly restored
all.equal(df, read_df)
#> [1] TRUE
```

``` r
# Clean up the temporary file
unlink(file)
```
