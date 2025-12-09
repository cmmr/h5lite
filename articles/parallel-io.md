# Parallel Processing

``` r
library(h5lite)

# We'll use a temporary file for this guide.
file <- tempfile(fileext = ".h5")
```

## Introduction

In high-performance computing, it’s common to use parallel processing to
speed up data analysis. R offers several parallel programming models,
which can be broadly categorized into two types:

1.  **Multi-threading:** Using packages like `RcppParallel`, where
    multiple threads operate within a single R process, sharing the same
    memory space.
2.  **Multi-processing:** Using packages like `future`, `parallel`, or
    `callr`, where multiple independent R processes are launched, each
    with its own memory space.

When multiple threads or processes need to access the same HDF5 file,
it’s critical to understand the concurrency guarantees provided by the
HDF5 library to avoid data corruption. This vignette explains how
`h5lite` behaves in these scenarios and provides best practices for safe
parallel I/O.

## HDF5 Thread-Safety

`h5lite` links to the `hdf5lib` R package, which provides a static build
of the HDF5 library (version 1.14.6 as of this writing). This version of
HDF5 was compiled with the `--enable-threadsafe` option.

What does this mean? According to the official HDF5 documentation, the
thread-safety feature ensures that all HDF5 API calls are protected by a
global mutex. \[1\] This means:

- Only one HDF5 function can execute at a time within a single process,
  even across multiple threads.
- It prevents race conditions and memory corruption when multiple
  threads in the same process (e.g., with `RcppParallel`) call `h5lite`
  functions concurrently.
- The library is “safe” in that it won’t crash or corrupt your file, but
  write operations are serialized, not performed in parallel.

**Important:** This built-in thread-safety **only applies to multiple
threads within a single process**. It does **not** coordinate access
between multiple independent processes.

## Multi-threaded Access (e.g., `RcppParallel`)

When using a multi-threaded framework, the HDF5 library’s internal mutex
handles synchronization for you.

### Best Practices

1.  **Concurrent Reads are Safe:** Multiple threads can safely call
    [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md) on
    the same file simultaneously. The HDF5 library will manage access,
    and each thread will receive the correct data.

2.  **Concurrent Writes are Serialized:** Multiple threads can call
    [`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
    without corrupting the file. However, the global HDF5 lock means the
    writes will execute one at a time. This is safe but offers no
    performance benefit for writing. If multiple threads attempt to
    write, they will be blocked until the lock is released.

3.  **Avoid Writing to the Same Dataset:** While the library prevents
    file corruption, having multiple threads attempt to write to the
    exact same dataset path can lead to unpredictable results (i.e.,
    which thread’s data ends up in the file last is non-deterministic).
    It is much safer to have each thread write to a unique dataset.

### Example: Writing from Multiple Threads

Here is a complete `Rcpp` example using the `RcppParallel` package. It
demonstrates how multiple threads can safely call back to the R
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)
function. The HDF5 library’s internal mutex serializes these calls,
preventing file corruption.

> **Note:** This pattern is safe but does not provide a performance
> boost for writing, as the writes happen one at a time. The primary
> benefit is for “read-heavy” parallel operations, or for simplifying
> code where a parallel section also needs to perform occasional,
> non-performance-critical writes.

``` cpp
// [[Rcpp::depends(RcppParallel)]]
#include <Rcpp.h>
#include <RcppParallel.h>

struct H5Writer : public RcppParallel::Worker {
  const std::string file;
  Rcpp::Function h5_write_r;
  
  // Constructor to receive the file path and the R function
  H5Writer(const std::string& file, Rcpp::Function h5_write_r) 
    : file(file), h5_write_r(h5_write_r) {}
  
  // The parallel workhorse function
  void operator()(std::size_t begin, std::size_t end) {
    for (std::size_t i = begin; i < end; ++i) {
      // Each thread writes to a unique dataset path
      std::string dset_name = "thread_data/" + std::to_string(i);
      Rcpp::NumericVector data = Rcpp::NumericVector::create(i);
      
      // Call back into R. The HDF5 global lock makes this thread-safe.
      h5_write_r(file, dset_name, data);
    }
  }
};

// [[Rcpp::export]]
void parallel_write_r_callback(std::string file, int n_threads) {
  // Look up the h5lite::h5_write function from its namespace
  Rcpp::Environment h5lite_ns = Rcpp::Environment::namespace_env("h5lite");
  Rcpp::Function h5_write_r = h5lite_ns["h5_write"];
  
  H5Writer writer(file, h5_write_r);
  RcppParallel::parallelFor(0, n_threads, writer);
}
```

## Multi-process Access (e.g., `future`, `callr`)

When multiple independent processes access the same HDF5 file, the
situation is more complex. The HDF5 library’s internal thread-safety
lock is irrelevant because each process has its own memory and its own
instance of the library.

By default, the HDF5 library **does not use file locking** to coordinate
access between processes. \[2\] This means:

- **Concurrent Reads are Generally Safe:** If the file is not being
  modified, multiple processes can read from it simultaneously without
  issue.
- **Concurrent Writes are NOT Safe:** If two or more processes attempt
  to write to the same HDF5 file at the same time, you are very likely
  to corrupt the file. This is a fundamental limitation.
- **Mixed Read/Write is NOT Safe (by default):** If one process is
  writing while another is reading, the reading process may see
  inconsistent or corrupted data.

### Best Practice: External Locking

To safely write to a single HDF5 file from multiple processes, you
**must** implement an external locking mechanism. The goal is to ensure
that only one process can have the file open for writing at any given
time.

The `interprocess` R package is an excellent tool for this. It provides
a file-based mutex that works across different R processes.

The workflow is: 1. Acquire a lock using `interprocess::lock()`. 2.
Perform the `h5lite` write operation. 3. Release the lock using
`interprocess::unlock()`.

### Example: Writing from Multiple Processes with `future` and `interprocess`

This example uses the `future` framework to spawn multiple R sessions.
Each session attempts to write to the same HDF5 file, but access is
protected by an `interprocess` lock.

``` r
library(future)
library(future.apply)
library(interprocess)
library(h5lite)

# Use a temporary file for the HDF5 data
h5_file <- tempfile(fileext = ".h5")

# Create a lock file associated with our HDF5 file
# This lock file will coordinate access across processes.
lock_file <- paste0(h5_file, ".lock")

# Set up a parallel backend with 2 processes
plan(multisession, workers = 2)

message("HDF5 file: ", h5_file)
message("Lock file: ", lock_file)

# Use future_lapply to run this code in parallel sessions
future_lapply(1:4, function(i) {
  
  # --- CRITICAL SECTION START ---
  # Acquire the lock. This call will block until the lock is available.
  # The timeout prevents it from waiting forever if something goes wrong.
  lck <- interprocess::lock(lock_file, timeout = 30000)
  
  # Now that we have the lock, it is safe to write.
  message(sprintf("Process %d acquired lock, writing...", Sys.getpid()))
  
  # Create a unique name for this process's data
  dset_name <- paste0("process_data/", Sys.getpid(), "_", i)
  data_to_write <- runif(5)
  
  # Perform the write operation
  h5_write(h5_file, dset_name, data_to_write)
  
  # Simulate some work
  Sys.sleep(0.5)
  
  # Release the lock so another process can acquire it
  interprocess::unlock(lck)
  message(sprintf("Process %d released lock.", Sys.getpid()))
  # --- CRITICAL SECTION END ---
  
  return(TRUE)
})

# Shut down the parallel workers
plan(sequential)

# Inspect the final file - it contains data from all processes
h5_ls(h5_file, recursive = TRUE)

# Clean up
unlink(h5_file)
unlink(lock_file)
```

Without the `interprocess::lock()` and `unlock()` calls, the above code
would be a race condition with a high probability of creating a
corrupted HDF5 file.

## Advanced Topic: Single-Writer/Multiple-Reader (SWMR)

HDF5 offers a specific feature for the “one writer, many readers”
scenario called SWMR. This allows one process to write to a file while
multiple other processes read from it, without the readers needing to
constantly re-open the file.

Currently, `h5lite` does **not** provide an explicit API to enable or
use SWMR mode. This is an advanced feature that requires careful setup
of file access properties. For use cases requiring SWMR, a lower-level R
package like `rhdf5` or `hdf5r` would be more appropriate.

## Summary of Recommendations

| Scenario              | Environment    | Safety     | `h5lite` Action                                                                                                                       | Best Practice                                              |
|:----------------------|:---------------|:-----------|:--------------------------------------------------------------------------------------------------------------------------------------|:-----------------------------------------------------------|
| **Concurrent Reads**  | Multi-threaded | **Safe**   | [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)                                                                     | No special action needed.                                  |
| **Concurrent Reads**  | Multi-process  | **Safe**   | [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)                                                                     | Safe as long as no process is writing.                     |
| **Concurrent Writes** | Multi-threaded | **Safe**   | [`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)                                                                   | Safe, but writes are serialized. Write to unique datasets. |
| **Concurrent Writes** | Multi-process  | **UNSAFE** | [`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)                                                                   | **Must use an external lock** (e.g., `interprocess`).      |
| **Mixed Read/Write**  | Multi-process  | **UNSAFE** | [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)/[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) | **Must use an external lock** for the writer.              |

## References

1.  The HDF5 Group. (2024). *Thread-safety in the HDF5 Library*.
    \[Online\]. Available:
    <https://docs.hdfgroup.org/hdf5/v1_14/develop/threadsafe.html>
2.  The HDF5 Group. (2024). *Concurrent Access to HDF5 Files*.
    \[Online\]. Available:
    <https://docs.hdfgroup.org/hdf5/v1_14/develop/conc_access.html>

``` r
# Clean up the temporary file
unlink(file)
```
