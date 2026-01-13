# Data Frames

Data frames are the workhorse of data analysis in R. In HDF5, data
frames are stored as **Compound Datasets**. This allows different
columns to have different data types (e.g., integer, float, string)
within the same dataset, much like a SQL table.

This vignette explains how `h5lite` handles data frames, including row
names, factors, and missing values.

``` r
library(h5lite)
file <- tempfile(fileext = ".h5")
```

## Basic Usage

Writing a data frame is as simple as writing any other object. `h5lite`
automatically maps each column to its appropriate HDF5 type.

``` r
# Create a standard data frame
df <- data.frame(
  id = 1:5,
  group = c("A", "A", "B", "B", "C"),
  score = c(10.5, 9.2, 8.4, 7.1, 6.0),
  passed = c(TRUE, TRUE, TRUE, FALSE, FALSE),
  stringsAsFactors = FALSE
)

# Write to HDF5
h5_write(df, file, "study_data/results")

# Fetch the column names
h5_names(file, "study_data/results")
#> [1] "id"     "group"  "score"  "passed"

# Read back
df_in <- h5_read(file, "study_data/results")

head(df_in)
#>   id group score passed
#> 1  1     A  10.5      1
#> 2  2     A   9.2      1
#> 3  3     B   8.4      1
#> 4  4     B   7.1      0
#> 5  5     C   6.0      0
```

## Customizing Column Types

You can use the `as` argument to control the storage type for specific
columns. This is passed as a named vector where the names correspond to
the column names.

This is particularly useful for optimizing storage (e.g., saving space
by storing small integers as `int8` or single characters as `ascii[1]`).

``` r
df_small <- data.frame(
  id   = 1:10,
  code = rep("A", 10)
)

# Force 'id' to be uint16 and 'code' to be an ascii string
h5_write(df_small, file, "custom_df", 
         as = c(id = "uint16", code = "ascii[]"))
```

## Row Names

Standard HDF5 Compound Datasets do not have a concept of “row names”.
However, `h5lite` preserves them using **Dimension Scales**.

When you write a data frame with row names, `h5lite` creates a separate
dataset (usually named `_rownames`) and links it to the main table. When
reading, `h5lite` automatically restores these as the `row.names` of the
data frame.

``` r
mtcars_subset <- head(mtcars, 3)

h5_write(mtcars_subset, file, "cars")

h5_str(file)
#> /
#> ├── study_data/
#> │   └── results <compound[4] × 5>
#> │       ├── $id <uint8>
#> │       ├── $group <utf8[1]>
#> │       ├── $score <float64>
#> │       └── $passed <uint8>
#> ├── custom_df <compound[2] × 10>
#> │   ├── $id <uint16>
#> │   └── $code <ascii[1]>
#> ├── cars <compound[11] × 3>
#> │   ├── @DIMENSION_LIST <vlen × 1>
#> │   ├── $mpg <float64>
#> │   ├── $cyl <uint8>
#> │   ├── $disp <uint8>
#> │   ├── $hp <uint8>
#> │   ├── $drat <float64>
#> │   ├── $wt <float64>
#> │   ├── $qsec <float64>
#> │   ├── $vs <uint8>
#> │   ├── $am <uint8>
#> │   ├── $gear <uint8>
#> │   └── $carb <uint8>
#> └── cars_rownames <utf8 × 3>
#>     ├── @CLASS <ascii[16] scalar>
#>     └── @REFERENCE_LIST <compound[2] × 1>
#>         ├── $dataset <reference>
#>         └── $dimension <uint32>

# Read back
result <- h5_read(file, "cars")
print(row.names(result))
#> [1] "Mazda RX4"     "Mazda RX4 Wag" "Datsun 710"
```
