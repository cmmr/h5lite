# h5lite 2.2.0.0

* Fixed Blosc codecs without a level of their own (`"blosc1"`, `"blosc2"`, `"blosc2-ndlz"`, `"blosc1-snappy"`, standard `"blosc*-lz4"`) and `"blosc2-zfp-acc-*"` storing data uncompressed.
* `"blosc1-gzip"` and `"blosc2-gzip"` now use Blosc instead of plain gzip.
* ZFP and `float_rounding` no longer corrupt `NA`, `NaN`, or `Inf`: ZFP falls back to gzip and `float_rounding` is skipped for data containing them.
* `"lz4-[level]"` now passes the requested LZ4-HC level instead of always using level 9.
* `compress = "none"` no longer chunks or shuffles the data, and `compress = TRUE` now selects gzip instead of no compression.
* Unsupported data with `"blosc2-zfp-*"` now falls back to the default shuffle + gzip pipeline.
* `h5_inspect()` no longer prints large chunk dimensions in scientific notation.
* Reorganized the vignettes; `vignette('compression')` now covers every bundled codec, lossy compression, sharing files with other software, and chunk tuning.


# h5lite 2.1.1.1

* Fixed warnings introduced by GCC 16: `‘%d’ directive output may be truncated` in `utils.c`.


# h5lite 2.1.1.0

* New functions: `h5_compression()` and `h5_inspect()`.
* Added support for a variety of compression codecs - see `vignette('compression')`.
* Added support for partial reading - see `vignette('partial-reading')`.
* `h5_length()` and `h5_dim()` now return numeric values instead of integer to support very large datasets.



# h5lite 2.0.0.2

* Initial CRAN submission.
