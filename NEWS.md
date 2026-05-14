# h5lite 2.1.1.1

* Fixed warnings introduced by GCC 16: `‘%d’ directive output may be truncated` in `utils.c`.


# h5lite 2.1.1.0

* New functions: `h5_compression()` and `h5_inspect()`.
* Added support for a variety of compression codecs - see `vignette('compression')`.
* Added support for partial reading - see `vignette('partial-reading')`.
* `h5_length()` and `h5_dim()` now return numeric values instead of integer to support very large datasets.



# h5lite 2.0.0.2

* Initial CRAN submission.
