#include "h5lite.h"
#include <stdlib.h>
#include <string.h>

/* * direction_to_r = 1 : HDF5 (Row-Major) -> R (Col-Major)
 * direction_to_r = 0 : R (Col-Major) -> HDF5 (Row-Major)
 */
void h5_transpose(void *src, void *dest, int rank, hsize_t *dims, size_t el_size, int direction_to_r) {
  if (rank <= 1) {
    hsize_t total = 1;
    if (rank == 1) total = dims[0];
    memcpy(dest, src, total * el_size);
    return;
  }
  
  hsize_t total_elements = 1;
  for (int i = 0; i < rank; i++) total_elements *= dims[i];
  
  /* Strides calculation */
  hsize_t *c_strides = (hsize_t *)malloc(rank * sizeof(hsize_t));
  c_strides[rank - 1] = 1;
  for (int i = rank - 2; i >= 0; i--) c_strides[i] = c_strides[i + 1] * dims[i + 1];
  
  hsize_t *r_strides = (hsize_t *)malloc(rank * sizeof(hsize_t));
  r_strides[0] = 1;
  for (int i = 1; i < rank; i++) r_strides[i] = r_strides[i - 1] * dims[i - 1];
  
  /* Determine which stride is Source vs Dest */
  hsize_t *dest_strides = direction_to_r ? r_strides : c_strides;
  
  hsize_t *coords = (hsize_t *)calloc(rank, sizeof(hsize_t));
  char *src_bytes = (char *)src;
  char *dest_bytes = (char *)dest;
  
  /* Iterate through Source linearly */
  for (hsize_t i = 0; i < total_elements; i++) {
    
    /* Calculate Dest Index based on current odometer coords */
    hsize_t dest_idx = 0;
    for (int d = 0; d < rank; d++) {
      dest_idx += coords[d] * dest_strides[d];
    }
    
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
