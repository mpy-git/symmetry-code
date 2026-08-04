# -*- coding: utf-8 -*-

from sage.all import *
import hashlib
import random
import math
import time

set_random_seed(12345)
random.seed(12345)

def run_end_to_end_test():
    q = 12289
    n = 512
    delta = 20
    Zq = GF(q)

    g = Zq.multiplicative_generator()
    w = g^((q - 1) / (2 * n))
    roots = [w^(2*i + 1) for i in range(n)]

    NTT_mat = matrix(Zq, n, n, lambda i, j: roots[i]^j)
    inv_n = Zq(n)^-1
    INTT_mat = matrix(Zq, n, n, lambda i, j: inv_n * roots[j]^(-i))

    def lift_centered(val):
        v = Integer(val)
        if v > q // 2:
            v -= q
        return v

    def hash_to_ring(msg_bytes):
        digest = hashlib.sha512(msg_bytes).digest()
        rng = random.Random(digest)
        return vector(Zq, [rng.randint(0, q-1) for _ in range(n)])

    def sample_bounded_discrete_gaussian(sigma, bound):
        support = list(range(-bound, bound + 1))
        weights = [math.exp(-(x**2) / (2.0 * sigma**2)) for x in support]
        total_weight = sum(weights)
        pmf = [w / total_weight for w in weights]
        cdf = []
        cumulative = 0.0
        for p in pmf:
            cumulative += p
            cdf.append(cumulative)
        u = random.random()
        for i, prob in enumerate(cdf):
            if u <= prob:
                return support[i]
        return support[-1]

    def KeyGen():
        a = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])
        b = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])
        A_freq = NTT_mat * a
        B_freq = NTT_mat * b
        H_freq = vector(Zq, [A_freq[i] * B_freq[i] for i in range(n)])
        h_time = INTT_mat * H_freq
        return h_time, H_freq, a, b

    def Sign_Honest(msg_bytes):
        H_m = hash_to_ring(msg_bytes)
        sigma_dist = delta / 3.0
        s_coeffs = []
        for i in range(n):
            noise = sample_bounded_discrete_gaussian(sigma_dist, bound=delta)
            s_coeffs.append(H_m[i] + noise)
        s = vector(Zq, s_coeffs)
        return s

    def Verify(h_time, msg_bytes, sigma):
        H_m = hash_to_ring(msg_bytes)
        H_freq = NTT_mat * h_time
        Sigma_freq = NTT_mat * sigma
        Y_freq = vector(Zq, [H_freq[i] * Sigma_freq[i] for i in range(n)])
        y_time = INTT_mat * Y_freq
        error_norm = max(abs(lift_centered(y_time[i] - H_m[i])) for i in range(n))
        is_accept = (error_norm <= delta)
        return is_accept, error_norm

    def Sign_Forge(H_pk_freq, msg_bytes):
        H_m = hash_to_ring(msg_bytes)
        C_freq = NTT_mat * H_m
        Sigma_freq = []
        for i in range(n):
            if H_pk_freq[i] != Zq(0):
                Sigma_freq.append(C_freq[i] / H_pk_freq[i])
            else:
                Sigma_freq.append(Zq(0))
        Sigma_freq = vector(Zq, Sigma_freq)
        sigma_forged = INTT_mat * Sigma_freq
        return sigma_forged

    test_msg = b"Symmetry"

    while True:
        h_time, H_freq, _, _ = KeyGen()
        if all(val != 0 for val in H_freq):
            break

    sigma_honest = Sign_Honest(test_msg)
    is_acc_honest, err_honest = Verify(h_time, test_msg, sigma_honest)

    print(f"Honest: {'ACCEPT' if is_acc_honest else 'REJECT'} (error={err_honest})")

    sigma_forged = Sign_Forge(H_freq, test_msg)
    is_acc_forged, err_forged = Verify(h_time, test_msg, sigma_forged)

    print(f"Forgery: {'ACCEPT' if is_acc_forged else 'REJECT'} (error={err_forged})")

if __name__ == "__main__":
    run_end_to_end_test()
