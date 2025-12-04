# Working with Data Frames

``` r
library(h5lite)

# We'll use a temporary file for this guide.
file <- tempfile(fileext = ".h5")
```

## Introduction

The `data.frame` is R’s primary data structure for tabular data,
containing columns of potentially different types. `h5lite` provides
first-class support for `data.frame` objects by mapping them to a native
HDF5 structure called a **compound dataset**.

This vignette explains how `data.frame` objects are written and read,
and provides technical details on the underlying HDF5 implementation.

For details on other data structures, see
[`vignette("atomic-vectors", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/atomic-vectors.md)
and
[`vignette("matrices", package = "h5lite")`](https://cmmr.github.io/h5lite/articles/matrices.md).

## 1. Writing and Reading Data Frames

Writing a `data.frame` is a one-line command with
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md).

``` r
my_df <- data.frame(
  trial = 1:4,
  sample_id = c("A1", "A2", "B1", "B2"),
  value = c(10.2, 11.1, 9.8, 10.5),
  pass_qc = c(TRUE, TRUE, FALSE, TRUE),
  condition = factor(c("control", "treat", "control", "treat"))
)

h5_write(file, "my_df", my_df)
```

You can inspect the object with
[`h5_str()`](https://cmmr.github.io/h5lite/reference/h5_str.md) and
[`h5_class()`](https://cmmr.github.io/h5lite/reference/h5_class.md).
Notice that `h5lite` correctly identifies it as a `data.frame` backed by
a `compound` HDF5 type.

``` r
h5_str(file)
#> Listing contents of: /tmp/RtmpIxzAzC/file247a75595fe0.h5
#> Root group: /
#> ----------------------------------------------------------------
#> Type            Name
#> ----------------------------------------------------------------
#> compound[4]  my_df
h5_class(file, "my_df")
#> [1] "data.frame"
```

Reading the data back with
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)
restores it as an R `data.frame`.

``` r
read_df <- h5_read(file, "my_df")

str(read_df)
#> 'data.frame':    4 obs. of  5 variables:
#>  $ trial    : num  1 2 3 4
#>  $ sample_id: chr  "A1" "A2" "B1" "B2"
#>  $ value    : num  10.2 11.1 9.8 10.5
#>  $ pass_qc  : num  1 1 0 1
#>  $ condition: Factor w/ 2 levels "control","treat": 1 2 1 2
```

### Data Type Fidelity

`h5lite` aims for a high-fidelity round-trip, but there are two
important conversions to note:

1.  **`integer` -\> `numeric`**: All integer columns (`trial` in our
    example) are read back as `numeric` (double) vectors. This is a
    safety measure to prevent integer overflow.
2.  **`logical` -\> `numeric`**: `logical` columns (`pass_qc`) are
    stored as 8-bit integers (0/1) and are also read back as `numeric`.

`factor` columns, however, are perfectly preserved.

Let’s verify the round-trip by manually converting the original
`data.frame` to match the expected output.

``` r
my_df_cmp <- my_df
my_df_cmp$trial <- as.numeric(my_df_cmp$trial)
my_df_cmp$pass_qc <- as.numeric(my_df_cmp$pass_qc)

all.equal(read_df, my_df_cmp)
#> [1] TRUE
```

## Advanced Details: The HDF5 Compound Type

When you write a `data.frame`, `h5lite` does not save each column as a
separate dataset. Instead, it creates a single HDF5 dataset with a
**compound datatype**.

A compound type is analogous to a `struct` in C. It is a collection of
named members, where each member has its own datatype. For a
`data.frame`, this structure looks like:

- **HDF5 Dataset:** A 1D array, where the length is the number of rows
  in the `data.frame`.
- **HDF5 Datatype:** A compound type where:
  - Each **member** of the struct corresponds to a **column** of the
    `data.frame`.
  - The member’s **name** is the column name.
  - The member’s **datatype** is the HDF5 equivalent of the R column’s
    type (e.g., `H5T_FLOAT64` for `numeric`, `H5T_STRING` for
    `character`, `H5T_ENUM` for `factor`).

This approach has several advantages for HDF5 experts and
interoperability:

1.  **Portability:** A compound dataset is a standard, self-describing
    HDF5 structure. A Python user with `h5py` or a C++ user can read
    this dataset and immediately get a structured array or a vector of
    structs, with all column names and types preserved.
2.  **Atomicity:** The entire table is a single object in the HDF5 file,
    which can be easier to manage than a group containing many separate
    column-datasets.
3.  **Efficiency:** For many access patterns, reading a single
    contiguous block of compound data can be more efficient than reading
    from multiple disparate datasets.

## Preserving `data.frame` Attributes

Like other R objects, `data.frame`s can have metadata attached. The most
common is `row.names`. To ensure these are saved, use `attrs = TRUE`.

``` r
df_with_attrs <- my_df
row.names(df_with_attrs) <- df_with_attrs$sample_id
attr(df_with_attrs, "description") <- "My experiment data"

h5_write(file, "df_with_attrs", df_with_attrs, attrs = TRUE)

# Inspect the HDF5 attributes created
h5_ls_attr(file, "df_with_attrs")
#> [1] "names"       "class"       "row.names"   "description"

# Read back with attributes
read_df_with_attrs <- h5_read(file, "df_with_attrs", attrs = TRUE)

# Manually adjust for type conversions before comparing
df_with_attrs$trial <- as.numeric(df_with_attrs$trial)
df_with_attrs$pass_qc <- as.numeric(df_with_attrs$pass_qc)

all.equal(read_df_with_attrs, df_with_attrs)
#> [1] TRUE
```

> **Note:** The `row.names` attribute is read back correctly because of
> a special rule in
> [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md). It
> detects the attribute named `"row.names"`, and if it is a `numeric`
> vector, it is coerced back to `integer` to satisfy R’s requirements
> for a valid `data.frame`.

``` r
# Clean up the temporary file
unlink(file)
```
