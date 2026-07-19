# -*- coding: utf-8 -*-

from sage.all import *
import time

def test_falcon_m_forgery(trials=1000000, output_file="falcon_m_results.txt"):
    with open(output_file, "w") as f:

        def log(msg=""):
            print(msg)
            f.write(str(msg) + "\n")
            f.flush()

        log("Initialization: n=512, q=12289, Delta=20, trials={}".format(trials))

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

        success_count = 0
        invertible_count = 0

        error_norms_invertible = []
        error_norms_non_invertible = []
        forgery_times = []

        for trial_idx in range(trials):
            a = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])
            b = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])

            A_freq = NTT_mat * a
            B_freq = NTT_mat * b
            H_pk_freq = vector(Zq, [A_freq[i] * B_freq[i] for i in range(n)])

            is_invertible = all(val != 0 for val in H_pk_freq)
            if is_invertible:
                invertible_count += 1

            c_star = vector(Zq, [ZZ.random_element(0, q-1) for _ in range(n)])
            C_freq = NTT_mat * c_star

            start_time = time.time()

            Sigma_freq = []
            for i in range(n):
                if H_pk_freq[i] != 0:
                    Sigma_freq.append(C_freq[i] / H_pk_freq[i])
                else:
                    Sigma_freq.append(Zq(0))
            Sigma_freq = vector(Zq, Sigma_freq)

            sigma_star = INTT_mat * Sigma_freq
            end_time = time.time()

            forgery_times.append((end_time - start_time) * 1000)

            Y_freq = vector(Zq, [H_pk_freq[i] * Sigma_freq[i] for i in range(n)])
            y_time = INTT_mat * Y_freq

            error_norm = max(abs(lift_centered(y_time[i] - c_star[i])) for i in range(n))
            is_success = (error_norm <= delta)

            if is_success:
                success_count += 1

            if is_invertible:
                error_norms_invertible.append(error_norm)
            else:
                error_norms_non_invertible.append(error_norm)

        inv_rate = float(invertible_count) / trials * 100
        succ_rate = float(success_count) / trials * 100
        avg_forgery_time = sum(forgery_times) / trials
        max_err_inv = max(error_norms_invertible) if error_norms_invertible else 0
        max_err_non_inv = max(error_norms_non_invertible) if error_norms_non_invertible else 0

        log("\n--- Final Results ---")
        log("Total Trials: {}".format(trials))
        log("Fully Invertible PKs: {} ({:.2f}%)".format(invertible_count, inv_rate))
        log("Successful Forgeries: {} ({:.2f}%)".format(success_count, succ_rate))
        log("Avg Forgery Time: {:.4f} ms".format(avg_forgery_time))
        log("Max L_inf Error (Inv): {}".format(max_err_inv))
        log("Max L_inf Error (Non-Inv): {}".format(max_err_non_inv))

test_falcon_m_forgery(1000000, "falcon_m_results.txt")