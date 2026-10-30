# h5lite 2.2.0.0

* Works with hdf5lib 2.2.0.0 and 2.2.0.1. Some fixes take effect only when h5lite is built with hdf5lib 2.2.0.1 or later; they are listed under "With hdf5lib 2.2.0.1" below.
* New `h5_threads()` sets how many threads `h5lite` uses for parallel work, currently the Blosc and Blosc2 codecs. The `H5LITE_NTHREADS` environment variable sets the default. Threads need hdf5lib 2.2.0.1 or later.

## Crashes and data loss

* Fixed an R crash when a partial read of variable-length strings failed (e.g. a fractional `start`). `start` and `count` must now be whole numbers.
* Fixed writing a data frame with a matrix column reading past the end of its other columns. Matrix columns, columns of the wrong length, and duplicate or empty column names are now errors.
* An R error raised mid-call no longer leaves the HDF5 file open (and, on Windows, locked) for the rest of the session. Strings marked with `"bytes"` encoding are now rejected before writing starts.
* A compression filter that rejects data when a dataset is closed (as HDF5 flushes its chunk cache) is now an error, and the incomplete dataset is removed. Previously HDF5 dropped the chunk silently.
* `h5_move()` no longer deletes a group moved into itself (e.g. `"g"` to `"g/sub"`); this is now an error.
* Dimension scales (the datasets holding `names`, `dimnames`, and `row.names`) are now kept consistent: `h5_move()` moves a dataset's scales with it, `h5_delete()` and overwriting delete them with it (scales not named after the dataset, such as netCDF coordinate variables, are detached but kept), deleting a scale detaches it, and writing a scale never overwrites an unrelated object (previously, writing `x` replaced anything named `x_names`, and could rewrite the names of a moved dataset).
* `h5_write(list, file, name, attr = ...)` no longer replaces the dataset `name` with a group; lists can't be written as attributes.
* List elements without unique, non-empty names are now an error instead of being dropped (or, for `list(a = 1, 2)`, deleting the group).
* Overwriting a group with a list now writes the new group in full before removing the old one, so a failure leaves the original intact.
* `POSIXct` times are now stored in UTC (previously local times were labelled `Z`), with fractional seconds. `POSIXlt` is now written like `POSIXct` instead of as an empty group.
* Fixed-length strings that fill their full width now keep their last character when read from files that pad with nulls or spaces (as h5py does).
* `utf8[n]` and fixed-length strings are no longer truncated in the middle of a multibyte character, and their width is measured in UTF-8 bytes.
* `as = "ascii"` now transliterates every string, not just the first.
* Values outside the range of the requested type (e.g. `70000` as `float16`, `2^63` as `int64`) are now an error instead of becoming `Inf` or wrapping around.
* `blosc2_truncate` no longer corrupts 32- and 64-bit integers, including those in data frames (it zeroed their low bits: with `blosc2_truncate = 10`, every `int32` below 8192 read back as 0), or turns `NA` into `NaN` or `Inf`. It now applies only to `float32` and `float64` data without `NA` or `NaN`.
* `int64` `NA` values now read back as `NA` instead of `-9.22e18`, and `uint64` values above the `int64` range read with `as = "bit64"` become `NA` (with a warning) instead of being clamped.

## Other fixes

* Enum values with no matching member, and attributes named like R's structural attributes (`dim`, `class`, ...), no longer produce malformed or reshaped results. Factors with empty-string levels can no longer be written.
* Reading a NULL dataset that has attributes no longer errors.
* Lists can be written to the root group (`h5_write(list, file, "/")`, `h5$write(list)`).
* `h5_create_file()` and `h5_open()` now work on read-only files.
* `as` fixes: an unnamed `as` (or non-`@` key) no longer applies to attributes when writing; `as` is now honored for factors (which can be stored as strings, e.g. `as = c(grade = "ascii[1]")`), raw, complex, `integer64`, NULL, and nested lists; `"skip"` and `"null"` must be spelled out rather than abbreviated; type-class keys like `.int` only match numeric data when reading; `"auto"` keeps the automatic type; attributes read or written directly accept plain or `@` keys; and `"null"` drops data frame columns when reading.
* A multi-value `start` on a data frame is now an error, and `start`/`count` on a group apply to each of its datasets.
* `h5_length()` returns 0 for NULL datasets and attributes.
* `h5_ls()` and `h5_names()` (for groups) now return names in the order `sort()` puts them, instead of an arbitrary order, and `full.names = TRUE` returns absolute paths. `h5_read()` on a group and `h5_str()` now follow the order objects were created (in files written by this version; name order otherwise), so lists read back in the order they were written.
* `h5_str()` shows names longer than 255 bytes, and `h5_str()` and `h5_attr_names()` no longer show HDF5's `DIMENSION_LIST`/`REFERENCE_LIST` attributes.
* HDF5's internal error stack is no longer printed before h5lite's error messages.
* `h5_open()` handle methods now accept the same arguments as the corresponding functions (e.g. `h5$read(name, start, count)`), `".."` works in absolute paths, and a relative file path keeps working after `setwd()`.
* `I()` around a length-one `POSIXct` now writes a scalar, and its warning for longer objects appears once.
* `h5_inspect()` reports filter parameters as non-negative numbers.

## Compression

* Fixed Blosc codecs without a level of their own (`"blosc1"`, `"blosc2"`, `"blosc2-ndlz"`, `"blosc1-snappy"`, standard `"blosc*-lz4"`) and `"blosc2-zfp-acc-*"` storing data uncompressed.
* `"blosc1-gzip"` and `"blosc2-gzip"` now use Blosc instead of plain gzip.
* ZFP and `float_rounding` no longer corrupt `NA`, `NaN`, or `Inf`: ZFP falls back to gzip and `float_rounding` is skipped for data containing them.
* `print(h5_inspect())` reads Blosc2's settings in the new layout as well as those written by earlier versions (including the `blosc2_truncate` bits of 1-D datasets and of negative settings) and by other software, lists the pre-filters in the order they run (truncation, delta, shuffle), and shows when Blosc2's ZFP codecs declined a dataset.
* `blosc2_delta` and `blosc2_truncate` are no longer passed to `"blosc2-ndlz"` and `"blosc2-zfp-..."`, which never ran them. `print(h5_inspect())` listed them anyway, and `blosc2_truncate = 8` made NDLZ use 8x8 cells. `print(h5_compression("blosc2-ndlz"))` no longer claims a bitshuffle.
* `blosc2_truncate` must be between -51 and 52, and not 0. A setting that keeps no bits or drops a whole mantissa used to leave the data uncompressed. For `float32` data, settings that would drop 23 bits or more are skipped.
* `"lz4-[level]"` now passes the requested LZ4-HC level instead of always using level 9.
* A ZFP tolerance or rate of 0 (e.g. `"blosc2-zfp-acc-0"`, which silently used a tolerance of 1) is now an error.
* `float_rounding` on `float16` or `bfloat16` data no longer makes the write fail; HDF5's Scale-Offset filter can't handle them, so it is skipped.
* `compress = "none"` no longer chunks or shuffles the data, and `compress = TRUE` now selects gzip instead of no compression.
* Unsupported data with `"blosc2-zfp-*"` now falls back to the default shuffle + gzip pipeline.
* Standalone ZFP (`"zfp-..."`) now falls back to the default shuffle + gzip pipeline for data whose chunks have no dimension longer than one (e.g. a single value) or more than four, which ZFP can't compress. The write used to fail.
* `h5_inspect()` no longer prints large chunk dimensions in scientific notation.
* Reorganized the vignettes; `vignette('compression')` now covers every bundled codec, lossy compression, sharing files with other software, and chunk tuning.

## With hdf5lib 2.2.0.1

These take effect when h5lite is built with hdf5lib 2.2.0.1 or later.

* Blosc and Blosc2 use the threads set by `h5_threads()`.
* Blosc2 datasets are stored in hdf5lib's new parameter layout, which keeps the reference HDF5-Blosc2 filter's values in its slots and packs the pre-filters and `blosc2_truncate` bits into the first. So `hdf5plugin` describes them by their last pre-filter, `h5py` can append to them, and `h5py` can read 1-D Blosc2 datasets. `hdf5plugin` used to read the pre-filter bitmask h5lite recorded as a single filter code, which isn't a valid one with `blosc2_delta` or `blosc2_truncate`. 1-D Blosc2 datasets written earlier can't be read by `h5py` until they are rewritten.
* `"blosc2-zfp-..."` now compresses arrays of more than four dimensions, and chunks with a dimension shorter than 4, which it used to store uncompressed. Data of fewer than four values is stored uncompressed, and `print(h5_inspect())` shows e.g. `blosc2 [zfp-acc] (declined: stored uncompressed)`.
* Blosc2 now compresses matrices and arrays after `int_packing` or `float_rounding`. It used to refuse every chunk with two or more dimensions after Scale-Offset, leaving them packed but otherwise uncompressed.
* `"snappy"` datasets are written in the block layout of snappy-cuda, the filter registered for Snappy's HDF5 filter ID. h5lite built with hdf5lib 2.2.0.0 or earlier can't read them; older ones can still be read.
* Datasets compressed with SZ3 (filter 32024) can be read when an SZ3 plugin is on `HDF5_PLUGIN_PATH`. hdf5lib's read-only BitRound shim claimed SZ3's ID, which made them unreadable; it now uses BitRound's own, 32032, which `h5_inspect()` names `bitround`.


# h5lite 2.1.1.1

* Fixed warnings introduced by GCC 16: `‘%d’ directive output may be truncated` in `utils.c`.


# h5lite 2.1.1.0

* New functions: `h5_compression()` and `h5_inspect()`.
* Added support for a variety of compression codecs - see `vignette('compression')`.
* Added support for partial reading - see `vignette('partial-reading')`.
* `h5_length()` and `h5_dim()` now return numeric values instead of integer to support very large datasets.



# h5lite 2.0.0.2

* Initial CRAN submission.
