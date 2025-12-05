# scripts/generate_h5.R
if (!requireNamespace("h5lite", quietly = TRUE)) {
  stop("h5lite must be installed to run this script.")
}
library(h5lite)

file_path <- "test_interop.h5"
if (file.exists(file_path)) unlink(file_path)

cat("Generating HDF5 file at:", file_path, "\n")

# --- 1. Atomic Vectors ---
h5_write(file_path, "vec_double", c(1.1, 2.2, 3.3))
h5_write(file_path, "vec_int", as.integer(c(1, 2, 3, 4, 5)))
# Note: R logicals are typically written as integers (0/1) or enums in HDF5
h5_write(file_path, "vec_logical", c(TRUE, FALSE, TRUE))
h5_write(file_path, "vec_char", c("apple", "banana", "cherry"))

# --- 2. Matrix/Array ---
# R fills matrices by column. 
# matrix(1:6, 2, 3) -> 
#      [,1] [,2] [,3]
# [1,]    1    3    5
# [2,]    2    4    6
mat <- matrix(1:6, nrow = 2, ncol = 3)
h5_write(file_path, "matrix_int", mat)

# --- 3. Data Frame (Compound Dataset) ---
# Using types seen in src/write_compound.c logic (ints, doubles, strings)
df <- data.frame(
  id = c(1L, 2L, 3L),
  score = c(10.5, 20.5, 30.5),
  label = c("A", "B", "C"),
  stringsAsFactors = FALSE
)
h5_write(file_path, "dataframe", df)

# --- 4. Attributes ---
h5_write(file_path, "dset_with_attr", c(100L, 200L))
h5_write_attr(file_path, "dset_with_attr", "unit", "meters")
h5_write_attr(file_path, "dset_with_attr", "scale", 1.5)

cat("Finished generating HDF5 file.\n")
