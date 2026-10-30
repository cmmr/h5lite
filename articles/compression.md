# Compression

HDF5 compresses data transparently. Datasets are compressed when they
are written and decompressed when they are read, so your R code stays
the same and only the file gets smaller. `h5lite` compresses every
dataset by default. Through `hdf5lib`, it also bundles a full set of
codecs: **gzip**, **szip**, **Zstandard**, **LZ4**, **bzip2**, **LZF**,
**Snappy**, **Bitshuffle**, **Blosc**, **Blosc2**, and **ZFP**. All of
them work out of the box, with no system libraries to install.

This vignette covers:

- [What `h5lite` does by default](#compression-by-default), and which
  objects get compressed.
- [How to choose a codec](#choosing-a-codec), including [how to
  benchmark your own data](#comparing-codecs-on-your-own-data).
- [Sharing compressed files](#sharing-files-with-other-software) with
  Python and other HDF5 software.
- [Lossy compression](#lossy-compression) for numeric data.
- [How the filter pipeline is assembled](#the-filter-pipeline), [how
  chunks are sized](#chunking), and [how to inspect the
  results](#inspecting-the-results).
- A [complete reference](#compression-string-reference) of compression
  strings.

## Compression by Default

You don’t have to do anything to get compression:

``` r

library(h5lite)
file <- tempfile(fileext = ".h5")

temps <- round(20 + cumsum(rnorm(1e5, sd = 0.05)), 2)
h5_write(temps, file, "temps/default")

h5_inspect(file, "temps/default")
#> <HDF5 Dataset Properties>
#>   Type:    float64             Size:    781.25 KB
#>   Layout:  chunked             Disk:    389.53 KB
#>   Chunks:  [100000]            Ratio:   2.01x
#>   Pipeline: shuffle -> gzip
```

The default, `compress = "gzip"`, means **gzip at level 5**, preceded by
HDF5’s byte **shuffle** filter, with the data split into **chunks of
about 1 MB**. Gzip is the default because every HDF5 installation can
read it.

To use a different codec, pass a string to `compress`:

``` r

h5_write(temps, file, "temps/zstd", compress = "zstd-5")
h5_write(temps, file, "temps/none", compress = "none")
```

To control more than the codec, such as the chunk size, a checksum, or
lossy pre-filters, build a configuration with
[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
and pass that instead. Printing the configuration shows the pipeline it
will build:

``` r

cmp <- h5_compression("zstd-5", checksum = TRUE, chunk_size = 256 * 1024)
cmp
#> <HDF5 Compression Configuration>
#>   Codec:           zstd-5
#>   Shuffle:         Byte Shuffle (Native HDF5)
#>   Chunk Size:      256.00 KB
#>   Checksum:        Fletcher32

h5_write(temps, file, "temps/configured", compress = cmp)
```

The same `compress` argument works with the object-oriented interface
(`h5$write()`). When you write a list, the configuration applies to
every dataset created from that list.

### What Gets Compressed

HDF5 can only compress *chunked datasets*, so a few kinds of objects are
always stored uncompressed:

| Object | Compressed? | Notes |
|:---|:--:|:---|
| Vectors, matrices, arrays | Yes | Numeric, logical, factor, complex, raw, and `integer64` data. |
| Data frames | Yes | Whole rows (compound records) are compressed together. |
| Fixed-length strings | Yes | Often compress extremely well. |
| Variable-length strings | No | The text lives outside the dataset’s chunks. See below. |
| Scalars (written with [`I()`](https://rdrr.io/r/base/AsIs.html)) | No | A single value is stored as-is. |
| Attributes | No | HDF5 does not support filters on attributes. |
| `NULL` and zero-length data | No | There is nothing to compress. |

**Strings deserve special attention.** By default, `h5lite` stores
character vectors as *fixed-length* strings when they contain no `NA`
and have similar lengths, and as *variable-length* strings otherwise.
Fixed-length strings sit in the chunks and compress like any other data.
Variable-length strings are kept in a separate area of the file, so the
filter pipeline only ever sees small references to them. If you want
text compressed, write it as fixed-length with `as = "utf8[]"`.
Fixed-length strings can’t hold `NA`, though.

``` r

words <- sample(c("control", "treatment", "placebo"), 1e4, replace = TRUE)
h5_write(words, file, "strings/fixed")
h5_inspect(file, "strings/fixed")
#> <HDF5 Dataset Properties>
#>   Type:    utf8[9]             Size:    87.89 KB
#>   Layout:  chunked             Disk:    21.87 KB
#>   Chunks:  [10000]             Ratio:   4.02x
#>   Pipeline: shuffle -> gzip
```

Very small datasets can end up a few bytes *larger* after compression
because of filter overhead. This is harmless and isn’t worth optimizing.

## Choosing a Codec

The right codec depends on who will read the file and whether you care
most about speed, size, or portability.

| If you want… | Use | Why |
|:---|:---|:---|
| Files that any HDF5 software can read | `"gzip"` (the default) | Built into every HDF5 library. |
| Fast I/O with good ratios | `"zstd-5"`, `"blosc2-zstd-5"` | Faster than gzip, with similar or better ratios. |
| The fastest possible I/O | `"lz4"`, `"bshuf-lz4"` | Plain LZ4 trades ratio for speed. Bitshuffling often wins the ratio back on numeric data. |
| The smallest lossless files | `"bshuf-zstd-19"`, `"zstd-19"` | Slow to write, but still fast to read. |
| Integers that span a narrow range | `int_packing = TRUE` with any codec | Stores each value in the fewest bits possible. |
| Numbers where a small error is fine | ZFP, `float_rounding`, `blosc2_truncate` | Lossy. See [Lossy Compression](#lossy-compression). |

Every codec except gzip and szip is an HDF5 *plugin*. Other software
needs that plugin installed to read the data. See [Sharing Files with
Other Software](#sharing-files-with-other-software) before using these
codecs for files that you hand off to others.

### Gzip

`"gzip-[level]"` (levels 1-9, default 5) is the universal standard. It
isn’t the fastest or the strongest codec, but any HDF5 reader in any
language can open it. Use it for files that you share, publish, or
archive. Higher levels are slower and often barely smaller than level 5.

### Zstandard and LZ4

- **`"zstd-[level]"`** (levels 1-22, default 3): Zstandard compresses
  about as well as gzip or better, in much less time. Levels 3-5 are a
  good balance. Levels above about 15 are much slower to write but no
  slower to read, which suits data that is written once and read many
  times.

- **`"lz4-[level]"`**: LZ4 favors speed over ratio. Level 0 (the
  default) is standard LZ4. Levels 1-12 select the slower, stronger
  LZ4-HC mode.

### Blosc2 and Bitshuffle

**Bitshuffle** rearranges data at the bit level before handing it to a
compressor (see [Shuffling](#shuffling)). On numeric data, this often
beats byte shuffling by a wide margin. You can get bitshuffling in two
ways:

- **`"bshuf-lz4"`** and **`"bshuf-zstd-[level]"`** use the standalone
  Bitshuffle plugin with a built-in LZ4 or Zstandard compressor.

- **`"blosc2-[codec]-[level]"`** uses **Blosc2**, a meta-compressor that
  splits each chunk into cache-sized blocks, bitshuffles them, and
  compresses them with a sub-codec: `"blosc2-zstd-5"` or
  `"blosc2-lz4-5"`, for example. Blosc2 also offers the optional
  [delta](#blosc2-delta) and
  [truncate-precision](#blosc2-truncate-precision) pre-filters, and it
  can run ZFP (`"blosc2-zfp-..."`).

Blosc and Blosc2 can compress and decompress the blocks of each chunk in
parallel. They use one thread unless you ask for more with
[`h5_threads()`](https://cmmr.github.io/h5lite/reference/h5_threads.md),
for example `h5_threads(4)`, which sets the thread count for everything
in `h5lite` that runs in parallel. Threads help most when compression is
slow, as with high Zstandard levels, and with large chunks, but they
speed up reading at the default 1 MB chunk size too. To change the
default of one thread without calling
[`h5_threads()`](https://cmmr.github.io/h5lite/reference/h5_threads.md),
set the `H5LITE_NTHREADS` environment variable. Threads need `hdf5lib`
2.2.0.1 or later: when `h5lite` is built with `hdf5lib` 2.2.0.0, Blosc
always uses one thread.

### Szip

**`"szip-nn"`** and **`"szip-ec"`** are provided by the `libaec` library
and are part of the core HDF5 filter set. **Nearest Neighbor** (`nn`)
coding suits smooth, correlated data such as time series or gradients.
**Entropy Coding** (`ec`) suits uncorrelated or categorical integer
data. Szip works only on numeric data. For anything else, `h5lite` falls
back to gzip (see [Rules and Automatic
Adjustments](#rules-and-automatic-adjustments)). Modern codecs usually
beat szip, but it is still common in some scientific fields, such as
Earth observation data.

### Legacy Codecs

**`"blosc1-..."`**, **`"bzip2-[level]"`**, **`"lzf"`**, and
**`"snappy"`** are included mainly so you can read and write files for
older pipelines that already use them. They are generally slower or
weaker than the codecs above, so they aren’t recommended for new data.

### Comparing Codecs on Your Own Data

Codec performance depends heavily on the data, so the most reliable way
to choose is to try a few. This small helper writes the same object with
each codec and reports the compression ratio:

``` r

compression_ratio <- function(x, codecs, ...) {
  tmp <- tempfile(fileext = ".h5")
  on.exit(unlink(tmp))
  sapply(codecs, function(codec) {
    h5_write(x, tmp, "x", compress = h5_compression(codec, ...))
    info <- h5_inspect(tmp, "x")
    round(info$uncompressed_size / info$storage_size, 2)
  })
}

codecs <- c("gzip", "zstd-5", "zstd-19", "lz4", "bshuf-lz4",
            "bshuf-zstd-5", "blosc2-lz4-5", "blosc2-zstd-5")

# A slowly varying sensor signal (float64)
compression_ratio(temps, codecs)
#>          gzip        zstd-5       zstd-19           lz4     bshuf-lz4 
#>          2.01          2.03          2.08          1.29          2.39 
#>  bshuf-zstd-5  blosc2-lz4-5 blosc2-zstd-5 
#>          2.46          1.31          2.47

# Small counts (stored as uint8)
compression_ratio(rpois(1e5, lambda = 3), codecs)
#>          gzip        zstd-5       zstd-19           lz4     bshuf-lz4 
#>          2.35          2.36          2.83          1.38          2.35 
#>  bshuf-zstd-5  blosc2-lz4-5 blosc2-zstd-5 
#>          2.46          2.44          2.49
```

To compare speed too, wrap the
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) and
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) calls
in [`system.time()`](https://rdrr.io/r/base/system.time.html), or use a
benchmarking package such as `bench`. Use realistically large data: on
tiny inputs, the timings mostly measure overhead.

## Sharing Files with Other Software

`h5lite` can read every codec it can write, so files compressed with any
of them can be read by anyone using `h5lite`. Other software is a
different story. HDF5 filters fall into two groups:

- **Built into HDF5:** gzip, shuffle, scale-offset (`int_packing` and
  `float_rounding`), and the Fletcher32 checksum are part of every HDF5
  library. Szip is also built in when HDF5 is compiled with `libaec` or
  `szip` support, which is common but not guaranteed.

- **Plugins:** Zstandard, LZ4, bzip2, LZF, Snappy, Bitshuffle, Blosc,
  Blosc2, and ZFP. Software that reads these datasets must have the
  matching filter plugin. Otherwise it fails with an error saying that a
  required filter is not available. The file itself is fine, but that
  reader can’t decompress the data.

How to get the plugins elsewhere:

- **Python (`h5py`):** Install the
  [`hdf5plugin`](https://pypi.org/project/hdf5plugin/) package and run
  `import hdf5plugin` before opening the file. This registers Blosc,
  Blosc2, Bitshuffle, bzip2, LZ4, ZFP, and Zstandard. LZF is already
  built into `h5py`. There is no Python plugin for `"snappy"`; use
  `"blosc1-snappy"` to share Snappy-compressed data.

- **Command-line tools, HDFView, and other languages:** Install the
  filter plugin libraries and point the `HDF5_PLUGIN_PATH` environment
  variable at the directory that contains them.

**A practical rule:** use gzip, optionally with `int_packing`,
`float_rounding`, or `checksum`, for files you hand off to others. Use
the modern codecs for working files that you, or other `h5lite` users,
will read.

## Lossy Compression

For large numeric datasets, you can get much higher compression ratios
by discarding precision you don’t need. `h5lite` supports three lossy
approaches.

### ZFP

ZFP is a compressor built specifically for numeric arrays. It has three
lossy modes and one lossless mode:

- **Accuracy** (`"zfp-acc-[tolerance]"`): No value changes by more than
  the given absolute tolerance, such as `"zfp-acc-0.001"`.
- **Precision** (`"zfp-prec-[bits]"`): Keeps a fixed number of bits of
  precision, so the error scales with each value’s magnitude, such as
  `"zfp-prec-16"`.
- **Rate** (`"zfp-rate-[bits]"`): Stores exactly the given number of
  bits per value, which gives a predictable file size, such as
  `"zfp-rate-8"`.
- **Reversible** (`"zfp-rev"`): Lossless.

``` r

h5_write(temps, file, "lossy/zfp", compress = "zfp-acc-0.01")

# No value has moved by more than 0.01
max(abs(h5_read(file, "lossy/zfp") - temps))
#> [1] 0.004433594

h5_inspect(file, "lossy/zfp")
#> <HDF5 Dataset Properties>
#>   Type:    float64             Size:    781.25 KB
#>   Layout:  chunked             Disk:    163.39 KB
#>   Chunks:  [100000]            Ratio:   4.78x
#>   Pipeline: zfp
```

ZFP has requirements that are easy to miss:

- **It needs 32- or 64-bit numeric types:** `float32`, `float64`,
  `int32`, or `int64`. Inside Blosc2 (`"blosc2-zfp-..."`), only
  `float32` and `float64` work. Because `h5lite` automatically stores
  whole numbers in the smallest type that fits (often `uint8` or
  `uint16`), integer data usually needs an explicit `as`. When the type
  isn’t supported, `h5lite` quietly uses gzip instead, so check the
  result with
  [`h5_inspect()`](https://cmmr.github.io/h5lite/reference/h5_inspect.md):

  ``` r

  # Stored as uint16, so ZFP is skipped and gzip is used instead
  h5_write(1:1000, file, "lossy/zfp_skipped", compress = "zfp-rev")
  h5_inspect(file, "lossy/zfp_skipped")
  #> <HDF5 Dataset Properties>
  #>   Type:    uint16              Size:    1.95 KB
  #>   Layout:  chunked             Disk:    299.00 B
  #>   Chunks:  [1000]              Ratio:   6.69x
  #>   Pipeline: shuffle -> gzip

  # Storing as int32 lets ZFP run
  h5_write(1:1000, file, "lossy/zfp_int32", compress = "zfp-rev", as = "int32")
  h5_inspect(file, "lossy/zfp_int32")
  #> <HDF5 Dataset Properties>
  #>   Type:    int32               Size:    3.91 KB
  #>   Layout:  chunked             Disk:    1.53 KB
  #>   Chunks:  [1000]              Ratio:   2.56x
  #>   Pipeline: zfp
  ```

- **It can’t store `NA`, `NaN`, or `Inf`.** ZFP would turn them into
  arbitrary numbers, so `h5lite` writes data that contains them with the
  default pipeline (shuffle + gzip) instead. Those values come back
  exactly.

- **Standalone ZFP compresses blocks of one to four dimensions.** Data
  whose chunks have no dimension longer than one (a single value, say)
  or more than four is written with the default pipeline (shuffle +
  gzip) instead. With `hdf5lib` 2.2.0.1 or later, ZFP inside Blosc2
  compresses chunks of any shape, but stores data of fewer than four
  values uncompressed in the same way.

- **In Blosc2, accuracy mode supports only powers of ten.** For
  `"blosc2-zfp-acc-[tolerance]"`, the tolerance is rounded down to a
  power of ten (for example, `0.05` becomes `0.01`).

### Scale-Offset: `int_packing` and `float_rounding`

The Scale-Offset filter is built into HDF5, so it’s the one form of
lossy compression that every HDF5 reader understands. It works on one
chunk at a time and runs before the main compressor.

- **`int_packing = TRUE`** (lossless) subtracts each chunk’s minimum
  value and stores the remainders using the fewest bits that can
  represent them. This is effective for integers that span a narrow
  range, such as years, sensor counts, or IDs. Passing a number instead,
  such as `int_packing = 8`, forces that bit width. Use a fixed width
  only if you know the range fits.

- **`float_rounding = d`** (lossy) stores floating-point values as
  integer multiples of 10^(-d), measured from the chunk’s minimum, and
  then bit-packs them. Every value comes back within half a unit of the
  `d`-th decimal place, for example within ±0.005 when `d = 2`. Because
  the steps are counted from the chunk’s minimum rather than from zero,
  the values you read back won’t necessarily print as round decimals.

``` r

# Integers in a narrow range: lossless
ids <- sample(100000:100100, 1e5, replace = TRUE)
h5_write(ids, file, "packed/ids", compress = h5_compression("gzip", int_packing = TRUE))
identical(h5_read(file, "packed/ids"), ids)
#> [1] TRUE

# Floats kept to 2 decimal places: lossy
readings <- rnorm(1e5, mean = 98.6, sd = 0.5)
h5_write(readings, file, "packed/readings",
         compress = h5_compression("gzip", float_rounding = 2))
max(abs(h5_read(file, "packed/readings") - readings))
#> [1] 0.004999984

h5_inspect(file, "packed/readings")
#> <HDF5 Dataset Properties>
#>   Type:    float64             Size:    781.25 KB
#>   Layout:  chunked             Disk:    109.92 KB
#>   Chunks:  [100000]            Ratio:   7.11x
#>   Pipeline: scaleoffset -> gzip
```

A few things to know:

- `int_packing` affects only datasets stored as integers, and
  `float_rounding` affects only datasets stored as floating point. You
  can set both in one configuration when you write a list that contains
  both kinds of data.
- Integer vectors that contain `NA` are stored as `float64`, so
  `int_packing` doesn’t apply to them.
- **`float_rounding` can’t store `NA` or `NaN`.** The filter would turn
  them into ordinary numbers, so `h5lite` skips `float_rounding` for any
  dataset that contains `NA`, `NaN`, or `Inf`.
- Scale-Offset turns off shuffling, and it can’t be combined with szip,
  ZFP, Bitshuffle, or the Blosc2 pre-filters.

### Blosc2 Truncate Precision

With any Blosc2 codec except NDLZ and ZFP, `blosc2_truncate = n` keeps
`n` bits of each floating-point value’s mantissa and zeroes the rest,
which makes the data much more compressible. The relative error is about
2^(-n). A `float64` has 52 mantissa bits and a `float32` has 23, so
`blosc2_truncate = 23` gives `float64` data roughly single-precision
accuracy while keeping the `float64` type. A negative `n` drops that
many bits instead: `blosc2_truncate = -29` also keeps 23 bits of a
`float64`.

Truncation only applies to `float32` and `float64` data. Integers, data
frames, and `float16`/`bfloat16` data are written without it, and so is
data containing `NA` or `NaN`, since zeroing those bits would turn `NA`
into `NaN` or `Inf`. So is `float32` data when a negative `n` would drop
all 23 of its mantissa bits.

``` r

x <- rnorm(1e5)
h5_write(x, file, "lossy/truncated",
         compress = h5_compression("blosc2-zstd-5", blosc2_truncate = 16))

# Largest relative error
max(abs((h5_read(file, "lossy/truncated") - x) / x))
#> [1] 1.523367e-05

h5_inspect(file, "lossy/truncated")
#> <HDF5 Dataset Properties>
#>   Type:    float64             Size:    781.25 KB
#>   Layout:  chunked             Disk:    261.72 KB
#>   Chunks:  [100000]            Ratio:   2.99x
#>   Pipeline: blosc2 [trunc(bits=16) -> bitshuffle -> zstd]
```

## The Filter Pipeline

[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
assembles HDF5’s filter pipeline for you. Data passes through these
stages in order:

1.  **Scale-Offset** (optional): `int_packing` or `float_rounding`.
2.  **Shuffle**: rearranges bytes or bits so that the compressor finds
    more patterns. Chosen automatically.
3.  **Compressor**: the codec you chose.
4.  **Fletcher32 checksum** (optional): `checksum = TRUE`.

### Shuffling

A shuffle filter doesn’t compress anything by itself. It reorders the
data so that the compressor can do a better job. The **byte shuffle**
groups the 1st byte of every value together, then the 2nd byte of every
value, and so on:

- **Integers:** Small values stored in a wide type have many zero bytes.
  After shuffling, those zeros form long runs that compress extremely
  well.
- **Floating point:** Values of similar magnitude share their sign and
  exponent bytes. Grouped together, those bytes become highly
  repetitive.

**Bitshuffle** does the same thing one bit at a time, which exposes even
more redundancy in numeric data.

`h5lite` picks the shuffle for you:

| Pipeline | Shuffle used |
|:---|:---|
| `"blosc1-..."` or `"blosc2-..."` | Blosc’s internal bitshuffle |
| `"blosc2-ndlz"` | None. NDLZ works on the raw bytes. |
| `"bshuf-lz4"` or `"bshuf-zstd"` | Bitshuffle (built into the codec) |
| Any other codec (gzip, zstd, lz4, …) | HDF5’s byte shuffle |
| Scale-Offset, szip, or ZFP | None. Shuffling would break these filters. |
| 1-byte data (logicals, `uint8`, `int8`, small factors) | None. There is nothing to shuffle. |

### Blosc2 Delta

With any Blosc2 codec except NDLZ and ZFP, `blosc2_delta = TRUE` adds
Blosc2’s delta pre-filter, which encodes values relative to a reference
block before compression. It can help with slowly varying data, but it
can also make things worse. Test it on your data with the helper from
[Comparing Codecs](#comparing-codecs-on-your-own-data):

``` r

blosc2_codecs <- c("blosc2-zstd-5", "blosc2-lz4-5")
rbind(
  without_delta = compression_ratio(temps, blosc2_codecs),
  with_delta    = compression_ratio(temps, blosc2_codecs, blosc2_delta = TRUE) )
#>               blosc2-zstd-5 blosc2-lz4-5
#> without_delta          2.47         1.31
#> with_delta             2.45         1.44
```

### Checksums

`checksum = TRUE` appends a Fletcher32 checksum to every chunk.
Corrupted chunks are then detected when they are read, instead of
silently returning bad values. The checksum is built into HDF5, costs
very little, and works with every codec.

### Rules and Automatic Adjustments

[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
**raises an error** for settings that can never work:

- An unrecognized compression string, or a level outside the codec’s
  range.
- `int_packing` or `float_rounding` combined with an szip, ZFP, or
  `bshuf-` codec, or with `blosc2_delta` or `blosc2_truncate`.
- A `blosc2_truncate` of `0`, or outside `-51` to `52`.

Other settings depend on the data being written, so
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
**quietly adjusts** them instead:

- **Szip and ZFP** fall back to the default pipeline (shuffle + gzip
  level 5) when the data type isn’t supported (see [ZFP](#zfp)), or when
  the data is non-numeric, such as strings, data frames, or factors.
  Szip also falls back when the chunk’s fastest-changing dimension has
  fewer than 2 elements, and standalone ZFP when the chunks have no
  dimension longer than one, or more than four.
- **Missing and non-finite values:** ZFP falls back to the default
  pipeline, and `float_rounding` is skipped, for data that contains
  `NA`, `NaN`, or `Inf`, because those filters can’t store them.
  `blosc2_truncate` is skipped for data containing `NA` or `NaN`.
- **Shuffling** is skipped where it would be useless or harmful (see
  [Shuffling](#shuffling)).
- **`blosc2_delta` and `blosc2_truncate`** apply only to `"blosc2-..."`
  codecs other than `"blosc2-ndlz"` and `"blosc2-zfp-..."`. With any
  other codec, they are ignored. `blosc2_truncate` also applies only to
  `float32` and `float64` data, and not to `float32` data when it would
  drop all 23 mantissa bits.
- **Scalars** are never compressed.

When in doubt,
[`h5_inspect()`](https://cmmr.github.io/h5lite/reference/h5_inspect.md)
shows the pipeline that was actually applied.

## Chunking

HDF5 doesn’t compress a dataset as one block. It splits the dataset into
**chunks** and compresses each one independently. When you read any part
of a chunk, HDF5 decompresses the entire chunk.

`h5lite` picks chunk dimensions automatically. It starts with the full
dataset and repeatedly halves its largest dimension until a chunk fits
within `chunk_size`, which defaults to 1 MB. For a matrix with many more
rows than columns, this keeps entire rows inside each chunk, which works
well with [partial
reading](https://cmmr.github.io/h5lite/articles/partial-reading.md) by
row:

``` r

mat <- matrix(rnorm(1e6), nrow = 10000, ncol = 100)   # 8 MB of float64

h5_write(mat, file, "chunks/default")
h5_inspect(file, "chunks/default")
#> <HDF5 Dataset Properties>
#>   Type:    float64             Size:    7.63 MB
#>   Layout:  chunked             Disk:    6.74 MB
#>   Chunks:  [1250 x 100]        Ratio:   1.13x
#>   Pipeline: shuffle -> gzip

h5_write(mat, file, "chunks/small", compress = h5_compression(chunk_size = 64 * 1024))
h5_inspect(file, "chunks/small")
#> <HDF5 Dataset Properties>
#>   Type:    float64             Size:    7.63 MB
#>   Layout:  chunked             Disk:    6.84 MB
#>   Chunks:  [79 x 100]          Ratio:   1.11x
#>   Pipeline: shuffle -> gzip
```

The default is a good choice for most data. Consider changing it when:

- **You often read small slices** with `start` and `count`. Smaller
  chunks (for example, 64-256 KB) mean less data is decompressed for
  each read.
- **You always read whole datasets.** Larger chunks may compress
  slightly better.

Avoid the extremes. Chunks below about 10 KB add a lot of indexing
overhead and compress poorly. Chunks of tens of megabytes make every
partial read expensive.

## Inspecting the Results

[`h5_inspect()`](https://cmmr.github.io/h5lite/reference/h5_inspect.md)
reports how a dataset is stored:

- **Type**: the HDF5 data type on disk.
- **Size**: the uncompressed size of the data.
- **Disk**: the space the data actually occupies in the file.
- **Ratio**: Size divided by Disk.
- **Layout**: `chunked` for compressed data. Scalars are stored as
  `contiguous`.
- **Chunks**: the chunk dimensions.
- **Pipeline**: the filters that were actually applied, in order.

``` r

h5_inspect(file, "temps/configured")
#> <HDF5 Dataset Properties>
#>   Type:    float64             Size:    781.25 KB
#>   Layout:  chunked             Disk:    400.67 KB
#>   Chunks:  [25000]             Ratio:   1.95x
#>   Pipeline: shuffle -> zstd -> fletcher32
```

The returned object is a list, so you can also use the values in code.
That’s what the `compression_ratio()` helper above does:

``` r

info <- h5_inspect(file, "temps/configured")
info$storage_size
#> [1] 410290
sapply(info$filters, `[[`, "name")
#> [1] "shuffle"    "zstd"       "fletcher32"
```

## Compression String Reference

The `compress` argument of
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) and
[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
accepts the strings below. Strings are case-insensitive. A few
shorthands also work: `compress = 1` through `compress = 9` selects that
gzip level, `TRUE` selects the default (`"gzip"`), and `FALSE` selects
`"none"`.

| Codec | Strings | Level or parameter |
|:---|:---|:---|
| None | `"none"` | \- |
| Gzip | `"gzip"`, `"gzip-[level]"` | 1-9 (default 5) |
| Zstandard | `"zstd"`, `"zstd-[level]"` | 1-22 (default 3) |
| LZ4 | `"lz4"`, `"lz4-[level]"` | 0-12 (default 0). 0 is LZ4 and 1+ is LZ4-HC. |
| Bitshuffle + LZ4 | `"bshuf-lz4"` | \- |
| Bitshuffle + Zstandard | `"bshuf-zstd"`, `"bshuf-zstd-[level]"` | 1-22 (default 3) |
| Blosc2 | `"blosc2"` (BloscLZ), `"blosc2-ndlz"` | \- |
| Blosc2 + sub-codec | `"blosc2-lz4-[level]"`, `"blosc2-zstd-[level]"`, `"blosc2-gzip-[level]"` | Same ranges as the standalone codec |
| Blosc2 + ZFP | `"blosc2-zfp-acc-[tol]"`, `"blosc2-zfp-prec-[bits]"`, `"blosc2-zfp-rate-[bits]"` | Required. `float32` and `float64` only. |
| ZFP | `"zfp-acc-[tol]"`, `"zfp-prec-[bits]"`, `"zfp-rate-[bits]"` | Required |
| ZFP (lossless) | `"zfp-rev"` | \- |
| Szip | `"szip-nn"`, `"szip-ec"` | \- |
| Blosc (v1) | `"blosc1"`, `"blosc1-snappy"`, `"blosc1-lz4-[level]"`, `"blosc1-zstd-[level]"`, `"blosc1-gzip-[level]"` | Same ranges as the standalone codec |
| bzip2 | `"bzip2"`, `"bzip2-[level]"` | 1-9 (default 9) |
| LZF, Snappy | `"lzf"`, `"snappy"` | \- |

Inside Blosc and Blosc2, levels are mapped onto Blosc’s own 0-9 scale.
The full range of a sub-codec’s levels is accepted, but some neighboring
levels behave the same.

[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
also accepts `chunk_size`, `checksum`, `int_packing`, `float_rounding`,
`blosc2_delta`, and `blosc2_truncate`. See
[`?h5_compression`](https://cmmr.github.io/h5lite/reference/h5_compression.md)
for details.

*For filter IDs, parameters, and implementation details of each codec,
see the [hdf5lib compression
guide](https://cmmr.github.io/hdf5lib/articles/compression.html).*
