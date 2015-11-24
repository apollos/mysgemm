#ifndef MYSGEMM_H
#define MYSGEMM_H

extern "C" {
    /* Assume C declarations for C++ */

/* Host implementation of a simple version of sgemm */
void simple_sgemm(int n, float alpha, const float *A, const float *B,
                         float beta, float *C);
float check_result(const float *result,
                          const float *reference,
                          int size);
void device_cublas_sgemm(int n,
                                    float alpha,
                                    const float *d_A, const float *d_B,
                                    float beta,
                                    float *d_C);
}

#endif
