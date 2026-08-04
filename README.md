# Cryptanalysis of the Falcon-M Signature Scheme

This repository contains the companion source code for the paper:  
**"Cryptanalysis of the Falcon-M Signature Scheme"** 

It provides complete SageMath scripts to reproduce the attacks described in the paper, including the universal forgery via algebraic inversion and the salt-search existential forgery, as well as a direct end-to-end demonstration of the structural flaw.

---

## 1. Experimental Instantiation Details (Important Notes)

### 1.1 Discrete Gaussian Sampling
To strictly simulate the intended algorithmic behavior, honest signatures are generated using a precise Discrete Gaussian sampling procedure across all relevant scripts (`code2.sage` and `code3.sage`):
- **Gaussian Parameter:** $\sigma = \delta / 3.0$ (where $\delta = 20$).
- **Truncation Interval:** Strictly bounded to $[-\delta, \delta]$.
- **Numerical Method:** Cumulative Distribution Function (CDF) inversion.
- **Precision:** Standard 53-bit floating-point precision (IEEE 754) provided by Python's native math libraries.


### 1.2 Computational Complexity
While the universal forgery is theoretically bounded by $\mathcal{O}(n \log n)$ via a fast Number Theoretic Transform (NTT), the scripts in this repository prioritize mathematical transparency. They utilize dense matrix multiplication to represent the NTT over the polynomial ring, operating at an actual empirical complexity of $\mathcal{O}(n^2)$. Optimizing for exact asymptotic performance requires specialized NTT implementations.

---

## 2. Reproducibility & System Requirements

To ensure exact statistical reproducibility, all scripts utilize a fixed random seed (`set_random_seed(12345)` and `random.seed(12345)`). 

**Permanent Release / Commit Identifier:** 
- Release Tag: `v2.0-Revision` 

**Prerequisites:**
- **OS:** Debian 9.9 (or compatible Linux environment)
- **Software:** SageMath 7.4 (or later) utilizing Python 3.x

---

## 3. Execution Instructions

The statistical invertibility experiments and end-to-end forgery demonstrations are clearly separated into distinct scripts.

### 3.1 Reproduce the Salt-Search Forgery Attack (`code1.sage`)
Evaluates the complete invertibility rate of public keys and calculates the expected search counts (retry budgets) for localized existential forgeries across 1,000,000 independent trials.

**Exact Command:**
```bash
sage code1.sage

```

**Measured Runtime:** ~6.5 hours on an Intel Xeon Gold 6271C CPU (2.60 GHz) for 1,000,000 trials.

---

### 3.2 End-to-End Vulnerability Demonstration (`code2.sage`)

A concrete, end-to-end evaluation that explicitly generates an honest signature (using exact discrete Gaussian noise) and a forged signature via algebraic division. **Crucially, both signatures are submitted to the exact same `Verify` function** to record the acceptance results.

**Exact Command:**

```bash
sage code2.sage

```

**Example Output:**

```
Honest: REJECT (error=6129)
Forgery: ACCEPT (error=0)

```

**Measured Runtime:** < 1 second.

---

### 3.3 Evaluate Honest Signature Acceptance Rate (`code3.sage`)

Rigorously evaluates 1,000,000 honestly generated signatures (using the specified discrete Gaussian distribution) to empirically demonstrate the fundamental correctness failure of the scheme.

**Exact Command:**

```bash
sage code3.sage

```

**Example Output (Excerpt):**

```
--- Final Results: Honest Signature Test ---
Total Trials: 1000000
Honest Acceptance Rate: 0.00% (Expected: negligible)
Average Honest L_inf Error: 6128.55 (Expected: ~6144, Threshold: 20)

```

**Measured Runtime:** ~3.1 hours on an Intel Xeon Gold 6271C CPU (2.60 GHz).

---

## License & Contact

This repository is provided for academic and research purposes only. Please refer to the original paper for detailed licensing and attribution. For questions or issues regarding the code, please open an issue on this repository.

```

```
