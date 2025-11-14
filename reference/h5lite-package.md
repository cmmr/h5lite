# h5lite: A Simple and Lightweight HDF5 Interface

The h5lite package provides a simple, lightweight, and user-friendly
interface for reading and writing HDF5 files. It is designed for R users
who want to save and load R objects (vectors, matrices, arrays) to an
HDF5 file without needing to understand the low-level details of the
HDF5 C API.

## Details

`h5lite` handles common tasks automatically:

- Saving R objects with the correct dimensions.

- Reading data back into R as matrices or arrays.

- Reading and writing R `factor` objects as native HDF5 `ENUM` types.

- Automatically overwriting data and creating parent groups.

- Writing compressed datasets.

- Safely reading all numeric types without integer overflow.

- Reading and writing R `raw` vectors.

This package uses the HDF5 library developed by The HDF Group
(<https://www.hdfgroup.org/>).

## See also

Useful links:

- <https://cmmr.github.io/h5lite/>

## Author

**Maintainer**: Daniel P. Smith <dansmith01@gmail.com>
