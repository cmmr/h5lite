if (requireNamespace("tinytest", quietly = TRUE)) {
  
  library(h5lite)
  
  if (dir.exists("tinytests")) { test_dir <- "tinytests"       }
  else                         { test_dir <- "tests/tinytests" }
  
  results <- tinytest::run_test_dir(test_dir)
  passed  <- as.logical(results)
  
  print(results)
  
  if (!all(passed)) {
    stop("One or more tinytest tests failed.")
  }
}
