library(h5lite)

filename <- "interop_test.h5"
if (file.exists(filename)) file.remove(filename)

cat("--- Generating HDF5 Data from R ---\n")

# ==========================================
# 1. BASIC VECTORS
# ==========================================
# Integer
h5_write(c(1L, 2L, -5L), filename, "vec/int")

# Double
h5_write(c(1.1, 2.2, 3.14), filename, "vec/dbl")

# Logical (Boolean)
# R stores TRUE=1, FALSE=0 internally. We test how they arrive in HDF5.
h5_write(c(TRUE, FALSE, TRUE), filename, "vec/bool")

# Fixed-Length Strings
h5_write(c("alpha", "bravo", "charlie"), filename, "vec/str")


# ==========================================
# 2. FACTORS (ENUMS)
# ==========================================
# Case A: Standard Factor (Alphabetical levels)
f_std <- factor(c("small", "medium", "small", "large"))
h5_write(f_std, filename, "factor/standard")

# Case B: Reordered Levels (Crucial for testing index mapping)
# Data: "z", "x", "y"
# Levels: "z" (1), "y" (2), "x" (3) -> Ints in R: 1, 3, 2
f_ord <- factor(c("z", "x", "y"), levels = c("z", "y", "x"))
h5_write(f_ord, filename, "factor/reordered")


# ==========================================
# 3. MATRICES (LAYOUT TEST)
# ==========================================
# Matrix A: Integer, 2 Rows x 3 Cols
# R (Col-Major) fills column by column:
#      [,1] [,2] [,3]
# [1,]    1    3    5
# [2,]    2    4    6
m_int <- matrix(1:6, nrow = 2, ncol = 3)
h5_write(m_int, filename, "matrix/int_2x3")

# Matrix B: Double, 3 Rows x 2 Cols
#      [,1] [,2]
# [1,]  0.1  0.4
# [2,]  0.2  0.5
# [3,]  0.3  0.6
m_dbl <- matrix(c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6), nrow = 3, ncol = 2)
h5_write(m_dbl, filename, "matrix/dbl_3x2")


# ==========================================
# 4. COMPOUND (DATA FRAMES)
# ==========================================
# A complex dataframe mixing strings, ints, and factors
df <- data.frame(
  id = 1:3,
  code = c("A-1", "B-2", "C-3"),             # String
  status = factor(c("ok", "fail", "ok")),    # Factor (Enum)
  value = c(10.5, 20.0, 15.5),               # Double
  stringsAsFactors = FALSE
)
h5_write(df, filename, "compound/mixed")


# ==========================================
# 5. ATTRIBUTES
# ==========================================
# Verify we can write metadata to a dataset
h5attr(filename, "vec/int", "description") <- "Test Integers"
h5attr(filename, "vec/int", "version") <- 1L

cat("Successfully generated", filename, "\n")
