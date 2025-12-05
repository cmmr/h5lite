# scripts/verify_h5.py
import h5py
import numpy as np
import sys

file_path = "test_interop.h5"

def fail(msg):
    print(f"FAILURE: {msg}")
    sys.exit(1)

def as_scalar(val):
    """Helper to safely extract scalar values from 0-d or 1-d numpy arrays."""
    if isinstance(val, np.ndarray):
        if val.size == 1:
            return val.item()
    return val

try:
    with h5py.File(file_path, "r") as f:
        print(f"Successfully opened {file_path}")

        # --- 1. Verify Vectors ---
        data = f["vec_double"][:]
        expected = np.array([1.1, 2.2, 3.3])
        if not np.allclose(data, expected):
            fail(f"vec_double mismatch.\nExpected: {expected}\nGot: {data}")
        print("Verified vec_double")

        data = f["vec_int"][:]
        expected = np.array([1, 2, 3, 4, 5])
        if not np.array_equal(data, expected):
            fail(f"vec_int mismatch.\nExpected: {expected}\nGot: {data}")
        print("Verified vec_int")

        data = f["vec_logical"][:]
        expected = np.array([1, 0, 1])
        if not np.array_equal(data, expected):
            fail(f"vec_logical mismatch.\nExpected: {expected}\nGot: {data}")
        print("Verified vec_logical")

        data = f["vec_char"][:]
        expected = np.array([b"apple", b"banana", b"cherry"])
        if not np.array_equal(data, expected):
            fail(f"vec_char mismatch.\nExpected: {expected}\nGot: {data}")
        print("Verified vec_char")

        # --- 2. Verify Matrix ---
        data = f["matrix_int"][:]
        expected = np.array([[1, 3, 5], [2, 4, 6]])
        
        if data.shape != (2, 3):
             fail(f"Matrix shape mismatch. Expected (2,3), Got {data.shape}")
        
        if not np.array_equal(data, expected):
            fail(f"matrix_int mismatch.\nExpected:\n{expected}\nGot:\n{data}")
        print("Verified matrix_int")

        # --- 3. Verify Data Frame ---
        data = f["dataframe"][:]
        if data['id'][0] != 1 or data['score'][1] != 20.5 or data['label'][2] != b'C':
             fail(f"dataframe content mismatch. Got: {data}")
        print("Verified dataframe")

        # --- 4. Verify Attributes ---
        dset = f["dset_with_attr"]
        
        # Check 'unit' attribute
        if "unit" not in dset.attrs:
            fail("Attribute 'unit' missing")
            
        unit_val = as_scalar(dset.attrs["unit"])
        # h5py might return bytes, decode if necessary
        if isinstance(unit_val, bytes):
            unit_val = unit_val.decode()
            
        if unit_val != "meters":
            fail(f"Attribute 'unit' mismatch. Expected 'meters', Got: {unit_val}")

        # Check 'scale' attribute
        if "scale" not in dset.attrs:
             fail("Attribute 'scale' missing")
             
        scale_val = as_scalar(dset.attrs["scale"])
        if not np.isclose(scale_val, 1.5):
             fail(f"Attribute 'scale' mismatch. Expected 1.5, Got: {scale_val}")
             
        print("Verified attributes")

    print("\nALL TESTS PASSED")

except Exception as e:
    fail(f"An exception occurred: {e}")
