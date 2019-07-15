/*
STREAM kernels using scalar types and unrolling.
*/

#if (QUARTUS_MAJOR_VERSION <= 18)
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
#endif

#ifndef STREAM_TYPE
#define STREAM_TYPE double
#endif

#ifndef UNROLL_COUNT
#define UNROLL_COUNT 8
#endif

__kernel
void copy(__global const STREAM_TYPE * restrict in,
          __global STREAM_TYPE * restrict out,
          uint array_size) {

    #pragma unroll UNROLL_COUNT
    for(uint i = 0; i < array_size; i++){
        out[i] = in[i];
    }
}

__kernel
void add(__global const STREAM_TYPE * restrict in1,
          __global const STREAM_TYPE * restrict in2,
          __global STREAM_TYPE * restrict out,
          uint array_size) {

    #pragma unroll UNROLL_COUNT
    for (uint i=0; i<array_size; i++){
        out[i] = in1[i] + in2[i];
    }
}

__kernel
void scale(__global const STREAM_TYPE * restrict in,
          __global STREAM_TYPE * restrict out,
          STREAM_TYPE scalar,
          uint array_size) {

    #pragma unroll UNROLL_COUNT
    for (uint i=0; i<array_size; i++){
        out[i] = scalar * in[i];
    }
}

__kernel
void triad(__global const STREAM_TYPE * restrict in1,
          __global const STREAM_TYPE * restrict in2,
          __global STREAM_TYPE * restrict out,
          STREAM_TYPE scalar,
          uint array_size) {
    
    #pragma unroll UNROLL_COUNT
    for (uint i=0; i<array_size; i++){
        out[i] = in1[i] + scalar * in2[i];
    }
}