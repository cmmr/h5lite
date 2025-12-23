library(rhdf5)

file_path <- testthat::test_path('input/fixed_len.h5')

# Example data: R character vector
# Note: These are different lengths, but we will force them into a fixed width
vec_data <- c("BRCA1", "TP53", "EGFR", "MYC")
mtx_data <- t(matrix(vec_data, nrow = 2, ncol = 2))

h5createFile(file_path)

h5createDataset(
  file         = file_path,
  dataset      = 'chr_vec',
  dims         = length(vec_data),   # Dimension of the array
  storage.mode = "character",
  size         = 10, # THIS enforces fixed length (STRSIZE=10)
  chunk        = 1
)

h5createDataset(
  file         = file_path,
  dataset      = 'chr_mtx',
  dims         = dim(mtx_data),   # Dimension of the matrix
  storage.mode = "character",
  size         = 10, # THIS enforces fixed length (STRSIZE=10)
  chunk        = c(1, 1)
)

h5write(obj = vec_data, file = file_path, name = 'chr_vec')
h5write(obj = mtx_data, file = file_path, name = 'chr_mtx')

h5lite::h5_delete(file_path, 'chr_vec', 'rhdf5-NA.OK')
h5lite::h5_delete(file_path, 'chr_mtx', 'rhdf5-NA.OK')

