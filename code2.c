#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <oqs/oqs.h>
#include "api.h"
#include "params.h"

#define TR_BYTES 32
#define MU_BYTES 64
#define RND_BYTES 32
#define DS_BYTE 0x00

#define FM_HC_120_PK_BYTES (CRYPTO_PUBLICKEYBYTES + TR_BYTES)
#define FM_HC_120_SK_BYTES (CRYPTO_SECRETKEYBYTES + TR_BYTES)
#define FM_HC_120_SIG_BYTES CRYPTO_BYTES

static inline uint64_t cpucycles(void) {
    unsigned int hi, lo;
    __asm__ __volatile__ ("rdtsc\n\t" : "=a" (lo), "=d"(hi));
    return ((uint64_t)lo) | (((uint64_t)hi) << 32);
}

void shake256_hash(uint8_t *out, size_t out_len, const uint8_t *in, size_t in_len) {
    EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(mdctx, EVP_shake256(), NULL);
    EVP_DigestUpdate(mdctx, in, in_len);
    EVP_DigestFinalXOF(mdctx, out, out_len);
    EVP_MD_CTX_free(mdctx);
}

int FM_HC_120_KeyGen(uint8_t *pk, uint8_t *sk) {
    uint8_t pk_core[CRYPTO_PUBLICKEYBYTES];
    uint8_t sk_core[CRYPTO_SECRETKEYBYTES];
    uint8_t tr[TR_BYTES];
    if (crypto_sign_keypair(pk_core, sk_core) != 0) return -1;
    shake256_hash(tr, TR_BYTES, pk_core, CRYPTO_PUBLICKEYBYTES);
    memcpy(pk, pk_core, CRYPTO_PUBLICKEYBYTES);
    memcpy(pk + CRYPTO_PUBLICKEYBYTES, tr, TR_BYTES);
    memcpy(sk, sk_core, CRYPTO_SECRETKEYBYTES);
    memcpy(sk + CRYPTO_SECRETKEYBYTES, tr, TR_BYTES);
    return 0;
}

int FM_HC_120_Sign(uint8_t *sig, size_t *siglen, const uint8_t *m, size_t mlen, const uint8_t *ctx, uint8_t ctx_len, const uint8_t *sk) {
    const uint8_t *sk_core = sk;
    const uint8_t *tr = sk + CRYPTO_SECRETKEYBYTES;

    size_t m_star_len = 1 + 1 + ctx_len + mlen;
    uint8_t *m_star = (uint8_t *)malloc(m_star_len);
    m_star[0] = DS_BYTE; m_star[1] = ctx_len;
    if (ctx_len > 0) memcpy(m_star + 2, ctx, ctx_len);
    memcpy(m_star + 2 + ctx_len, m, mlen);

    size_t hash_input_len = TR_BYTES + m_star_len;
    uint8_t *hash_input = (uint8_t *)malloc(hash_input_len);
    memcpy(hash_input, tr, TR_BYTES);
    memcpy(hash_input + TR_BYTES, m_star, m_star_len);

    uint8_t mu[MU_BYTES];
    shake256_hash(mu, MU_BYTES, hash_input, hash_input_len);

    uint8_t rnd[RND_BYTES]; RAND_bytes(rnd, RND_BYTES);
    uint8_t dummy_k0[32] = {0};
    uint8_t hedged_buf[32 + RND_BYTES + MU_BYTES];
    memcpy(hedged_buf, dummy_k0, 32);
    memcpy(hedged_buf + 32, rnd, RND_BYTES);
    memcpy(hedged_buf + 32 + RND_BYTES, mu, MU_BYTES);
    uint8_t seed_ybb[32];
    shake256_hash(seed_ybb, 32, hedged_buf, sizeof(hedged_buf));

    size_t smlen;
    uint8_t *sm_temp = (uint8_t *)malloc(CRYPTO_BYTES + MU_BYTES);
    crypto_sign(sm_temp, &smlen, mu, MU_BYTES, NULL, 0, sk_core);
    *siglen = smlen - MU_BYTES;
    memcpy(sig, sm_temp, *siglen);

    free(sm_temp); free(m_star); free(hash_input);
    return 0;
}

int FM_HC_120_Verify(const uint8_t *sig, size_t siglen, const uint8_t *m, size_t mlen, const uint8_t *ctx, uint8_t ctx_len, const uint8_t *pk) {
    const uint8_t *pk_core = pk;
    const uint8_t *tr = pk + CRYPTO_PUBLICKEYBYTES;

    uint8_t tr_check[TR_BYTES];
    shake256_hash(tr_check, TR_BYTES, pk_core, CRYPTO_PUBLICKEYBYTES);
    if (memcmp(tr_check, tr, TR_BYTES) != 0) return -1;

    size_t m_star_len = 1 + 1 + ctx_len + mlen;
    uint8_t *m_star = (uint8_t *)malloc(m_star_len);
    m_star[0] = DS_BYTE; m_star[1] = ctx_len;
    if (ctx_len > 0) memcpy(m_star + 2, ctx, ctx_len);
    memcpy(m_star + 2 + ctx_len, m, mlen);

    size_t hash_input_len = TR_BYTES + m_star_len;
    uint8_t *hash_input = (uint8_t *)malloc(hash_input_len);
    memcpy(hash_input, tr, TR_BYTES);
    memcpy(hash_input + TR_BYTES, m_star, m_star_len);

    uint8_t mu[MU_BYTES];
    shake256_hash(mu, MU_BYTES, hash_input, hash_input_len);

    uint8_t *sm = (uint8_t *)malloc(siglen + MU_BYTES);
    memcpy(sm, sig, siglen);
    memcpy(sm + siglen, mu, MU_BYTES);

    size_t mlen_out;
    uint8_t m_out[MU_BYTES];
    int ret = crypto_sign_open(m_out, &mlen_out, sm, siglen + MU_BYTES, NULL, 0, pk_core);

    free(m_star); free(hash_input); free(sm);
    return ret;
}

void benchmark_standard_scheme(const char *alg_name, int iterations) {
    OQS_SIG *sig = OQS_SIG_new(alg_name);
    if (sig == NULL) {
        printf("%s | not available\n", alg_name);
        return;
    }

    uint8_t *pk = malloc(sig->length_public_key);
    uint8_t *sk = malloc(sig->length_secret_key);
    uint8_t *signature = malloc(sig->length_signature);
    size_t sig_len;

    uint8_t msg[] = "Standard benchmark message.";
    size_t msg_len = strlen((char *)msg);

    uint64_t t0, t1;
    uint64_t cycles_keygen = 0, cycles_sign = 0, cycles_verify = 0;

    for (int i = 0; i < iterations; i++) {
        t0 = cpucycles();
        OQS_SIG_keypair(sig, pk, sk);
        t1 = cpucycles();
        cycles_keygen += (t1 - t0);

        t0 = cpucycles();
        OQS_SIG_sign(sig, signature, &sig_len, msg, msg_len, sk);
        t1 = cpucycles();
        cycles_sign += (t1 - t0);

        t0 = cpucycles();
        OQS_SIG_verify(sig, msg, msg_len, signature, sig_len, pk);
        t1 = cpucycles();
        cycles_verify += (t1 - t0);
    }

    printf("%s | %lu | %lu | %lu | %zu | %zu | %zu\n",
           alg_name,
           cycles_keygen / iterations,
           cycles_sign / iterations,
           cycles_verify / iterations,
           sig->length_public_key,
           sig->length_secret_key,
           sig->length_signature);

    free(pk); free(sk); free(signature);
    OQS_SIG_free(sig);
}

int main() {
    int iterations = 50000;

    uint8_t pk[FM_HC_120_PK_BYTES];
    uint8_t sk[FM_HC_120_SK_BYTES];
    uint8_t msg[] = "Benchmarking signature with strict API adherence.";
    size_t msg_len = strlen((char *)msg);
    uint8_t ctx[] = "Test-Ctx";
    uint8_t ctx_len = strlen((char *)ctx);
    uint8_t sig[FM_HC_120_SIG_BYTES];
    size_t sig_len = 0;

    uint64_t t0, t1;
    uint64_t cycles_keygen = 0, cycles_sign = 0, cycles_verify = 0;

    for(int i=0; i<100; i++) FM_HC_120_KeyGen(pk, sk);

    for (int i = 0; i < iterations; i++) {
        t0 = cpucycles();
        FM_HC_120_KeyGen(pk, sk);
        t1 = cpucycles();
        cycles_keygen += (t1 - t0);

        t0 = cpucycles();
        FM_HC_120_Sign(sig, &sig_len, msg, msg_len, ctx, ctx_len, sk);
        t1 = cpucycles();
        cycles_sign += (t1 - t0);

        t0 = cpucycles();
        FM_HC_120_Verify(sig, sig_len, msg, msg_len, ctx, ctx_len, pk);
        t1 = cpucycles();
        cycles_verify += (t1 - t0);
    }

    printf("Scheme | KeyGen(cyc) | Sign(cyc) | Verify(cyc) | PK_bytes | SK_bytes | Sig_bytes\n");
    printf("FM-HC-120 | %lu | %lu | %lu | %d | %d | %d\n",
           cycles_keygen / iterations,
           cycles_sign / iterations,
           cycles_verify / iterations,
           FM_HC_120_PK_BYTES,
           FM_HC_120_SK_BYTES,
           FM_HC_120_SIG_BYTES);

    benchmark_standard_scheme("Falcon-512", iterations);
    benchmark_standard_scheme("ML-DSA-44", iterations);

    return 0;
}