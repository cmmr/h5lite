# Get Started with h5lite

## Get Started with h5lite

The `h5lite` package provides a simplified, user-friendly interface for
interacting with HDF5 files in R. While HDF5 is a complex hierarchical
data format, `h5lite` is designed to feel familiar to R users by mapping
HDF5 concepts directly to R’s native data structures.

This guide introduces the core concepts and basic usage. For detailed
information on specific topics, please refer to the other vignettes: \*
**Data Types & Compression**: Controlling storage types and compression.
\* **Complex Data Structures**: Handling `data.frame`s, `list`s,
factors, and complex numbers. \* **Metadata & Attributes**: Working with
R attributes, names, and dimnames. \* **File Management**: Inspecting,
organizing, and modifying HDF5 files.

### HDF5 for R Users

If you are new to HDF5, the easiest way to understand it is through R
analogues. HDF5 files function like a file system within a single file,
containing “groups” (folders) and “datasets” (files).

| R Concept           | HDF5 Concept         | Description                                                       |
|:--------------------|:---------------------|:------------------------------------------------------------------|
| **List**            | **Group**            | A container that holds other objects (datasets or other groups).  |
| **Vector / Matrix** | **Dataset**          | A multidimensional array of data (numeric, character, etc.).      |
| **Data Frame**      | **Compound Dataset** | A table where each column can have a different data type.         |
| **Attribute**       | **Attribute**        | Metadata attached to a specific object (e.g., units, timestamps). |
| **Factor**          | **Enum**             | An integer vector with associated string labels.                  |

### Basic Usage

The package uses two primary functions:
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) to
save data and
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) to
load it.

#### Writing Numeric Data

You can write standard R arrays and vectors directly to an HDF5 file.
`h5lite` automatically handles dimensions.

``` r
library(h5lite)
file <- tempfile(fileext = ".h5")

# 1. 1D Array (Vector)
vec <- c(1.5, 2.3, 4.2)
h5_write(vec, file, "examples/vector")

# 2. 2D Array (Matrix)
mat <- matrix(1:9, nrow = 3, ncol = 3)
h5_write(mat, file, "examples/matrix")

# 3. 3D Array
arr <- array(1:24, dim = c(4, 3, 2))
h5_write(arr, file, "examples/array_3d")

# 4. Scalar
# By default, R treats length-1 vectors as arrays. 
# Wrap in I() to write a true HDF5 scalar.
val <- I(42)
h5_write(val, file, "examples/scalar")
```

*Note: While `h5lite` supports preserving row and column names for
matrices and vectors, these examples omit them for simplicity. See the
**Metadata & Attributes** vignette for details on how dimension names
are stored.*

#### Reading Data

Data is read back into its native R format.

``` r
x <- h5_read(file, "examples/matrix")
print(x)
#>      [,1] [,2] [,3]
#> [1,]    1    4    7
#> [2,]    2    5    8
#> [3,]    3    6    9
```

### Data Type Mapping

`h5lite` automatically selects the appropriate HDF5 data type based on
the content of your R objects.

| R Data Type    | HDF5 Equivalent  | Description                                   |
|:---------------|:-----------------|:----------------------------------------------|
| **Numeric**    | *variable*       | Selects optimal type: `int8`, `float32`, etc. |
| **Logical**    | `H5T_STD_U8LE`   | Stored as 0 (FALSE) or 1 (TRUE) (`uint8`).    |
| **Character**  | `H5T_STRING`     | Variable or fixed-length UTF-8 strings.       |
| **Complex**    | `H5T_COMPLEX`    | Native HDF5 2.0+ complex numbers.             |
| **Raw**        | `H5T_OPAQUE`     | Raw bytes / binary data.                      |
| **Factor**     | `H5T_ENUM`       | Integer indices with label mapping.           |
| **integer64**  | `H5T_STD_I64LE`  | 64-bit signed integers via `bit64` package.   |
| **POSIXt**     | `H5T_STRING`     | ISO 8601 string (`YYYY-MM-DDTHH:MM:SSZ`).     |
| **List**       | `H5O_TYPE_GROUP` | Recursive container structure.                |
| **Data Frame** | `H5T_COMPOUND`   | Table of mixed types.                         |
| **NULL**       | `H5S_NULL`       | Creates a placeholder.                        |

You can use the `as` argument to explicitly set the HDF5 data type for
numeric, logical, and character vectors. See the **Data Types &
Compression** vignette for details.

### Complex Data Structures

#### Lists as Groups

R lists are naturally hierarchical, making them perfect for creating
HDF5 groups.

``` r
my_list <- list(
  config = list(id = 1L, status = "active"),
  data   = runif(10)
)
# Creates a group "/experiment" containing "config" (group) and "data" (dataset)
h5_write(my_list, file, "experiment") 
```

#### Data Frames as Compound Datasets

Data frames are written as native HDF5 compound datasets, allowing
efficient storage of tabular data with mixed types.

``` r
df <- data.frame(
  id = 1:5,
  val = c(1.1, 2.2, 3.3, 4.4, 5.5)
)
h5_write(df, file, "study_data")
```

For more details on these structures, including how to handle factors
and nested lists, refer to the **Complex Data Structures** vignette.

### Attributes

Attributes are small pieces of metadata attached to objects. `h5lite`
writes R attributes (like `units` or `description`) as HDF5 attributes.

``` r
# Write a dataset
h5_write(1:10, file, "measurements")

# Attach an attribute to it
h5_write("meters", file, "measurements", attr = "units")
```

See the **Metadata & Attributes** vignette for information on reading
specific attributes and how special R attributes like `dimnames` are
handled.

### File Inspection

You can inspect the contents of an HDF5 file without reading the data
into memory using
[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md) and
[`h5_str()`](https://cmmr.github.io/h5lite/reference/h5_str.md).

``` r
# List contents
h5_ls(file)
#>  [1] "examples"                 "examples/vector"         
#>  [3] "examples/matrix"          "examples/array_3d"       
#>  [5] "examples/scalar"          "experiment"              
#>  [7] "experiment/config"        "experiment/config/id"    
#>  [9] "experiment/config/status" "experiment/data"         
#> [11] "study_data"               "measurements"

# Print structure tree (like R's str())
h5_str(file)
#> /
#> ├── examples/
#> │   ├── vector <float64 × 3>
#> │   ├── matrix <uint8 × 3 × 3>
#> │   ├── array_3d <uint8 × 4 × 3 × 2>
#> │   └── scalar <uint8 scalar>
#> ├── experiment/
#> │   ├── config/
#> │   │   ├── id <uint8 × 1>
#> │   │   └── status <utf8[6] × 1>
#> │   └── data <float64 × 10>
#> ├── study_data <compound[2] × 5>
#> │   ├── $id <uint8>
#> │   └── $val <float64>
#> └── measurements <uint8 × 10>
#>     └── @units <utf8[6] × 1>
```

For advanced file operations, including moving, deleting, and verifying
objects, refer to the **File Management** vignette.
