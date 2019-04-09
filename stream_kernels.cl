#ifndef STREAM_TYPE
#define STREAM_TYPE double
#endif

#ifndef MEMORY_WIDTH
#define MEMORY_WIDTH 512
#endif

#ifndef MAX_BURST_SIZE
#define MAX_BURST_SIZE 16
#endif

#ifndef LOCAL_MEM_ARRAY_SIZE
#define LOCAL_MEM_ARRAY_SIZE (MAX_BURST_SIZE * MEMORY_WIDTH / sizeof(STREAM_TYPE))
#endif

__kernel
void copy(__global const STREAM_TYPE * restrict in,
          __global STREAM_TYPE * restrict out,
          uint array_size) {
    __local STREAM_TYPE tmp_in[LOCAL_MEM_ARRAY_SIZE];
    for (uint i=0; i<array_size; i = i + LOCAL_MEM_ARRAY_SIZE){
        
        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            tmp_in[k] = in[i + k];
        }

        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            out[i+k] = tmp_in[k];
        }
    }
}

__kernel
void add(__global const STREAM_TYPE * restrict in1,
          __global const STREAM_TYPE * restrict in2,
          __global STREAM_TYPE * restrict out,
          uint array_size) {
    __local STREAM_TYPE tmp_in1[LOCAL_MEM_ARRAY_SIZE];   
    __local STREAM_TYPE tmp_in2[LOCAL_MEM_ARRAY_SIZE];
    __local STREAM_TYPE tmp_out[LOCAL_MEM_ARRAY_SIZE];
    for (uint i=0; i<array_size; i = i + LOCAL_MEM_ARRAY_SIZE){
        
        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            tmp_in1[k] = in1[i + k];
        }
        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            tmp_in2[k] = in2[i + k];
        }
        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            tmp_out[k] = tmp_in1[k] + tmp_in2[k];
        }

        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            out[i+k] = tmp_out[k];
        }
    }
}

__kernel
void scalar(__global const STREAM_TYPE * restrict in,
          __global STREAM_TYPE * restrict out,
          STREAM_TYPE scalar,
          uint array_size) {
    __local STREAM_TYPE tmp_in[LOCAL_MEM_ARRAY_SIZE];  
    for (uint i=0; i<array_size; i = i + LOCAL_MEM_ARRAY_SIZE){
        
        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            tmp_in[k] = scalar * in[i + k];
        }

        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            out[i+k] = tmp_in[k];
        }
    }
}

__kernel
void triad(__global const STREAM_TYPE * restrict in1,
          __global const STREAM_TYPE * restrict in2,
          __global STREAM_TYPE * restrict out,
          STREAM_TYPE scalar,
          uint array_size) {
    __local STREAM_TYPE tmp_in1[LOCAL_MEM_ARRAY_SIZE];   
    __local STREAM_TYPE tmp_in2[LOCAL_MEM_ARRAY_SIZE];
    __local STREAM_TYPE tmp_out[LOCAL_MEM_ARRAY_SIZE];
    for (uint i=0; i<array_size; i = i + LOCAL_MEM_ARRAY_SIZE){
        
        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            tmp_in1[k] = in1[i + k];
        }
        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            tmp_in2[k] = scalar * in2[i + k];
        }
        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            tmp_out[k] = tmp_in1[k] + tmp_in2[k];
        }

        #pragma unroll
        for (uint k = 0; k < LOCAL_MEM_ARRAY_SIZE; k++){
            out[i+k] = tmp_out[k];
        }
    }
}