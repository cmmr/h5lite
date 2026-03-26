# Define HDF5 Compression and Filter Settings

Constructs a comprehensive filter pipeline configuration to be passed as
the `compress` argument to
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md).
This function allows fine-grained control over chunking, pre-filters,
compression algorithms, and data scaling.

## Usage

``` r
h5_compression(
  compress = "gzip",
  chunk_size = 1024 * 1024,
  checksum = FALSE,
  int_packing = FALSE,
  float_rounding = NULL,
  blosc2_delta = FALSE,
  blosc2_truncate = NULL
)
```

## Arguments

- compress:

  A string specifying the compression algorithm and optional level
  (e.g., `"none"`, `"gzip"`, `"zstd-7"`, `"lz4"`, `"blosc1-lz4-9"`,
  `"blosc2-gzip-3"`, `"blosc2-zstd"`). See the **Valid Compression
  Strings** section below for an exhaustive list of supported formats.
  Default is `"gzip"`.

- chunk_size:

  An integer specifying the target chunk size in bytes. Default is
  `1048576` (1 MB).

- checksum:

  A logical value indicating whether to apply the Fletcher32 checksum
  filter at the end of the pipeline to detect data corruption. Default
  is `FALSE`.

- int_packing:

  Control the HDF5 Scale-Offset filter for integer datasets. *(Note:
  Incompatible with `szip`, `zfp`, `bshuf`, and Blosc2 pre-filters).*

  - `FALSE` (Default): Disabled.

  - `TRUE`: Automatically calculates and applies the mathematically
    optimal minimum bit-width for each individual chunk.

  - Integer (e.g., `8`): Forces packing into exactly that many bits.

- float_rounding:

  Control the HDF5 Scale-Offset filter for floating-point
  datasets.*(Note: Incompatible with `szip`, `zfp`, `bshuf`, and Blosc2
  pre-filters).*

  - `NULL` (Default): Disabled.

  - Integer (e.g., `3`): The number of base-10 decimal places of detail
    to preserve before truncating and packing the values (e.g.,
    `3.141`). Negative numbers round to powers of 10.

- blosc2_delta:

  A logical value. If `TRUE` and a `blosc2` compressor is selected,
  applies the Blosc2 Delta pre-filter before compression. Default is
  `FALSE`.

- blosc2_truncate:

  An integer. If provided and a `blosc2` compressor is selected, applies
  the Blosc2 Truncate Precision pre-filter to floating-point data,
  preserving exactly the specified number of uncompressed bits. Default
  is `NULL`.

## Value

An S3 object of class `compress` containing the parsed pipeline
parameters.

## Valid Compression Strings

The `compress` argument accepts a highly specific string syntax to
define both the codec and its operational level.

### Native / Core Codecs

- `"none"`: No compression.

- `"gzip-[level]"`: Levels `1` to `9`. Default is `5`. (e.g., `"gzip"`
  or `"gzip-9"`).

- `"zstd-[level]"`: Levels `1` to `22`. Default is `3`. (e.g., `"zstd"`
  or `"zstd-7"`).

- `"lz4-[level]"`: Levels `0` to `12`. Default is `0`. Level `0` is
  standard LZ4. Levels `1+` trigger LZ4-HC.

### Bitshuffle Pre-filter

Forces the native Bitshuffle pre-filter before compression.

- `"bshuf-lz4"`: Bitshuffle + LZ4.

- `"bshuf-zstd-[level]"`: Bitshuffle + Zstd (Levels `1` to `22`).

### Blosc Meta-compressors

Blosc applies its own highly optimized bitshuffling and multi-threading.

- **Blosc2 (Recommended):** `"blosc2"` (blosclz),
  `"blosc2-lz4-[level]"`, `"blosc2-zstd-[level]"`,
  `"blosc2-gzip-[level]"`, `"blosc2-ndlz"`

- **Blosc1 (Legacy):** `"blosc1"` (blosclz), `"blosc1-lz4-[level]"`,
  `"blosc1-zstd-[level]"`, `"blosc1-gzip-[level]"`, `"blosc1-snappy"`

### ZFP (Lossy Floating-Point Compression)

ZFP can be run standalone (for integers and floats) or inside Blosc2
(floats only). Unlike `[level]`, `[tolerance]` and `[bits]` are
required.

- **Accuracy Mode** (Absolute error tolerance): `"zfp-acc-[tolerance]"`
  or `"blosc2-zfp-acc-[tolerance]"` (e.g., `"zfp-acc-0.001"`).

- **Precision Mode** (Bits of precision): `"zfp-prec-[bits]"` or
  `"blosc2-zfp-prec-[bits]"` (e.g., `"zfp-prec-16"`).

- **Rate Mode** (Bits of storage per value): `"zfp-rate-[bits]"` or
  `"blosc2-zfp-rate-[bits]"` (e.g., `"zfp-rate-8"`).

- **Reversible Mode** (Standalone Lossless): `"zfp-rev"`.

### Legacy Codecs

- `"szip-nn"`, `"szip-ec"`: SZIP Nearest Neighbor or Entropy Coding.

- `"bzip2-[level]"`: Levels `1` to `9`. Default is `9`. (e.g.,
  `"bzip2-4"`).

- `"lzf"`, `"snappy"`: Fast, unconfigurable legacy compressors.

## Automatic Shuffling

To maximize compression ratios without requiring users to manually
manage complex pipeline interactions, `h5_compression` automatically
configures the optimal shuffling pre-filter based on the following
strict hierarchy:

**1. Blosc's Internal Bitshuffle (Preferred)** If a Blosc
meta-compressor is selected (e.g., `"blosc2-zstd"`), the pipeline
automatically enables Blosc's highly optimized, internal bitshuffle
routine. This achieves peak compression performance without requiring
the standalone Bitshuffle plugin to be installed.

**2. Explicit Bitshuffle Plugin** If a standard codec is explicitly
prefixed with `bshuf-` (e.g., `"bshuf-lz4"`), the pipeline delegates to
the standalone Bitshuffle plugin.

**3. Native HDF5 Byte Shuffle (Fallback)** If a standard compressor is
selected (e.g., `"zstd-5"` or `"gzip"`), the pipeline safely falls back
to the core HDF5 library's native byte shuffle filter. This guarantees
improved compression while maintaining universal compatibility.

**4. Strict Mutual Exclusions (When Shuffling is Disabled)** To prevent
data corruption or wasted CPU cycles, all shuffling is **forcefully
disabled** in the following scenarios:

- **Scale-Offset Active:** If `int_packing` or `float_rounding` is
  applied, shuffling is disabled because scale-offset destroys the
  byte-alignment that shuffling relies on.

- **ZFP & SZIP:** These algorithms perform mathematical compression
  directly on numerical values and will corrupt if the bitstream is
  rearranged beforehand.

- **1-Byte Data:** Characters, booleans, and 8-bit integers cannot be
  meaningfully shuffled, so the step is skipped.

## See also

[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md),
[`vignette('compression')`](https://cmmr.github.io/h5lite/articles/compression.md)

## Examples

``` r
# 1. Simple fast compression (Zstd level 7)
h5_compression("zstd-7")
#> <HDF5 Compression Configuration>
#>   Codec:           zstd-7
#>   Shuffle:         Byte Shuffle (Native HDF5)
#>   Chunk Size:      1.00 MB
#>   Checksum:        None

# 2. Optimal integer packing (Scale-Offset)
h5_compression("gzip-9", int_packing = TRUE)
#> <HDF5 Compression Configuration>
#>   Codec:           gzip-9
#>   Shuffle:         None (Disabled by Scale-Offset)
#>   Chunk Size:      1.00 MB
#>   Checksum:        None
#>   Int Packing:     Optimal (Auto)

# 3. Complex Blosc2 Pipeline (Delta + Zstd)
h5_compression("blosc2-zstd-5", blosc2_delta = TRUE)
#> <HDF5 Compression Configuration>
#>   Codec:           blosc2-zstd-5
#>   Shuffle:         Bitshuffle (Blosc Internal)
#>   Chunk Size:      1.00 MB
#>   Checksum:        None
#>   Blosc2 Delta:    TRUE

# 4. Lossy ZFP compression (Tolerance of 0.05)
h5_compression("zfp-acc-0.05")
#> <HDF5 Compression Configuration>
#>   Codec:           zfp-acc-0.05
#>   Shuffle:         None (Incompatible with zfp)
#>   Chunk Size:      1.00 MB
#>   Checksum:        None

# Pass the compress object directly to h5_write
file <- tempfile(fileext = ".h5")
cmp  <- h5_compression("gzip-9", checksum = TRUE)
h5_write(combn(1:10, 3), file, "sets", compress = cmp)

print(cmp)
#> <HDF5 Compression Configuration>
#>   Codec:           gzip-9
#>   Shuffle:         Byte Shuffle (Native HDF5)
#>   Chunk Size:      1.00 MB
#>   Checksum:        Fletcher32

inspect(file, "sets")
#> Error in inspect(file, "sets"): could not find function "inspect"

# Clean up
unlink(file)
```
