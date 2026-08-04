from sage.all import *
import random
import math

set_random_seed(12345)
random.seed(12345)

def test_falcon_m_honest_signatures(trials=1000000, output_file="falcon_m_honest_results.txt"):
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

    sigma_dist = delta / 3.0

    honest_success_count = 0
    honest_error_norms = []

    for trial_idx in range(trials):
        a = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])
        b = vector(Zq, [ZZ.random_element(-100, 100) for _ in range(n)])

        A_freq = NTT_mat * a
        B_freq = NTT_mat * b
        H_pk_freq = vector(Zq, [A_freq[i] * B_freq[i] for i in range(n)])

        c_star = vector(Zq, [ZZ.random_element(0, q-1) for _ in range(n)])

        s_honest_coeffs = []
        for i in range(n):
            noise = sample_bounded_discrete_gaussian(sigma_dist, bound=delta)
            s_honest_coeffs.append(c_star[i] + noise)
        sigma_honest = vector(Zq, s_honest_coeffs)

        S_honest_freq = NTT_mat * sigma_honest
        Y_honest_freq = vector(Zq, [H_pk_freq[i] * S_honest_freq[i] for i in range(n)])
        y_honest_time = INTT_mat * Y_honest_freq

        error_norm_honest = max(abs(lift_centered(y_honest_time[i] - c_star[i])) for i in range(n))
        is_honest_success = (error_norm_honest <= delta)

        if is_honest_success:
            honest_success_count += 1
        honest_error_norms.append(error_norm_honest)

    honest_succ_rate = float(honest_success_count) / trials * 100
    avg_honest_err = float(sum(honest_error_norms)) / trials
    return honest_succ_rate, avg_honest_err

if __name__ == "__main__":
    test_falcon_m_honest_signatures(1000000)
