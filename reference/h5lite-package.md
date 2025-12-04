# h5lite: A Simple and Lightweight HDF5 Interface

The `h5lite` package provides a simple, lightweight, and user-friendly
interface for reading and writing HDF5 files. It is designed for R users
who want to save and load common R objects (vectors, matrices, arrays,
factors, and data.frames) to an HDF5 file without needing to understand
the low-level details of the HDF5 C API.

## Key Features

- **Simple API:** Use familiar functions like
  [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) and
  [`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md).

- **Automatic Handling:** Dimensions, data types, and group creation are
  handled automatically.

- **Safe by Default:** Numeric data is read as `double` to prevent
  integer overflow.

- **Easy Installation:** The required HDF5 library is bundled with the
  package.

## Vignettes

The following vignettes provide detailed examples and explanations for
common tasks:

- [`vignette("h5lite")`](https://cmmr.github.io/h5lite/articles/h5lite.md):
  A general introduction to the package.

- [`vignette("atomic-vectors")`](https://cmmr.github.io/h5lite/articles/atomic-vectors.md):
  Details on writing atomic vectors and scalars.

- [`vignette("matrices")`](https://cmmr.github.io/h5lite/articles/matrices.md):
  Details on writing matrices and arrays.

- [`vignette("data-frames")`](https://cmmr.github.io/h5lite/articles/data-frames.md):
  Details on writing `data.frame` objects.

- [`vignette("data-organization")`](https://cmmr.github.io/h5lite/articles/data-organization.md):
  How to organize data using groups and lists.

- [`vignette("attributes-in-depth")`](https://cmmr.github.io/h5lite/articles/attributes-in-depth.md):
  A deep dive into using attributes.

- [`vignette("parallel-io")`](https://cmmr.github.io/h5lite/articles/parallel-io.md):
  Guide for using h5lite in parallel environments.

## See also

Useful links:

- <https://cmmr.github.io/h5lite/>

- Report bugs at <https://github.com/cmmr/h5lite/issues>

Key functions:
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md),
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md),
[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md),
[`h5_str()`](https://cmmr.github.io/h5lite/reference/h5_str.md)

## Author

**Maintainer**: Daniel P. Smith <dansmith01@gmail.com>
