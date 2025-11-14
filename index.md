# h5lite

**h5lite** is an R package that provides a simple, lightweight, and
user-friendly interface for reading and writing HDF5 files.

It is designed for R users who just want to save and load R objects
(vectors, matrices, arrays) to an HDF5 file without needing to
understand the low-level details.

`h5lite` handles common tasks automatically:

- Saving R objects with the correct dimensions.
- Reading data back into R as matrices or arrays.
- **Reading and writing R `factor` objects as native HDF5 `ENUM`
  types.**
- Automatically overwriting data and creating parent groups.
- **Writing compressed datasets.**
- Safely reading all numeric types without integer overflow.
- Reading and writing R `raw` vectors.

This package uses the HDF5 library developed by The HDF Group
(<https://www.hdfgroup.org/>).

## Installation

You can install the released version of `h5lite` from CRAN:

    install.packages("h5lite")

## Quick Start

The API is designed to be simple and predictable.

    library(h5lite)

    file <- tempfile(fileext = ".h5")

### 1. Write Data

Use [`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
to write vectors, matrices, or arrays.

    # Write a vector
    h5_write(file, "data/vector", 1:10, dtype = "integer")

    # Write an R matrix
    mat <- matrix(c(1.1, 2.2, 3.3, 4.4), nrow = 2, ncol = 2)
    h5_write(file, "data/matrix", mat)

    # Write a 3D array
    arr <- array(1L:24L, dim = c(2, 3, 4))
    h5_write(file, "data/array", arr, dtype = "integer")

    # Write a scalar (dims = NULL)
    h5_write(file, "scalar_string", "Hello!", dims = NULL)

    # Write a factor (automatically creates an ENUM type)
    fac <- as.factor(c("a", "b", "a", "c"))
    h5_write(file, "factor_data", fac)

    # Write a large vector with compression enabled
    h5_write(file, "compressed_data", 1:10000, compress = TRUE)

### 2. List Contents

Use [`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md) to see
the file structure.

    # List all objects recursively
    h5_ls(file)
    #> [1] "data"              "data/array"        "data/matrix"
    #> [4] "data/vector"       "scalar_string"

    # List only the top level
    h5_ls(file, recursive = FALSE)
    #> [1] "data"            "scalar_string"

### 3. Read Data

Use [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) to
read data back into R. The function automatically restores the correct
dimensions.

    # Read the matrix
    mat_in <- h5_read(file, "data/matrix")
    print(mat_in)
    #>      [,1] [,2]
    #> [1,1]  1.1  3.3
    #> [2,1]  2.2  4.4

    # Verify dimensions
    print(dim(mat_in))
    #> [1] 2 2

    all.equal(mat, mat_in)
    #> [1] TRUE

### 4. Attributes

You can easily read and write metadata using attributes.

    # Write attributes to the "data/matrix" dataset
    h5_write_attr(file, "data/matrix", "units", "meters", dims = NULL)
    h5_write_attr(file, "data/matrix", "scale", c(1.0, 1.0), dims = c(1, 2))

    # List attributes
    h5_ls_attr(file, "data/matrix")
    #> [1] "units" "scale"

    # Read an attribute
    units <- h5_read_attr(file, "data/matrix", "units")
    print(units)
    #> [1] "meters"

### 5. Overwriting & Deleting

Writing to an existing path automatically overwrites the data. To
explicitly delete objects:

    # Overwrite the vector
    h5_write(file, "data/vector", c(99, 100))
    h5_read(file, "data/vector")
    #> [1] 99 100

    # Delete the dataset
    h5_delete(file, "data/vector")

    # Delete the attribute
    h5_delete_attr(file, "data/matrix", "units")

    # Delete an entire group and its contents
    h5_delete_group(file, "data")

    h5_ls(file)
    #> [1] "scalar_string"

## Comparison to Other HDF5 Packages

- **`rhdf5` (Bioconductor):** This is a powerful and mature package that
  provides a comprehensive, low-level wrapper around the HDF5 C API. It
  is excellent if you need fine-grained control over file properties,
  chunking, compression, and complex datatypes. It bundles its HDF5
  dependency via the `Rhdf5lib` Bioconductor package.

- **`hdf5r` (CRAN):** This package provides a modern, R6 class-based
  interface to HDF5. It is also very comprehensive and powerful, but it
  **requires users to install and manage a separate, system-level HDF5
  library**, which can make installation complex.

- **`h5lite`:** This package is **not** a comprehensive wrapper. It is
  an “opinionated” interface focused on simplicity and safety for the
  most common 80% of use cases. `h5lite` prioritizes a simple, R-like
  functional syntax (`h5_read`, `h5_write`) and **bundles its HDF5
  dependency** (via `hdf5lib`) for easy installation.

| Feature                  | `h5lite`                                   | `rhdf5` / `hdf5r`                               |
|--------------------------|--------------------------------------------|-------------------------------------------------|
| **API Style**            | Simple R functions (`h5_read`, `h5_write`) | Comprehensive HDF5 API wrappers                 |
| **Ease of Use**          | **High**. Designed for R users.            | **Medium**. Requires HDF5 knowledge.            |
| **HDF5 Dependency**      | **Bundled** (via `hdf5lib`)                | Bundled (`rhdf5`) or External (`hdf5r`)         |
| **Dimension Order**      | **Automatic**. Transposes C \<-\> R order. | **Manual**. User must manage transposing.       |
| **Integer Reading**      | **Safe** (always `double`).                | **Precise** (can overflow `int`).               |
| **Group Creation**       | **Automatic** (`mkdir -p`).                | **Manual** (requires explicit `h5createGroup`). |
| **Object Overwrite**     | **Automatic**. `h5_write` overwrites.      | **Manual** (requires check/delete first).       |
| **Chunking/Compression** | **Automatic Decompression Only**.          | **Full support**.                               |

**Conclusion:** Use `rhdf5` or `hdf5r` if you are an advanced user who
needs fine-grained control over HDF5 file properties. Use `h5lite` if
you want to quickly and safely save R matrices, arrays, and lists to an
HDF5 file without worrying about the low-level details.

## Limitations

`h5lite` is intentionally simple and is **not** a complete HDF5 wrapper.
It focuses on reading and writing R’s atomic vectors, matrices, and
arrays.

Features that are **not supported** include:

- **Writing Compressed or Chunked Data:** `h5lite` writes data in a
  simple, contiguous layout. It does not provide options to set chunking
  or compression filters (like gzip). It *can*, however, read data that
  was compressed by another program.

- **Compound Datatypes:** HDF5’s struct-like `H5T_COMPOUND` type is not
  supported. `h5lite` cannot read or write R data frames as compound
  types.

- **Complex Datatypes:** `H5T_ENUM` (enumerations/factors),
  `H5T_BITFIELD`, and most `H5T_REFERENCE` types are not supported.

- **Property Lists:** `h5lite` does not expose advanced property lists
  (e.g., for setting fill values, link creation properties, etc.).

If you need any of these advanced features, please use `rhdf5` or
`hdf5r`.

## File Structure Utility Functions

### Inspecting On-Disk Types

Since `h5_read` converts all numbers to `double` for safety, you can use
`h5_typeof` to see the *actual* on-disk storage type.

    # Write data as 32-bit floats and 16-bit integers

    h5_write(file, "floats", 1:5, dtype = "float")
    h5_write(file, "shorts", 1:5, dtype = "short")

    h5_typeof(file, "floats")
    #> [1] "FLOAT"
    h5_typeof(file, "shorts")
    #> [1] "SHORT"
    h5_typeof_attr(file, "data/matrix", "scale")
    #> [1] "DOUBLE"

### Inspecting Dimensions

Use `h5_dim` to check the dimensions of a dataset without reading its
(potentially very large) data.

    h5_dim(file, "data/array")
    #> [1] 2 3 4

### Creating Empty Groups

If you want to create an empty group structure, use `h5_create_group`.

    h5_create_group(file, "/metadata/logs")
    h5_ls(file)
    #> [1] "metadata"       "metadata/logs"  "scalar_string"
