#ifndef STREAM_TYPE
#define STREAM_TYPE double
#endif

#ifndef MEMORY_WIDTH
#define MEMORY_WIDTH 512
#endif

#ifndef MAX_BURST_SIZE
#define MAX_BURST_SIZE 16
#endif

#define LOCAL_MEM_ARRAY_SIZE (MAX_BURST_SIZE * MEMORY_WIDTH / sizeof(STREAM_TYPE))

__kernel
void copy(__global const STREAM_TYPE * restrict in,
          __global STREAM_TYPE * restrict out,
          uint array_size) {
    for(uint i = 0; i < array_size; i++){
        out[i] = in[i];
    }
}

__kernel
void add(__global const STREAM_TYPE * restrict in1,
          __global const STREAM_TYPE * restrict in2,
          __global STREAM_TYPE * restrict out,
          uint array_size) {
    
    for (uint i=0; i<array_size; i++){
        out[i] = in1[i] + in2[i];
    }
}

__kernel
void scalar(__global const STREAM_TYPE * restrict in,
          __global STREAM_TYPE * restrict out,
          STREAM_TYPE scalar,
          uint array_size) {
    
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
    
    for (uint i=0; i<array_size; i++){
        out[i] = in1[i] + scalar * in2[i];
    }
}