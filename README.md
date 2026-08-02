# Cryptanalysis of the Falcon‑M Signature Scheme

This repository contains the companion source code for the paper:  
**"Cryptanalysis of the Falcon‑M Signature Scheme"** (to appear in *Symmetry*).

It provides complete SageMath scripts to reproduce the attacks described in the paper, including the universal forgery via algebraic inversion and the salt‑search existential forgery, as well as a direct end‑to‑end demonstration of the structural flaw.

---

## Repository Structure

- **`code1.sage`** – Reproduces the **1,000,000‑trial salt‑search universal forgery attack** against Falcon‑M, outputting success rates for various retry budgets (matching Table 2 in the paper).
- **`code2.sage`** – **End‑to‑end cryptanalysis test** that demonstrates:
  - Honest signature generation (using exact discrete Gaussian sampling) **always fails** verification (zero acceptance rate).
  - Universal forgery via pointwise algebraic division in the frequency domain **always succeeds** when the public key is fully invertible.
- **`code3.sage`** – Independently evaluates the **honest signature acceptance rate** of Falcon‑M, confirming that the structural defect causes a 0% acceptance rate.
- **`test_vectors.txt`** – Reserved for future Known Answer Tests (KAT) if a secure variant (e.g., FM‑HC‑120) is later provided; currently a placeholder.

---

## System Requirements & Dependencies

All scripts are written in **SageMath** and have been tested under the following environment:

- **OS:** Debian 9.9 (or compatible)
- **Software:** SageMath 7.4 (or later)

---

## Execution Instructions

### 1. Reproduce the Salt‑Search Forgery Attack (`code1.sage`)

Run the universal forgery simulation. Results will be written to `falcon_m_results.txt`.

```bash
sage code1.sage
```

### 2. Run the End‑to‑End Vulnerability Demonstration (`code2.sage`)

This script performs the following steps:

- Generates a Falcon‑M key pair, forcing a **fully invertible** public key for clear attack demonstration.
- Generates an **honest signature** using exact discrete Gaussian sampling and verifies it – expected to **reject**.
- Constructs a **forged signature** via frequency‑domain algebraic division and verifies it – expected to **accept** with zero error.

```bash
sage code2.sage
```

Example output:

```
Honest: REJECT (error=6129)
Forgery: ACCEPT (error=0)
```

### 3. Evaluate Honest Signature Acceptance Rate (`code3.sage`)

Runs a large number of honest signatures and outputs the acceptance rate to `falcon_m_honest_results.txt` (expected to be 0.00%).

```bash
sage code3.sage
```

---

## Theoretical Background

Falcon‑M removes the NTRU trapdoor mechanism (\(fG - gF = q\)) to achieve lightweight performance. However, this causes the verification equation to degenerate into a **publicly solvable linear system**:

\[
\| \text{IFFT}(H_{pk}(\omega) \odot \Sigma(\omega)) - H(m) \|_{\infty} \leq \delta
\]

Since the only unknown is the signature polynomial, an adversary can perform **pointwise algebraic inversion** in the frequency domain:

\[
\Sigma(\omega) = C(\omega) \odot H_{pk}^{-1}(\omega)
\]

For invertible public keys (about \(91.99\%\) of cases under parameters \(n=512, q=12289\)), this yields a valid forgery with **zero residual error** and time complexity \(O(n \log n)\). For non‑invertible keys, a salt‑search strategy achieves existential forgery with expected \(q^k\) iterations.

`code2.sage` implements this exact attack side‑by‑side with honest signing, providing a clear visual proof of the vulnerability.

---


## License

This repository is provided for academic and research purposes only. Please refer to the original paper for detailed licensing and attribution.

---

## References

> Zuo, L., Ma, P., Xu, S., Zhang, Z., & Zhao, Y. (2026). Cryptanalysis of the Falcon‑M Signature Scheme. *Symmetry*.

---

## Contact

For questions or issues regarding the code, please open an issue on this repository.

---
