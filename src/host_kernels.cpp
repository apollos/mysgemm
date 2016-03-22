/* Includes, system */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* Host implementation of a simple version of sgemm */
void simple_sgemm(int n, float alpha, const float *A, const float *B,
                         float beta, float *C)
{
    int i;
    int j;
    int k;

    for (i = 0; i < n; ++i)
    {
        for (j = 0; j < n; ++j)
        {
            float prod = 0;

            for (k = 0; k < n; ++k)
            {
                prod += A[k * n + i] * B[j * n + k];
            }

            C[j * n + i] = alpha * prod + beta * C[j * n + i];
        }
    }
}

/* Checks result against reference and returns relative error */
float check_result(const float *result,
                          const float *reference,
                          int size)
{
    float error_norm = 0.0f;
    float ref_norm = 0.0f;

    for (int i = 0; i < size; ++i)
    {
        float diff = reference[i] - result[i];
        error_norm += diff * diff;
        ref_norm += reference[i] * reference[i];
    }

    error_norm = (float) sqrtf((double) error_norm);
    ref_norm = (float) sqrtf((double) ref_norm);

    if (fabs(ref_norm) < 1e-7)
    {
        fprintf(stderr, "!!!! Result check failed: reference norm is 0\n");

        // cudaDeviceReset causes the driver to clean up all state. While
        // not mandatory in normal operation, it is good practice.  It is also
        // needed to ensure correct operation when the application is being
        // profiled. Calling cudaDeviceReset causes all profile data to be
        // flushed before the application exits
        exit(EXIT_FAILURE);
    }

    return error_norm / ref_norm;
}
