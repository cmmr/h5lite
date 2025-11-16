# h5lite <img src="man/figures/logo.png" align="right" width="172" height="200" alt="h5lite logo" />

**h5lite** is an R package that provides a simple and lightweight interface for reading and writing HDF5 files.

It is designed for R users who want to save and load common R objects (vectors, matrices, arrays, factors) to an HDF5 file without needing to understand the low-level details of the HDF5 library.

## Why use h5lite?

`h5lite` is "opinionated" software that prioritizes simplicity and safety for the most common use cases. It handles the tricky parts of HDF5 automatically so you can focus on your data.

-   **Simple, R-native API:** Use familiar functions like `h5_read()` and `h5_write()`. No need to learn a complex new syntax.
-   **"It Just Works" Philosophy:**
    -   Dimensions are handled automatically. R matrices are saved as matrices and read back as matrices.
    -   Parent groups are created as needed (e.g., writing to `"group/data"` works even if `"group"` doesn't exist).
    -   Writing to an existing dataset path overwrites it, just like re-assigning a variable.
-   **Safe and Efficient:**
    -   Numeric data is read back as `double` to prevent integer overflow surprises.
    -   Automatic data type selection saves space by default (e.g., `1:100` is stored as an 8-bit integer).
    -   Built-in, easy-to-use compression (`compress = TRUE`).
-   **Easy Installation:** `h5lite` bundles its HDF5 dependency, so installation is a simple `install.packages("h5lite")`. No need to manage system libraries.

This package uses the HDF5 library developed by The HDF Group (<https://www.hdfgroup.org/>).

## Installation

You can install the released version of `h5lite` from CRAN:

```r
install.packages("h5lite")
```

## Quick Start

The API is designed to be simple and predictable.

```r
library(h5lite)

file <- tempfile(fileext = ".h5")
```

### 1. Write Data

Use `h5_write()` to save R objects. It automatically handles dimensions and chooses an efficient on-disk data type.

```r
# Write a vector
h5_write(file, "data/vector", 1:10)

# Write an R matrix
mat <- matrix(c(1.1, 2.2, 3.3, 4.4), nrow = 2, ncol = 2)
h5_write(file, "data/matrix", mat)

# Write a 3D array
arr <- array(1L:24L, dim = c(2, 3, 4))
h5_write(file, "data/array", arr)

# Write a scalar (dims = NULL)
h5_write(file, "scalar_string", "Hello!", dims = NULL)

# Write a factor (seamlessly stored and read back)
fac <- as.factor(c("a", "b", "a", "c"))
h5_write(file, "factor_data", fac)

# Write a large vector with compression enabled
h5_write(file, "compressed_data", 1:10000, compress = TRUE)
```

### 2. List Contents

Use `h5_ls()` to see the file structure.

```r
# List all objects recursively
h5_ls(file, recursive = TRUE)
#> "compressed_data" "data"            "data/array"      "data/matrix"    
#> "data/vector"     "factor_data"     "scalar_string"  

# List only the top level
h5_ls(file, recursive = FALSE)
#> "compressed_data" "data"            "factor_data"     "scalar_string"
```

### 3. Read Data

Use `h5_read()` to read data back into R. The function automatically restores the correct dimensions.

```r
# Read the matrix
mat_in <- h5_read(file, "data/matrix")
print(mat_in)
#>      [,1] [,2]
#> [1,]  1.1  3.3
#> [2,]  2.2  4.4

# Verify dimensions
print(dim(mat_in))
#> 2 2

all.equal(mat, mat_in)
#> TRUE
```

### 4. Attributes

You can easily read and write metadata using attributes.

```r
# Write attributes to the "data/matrix" dataset
h5_write_attr(file, "data/matrix", "units", "meters", dims = NULL)
h5_write_attr(file, "data/matrix", "scale", c(1.0, 1.0))

# List attributes
h5_ls_attr(file, "data/matrix")
#> "scale" "units"

# Read an attribute
units <- h5_read_attr(file, "data/matrix", "units")
print(units)
#> "meters"
```

### 5. Overwriting & Deleting

Writing to an existing path automatically overwrites the data. Use the `h5_delete_dataset*` functions to explicitly remove objects.

```r
# Overwrite the vector
h5_write(file, "data/vector", c(99, 100))
h5_read(file, "data/vector")
#> 99 100

# Delete the dataset
h5_delete_dataset(file, "data/vector")

# Delete the attribute
h5_delete_attr(file, "data/matrix", "units")

# Delete an entire group and its contents
h5_delete_group(file, "data")

h5_ls(file)
#> "compressed_data" "factor_data"     "scalar_string"
```

## When to Use Another HDF5 Package

`h5lite` is intentionally simple. If you need advanced control over HDF5 features, you should use a more comprehensive package like **`rhdf5`** (from Bioconductor) or **`hdf5r`** (from CRAN).

| Feature                | `h5lite`                                     | `rhdf5` / `hdf5r`                               |
| ---------------------- | -------------------------------------------- | ----------------------------------------------- |
| **Primary Goal**       | Simplicity and safety for common R objects   | Comprehensive control over all HDF5 features    |
| **API Style**          | Simple R functions (`h5_read`, `h5_write`)   | Wrappers for the complete HDF5 C-API            |
| **Ease of Use**        | **High**. Designed for R users.              | **Medium**. Requires some HDF5 knowledge.       |
| **Installation**       | **Easy**. Bundled HDF5 library.              | Can be complex (`hdf5r` requires system library). |
| **Dimension Order**    | **Automatic**. Transposes for you.           | **Manual**. User must manage C vs. R order.     |
| **Numeric Safety**     | **Safe**. Reads numbers as `double`.         | **User's choice**. Can read as integers (risk of overflow). |
| **Object Overwrite**   | **Automatic**.                               | **Manual**. Requires check/delete first.        |
| **Compression**        | Simple on/off (`compress = TRUE`).           | Full control over filters, chunking, etc.       |

**Use `rhdf5` or `hdf5r` if you need to:**
-   Work with complex or custom HDF5 data types (e.g., compound types for data frames, bitfields).
-   Have fine-grained control over file properties, chunking, or compression filters.
-   Perform partial I/O (i.e., read or write a small slice of a very large on-disk dataset).

**Use `h5lite` if you want to:**
-   Quickly and safely save R matrices, arrays, and other objects to a file.
-   Avoid thinking about low-level details.
