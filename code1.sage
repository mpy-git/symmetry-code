# -*- coding: utf-8 -*-

from sage.all import *
import time
import hashlib
import random

set_random_seed(12345)
random.seed(int(12345))

def test_falcon_m_forgery_retry(trials=10000, output_file="falcon_m_results.txt"):
    with open(output_file, "w") as f:
        def log(msg=""):
            print(msg)
            f.write(str(msg) + "\n")
            f.flush()

        retry_budgets = [0, 1, 5, 10, 20, 100, 500, 1000]
        success_counts = {b: 0 for b in retry_budgets}

        q = 12289
        n = 512
        Zq = GF(q)

        g = Zq.multiplicative_generator()
        w = g^((q - 1) / (2 * n))
        roots = [w^(2*i + 1) for i in range(n)]

        NTT_mat = matrix(Zq, n, n, lambda i, j: roots[i]^j)
        inv_n = Zq(n)^-1
        INTT_mat = matrix(Zq, n, n, lambda i, j: inv_n * roots[j]^(-i))

        invertible_count = 0
        msg_base = b"Falcon-M Universal Forgery"

        start_time = time.time()

        for trial_idx in range(trials):
            a = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])
            b = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])

            A_freq = NTT_mat * a
            B_freq = NTT_mat * b
            H_pk_freq = vector(Zq, [A_freq[i] * B_freq[i] for i in range(n)])

            is_invertible = all(val != 0 for val in H_pk_freq)
            if is_invertible:
                invertible_count += 1

            min_salt_needed = -1
            max_retry_limit = max(retry_budgets)

            for salt in range(max_retry_limit + 1):
                data = msg_base + str(trial_idx).encode('utf-8') + str(salt).encode('utf-8')
                digest = hashlib.sha512(data).digest()
                local_rand = random.Random(digest)

                c_star = vector(Zq, [local_rand.randint(0, q-1) for _ in range(n)])
                C_freq = NTT_mat * c_star

                exact_cancellation = True
                Sigma_freq = []

                for i in range(n):
                    if H_pk_freq[i] != Zq(0):
                        Sigma_freq.append(C_freq[i] / H_pk_freq[i])
                    else:
                        Sigma_freq.append(Zq(0))
                        if C_freq[i] != Zq(0):
                            exact_cancellation = False

                if exact_cancellation:
                    min_salt_needed = salt
                    break

            if min_salt_needed != -1:
                for b in retry_budgets:
                    if min_salt_needed <= b:
                        success_counts[b] += 1

        end_time = time.time()
        total_time = end_time - start_time

        inv_rate = float(invertible_count) / trials * 100

        log("\n--- Final Results (Modular Ring Exact Match) ---")
        log("Total Trials: {}".format(trials))
        log("Simulation Time: {:.2f} s".format(total_time))
        log("Fully Invertible PKs (0-retry success): {} ({:.2f}%)".format(invertible_count, inv_rate))
        log("\n-------------------------------------------------------")
        log("{:<25} | {}".format("Maximum Salt Retries", "Attack Success Rate"))
        log("-------------------------------------------------------")

        for b in sorted(retry_budgets):
            succ_rate = float(success_counts[b]) / trials * 100
            log("{:<25} | {:.2f}%".format(b, succ_rate))

        log("-------------------------------------------------------")

if __name__ == "__main__":
    test_falcon_m_forgery_retry(1000000, "falcon_m_results.txt")
