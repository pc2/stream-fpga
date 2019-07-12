
#if (QUARTUS_MAJOR_VERSION <= 18)
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
#endif

#ifndef STREAM_TYPE
#define STREAM_TYPE double
#endif

#ifndef UNROLL_COUNT
#define UNROLL_COUNT 8
#endif

#define PASTER(x,y) x ## y
#define EVALUATOR(x,y) PASTER(x,y)
#define VEC_TYPE EVALUATOR(STREAM_TYPE, UNROLL_COUNT)

__kernel
void copy(__global const VEC_TYPE * restrict in,
          __global VEC_TYPE * restrict out,
          uint array_size) {

    uint half_size = array_size/(UNROLL_COUNT*2);
    #pragma ivdep
    for(uint i = 0; i < half_size; i++){
        out[i] = in[i];
        out[half_size+i] = in[half_size+i];
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
void scalar(__global const STREAM_TYPE * restrict in,
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
