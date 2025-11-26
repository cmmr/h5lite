#include "h5lite.h"
#include <stdlib.h>
#include <string.h>

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
