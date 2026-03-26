# Compression

HDF5 supports transparent data compression, allowing you to drastically
reduce the file size of your datasets with minimal effort. While the
HDF5 ecosystem has historically relied on standard `gzip` and `szip`,
modern data pipelines require higher throughput and advanced techniques
like lossy floating-point compression and optimized bitshuffling.

Powered by `hdf5lib`, `h5lite` bundles an extensive suite of
state-of-the-art compression filters natively, meaning you can use
modern codecs like **Blosc2**, **Zstandard (Zstd)**, **LZ4**, and
**ZFP** without installing any external system dependencies.

This vignette covers how to configure these compression pipelines using
the
[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
function, how to choose the right algorithm, how to tune chunk sizes,
and how to inspect your results using
[`h5_inspect()`](https://cmmr.github.io/h5lite/reference/h5_inspect.md).

``` r
library(h5lite)
file <- tempfile(fileext = ".h5")
```

## The `compress` Argument and `h5_compression()`

For simple use cases, you can pass a configuration string directly to
the `compress` argument of
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md).
`h5lite` handles the underlying chunking requirements automatically.

``` r
# Standard gzip compression at level 5
h5_write(rnorm(1000), file, "data/simple_gzip", compress = "gzip-5")

# High-performance Blosc2 with Zstandard
h5_write(rnorm(1000), file, "data/simple_blosc2", compress = "blosc2-zstd-5")
```

For advanced control over the entire compression pipeline - including
chunk sizing, pre-filters, data scaling, and checksums - use the
[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
function to build a configuration object to pass to
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md).

``` r
# Advanced pipeline: LZ4 compression + optimal integer packing + Fletcher32 checksum
cmp <- h5_compression(
  compress    = "lz4-9", 
  int_packing = TRUE, 
  checksum    = TRUE,
  chunk_size  = 512 * 1024 # 512 KB chunks
)

h5_write(1:1000, file, "data/advanced", compress = cmp)
```

### Valid Compression Strings Reference

The `compress` argument accepts specific string syntaxes to define both
the codec and its operational level. The table below lists all valid
combinations and indicates whether they require, permit, or forbid a
level or parameter suffix.

[TABLE]

------------------------------------------------------------------------

## Choosing a Codec: Modern vs. Legacy

With so many options available, selecting the right codec depends on
whether you are optimizing for extreme read/write speed, minimal file
size, or universal compatibility.

### 1. Blosc2 (Highly Recommended)

**Blosc2** is a high-performance meta-compressor optimized for binary
data. It automatically handles multi-threading and applies a highly
optimized internal bitshuffle algorithm before passing the data to a
sub-compressor.

- **`"blosc2-zstd-[level]"`**: Offers the best overall balance of
  extreme read/write speeds and excellent compression ratios. It
  effectively replaces standard gzip for modern analytical workloads.

- **`"blosc2-lz4-[level]"`**: Exceptionally fast. Best used when
  read/write speed is the absolute highest priority and storage space is
  less of a concern.

### 2. Standalone Modern Codecs

If you prefer not to use the Blosc2 wrapper, you can call modern codecs
directly:

- **`"zstd-[level]"`**: Zstandard (levels 1-22). Vastly superior to gzip
  in both speed and compression ratio.

- **`"lz4-[level]"`**: Standard LZ4 (level 0) or LZ4-HC (levels 1-12).

### 3. Gzip (The Universal Standard)

- **`"gzip-[level]"`**: Levels 1-9 (default is 5). Every compiled HDF5
  library worldwide supports gzip. Use this *only* if you plan to share
  your `.h5` files with external collaborators using older Python/Julia
  tools, or if you are archiving them for long-term storage where
  universal compatibility is mandatory.

### 4. Legacy Codecs (Obsolete or Niche)

- **`"szip-nn"` / `"szip-ec"`**: Historically fast for scientific data,
  provided safely here via the permissively licensed `libaec` library.
  Because the original library was frequently missing from legacy HDF5
  distributions, szip never saw universal adoption and is now largely
  obsolete compared to Blosc2 or Zstd.

- **`"blosc1"`**, **`"snappy"`**, **`"lzf"`**, **`"bzip2"`**: Included
  strictly to maintain backward compatibility, allowing you to read
  archived `.h5` files and write to legacy data processing pipelines.
  These early-generation algorithms lack the multi-threading
  optimizations, speeds, and compression ratios of modern alternatives,
  making them generally unsuitable for completely new datasets.

------------------------------------------------------------------------

## Lossy Compression: ZFP and Scale-Offset

For massive numeric datasets, lossless compression may not provide
enough space savings. `h5lite` supports two methods to discard
mathematically insignificant precision in exchange for massive
compression ratios.

### ZFP (Floating-Point & Integer)

ZFP is a specialized algorithm designed for high-throughput, lossy
compression of numerical arrays. It offers incredible ratios but
**requires purely numeric values**.

*(Note: The standalone `"zfp-..."` codecs support both integers and
floats. However, if ZFP is wrapped inside Blosc2 via `"blosc2-zfp-..."`,
it can only encode floating-point values).*

- **Accuracy Mode (`"zfp-acc-[tolerance]"`):** Guarantees that no
  decompressed value will differ from the original by more than the
  given absolute tolerance (e.g., `"zfp-acc-0.001"`).
- **Precision Mode (`"zfp-prec-[bits]"`):** Preserves a specific number
  of bits of precision (e.g., `"zfp-prec-16"`).
- **Rate Mode (`"zfp-rate-[bits]"`):** Forces the compressed data to use
  exactly a certain number of bits of storage per value (e.g.,
  `"zfp-rate-8"`).

``` r
# Lossy compression: decompressed values will be accurate to within +/- 0.05
cmp_zfp <- h5_compression("zfp-acc-0.05")
h5_write(rnorm(1e5), file, "data/zfp_floats", compress = cmp_zfp)
```

### Scale-Offset (Integer Packing & Float Rounding)

The native HDF5 Scale-Offset filter mathematically scales your data so
it can be stored using fewer bits. It processes data one chunk at a
time, and automatically reverses these operations when you read the file
to reproduce your original values.

- **Integer Packing (`int_packing`):** When you set
  `int_packing = TRUE`, HDF5 subtracts the minimum value in the chunk
  from all the other values. It then encodes these new, smaller values
  using the exact minimum number of bits necessary. For datasets with
  small ranges or lots of zeros, this saves a massive amount of space.
  (Alternatively, passing a number like `int_packing = 8` forces it to
  pack the data into exactly 8 bits).

- **Float Rounding (`float_rounding`):** When you pass an integer (like
  `float_rounding = 3`), HDF5 multiplies all the floating-point values
  by 10^3 to shift the decimal point. It then rounds the results to the
  nearest whole integer. Once they are integers, it applies the exact
  same bit-packing method described above. When the data is decoded, the
  operations are run in reverse to restore the original values, less any
  exact precision lost during the initial rounding step.

``` r
# 1. Integer Packing Example
# A dataset with a small range of values (e.g., years 2000 to 2050)
years <- sample(2000:2050, 100000, replace = TRUE)

# By default, R uses 32-bit integers. 
# With int_packing = TRUE, HDF5 subtracts 2000 from all values,
# leaving numbers from 0 to 50, which fit perfectly into just 6 bits!
cmp_int <- h5_compression("lz4-9", int_packing = TRUE)
h5_write(years, file, "data/packed_years", compress = cmp_int)

# 2. Float Rounding Example
# Sensor data where anything beyond 2 decimal places is just noise
sensor_data <- rnorm(100000, mean = 98.6, sd = 0.5)

# Multiplies by 10^2 (e.g., 98.614... -> 9861.4...), rounds to 9861, and bit-packs.
# When read back into R, it is automatically divided by 100 to restore 98.61.
cmp_float <- h5_compression("zstd-5", float_rounding = 2)
h5_write(sensor_data, file, "data/rounded_sensors", compress = cmp_float)
```

------------------------------------------------------------------------

## Filter Interactions & Invalid Combinations

Filters in HDF5 operate in a sequential pipeline, and certain filters
destroy the underlying byte structures that downstream algorithms rely
on.
[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
strictly enforces mutual exclusions and will throw an error if you
attempt an invalid combination:

1.  **Shuffling vs. Scale-Offset:** Pre-filters like Bitshuffle and Byte
    Shuffle rearrange the byte stream to group similar bits together for
    better compression. Scale-Offset (`int_packing` or `float_rounding`)
    packs data into non-standard bit widths, which destroys byte
    alignment. Therefore, **all automatic shuffling is forcefully
    disabled if Scale-Offset is active**.

2.  **Mathematical vs. Shuffling Codecs:** ZFP and Szip perform
    mathematical compression directly on raw numerical values. They will
    completely fail or corrupt if the bitstream is rearranged
    beforehand. **Do not combine ZFP or Szip with Scale-Offset,
    Bitshuffle, or Blosc2 pre-filters.**

3.  **String Data Limitations:** Szip and ZFP cannot be applied to
    character vectors. String compression relies on standard algorithms
    like `gzip` or `zstd`, and only works on *fixed-length* strings.
    Variable-length strings (such as those containing `NA` values)
    cannot be compressed by chunk filters at all.

------------------------------------------------------------------------

## Tuning Chunk Size

HDF5 does not compress a dataset as one monolithic block. Instead, it
divides the dataset into smaller “chunks” and compresses each
independently.

By default,
[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
targets a **1 MB chunk size** (`chunk_size = 1048576`), which is an
excellent default. However, you should manually tune this depending on
your specific access patterns:

- **Too Small (\< 10 KB):** Imposes huge metadata overhead. The internal
  HDF5 B-tree will bloat the file size, and the compression algorithms
  won’t have enough data to identify repeating patterns.

- **Too Large (\> 50 MB):** If you only want to read a tiny slice (e.g.,
  10 rows) of your dataset, HDF5 is forced to load and decompress the
  *entire chunk* containing those rows into memory. Overly large chunks
  cause massive read latency for subsetting operations.

``` r
# Optimizing for reading small, 100KB slices at a time
cmp_chunk <- h5_compression("blosc2-zstd-5", chunk_size = 102400)
h5_write(matrix(rnorm(10000), 100, 100), file, "data/tuned_chunks", compress = cmp_chunk)
```

------------------------------------------------------------------------

## Evaluating Results with `h5_inspect()`

It can be difficult to know exactly how well your compression strategy
is working. The
[`h5_inspect()`](https://cmmr.github.io/h5lite/reference/h5_inspect.md)
function allows you to peek under the hood of any dataset, revealing its
storage layout, chunk dimensions, the exact filter pipeline applied, and
the resulting compression ratio.

``` r
# Write some highly compressible (sequential) integer data
cmp_pack <- h5_compression('lz4-9', int_packing = TRUE, checksum = TRUE)
h5_write(matrix(5001:5100, 10, 10), file, "inspect/packed_mtx", compress = cmp_pack)

# Inspect the dataset's properties
h5_inspect(file, "inspect/packed_mtx")
```

**Output:**

``` text
<HDF5 Dataset Properties>
  Type:    uint16              Size:    200.00 B
  Layout:  chunked             Disk:    120.00 B
  Chunks:  [10 x 10]           Ratio:   1.67x
  Pipeline: scaleoffset -> lz4 -> fletcher32
```

You can use this compression ratio readout to iteratively test different
[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
configurations until you find the perfect balance for your specific
data.

``` r
# Clean up
unlink(file)
```

*For additional details about these codecs and the underlying library,
please see <https://cmmr.github.io/hdf5lib/articles/compression.html>.*
