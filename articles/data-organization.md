# Data Organization

HDF5 files are best understood as “file systems within a file.” Just as
your computer has folders and files, an HDF5 file has **Groups**
(folders) and **Datasets** (files). This hierarchical structure allows
you to organize complex experimental data, metadata, and configuration
settings into a single, self-describing package.

This vignette explains how to create, manage, and modify this structure
using `h5lite`.

``` r
library(h5lite)
file <- tempfile(fileext = ".h5")
```

## The Hierarchical Model

HDF5 uses POSIX-style paths (like Linux or macOS) to identify objects.
The root of the file is `/`.

- `/` : The Root Group
- `/experiment_1` : A Group (folder)
- `/experiment_1/data` : A Dataset (file) inside the group

## Creating Groups

### Implicit Creation (Recommended)

In most cases, you do not need to create groups manually. When you write
a dataset to a path like `"data/experiment/run1"`, `h5lite`
automatically creates the parent groups `"data"` and `"data/experiment"`
if they do not exist.

### Explicit Creation

If you need to create an empty group structure (perhaps to add
attributes to it), you can use
[`h5_create_group()`](https://cmmr.github.io/h5lite/reference/h5_create_group.md).
This function works like `mkdir -p`: it creates all necessary parent
groups.

``` r
# Create a deep hierarchy
h5_create_group(file, "project_A/simulation/run_01")

# Verify
h5_str(file)
#> /
#> └── project_A/
#>     └── simulation/
#>         └── run_01/
```

## Using Lists as Groups

The most powerful way to organize data in `h5lite` is by mapping R
**lists** to HDF5 **groups**.

When you pass a named list to
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md),
`h5lite` recursively writes the list structure to the file. \* **Named
Lists** become **Groups**. \* **Atomic Vectors/Matrices** inside the
list become **Datasets**.

This allows you to organize your entire data structure in R and save it
to disk in one command.

``` r
# Define a complex structure in R
experiment_data <- list(
  metadata = list(
    id         = I(101),
    technician = I("Dr. Smith"),
    timestamp  = I("2023-10-27")
  ),
  measurements = list(
    raw         = runif(10),
    calibration = c(0.1, 0.9)
  ),
  status = I("complete")
)

# Write the entire structure to a group named "exp_101"
h5_write(experiment_data, file, "exp_101")
```

## Inspecting Structure

You can visualize the organization of your file using
[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md) and
[`h5_str()`](https://cmmr.github.io/h5lite/reference/h5_str.md).

- [`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md): Returns
  a character vector of names. Useful for programmatic checks.
- [`h5_str()`](https://cmmr.github.io/h5lite/reference/h5_str.md):
  Prints a tree diagram. Useful for interactive exploration.

``` r
# List all objects recursively
h5_ls(file, recursive = TRUE)
#>  [1] "project_A"                        "project_A/simulation"            
#>  [3] "project_A/simulation/run_01"      "exp_101"                         
#>  [5] "exp_101/metadata"                 "exp_101/metadata/id"             
#>  [7] "exp_101/metadata/technician"      "exp_101/metadata/timestamp"      
#>  [9] "exp_101/measurements"             "exp_101/measurements/raw"        
#> [11] "exp_101/measurements/calibration" "exp_101/status"

# Visualize the tree
h5_str(file)
```

``` fansi
#> /
#> ├── project_A/
#> │   └── simulation/
#> │       └── run_01/
#> └── exp_101/
#>     ├── metadata/
#>     │   ├── id <uint8 scalar>
#>     │   ├── technician <utf8[9] scalar>
#>     │   └── timestamp <utf8[10] scalar>
#>     ├── measurements/
#>     │   ├── raw <float64 × 10>
#>     │   └── calibration <float64 × 2>
#>     └── status <utf8[8] scalar>
```

## Moving and Renaming

Data organization often changes. You can rename objects or move them to
different groups using
[`h5_move()`](https://cmmr.github.io/h5lite/reference/h5_move.md).

This operation is metadata-only, meaning it is extremely fast even for
large datasets, as the data itself is not rewritten.

``` r
# Rename 'exp_101' to 'archive_101'
h5_move(file, "exp_101", "archive_101")

# Move 'project_A' inside 'archive_101'
h5_move(file, "project_A", "archive_101/project_A")

h5_ls(file)
#>  [1] "archive_101"                            
#>  [2] "archive_101/metadata"                   
#>  [3] "archive_101/metadata/id"                
#>  [4] "archive_101/metadata/technician"        
#>  [5] "archive_101/metadata/timestamp"         
#>  [6] "archive_101/measurements"               
#>  [7] "archive_101/measurements/raw"           
#>  [8] "archive_101/measurements/calibration"   
#>  [9] "archive_101/status"                     
#> [10] "archive_101/project_A"                  
#> [11] "archive_101/project_A/simulation"       
#> [12] "archive_101/project_A/simulation/run_01"
```

## Deleting Objects

You can remove groups or datasets using
[`h5_delete()`](https://cmmr.github.io/h5lite/reference/h5_delete.md).

- Deleting a dataset removes the data.
- Deleting a group removes the group **and all of its children**
  (recursively).
- The file size does not change, but the freed space can be reused.

``` r
# Delete the entire archive group
h5_delete(file, "archive_101")

# The file is now empty (except for the root)
h5_ls(file)
#> character(0)
```
