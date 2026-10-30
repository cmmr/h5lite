/*
 * Generates tests/tinytests/files/foreign.h5: HDF5 objects that other software
 * (h5py, C programs) can write but h5lite never does, used by test-foreign.r.
 *
 * Build and run from the package root (Rtools gcc on Windows):
 *   gcc scripts/foreign_fixture.c -o foreign_fixture \
 *     $(Rscript -e 'cat(hdf5lib::c_flags())') $(Rscript -e 'cat(hdf5lib::ld_flags())') \
 *     $(R CMD config --ldflags)
 *   ./foreign_fixture tests/tinytests/files/foreign.h5    # R's bin/x64 must be on PATH
 */
#include <string.h>
#include <stdint.h>
#include "hdf5.h"
#include "hdf5_hl.h"

static hid_t vstr(void) {
  hid_t t = H5Tcopy(H5T_C_S1);
  H5Tset_size(t, H5T_VARIABLE);
  H5Tset_cset(t, H5T_CSET_UTF8);
  return t;
}

static hid_t mk_str_scale(hid_t f, const char *name, hsize_t n, const char **vals) {
  hid_t sp = H5Screate_simple(1, &n, NULL), t = vstr();
  hid_t ds = H5Dcreate2(f, name, t, sp, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
  H5Dwrite(ds, t, H5S_ALL, H5S_ALL, H5P_DEFAULT, vals);
  H5DSset_scale(ds, NULL);
  H5Tclose(t); H5Sclose(sp);
  return ds;
}

static hid_t mk_dbl(hid_t f, const char *name, int rank, hsize_t *dims) {
  double v[12] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
  hid_t sp = H5Screate_simple(rank, dims, NULL);
  hid_t ds = H5Dcreate2(f, name, H5T_IEEE_F64LE, sp, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
  H5Dwrite(ds, H5T_NATIVE_DOUBLE, H5S_ALL, H5S_ALL, H5P_DEFAULT, v);
  H5Sclose(sp);
  return ds;
}

int main(int argc, char **argv) {
  if (argc < 2) return 1;
  hid_t f = H5Fcreate(argv[1], H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);

  /* Dimension scales whose length differs from the dimension they label */
  { hsize_t d = 5; hid_t ds = mk_dbl(f, "short_scale", 1, &d);
    const char *s[3] = {"a", "b", "c"}; hid_t sc = mk_str_scale(f, "short_scale_names", 3, s);
    H5DSattach_scale(ds, sc, 0); H5Dclose(sc); H5Dclose(ds); }
  { hsize_t d = 3; hid_t ds = mk_dbl(f, "long_scale", 1, &d);
    const char *s[6] = {"a", "b", "c", "d", "e", "f"}; hid_t sc = mk_str_scale(f, "long_scale_names", 6, s);
    H5DSattach_scale(ds, sc, 0); H5Dclose(sc); H5Dclose(ds); }
  { hsize_t d[2] = {2, 3}; hid_t ds = mk_dbl(f, "mat_short_scale", 2, d);
    const char *s[2] = {"x", "y"}; hid_t sc = mk_str_scale(f, "mat_short_scale_colnames", 2, s);
    H5DSattach_scale(ds, sc, 1); H5Dclose(sc); H5Dclose(ds); }

  /* Enum holding a value (5) that is not one of its members */
  { hid_t et = H5Tenum_create(H5T_NATIVE_INT8); int8_t a = -1, b = 10, c = 100;
    H5Tenum_insert(et, "LOW", &a); H5Tenum_insert(et, "MID", &b); H5Tenum_insert(et, "HIGH", &c);
    hsize_t d = 4; hid_t sp = H5Screate_simple(1, &d, NULL);
    hid_t ds = H5Dcreate2(f, "enum_bad", et, sp, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
    int8_t vals[4] = {10, 5, -1, 100}; H5Dwrite(ds, et, H5S_ALL, H5S_ALL, H5P_DEFAULT, vals);
    H5Dclose(ds); H5Sclose(sp); H5Tclose(et); }

  /* Full-width fixed-length strings with SPACEPAD / NULLPAD (h5py writes NULLPAD) */
  { hsize_t d = 2; hid_t sp = H5Screate_simple(1, &d, NULL);
    hid_t t = H5Tcopy(H5T_C_S1); H5Tset_size(t, 5); H5Tset_strpad(t, H5T_STR_SPACEPAD);
    hid_t ds = H5Dcreate2(f, "str_spacepad", t, sp, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
    H5Dwrite(ds, t, H5S_ALL, H5S_ALL, H5P_DEFAULT, "ab   abcde"); H5Dclose(ds); H5Tclose(t);
    t = H5Tcopy(H5T_C_S1); H5Tset_size(t, 4); H5Tset_strpad(t, H5T_STR_NULLPAD);
    ds = H5Dcreate2(f, "str_nullpad", t, sp, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
    H5Dwrite(ds, t, H5S_ALL, H5S_ALL, H5P_DEFAULT, "abcdab\0\0"); H5Dclose(ds);

    /* The same inside a compound, plus an enum member with an unmapped value */
    hid_t et = H5Tenum_create(H5T_NATIVE_INT8); int8_t lo = 0, hi = 1;
    H5Tenum_insert(et, "lo", &lo); H5Tenum_insert(et, "hi", &hi);
    typedef struct { char s[4]; int8_t e; } rec;
    hid_t ct = H5Tcreate(H5T_COMPOUND, sizeof(rec));
    H5Tinsert(ct, "s", HOFFSET(rec, s), t); H5Tinsert(ct, "e", HOFFSET(rec, e), et);
    rec r[2]; memcpy(r[0].s, "abcd", 4); r[0].e = 1; memcpy(r[1].s, "xy\0\0", 4); r[1].e = 7;
    ds = H5Dcreate2(f, "cmpd_pad", ct, sp, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
    H5Dwrite(ds, ct, H5S_ALL, H5S_ALL, H5P_DEFAULT, r);
    hid_t at = H5Acreate2(ds, "label", t, sp, H5P_DEFAULT, H5P_DEFAULT);
    H5Awrite(at, t, "wxyzab\0\0"); H5Aclose(at);
    H5Dclose(ds); H5Tclose(ct); H5Tclose(et); H5Tclose(t); H5Sclose(sp); }

  /* Attributes whose names collide with R's structural attributes */
  { hsize_t d = 3; hid_t ds = mk_dbl(f, "attr_dim", 1, &d);
    hsize_t ad = 2; hid_t asp = H5Screate_simple(1, &ad, NULL); int dv[2] = {2, 2};
    hid_t a = H5Acreate2(ds, "dim", H5T_STD_I32LE, asp, H5P_DEFAULT, H5P_DEFAULT);
    H5Awrite(a, H5T_NATIVE_INT, dv); H5Aclose(a); H5Sclose(asp); H5Dclose(ds);
    ds = mk_dbl(f, "attr_class", 1, &d);
    hid_t t = vstr(), ssp = H5Screate(H5S_SCALAR); const char *cv = "foo";
    a = H5Acreate2(ds, "class", t, ssp, H5P_DEFAULT, H5P_DEFAULT); H5Awrite(a, t, &cv);
    H5Aclose(a); H5Sclose(ssp); H5Tclose(t); H5Dclose(ds); }

  /* uint64 values above INT64_MAX */
  { hsize_t d = 2; hid_t sp = H5Screate_simple(1, &d, NULL); uint64_t uv[2] = {18446744073709551615ULL, 7};
    hid_t ds = H5Dcreate2(f, "uint64_big", H5T_STD_U64LE, sp, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
    H5Dwrite(ds, H5T_NATIVE_UINT64, H5S_ALL, H5S_ALL, H5P_DEFAULT, uv); H5Dclose(ds); H5Sclose(sp); }

  H5Fclose(f);
  return 0;
}
