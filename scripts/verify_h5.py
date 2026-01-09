import h5py
import numpy as np
import sys

# --- Reporting Helpers ---
def pass_msg(msg):
    print(f"  [PASS] {msg}")

def fail_msg(msg, expected=None, actual=None):
    print(f"  [FAIL] {msg}")
    if expected is not None:
        print(f"         Expected: {expected}")
        print(f"         Actual:   {actual}")
    return False

def check_eq(actual, expected, name):
    # Handles lists, numpy arrays, and scalers
    actual_arr = np.array(actual)
    expected_arr = np.array(expected)
    
    # Check shape first
    if actual_arr.shape != expected_arr.shape:
        return fail_msg(f"{name} shape mismatch", expected_arr.shape, actual_arr.shape)

    # Check content
    # Use allclose for floats, equal for others
    if np.issubdtype(actual_arr.dtype, np.floating):
        match = np.allclose(actual_arr, expected_arr)
    else:
        match = np.array_equal(actual_arr, expected_arr)

    if match:
        pass_msg(f"{name} content match")
        return True
    else:
        return fail_msg(f"{name} value mismatch", expected, actual)

# --- Type Specific Verifiers ---

def verify_enum(dset, expected_labels, name):
    print(f"\n--- Verifying Enum: {name} ---")
    data = dset[:]
    
    # 1. Get the Map
    dtype = dset.dtype
    mapping = h5py.check_dtype(enum=dtype)
    if not mapping:
        return fail_msg("Dataset is not an HDF5 ENUM")
    
    # 2. Decode Integers to Strings
    rev_mapping = {v: k for k, v in mapping.items()}
    try:
        decoded = [rev_mapping[val] for val in data]
    except KeyError as e:
        return fail_msg(f"Found integer {e} in data with no Enum mapping!")

    # 3. Compare
    check_eq(decoded, expected_labels, "Labels")

def verify_compound(dset, expected_dict, name):
    print(f"\n--- Verifying Compound: {name} ---")
    data = dset[:]
    names = data.dtype.names
    
    for col_name, expected_vals in expected_dict.items():
        if col_name not in names:
            fail_msg(f"Column '{col_name}' missing from compound dataset")
            continue
            
        col_data = data[col_name]
        
        # Handle Byte Strings
        if col_data.dtype.kind == 'S': 
            col_data = [x.decode('utf-8') for x in col_data]
        
        # Handle Nested Enums
        elif h5py.check_dtype(enum=dset.dtype[col_name]):
            mapping = h5py.check_dtype(enum=dset.dtype[col_name])
            rev_mapping = {v: k for k, v in mapping.items()}
            col_data = [rev_mapping[x] for x in col_data]

        check_eq(col_data, expected_vals, f"Column '{col_name}'")

# --- Main Test Runner ---

filename = "interop_test.h5"
print(f"Opening {filename} for verification...")

with h5py.File(filename, "r") as f:
    
    # 1. Vectors
    print("\n--- Basic Vectors ---")
    check_eq(f["vec/int"], [1, 2, -5], "Integer Vector")
    check_eq(f["vec/dbl"], [1.1, 2.2, 3.14], "Double Vector")
    check_eq(f["vec/bool"], [1, 0, 1], "Boolean Vector (as 0/1)")
    
    # Strings (Decode bytes to utf-8)
    strs = [x.decode('utf-8') for x in f["vec/str"][:]]
    check_eq(strs, ["alpha", "bravo", "charlie"], "String Vector")

    # 2. Factors
    # Standard: small, medium, small, large
    verify_enum(f["factor/standard"], ["small", "medium", "small", "large"], "Standard Factor")
    
    # Reordered: z, x, y
    verify_enum(f["factor/reordered"], ["z", "x", "y"], "Reordered Factor")

    # 3. Matrices
    print("\n--- Matrices (Layout Check) ---")
    
    # Integer 2x3
    # R: 1, 3, 5 (row 1) / 2, 4, 6 (row 2)
    verify_matrix_int = [[1, 3, 5], [2, 4, 6]]
    check_eq(f["matrix/int_2x3"], verify_matrix_int, "Integer Matrix 2x3")
    
    # Double 3x2
    # R: 0.1, 0.4 / 0.2, 0.5 / 0.3, 0.6
    verify_matrix_dbl = [[0.1, 0.4], [0.2, 0.5], [0.3, 0.6]]
    check_eq(f["matrix/dbl_3x2"], verify_matrix_dbl, "Double Matrix 3x2")

    # 4. Compound
    verify_compound(f["compound/mixed"], {
        "id": [1, 2, 3],
        "code": ["A-1", "B-2", "C-3"],
        "status": ["ok", "fail", "ok"],
        "value": [10.5, 20.0, 15.5]
    }, "Mixed Data Frame")

    # 5. Attributes
    print("\n--- Attributes ---")
    dset = f["vec/int"]
    
    # Attr: description
    if "description" in dset.attrs:
        val = dset.attrs["description"]
        # H5py might return bytes or string depending on version/encoding
        if isinstance(val, bytes): val = val.decode('utf-8')
        check_eq(val, "Test Integers", "Attr 'description'")
    else:
        fail_msg("Attribute 'description' missing")

    # Attr: version
    if "version" in dset.attrs:
        check_eq(dset.attrs["version"], [1], "Attr 'version'")
    else:
        fail_msg("Attribute 'version' missing")

print("\nVerification Complete.")
