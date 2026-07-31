# Cryptanalysis and Secure Reconstruction of Falcon-M (FM-HC-120)

This repository contains the companion source code for the MDPI *Symmetry* submission: **"Cryptanalysis and Secure Reconstruction of the Falcon-M Signature Scheme"**. 

It provides the complete scripts to reproduce the cryptanalysis (universal forgery and salt-search experiments) against Falcon-M, as well as the C implementation of our proposed secure profile, **FM-HC-120**, including the fully implemented hedged randomization mechanism and performance benchmarks.

---

##  Repository Structure

*   **`code1.sage`**: The SageMath script reproducing the 1,000,000-trial salt-search universal forgery attack against Falcon-M.
*   **`code3.sage`**: The SageMath script evaluating the honest signature acceptance rate of Falcon-M, proving the functional correctness failure.
*   **`code2.c`**: The C language implementation of the FM-HC-120 scheme, featuring the required hedged randomization and performance benchmarking against standard NIST PQC algorithms (Falcon-512, ML-DSA-44).
*   **`test_vectors.txt`**: Standard Known Answer Tests (KATs) for FM-HC-120, providing fixed seed inputs and expected signature outputs for correct implementation verification.

---

##  System Requirements & Dependencies

To ensure exact reproducibility, the experimental environments used in the paper are listed below.

### 1. SageMath Environment (For Cryptanalysis)
The cryptanalysis scripts simulate exact algebraic cancellations over finite fields.
*   **OS:** Debian 9.9
*   **Software:** SageMath 7.4 (or later compatible versions)

### 2. C Environment (For FM-HC-120 Benchmarks)
The performance benchmarks utilize hardware-specific optimizations (e.g., AVX-512) and rely on standard cryptographic libraries.
*   **OS:** Debian 12
*   **Compiler:** GCC 12.2.0 (with `-O3 -march=native` flags)
*   **Dependencies:** 
    *   OpenSSL (`libssl-dev`): Required for `shake256_hash` and `RAND_bytes`.
    *   liboqs (`liboqs-dev`): The Open Quantum Safe library, required for instantiating the baseline ML-DSA-44 and Falcon-512 benchmarking comparisons.
    *   **HAETAE-120 Reference Implementation**: Since FM-HC-120 builds upon the HAETAE-120 core, `code2.c` requires the underlying NIST submission headers and source files to compile.

**Ubuntu/Debian Installation for C dependencies:**
```bash
sudo apt-get update
sudo apt-get install build-essential libssl-dev liboqs-dev

```

---

##  Execution Instructions

### 1. Reproducing the Falcon-M Forgery (Salt-Search Experiment)

Run the universal forgery simulation. This script will output the success rates across different maximum salt retries to a text file (`falcon_m_results.txt`), matching the experimental data in Table 2 of the manuscript.

```bash
sage code1.sage

```

### 2. Reproducing the Honest Signature Test

Run the script to verify the structural failure of honest Falcon-M signatures. It will output the acceptance rate (expected 0.00%) to `falcon_m_honest_results.txt`.

```bash
sage code3.sage

```

### 3. Compiling and Running FM-HC-120 Benchmarks

The FM-HC-120 implementation strictly integrates the **hedged randomization mechanism** during the signing phase. As detailed in `code2.c`, the masking seed is generated securely by hashing a combination of the secret key component, a 32-byte true random number (`rnd` via `RAND_bytes`), and the target message digest `mu`.

**Compilation setup:** Place `code2.c` inside the root directory of the official HAETAE-120 reference implementation (which contains the `include/` and `src/` directories) to ensure proper linking of the cryptographic core.

To compile and execute the benchmark:

```bash
# Compile the C benchmark alongside the HAETAE-120 underlying source files
gcc -O3 -march=native -Wall -I./include code2.c $(find ./src -name "*.c" ! -name "rng.c") -o benchmark -lcrypto -loqs

# Run the benchmark
./benchmark

```

---

##  Test Vectors (KAT)

To facilitate third-party verification of the FM-HC-120 algorithms, we provide deterministic test vectors. Please refer to the `test_vectors.txt` file in this repository. It includes hex-encoded outputs for:

* `seed`: The initial entropy for key generation (if fixed).
* `pk`: The compressed public key (`pk_core` + `tr`).
* `sk`: The secret key structure.
* `m` & `ctx`: The target message and context string.
* `sm`: The resulting signed message payload, ensuring the `UseHint` and high-bit recovery mechanisms function deterministically.

---

```

```
