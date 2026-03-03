# Data Compression

HDF5 supports transparent data compression, allowing you to drastically
reduce the file size of your datasets with minimal effort. `h5lite`
handles the underlying chunking requirements automatically and exposes
two primary compression algorithms: **gzip (zlib)** and **szip
(libaec)**.

This vignette covers how to choose the right algorithm, how string
compression is handled, and what performance trade-offs to expect.

``` r
library(h5lite)
file <- tempfile(fileext = ".h5")
```

## The `compress` Argument

You can control compression for any dataset written with
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
using the `compress` argument. `h5lite` accepts a string configuration
to explicitly define the algorithm and its parameters:

- `"gzip-5"` (default): Standard gzip compression at level 5. Levels
  `"gzip-1"` through `"gzip-9"` are also supported.
- `"szip-nn"`: Szip with Nearest Neighbor coding.
- `"szip-ec"`: Szip with Entropy Coding.
- `"none"`: Disables compression entirely.

*(Note: For backward compatibility, `TRUE`, `FALSE`, and integers
`0`-`9` are still accepted and map directly to gzip levels).*

------------------------------------------------------------------------

## Gzip: The Universal Standard

The gzip filter is the baseline compression standard in the HDF5
ecosystem. Every compiled HDF5 library worldwide is expected to support
gzip encoding and decoding.

**When to use it:** By default, and whenever you plan to share your
`.h5` files with external collaborators, Python/Julia users, or archive
them for long-term storage. Its universal availability guarantees your
data can always be read.

**Configuring Levels:** Gzip offers levels from 1 (fastest, lowest
compression) to 9 (slowest, highest compression). Level 5 provides a
well-balanced default for most numerical data.

``` r
# Default gzip compression
h5_write(rnorm(1000), file, "data/default_gzip")

# Maximum gzip compression
h5_write(rnorm(1000), file, "data/max_gzip", compress = "gzip-9")
```

------------------------------------------------------------------------

## Szip: The Performance Alternative

Szip is an extremely fast, specialized compression algorithm designed
specifically for scientific data. When applied correctly, it often
compresses faster, decompresses faster, and yields smaller files than
gzip.

However, **szip is not universally supported.** Due to an expired patent
encumbrance from the early 2000s, many open-source tools and legacy HDF5
distributions were compiled *without* szip support. If you share an
szip-compressed file, the recipient may encounter a “Filter not
available” error. Use szip when you control the end-to-end data pipeline
or require maximum I/O performance on massive datasets.

`h5lite` exposes two szip coding methods, which you must choose based on
the nature of your data:

### 1. Nearest Neighbor (`"szip-nn"`)

Best for continuous, smooth, or highly correlated data. NN performs a
predictive delta-encoding step before compression - it subtracts
adjacent values and encodes the differences.

- **Ideal for:** Floating-point arrays (`float32`, `float64`),
  time-series data, and smooth image gradients.

### 2. Entropy Coding (`"szip-ec"`)

Best for uncorrelated, discrete, or random data where adjacent values do
not reliably predict one another.

- **Ideal for:** Categorical integer data, randomized matrices, or
  low-entropy labels.

``` r
# Highly correlated data -> Use Nearest Neighbor
smooth_signal <- sin(seq(0, 10, length.out = 10000))
h5_write(smooth_signal, file, "data/szip_signal", compress = "szip-nn")

# Discrete, uncorrelated data -> Use Entropy Coding
categories <- sample(1:5, 10000, replace = TRUE)
h5_write(categories, file, "data/szip_categories", compress = "szip-ec")
```

------------------------------------------------------------------------

## The Shuffle Filter

Whenever you enable **gzip** compression on a dataset with multi-byte
elements (like 32-bit integers or 64-bit doubles), `h5lite`
automatically enables the **HDF5 Shuffle Filter** in the pipeline before
compression. *(Note: The shuffle filter is intentionally disabled when
using szip, as byte-shuffling destroys the numeric correlation that the
szip algorithm relies upon).*

The shuffle filter does not compress data itself. Instead, it rearranges
the byte stream to make it more digestible for the gzip compressor. It
groups all the first bytes of every value together, then all the second
bytes, and so on.

- **For Integers:** Small integers often have many zero-padding bytes.
  The shuffle filter groups these zeros into long runs, which gzip
  compresses extremely efficiently. This allows `int32` data to compress
  nearly as well as `int8` data if the values are small.

- **For Floats:** Floating point numbers often share the same exponent
  bytes if they are in a similar range. The shuffle filter groups these
  identical exponent bytes, creating repetitive patterns that gzip can
  compress.

This automatic step is practically “free” in terms of CPU time and
significantly boosts the final compression ratio.

------------------------------------------------------------------------

## Compressing Strings

String compression in HDF5 depends entirely on whether the strings are
stored with fixed or variable lengths.

### Fixed-Length Strings (Compressible)

By default, `h5lite` stores character vectors as fixed-length strings,
provided there are no `NA` values and the string lengths are relatively
consistent. These strings are stored in a contiguous, rectangular block
of memory, making them **highly compressible**.

**The Szip Fallback:** Szip algorithms are strictly designed for numeric
arrays and do not support string datasets. If you request `"szip-nn"` or
`"szip-ec"` on a character vector, `h5lite` will detect the
incompatibility and gracefully fall back to `"gzip-5"`.

``` r
# Highly compressible (Fixed-length by default), automatically falls back to gzip-5
h5_write(c("A", "B", "C"), file, "strings/default_fixed", compress = "szip-nn")
```

### Variable-Length Strings (No Compression)

`h5lite` automatically switches to variable-length strings if the
character vector contains `NA` values, or if the string lengths are
extremely large or highly variable. HDF5 stores these as arrays of
pointers to a separate memory heap. **Variable-length strings cannot be
compressed by chunk filters.** If applied, the `compress` argument will
be safely ignored.

*(Note: If you attempt to explicitly force fixed-length storage using
the `as` argument - e.g., `as = "utf8[20]"` - on a vector containing
`NA` values, `h5lite` will throw an error rather than silently
corrupting the missing values).*

``` r
# Cannot be compressed (Auto-switches to variable-length due to NA)
h5_write(c("apple", "banana", NA), file, "strings/var", compress = "gzip-5")
```

------------------------------------------------------------------------

## Performance Benchmarks & Expectations

While exact performance depends on your specific hardware and dataset
entropy, here are the typical heuristics for HDF5 compression:

### Gzip Scaling

- **`"gzip-1"`:** Offers the best balance of speed and size. It provides
  the vast majority of achievable compression in a fraction of the time.

- **`"gzip-5"`:** The standard default. Noticeably slower to write than
  level 1, but yields a moderately tighter file.

- **`"gzip-9"`:** Rarely recommended for active analytical workloads.
  The CPU cost is exceptionally high, and the space savings over level 5
  are typically marginal (often less than 1-2%). Use only for cold
  archival storage.

### Szip vs. Gzip

When applied to appropriate numeric data, szip generally outperforms
gzip across the board:

- **Compression Ratio:** On floating-point data, `"szip-nn"` often
  achieves tighter compression than `"gzip-9"` because of its native
  understanding of numeric deltas.

- **Write Speed:** Szip is computationally simpler than gzip, meaning it
  typically writes data faster than `"gzip-5"`.

- **Read Speed:** Szip decompression is remarkably fast, often
  un-bottlenecking I/O pipelines that would otherwise be stalled waiting
  for gzip to inflate data.

``` r
unlink(file)
```
