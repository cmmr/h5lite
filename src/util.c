#include "h5lite.h"


// # nocov start
SEXP errmsg_1(const char *fmt, const char *str1) {
    int   len    = snprintf(NULL, 0, fmt, str1);
    char *buffer = (char *) R_alloc(len + 1, sizeof(char));
    snprintf(buffer, len + 1, fmt, str1);
    return mkCharCE(buffer, CE_UTF8);
}

SEXP errmsg_2(const char *fmt, const char *str1, const char *str2) {
    int   len    = snprintf(NULL, 0, fmt, str1, str2);
    char *buffer = (char *) R_alloc(len + 1, sizeof(char));
    snprintf(buffer, len + 1, fmt, str1, str2);
    return mkCharCE(buffer, CE_UTF8);
}

SEXP errmsg_3(const char *fmt, const char *str1, const char *str2, const char *str3) {
    int   len    = snprintf(NULL, 0, fmt, str1, str2, str3);
    char *buffer = (char *) R_alloc(len + 1, sizeof(char));
    snprintf(buffer, len + 1, fmt, str1, str2, str3);
    return mkCharCE(buffer, CE_UTF8);
}
// # nocov end


/*
 * Gets a void* pointer to the underlying C array of an atomic R vector.
 * Returns NULL for types that are handled specially (like STRSXP).
 */
void* get_R_data_ptr(SEXP data) {
  if (TYPEOF(data) == REALSXP) return (void*)REAL(data);
  if (TYPEOF(data) == INTSXP)  return (void*)INTEGER(data);
  if (TYPEOF(data) == LGLSXP)  return (void*)LOGICAL(data);
  if (TYPEOF(data) == RAWSXP)  return (void*)RAW(data);
  if (TYPEOF(data) == CPLXSXP) return (void*)COMPLEX(data);
  return NULL; // # nocov
}

/*
 * Transposes a multi-dimensional array between R's column-major order and
 * HDF5's row-major (C) order.
 *
 * @param src Pointer to the source data buffer.
 * @param dest Pointer to the destination data buffer.
 * @param rank The number of dimensions of the array.
 * @param dims An array containing the size of each dimension.
 * @param el_size The size in bytes of a single element.
 * @param direction_to_r If 1, transposes from HDF5 to R. If 0, transposes from R to HDF5.
 * direction_to_r = 0 : R (Col-Major) -> HDF5 (Row-Major)
 */
void h5_transpose(void *src, void *dest, int rank, hsize_t *dims, size_t el_size, int direction_to_r) {
  /* For scalars (rank=0) or vectors (rank=1), no transposition is needed, just a direct copy. */
  if (rank <= 1) {
    hsize_t total = 1;
    if (rank == 1) total = dims[0];
    memcpy(dest, src, total * el_size);
    return;
  }
  
  hsize_t total_elements = 1;
  for (int i = 0; i < rank; i++) total_elements *= dims[i];
  
  /* Calculate strides for C (row-major) order. */
  /* The last dimension is contiguous (stride=1). */
  hsize_t *c_strides = (hsize_t *)malloc(rank * sizeof(hsize_t));
  c_strides[rank - 1] = 1;
  for (int i = rank - 2; i >= 0; i--) c_strides[i] = c_strides[i + 1] * dims[i + 1];
  
  /* Calculate strides for R (column-major) order. */
  /* The first dimension is contiguous (stride=1). */
  hsize_t *r_strides = (hsize_t *)malloc(rank * sizeof(hsize_t));
  r_strides[0] = 1;
  for (int i = 1; i < rank; i++) r_strides[i] = r_strides[i - 1] * dims[i - 1];
  
  /* Determine which set of strides to use for the destination. */
  hsize_t *dest_strides = direction_to_r ? r_strides : c_strides;
  
  /* 'coords' acts as an odometer, keeping track of the current multi-dimensional index. */
  hsize_t *coords = (hsize_t *)calloc(rank, sizeof(hsize_t));
  char *src_bytes = (char *)src;
  char *dest_bytes = (char *)dest;
  
  /* Iterate through the source buffer linearly, one element at a time. */
  for (hsize_t i = 0; i < total_elements; i++) {
    
    /* Calculate the destination index using the current coordinates and destination strides. */
    hsize_t dest_idx = 0;
    for (int d = 0; d < rank; d++) {
      dest_idx += coords[d] * dest_strides[d];
    }
    
    /* Copy the element from the linear source position to the calculated destination position. */
    memcpy(dest_bytes + (dest_idx * el_size), src_bytes + (i * el_size), el_size);
    
    /* Increment Odometer (based on Source Layout) */
    if (direction_to_r) {
      /* Source is C (Last dim fast) */
      for (int d = rank - 1; d >= 0; d--) {
        coords[d]++;
        if (coords[d] < dims[d]) break;
        coords[d] = 0;
      }
    } else {
      /* Source is R (First dim fast) */
      for (int d = 0; d < rank; d++) {
        coords[d]++;
        if (coords[d] < dims[d]) break;
        coords[d] = 0;
      }
    }
  }
  
  free(coords); free(c_strides); free(r_strides);
}

/*
 * Determines the target R type for an HDF5 dataset or attribute based on user-provided mappings.
 *
 * This function resolves the `as` argument from `h5_read()`, which can be a simple string
 * (e.g., "integer") or a named vector for fine-grained control (e.g., `c(id = "integer", .float = "double")`).
 *
 * Matching Logic & Precedence:
 * 1. Global Override: If `rmap` is a single unnamed string (e.g., "bit64"),
 *    it applies to all integer/float data.
 * 2. Element Name: If `el_name` matches a name in `rmap`, that type is used.
 * 3. Specific Type: Checks for keys like ".int32", ".uint64", ".float32".
 * 4. Generic Category: Checks for keys like ".int" (signed), ".uint" (unsigned), ".float".
 * 5. Global Default: Checks for the key ".".
 * 6. Fallback: R_TYPE_AUTO.
 * 7. Replaces R_TYPE_AUTO with R_TYPE_DOUBLE for floating-point data.
 *
 * @param file_type_id   The HDF5 datatype ID of the source.
 * @param rmap           The `as` argument from R (character vector).
 * @param element_name   The basename of the dataset/attribute/column.
 * @return               The target R_TYPE enum.
 */
R_TYPE rtype_from_map(hid_t file_type_id, SEXP rmap, const char *el_name) {

  if (rmap == R_NilValue || LENGTH(rmap) == 0) return R_TYPE_AUTO;
  
  /* Retrieve the names attribute and HDF5 class. */
  SEXP        names_vec = getAttrib(rmap, R_NamesSymbol);
  H5T_class_t class_id  = H5Tget_class(file_type_id);

  /* Check for global type coercion (length 1, unnamed). */
  if (LENGTH(rmap) == 1 && names_vec == R_NilValue) {
    const char *rtype = CHAR(STRING_ELT(rmap, 0));
    if (strcmp(rtype, "logical") == 0) return R_TYPE_LOGICAL;
    if (strcmp(rtype, "integer") == 0) return R_TYPE_INTEGER;
    if (strcmp(rtype, "double")  == 0) return R_TYPE_DOUBLE;
    if (strcmp(rtype, "bit64")   == 0) return R_TYPE_BIT64;
    if (strcmp(rtype, "null")    == 0) return R_TYPE_NULL;
    if (class_id == H5T_FLOAT)         return R_TYPE_DOUBLE;
    return R_TYPE_AUTO;
  }

  if (names_vec == R_NilValue) return R_TYPE_AUTO;

  /* Check if el_name matches a specific entry in rmap. */
  for (int i = 0; i < LENGTH(rmap); i++) {
    const char *key = Rf_translateCharUTF8(STRING_ELT(names_vec, i));
    if (strcmp(key, el_name) == 0) {
      const char *value = CHAR(STRING_ELT(rmap, i));
      if (strcmp(value, "logical") == 0) return R_TYPE_LOGICAL;
      if (strcmp(value, "integer") == 0) return R_TYPE_INTEGER;
      if (strcmp(value, "double")  == 0) return R_TYPE_DOUBLE;
      if (strcmp(value, "bit64")   == 0) return R_TYPE_BIT64;
      if (strcmp(value, "null")    == 0) return R_TYPE_NULL;
      if (class_id == H5T_FLOAT)         return R_TYPE_DOUBLE;
      return R_TYPE_AUTO;
    }
  }

  /* Search for type-specific and general type mappings. */

  char needle_full[12];
  char needle_type[12];

  /* Construct type keys (e.g., ".int32", ".uint") based on HDF5 class and sign. */
  int bitwidth = (int)H5Tget_size(file_type_id) * 8;
  if (class_id == H5T_FLOAT) {
    snprintf(needle_type, sizeof(needle_type), ".float");
    snprintf(needle_full, sizeof(needle_full), ".float%d", bitwidth);
  }
  else if (H5Tget_sign(file_type_id) == H5T_SGN_NONE) {
    snprintf(needle_type, sizeof(needle_type), ".uint");
    snprintf(needle_full, sizeof(needle_full), ".uint%d", bitwidth);
  }
  else {
    snprintf(needle_type, sizeof(needle_type), ".int");
    snprintf(needle_full, sizeof(needle_full), ".int%d", bitwidth);
  }

  R_TYPE dot_match  = R_TYPE_NOMATCH;
  R_TYPE type_match = R_TYPE_NOMATCH;
  
  /* Iterate through mappings to find type-based keys or the default "." key. */
  for (int i = 0; i < LENGTH(rmap); i++) {
    
    const char *key = Rf_translateCharUTF8(STRING_ELT(names_vec, i));
    
    /* Check for matches: specific type (.int32), general type (.int), or default (.) */
    if (strcmp(key, needle_full) == 0 || strcmp(key, needle_type) == 0 || strcmp(key, ".") == 0) {
    
      const char *value = CHAR(STRING_ELT(rmap, i));

      R_TYPE result = R_TYPE_DOUBLE;
      if (strcmp(value, "logical") == 0) result = R_TYPE_LOGICAL;
      if (strcmp(value, "integer") == 0) result = R_TYPE_INTEGER;
      if (strcmp(value, "bit64")   == 0) result = R_TYPE_BIT64;
      if (strcmp(value, "null")    == 0) result = R_TYPE_NULL;
      
      /* Prioritize specific matches over general ones */
      if      (strcmp(key, needle_full) == 0) { return result;       }
      else if (strcmp(key, needle_type) == 0) { type_match = result; }
      else                                    { dot_match  = result; }
    }
  }

  if (type_match != R_TYPE_NOMATCH) return type_match;
  if (dot_match  != R_TYPE_NOMATCH) return dot_match;
  if (class_id == H5T_FLOAT)        return R_TYPE_DOUBLE;

  return R_TYPE_AUTO;
}


/*
 * Coerces a numeric R vector to the target R type (integer, logical, etc.).
 *
 * This function handles the final conversion step after reading data from HDF5.
 * It supports:
 * 1. "auto": Checks if double values fit within R's integer range. If so, converts
 *    to integer. Otherwise, leaves as double. Only checks H5T_INTEGER file classes.
 * 2. "bit64": Adds the "integer64" class attribute for 64-bit integers.
 * 3. "logical" / "integer": Forces coercion using R's standard coercion functions.
 *
 * @param data         The R vector (usually REALSXP) containing the read data.
 * @param rtype        The target type determined by `rtype_from_map`.
 * @param file_type_id The HDF5 file datatype ID (used for size checks in "auto" mode).
 * @return             The coerced R vector (protected).
 */
SEXP coerce_to_rtype(SEXP data, R_TYPE rtype, hid_t file_type_id) {

  PROTECT(data);
  
  H5T_class_t data_class = H5Tget_class(file_type_id);
  
  if (rtype == R_TYPE_AUTO && data_class == H5T_INTEGER) {
    char as_integer = 1;
    
    /* Check for R integer overflow.
     * If the HDF5 type is 32-bit or larger (e.g. uint32, int64), values might
     * exceed R's 32-bit integer range (+/- 2e9). We scan the data to verify.
     */
    if (H5Tget_size(file_type_id) >= 4) {
      double *dbl_vec = REAL(data);
      R_xlen_t n_rows = XLENGTH(data);
      for (R_xlen_t i = 0; (i < n_rows) && as_integer; i++) {
        double val = dbl_vec[i];
        /* Check if value is within [INT_MIN, INT_MAX], (INT_MIN used for NA) */
        as_integer = (val > INT_MIN && val <= INT_MAX);
      }
    }
    
    /* If all values fit in R's int, then convert from DOUBLE to INTEGER */
    if (as_integer) rtype = R_TYPE_INTEGER;
  }
  
  /* Add "integer64" class for R's bit64 package */
  if (rtype == R_TYPE_BIT64) {
    SEXP class_attr = PROTECT(allocVector(STRSXP, 1));
    SET_STRING_ELT(class_attr, 0, mkChar("integer64"));
    setAttrib(data, R_ClassSymbol, class_attr);
    UNPROTECT(1);
  }
  /* Handle explicit Logical coercion */
  else if (rtype == R_TYPE_LOGICAL) {
    data = coerceVector(data, LGLSXP);
  }
  /* Handle explicit Integer coercion (or automatic integer) */
  else if (rtype == R_TYPE_INTEGER) {
    data = coerceVector(data, INTSXP);
  }

  UNPROTECT(1);
  return data;
}
