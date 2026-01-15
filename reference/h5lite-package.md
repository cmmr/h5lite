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

- **Safe by Default:** Auto-selects a safe R data type for numeric data
  to prevent overflow.

- **Easy Installation:** The required HDF5 library is bundled with the
  package.

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
([ORCID](https://orcid.org/0000-0002-2479-2044))

Other contributors:

- Alkek Center for Metagenomics and Microbiome Research \[copyright
  holder, funder\]
