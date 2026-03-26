# h5lite

[![cran](https://img.shields.io/cran/v/h5lite?logo=r&label=CRAN)](https://CRAN.R-project.org/package=h5lite)
[![conda](https://img.shields.io/conda/v/conda-forge/r-h5lite?logo=anaconda&label=conda)](https://anaconda.org/conda-forge/r-h5lite)
[![covr](https://img.shields.io/codecov/c/gh/cmmr/h5lite?logo=codecov)](https://app.codecov.io/gh/cmmr/h5lite)

**h5lite** is the pain-free way to work with HDF5 files in R.

It is designed for data scientists who want to read/write objects and
move on, and for package developers who need a reliable, dependency-free
storage backend.

## Why h5lite?

If you’ve struggled with complex HDF5 bindings in the past, `h5lite`
offers a fresh approach:

1.  **It Just Works:** No need to understand HDF5 dataspaces,
    hyperslabs, or property lists. `h5lite` maps R objects (numeric,
    character, factor, data.frame, and more) directly to their HDF5
    equivalents.

2.  **Zero System Dependencies:** `h5lite` bundles the HDF5 library (via
    `hdf5lib`). Users do **not** need to install HDF5 system libraries
    manually.

3.  **Smart Defaults, Full Control:** It automatically selects the most
    efficient data types (e.g., saving space by storing small integers
    as `int8`), but gives you granular control when you need to conform
    to a strict spec.

## Installation

Install the released version from CRAN:

``` r
install.packages("h5lite")
```

Or the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("cmmr/h5lite")
```

## Quick Start

The API consists primarily of two functions:
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) and
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md).

``` r
library(h5lite)
file <- tempfile(fileext = ".h5")

# 1. Write simple objects
h5_write(1:10, file, "my_vector")
h5_write(I(42), file, "my_vector", attr = "my_id")
h5_write(matrix(rnorm(9), 3, 3), file, "my_matrix")

# 2. Write a list (creates a group hierarchy)
config <- list(version = 1.0, params = list(a = 1, b = 2))
h5_write(config, file, "simulation_config")

# 3. Read it back
my_vec <- h5_read(file, "my_vector")

# 4. Inspect the file
h5_ls(file)
#> [1] "my_vector"                  "my_matrix"                  "simulation_config"         
#> [4] "simulation_config/version"  "simulation_config/params"   "simulation_config/params/a"
#> [7] "simulation_config/params/b"

h5_str(file)
#> /
#> ├── my_vector <uint8 × 10>
#> │   └── @my_id <uint8 scalar>
#> ├── my_matrix <float64 × 3 × 3>
#> └── simulation_config/
#>     ├── version <uint8 × 1>
#>     └── params/
#>         ├── a <uint8 × 1>
#>         └── b <uint8 × 1>
```

## Smart Data Typing

`h5lite` inspects your data and chooses the safest, most compact HDF5
data type automatically. You don’t need to know the specific HDF5 type
codes; `h5lite` handles the translation.

``` r
# R uses 32-bit integers by default
x <- 1:100 

# h5lite detects these values fit in 8 bits and saves space automatically
h5_write(x, file, "smart_ints")

h5_str(file)
#> ...
#> └── smart_ints <uint8 x 100>
```

## Power User Features

### The `as` Argument: Precise Control

Need to conform to a specific file specification? The `as` argument
allows you to override automatic behavior and explicitly define on-disk
types.

``` r
# Force specific numeric types
h5_write(1:10, file, "dataset_a", as = "int32")
h5_write(rnorm(10), file, "dataset_b", as = "float32")

# Control string lengths (e.g., fixed-length ASCII for compatibility)
h5_write(c("A", "B"), file, "fixed_strs", as = "ascii[10]")

h5_str(file)
#> ...
#> ├── dataset_a <int32 × 10>
#> ├── dataset_b <float32 × 10>
#> └── fixed_strs <ascii[10] × 2>
```

When writing Data Frames, you can map types for specific columns using a
named vector.

``` r
df <- data.frame(
  id    = 1:5, 
  score = c(1.1, 2.2, 3.3, 4.4, 5.5),
  note  = c("a", "b", "c", "d", "e")
)

# Store 'id' as 16-bit integer, 'score' as 32-bit float, and coerce 'note' to ascii
h5_write(df, file, "experiment_data", 
         as = c(id = "uint16", score = "float32", note = "ascii"))

h5_str(file)
#> ...
#> └── experiment_data <compound[3] × 5>
#>     ├── $id <uint16>
#>     ├── $score <float32>
#>     └── $note <ascii>
```

### Advanced Compression & Chunking

`h5lite` natively bundles an extensive suite of state-of-the-art
compression filters (including **Blosc2**, **Zstandard**, **LZ4**, and
lossy **ZFP**). For simple use cases, you can pass a string
configuration to the `compress` argument. For precise control over the
pipeline—including chunk sizing, bitshuffling, and Scale-Offset
scaling—use the
[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
function.

``` r
# Simple setup: High-performance Blosc2 with Zstandard
h5_write(rnorm(1000), file, "data_blosc", compress = "blosc2-zstd")

# Advanced setup: LZ4 compression, optimal integer packing, and custom chunk sizing
cmp <- h5_compression("lz4-9", int_packing = TRUE, chunk_size = 512 * 1024)
h5_write(1:1000, file, "data_custom", compress = cmp)
```

### Efficient Partial Reading

For large datasets that exceed system RAM, `h5lite` provides partial
reading via `start` and `count` parameters. It automatically targets the
most logical dimension (e.g., rows in a matrix or elements in a vector).

``` r
# Read a 100-row slice starting from row 500
subset <- h5_read(file, "large_matrix", start = 500, count = 100)
```

## Comparison

| Feature               | h5lite                     | rhdf5 / hdf5r                                          |
|:----------------------|:---------------------------|:-------------------------------------------------------|
| **Philosophy**        | “Opinionated” & Simple     | Comprehensive Wrapper                                  |
| **API Style**         | Native R (`read`/`write`)  | Low-level (Files, Dataspaces, Memspaces)               |
| **HDF5 Installation** | **Bundled** (Zero-config)  | **System Requirement** (Manual install often required) |
| **Data Typing**       | Automatic (safe defaults)  | Manual (user specified)                                |
| **Partial I/O**       | **Supported** (Simplified) | Supported (Manual hyperslabs)                          |
| **Learning Curve**    | Low (Minutes)              | High (Days)                                            |

**Use `rhdf5` or `hdf5r` if you need to:**

- Work with complex or custom HDF5 data types not supported by `h5lite`
  (e.g., bitfields, references, variable-length nested arrays).
- Perform advanced, multi-dimensional hyperslab selections that cannot
  be expressed with simple `start`/`count` parameters.

**Use `h5lite` if you want to:**

- Quickly and safely get data into or out of a file.
- Take advantage of modern, zero-config compression pipelines (Blosc2,
  Zstd, ZFP) without building system libraries.
- Perform efficient partial reads without the complexity of low-level
  hyperslab math.
- Avoid thinking about low-level details.

## Documentation

- **[Get Started](https://cmmr.github.io/h5lite/articles/h5lite.html)**:
  A general introduction.
- **[Atomic
  Vectors](https://cmmr.github.io/h5lite/articles/atomic-vectors.html)**:
  Details on vectors and scalars.
- **[Data
  Types](https://cmmr.github.io/h5lite/articles/data-types.html)**:
  Controlling storage types.
- **[Compression](https://cmmr.github.io/h5lite/articles/compression.html)**:
  Configuring modern codecs and tuning chunk size.
- **[Partial
  Reading](https://cmmr.github.io/h5lite/articles/partial-reading.html)**:
  Efficiently reading data subsets with `start` and `count`.
- **[Matrices and
  Arrays](https://cmmr.github.io/h5lite/articles/matrices.html)**:
  Handling multi-dimensional data.
- **[Data
  Frames](https://cmmr.github.io/h5lite/articles/data-frames.html)**:
  Using compound datasets.
- **[Organization](https://cmmr.github.io/h5lite/articles/organization.html)**:
  Using groups and lists to structure files.
- **[Attributes
  In-Depth](https://cmmr.github.io/h5lite/articles/attributes-in-depth.html)**:
  A deep dive into metadata handling.
- **[Object-Oriented
  Interface](https://cmmr.github.io/h5lite/articles/oo-interface.html)**:
  A guide to the
  [`h5_open()`](https://cmmr.github.io/h5lite/reference/h5_open.md)
  handle for a streamlined workflow.
- **[Parallel
  Processing](https://cmmr.github.io/h5lite/articles/parallel-io.html)**:
  Guide for multi-threaded and multi-process access.

![](https://cmmr-repos.goatcounter.com/count?p=/h5lite)
