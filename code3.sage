# -*- coding: utf-8 -*-

from sage.all import *

def test_falcon_m_honest_signatures(trials=1000000, output_file="falcon_m_honest_results.txt"):
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

        honest_success_count = 0
        honest_error_norms = []

        for trial_idx in range(trials):
            a = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])
            b = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])

            A_freq = NTT_mat * a
            B_freq = NTT_mat * b
            H_pk_freq = vector(Zq, [A_freq[i] * B_freq[i] for i in range(n)])

            c_star = vector(Zq, [ZZ.random_element(0, q-1) for _ in range(n)])

            s_honest = vector(Zq, [c_star[i] + ZZ.random_element(-delta, delta) for i in range(n)])
            sigma_honest = s_honest

            S_honest_freq = NTT_mat * sigma_honest
            Y_honest_freq = vector(Zq, [H_pk_freq[i] * S_honest_freq[i] for i in range(n)])
            y_honest_time = INTT_mat * Y_honest_freq

            error_norm_honest = max(abs(lift_centered(y_honest_time[i] - c_star[i])) for i in range(n))
            is_honest_success = (error_norm_honest <= delta)

            if is_honest_success:
                honest_success_count += 1
            honest_error_norms.append(error_norm_honest)

            if (trial_idx + 1) % 50000 == 0:
                log("Progress: {}/{}".format(trial_idx + 1, trials))

        honest_succ_rate = float(honest_success_count) / trials * 100
        avg_honest_err = float(sum(honest_error_norms)) / trials

        log("\n--- Final Results: Honest Signature Test ---")
        log("Total Trials: {}".format(trials))
        log("Honest Acceptance Rate: {:.2f}% (Expected: 0%)".format(honest_succ_rate))
        log("Average Honest L_inf Error: {:.2f} (Expected: ~6144, Threshold: 20)".format(avg_honest_err))

test_falcon_m_honest_signatures(1000000, "falcon_m_honest_results.txt")
