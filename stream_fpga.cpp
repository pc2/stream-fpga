/*-----------------------------------------------------------------------*/
/* Program: STREAM for FPGAs                                             */
/* Revision: $Id: stream_fpga.c,v 0.10 2019/04/05$                       */
/* Original code developed by John D. McCalpin                           */
/* Programmers: John D. McCalpin                                         */
/*              Joe R. Zagar                                             */
/*              Marius Meyer                                             */            
/*                                                                       */
/* This program measures memory transfer rates in MB/s for simple        */
/* computational kernels on FPGAs coded in C and OpenCL.                                     */
/*-----------------------------------------------------------------------*/
/* Copyright 1991-2013: John D. McCalpin                                 */
/*-----------------------------------------------------------------------*/
/* License:                                                              */
/*  1. You are free to use this program and/or to redistribute           */
/*     this program.                                                     */
/*  2. You are free to modify this program for your own use,             */
/*     including commercial use, subject to the publication              */
/*     restrictions in item 3.                                           */
/*  3. You are free to publish results obtained from running this        */
/*     program, or from works that you derive from this program,         */
/*     with the following limitations:                                   */
/*     3a. In order to be referred to as "STREAM benchmark results",     */
/*         published results must be in conformance to the STREAM        */
/*         Run Rules, (briefly reviewed below) published at              */
/*         http://www.cs.virginia.edu/stream/ref.html                    */
/*         and incorporated herein by reference.                         */
/*         As the copyright holder, John McCalpin retains the            */
/*         right to determine conformity with the Run Rules.             */
/*     3b. Results based on modified source code or on runs not in       */
/*         accordance with the STREAM Run Rules must be clearly          */
/*         labelled whenever they are published.  Examples of            */
/*         proper labelling include:                                     */
/*           "tuned STREAM benchmark results"                            */
/*           "based on a variant of the STREAM benchmark code"           */
/*         Other comparable, clear, and reasonable labelling is          */
/*         acceptable.                                                   */
/*     3c. Submission of results to the STREAM benchmark web site        */
/*         is encouraged, but not required.                              */
/*  4. Use of this program or creation of derived works based on this    */
/*     program constitutes acceptance of these licensing restrictions.   */
/*  5. Absolutely no warranty is expressed or implied.                   */
/*-----------------------------------------------------------------------*/
#include <math.h>
#include <fstream>
#include <iostream>
#include <assert.h>
#include <stdio.h>
#include <string>
#include <math.h>
#include <limits.h>
#include <float.h>
#include <unistd.h>

#include "CL/cl.hpp"

/*-----------------------------------------------------------------------
 * INSTRUCTIONS:
 *
 *	1) STREAM requires different amounts of memory to run on different
 *           systems, depending on both the system cache size(s) and the
 *           granularity of the system timer.
 *     You should adjust the value of 'STREAM_ARRAY_SIZE' (below)
 *           to meet *both* of the following criteria:
 *       (a) Each array must be at least 4 times the size of the
 *           available cache memory. I don't worry about the difference
 *           between 10^6 and 2^20, so in practice the minimum array size
 *           is about 3.8 times the cache size.
 *           Example 1: One Xeon E3 with 8 MB L3 cache
 *               STREAM_ARRAY_SIZE should be >= 4 million, giving
 *               an array size of 30.5 MB and a total memory requirement
 *               of 91.5 MB.  
 *           Example 2: Two Xeon E5's with 20 MB L3 cache each (using OpenMP)
 *               STREAM_ARRAY_SIZE should be >= 20 million, giving
 *               an array size of 153 MB and a total memory requirement
 *               of 458 MB.  
 *       (b) The size should be large enough so that the 'timing calibration'
 *           output by the program is at least 20 clock-ticks.  
 *           Example: most versions of Windows have a 10 millisecond timer
 *               granularity.  20 "ticks" at 10 ms/tic is 200 milliseconds.
 *               If the chip is capable of 10 GB/s, it moves 2 GB in 200 msec.
 *               This means the each array must be at least 1 GB, or 128M elements.
 *
 *
 *      Array size can be set at compile time without modifying the source
 *          code for the (many) compilers that support preprocessor definitions
 *          on the compile line.  E.g.,
 *                gcc -O -DSTREAM_ARRAY_SIZE=100000000 stream.c -o stream.100M
 *          will override the default size of 10M with a new size of 100M elements
 *          per array.
 */
#ifndef STREAM_ARRAY_SIZE
#   define STREAM_ARRAY_SIZE	10000000
#endif

/*  2) STREAM runs each kernel "NTIMES" times and reports the *best* result
 *         for any iteration after the first, therefore the minimum value
 *         for NTIMES is 2.
 *      There are no rules on maximum allowable values for NTIMES, but
 *         values larger than the default are unlikely to noticeably
 *         increase the reported performance.
 *      NTIMES can also be set on the compile line without changing the source
 *         code using, for example, "-DNTIMES=7".
 */
#ifdef NTIMES
#if NTIMES<=1
#   define NTIMES	10
#endif
#endif
#ifndef NTIMES
#   define NTIMES	10
#endif

/*  Users are allowed to modify the "OFFSET" variable, which *may* change the
 *         relative alignment of the arrays (though compilers may change the 
 *         effective offset by making the arrays non-contiguous on some systems). 
 *      Use of non-zero values for OFFSET can be especially helpful if the
 *         STREAM_ARRAY_SIZE is set to a value close to a large power of 2.
 *      OFFSET can also be set on the compile line without changing the source
 *         code using, for example, "-DOFFSET=56".
 */
#ifndef OFFSET
#   define OFFSET	0
#endif

/*
 *	3) Compile the code with optimization.  Many compilers generate
 *       unreasonably bad code before the optimizer tightens things up.  
 *     If the results are unreasonably good, on the other hand, the
 *       optimizer might be too smart for me!
 *
 *     For a simple single-core version, try compiling with:
 *            cc -O stream.c -o stream
 *     This is known to work on many, many systems....
 *
 *     To use multiple cores, you need to tell the compiler to obey the OpenMP
 *       directives in the code.  This varies by compiler, but a common example is
 *            gcc -O -fopenmp stream.c -o stream_omp
 *       The environment variable OMP_NUM_THREADS allows runtime control of the 
 *         number of threads/cores used when the resulting "stream_omp" program
 *         is executed.
 *
 *     To run with single-precision variables and arithmetic, simply add
 *         -DSTREAM_TYPE=float
 *     to the compile line.
 *     Note that this changes the minimum array sizes required --- see (1) above.
 *
 *     The preprocessor directive "TUNED" does not do much -- it simply causes the 
 *       code to call separate functions to execute each kernel.  Trivial versions
 *       of these functions are provided, but they are *not* tuned -- they just 
 *       provide predefined interfaces to be replaced with tuned code.
 *
 *
 *	4) Optional: Mail the results to mccalpin@cs.virginia.edu
 *	   Be sure to include info that will help me understand:
 *		a) the computer hardware configuration (e.g., processor model, memory type)
 *		b) the compiler name/version and compilation flags
 *      c) any run-time information (such as OMP_NUM_THREADS)
 *		d) all of the output from the test case.
 *
 * Thanks!
 *
 *-----------------------------------------------------------------------*/

# define HLINE "-------------------------------------------------------------\n"

# ifndef MIN
# define MIN(x,y) ((x)<(y)?(x):(y))
# endif
# ifndef MAX
# define MAX(x,y) ((x)>(y)?(x):(y))
# endif

/*
*  The file containing the OpenCL kernels.
*  Keep in mind that changes of STREAM_TYPE also affect the kernels.
*  So to change the used data type, STREAM_TYPE has to be modified in both,
*  the C code and the OpenCL code.
*-----------------------------------------------------------------------*/
#ifndef STREAM_FPGA_KERNEL
#define STREAM_FPGA_KERNEL "stream_kernels.aocx"
#endif

#ifndef STREAM_TYPE
#define STREAM_TYPE cl_float
#endif

#define STREAM_COPY_KERNEL "copy"
#define STREAM_SCALAR_KERNEL "scalar"
#define STREAM_ADD_KERNEL "add"
#define STREAM_TRIAD_KERNEL "triad"

static double	avgtime[6] = {0}, maxtime[6] = {0},
		mintime[6] = {FLT_MAX,FLT_MAX,FLT_MAX,FLT_MAX, FLT_MAX, FLT_MAX};

static std::string	label[6] = {"Copy:      ", "Scale:     ",
    "Add:       ", "Triad:     ", "PCI Write: ", "PCI Read:  "};

static double	bytes[6] = {
    2 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,
    2 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,
    3 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,
    3 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,
    3 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,
    3 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE
    };

//Inputs and Outputs to Kernel, X and Y are inputs, Z is output
//The aligned attribute is used to ensure alignment
//so that DMA could be used if we were working with a real FPGA board
static STREAM_TYPE A[STREAM_ARRAY_SIZE]  __attribute__ ((aligned (64)));
static STREAM_TYPE B[STREAM_ARRAY_SIZE]  __attribute__ ((aligned (64)));
static STREAM_TYPE C[STREAM_ARRAY_SIZE]  __attribute__ ((aligned (64)));

extern double mysecond();
extern void checkSTREAMresults();

int main(int argc, char * argv[])
{
    int			quantum, checktick();
    int			BytesPerWord;
    int			k;
    ssize_t		j;
    STREAM_TYPE		test_scalar, scalar;
    double		t, times[6][NTIMES];

    /* --- SETUP --- determine precision and check timing --- */

    printf(HLINE);
    printf("STREAM FPGA based in STREAM version $Revision: 5.10 $\n");
    printf(HLINE);
    BytesPerWord = sizeof(STREAM_TYPE);
    printf("This system uses %d bytes per array element.\n",
	BytesPerWord);

    printf(HLINE);
#ifdef N
    printf("*****  WARNING: ******\n");
    printf("      It appears that you set the preprocessor variable N when compiling this code.\n");
    printf("      This version of the code uses the preprocesor variable STREAM_ARRAY_SIZE to control the array size\n");
    printf("      Reverting to default value of STREAM_ARRAY_SIZE=%llu\n",(unsigned long long) STREAM_ARRAY_SIZE);
    printf("*****  WARNING: ******\n");
#endif

    printf("Array size = %llu (elements), Offset = %d (elements)\n" , (unsigned long long) STREAM_ARRAY_SIZE, OFFSET);
    printf("Memory per array = %.1f MiB (= %.1f GiB).\n", 
	BytesPerWord * ( (double) STREAM_ARRAY_SIZE / 1024.0/1024.0),
	BytesPerWord * ( (double) STREAM_ARRAY_SIZE / 1024.0/1024.0/1024.0));
    printf("Total memory required = %.1f MiB (= %.1f GiB).\n",
	(3.0 * BytesPerWord) * ( (double) STREAM_ARRAY_SIZE / 1024.0/1024.),
	(3.0 * BytesPerWord) * ( (double) STREAM_ARRAY_SIZE / 1024.0/1024./1024.));
    printf("Each kernel will be executed %d times.\n", NTIMES);
    printf(" The *best* time for each kernel (excluding the first iteration)\n"); 
    printf(" will be used to compute the reported bandwidth.\n");
    printf(HLINE);

	//Allocates memory with value from 0 to 1000
	for (int j=0; j<STREAM_ARRAY_SIZE; j++) {
	    A[j] = 1.0;
	    B[j] = 2.0;
	    C[j] = 0.0;
	}

    int err;
// Setting up OpenCL for FPGA
    //Setup Platform
	//Get Platform ID
	std::vector<cl::Platform> PlatformList;
	err = cl::Platform::get(&PlatformList);
	assert(err==CL_SUCCESS);

    cl::Platform platform = PlatformList[0];
    std::cout << "Platform Name: " << platform.getInfo<CL_PLATFORM_NAME>() << std::endl;

	//Setup Device
	//Get Device ID
	std::vector<cl::Device> DeviceList;
	err = PlatformList[0].getDevices(CL_DEVICE_TYPE_ACCELERATOR, &DeviceList);
	assert(err==CL_SUCCESS);
	
	//Create Context
	cl::Context streamcontext(DeviceList);
	assert(err==CL_SUCCESS);
    std::cout << "Device Name:   " << DeviceList[0].getInfo<CL_DEVICE_NAME>() << std::endl;
	//Create Command queue
	cl::CommandQueue streamqueue(streamcontext, DeviceList[0]); 
	assert(err==CL_SUCCESS);

#ifdef NO_INTERLEAVING
	//Create Buffers for input and output
	cl::Buffer Buffer_A(streamcontext, CL_MEM_READ_WRITE | CL_CHANNEL_1_INTELFPGA, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE);
	cl::Buffer Buffer_B(streamcontext, CL_MEM_READ_WRITE | CL_CHANNEL_2_INTELFPGA, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE);
	cl::Buffer Buffer_C(streamcontext, CL_MEM_READ_WRITE | CL_CHANNEL_3_INTELFPGA, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE);
#else
	//Create Buffers for input and output
	cl::Buffer Buffer_A(streamcontext, CL_MEM_READ_WRITE, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE);
	cl::Buffer Buffer_B(streamcontext, CL_MEM_READ_WRITE, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE);
	cl::Buffer Buffer_C(streamcontext, CL_MEM_READ_WRITE, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE);
#endif

	//Read in binaries from file
    char* used_kernel = (char*) STREAM_FPGA_KERNEL;
    if (argc > 1) {
        std::cout << "Using kernel given as argument" << std::endl;
        used_kernel = argv[1];
    }
    std::cout << "Kernel:        " << used_kernel << std::endl;
    std::cout << HLINE;
    std::ifstream aocx_stream(used_kernel, std::ifstream::binary);
    if (!aocx_stream.is_open()){
        std::cerr << "Not possible to open from given file!" << std::endl;
        return 1;
    }
    
	std::string prog(std::istreambuf_iterator<char>(aocx_stream), (std::istreambuf_iterator<char>()));
    aocx_stream.seekg(0, aocx_stream.end);
    unsigned file_size = aocx_stream.tellg();
    aocx_stream.seekg(0,aocx_stream.beg);
    char * buf = new char[file_size];
    aocx_stream.read(buf, file_size);

	cl::Program::Binaries mybinaries;
    mybinaries.push_back({buf, file_size});
    DeviceList.resize(1);

	// Create the Program from the AOCX file.
	cl::Program program(streamcontext, DeviceList, mybinaries);

	// create the kernels
    cl::Kernel testkernel(program, STREAM_SCALAR_KERNEL, &err);
    assert(err==CL_SUCCESS);
    cl::Kernel copykernel(program, STREAM_COPY_KERNEL, &err);
	assert(err==CL_SUCCESS);
	cl::Kernel scalarkernel(program, STREAM_SCALAR_KERNEL, &err);
	assert(err==CL_SUCCESS);
	cl::Kernel addkernel(program, STREAM_ADD_KERNEL, &err);
	assert(err==CL_SUCCESS);
	cl::Kernel triadkernel(program, STREAM_TRIAD_KERNEL, &err);
	assert(err==CL_SUCCESS);

	scalar = 3.0;
    test_scalar = 2.0E0;
	//prepare kernels
	err = testkernel.setArg(0, Buffer_A);
	assert(err==CL_SUCCESS);
	err = testkernel.setArg(1, Buffer_A);
	assert(err==CL_SUCCESS);
    err = testkernel.setArg(2, test_scalar);
	assert(err==CL_SUCCESS);
	err = testkernel.setArg(3, STREAM_ARRAY_SIZE);
	assert(err==CL_SUCCESS);
    //set arguments of copy kernel
	err = copykernel.setArg(0, Buffer_A);
	assert(err==CL_SUCCESS);
	err = copykernel.setArg(1, Buffer_C);
	assert(err==CL_SUCCESS);
	err = copykernel.setArg(2, STREAM_ARRAY_SIZE);
	assert(err==CL_SUCCESS);
	//set arguments of scalar kernel
	err = scalarkernel.setArg(0, Buffer_C);
	assert(err==CL_SUCCESS);
	err = scalarkernel.setArg(1, Buffer_B);
	assert(err==CL_SUCCESS);
	err = scalarkernel.setArg(2, scalar);
	assert(err==CL_SUCCESS);
	err = scalarkernel.setArg(3, STREAM_ARRAY_SIZE);
	assert(err==CL_SUCCESS);
	//set arguments of add kernel
	err = addkernel.setArg(0, Buffer_A);
	assert(err==CL_SUCCESS);
	err = addkernel.setArg(1, Buffer_B);
	assert(err==CL_SUCCESS);
	err = addkernel.setArg(2, Buffer_C);
	assert(err==CL_SUCCESS);
	err = addkernel.setArg(3, STREAM_ARRAY_SIZE);
	assert(err==CL_SUCCESS);
	//set arguments of triad kernel
	err = triadkernel.setArg(0, Buffer_B);
	assert(err==CL_SUCCESS);
	err = triadkernel.setArg(1, Buffer_C);
	assert(err==CL_SUCCESS);
	err = triadkernel.setArg(2, Buffer_A);
	assert(err==CL_SUCCESS);
	err = triadkernel.setArg(3, scalar);
	assert(err==CL_SUCCESS);
	err = triadkernel.setArg(4, STREAM_ARRAY_SIZE);
	assert(err==CL_SUCCESS);
    std::cout << "Prepared FPGA successfully!" << std::endl;
    std::cout << HLINE;
//End prepare FPGA

    if  ( (quantum = checktick()) >= 1) 
	printf("Your clock granularity/precision appears to be "
	    "%d microseconds.\n", quantum);
    else {
	printf("Your clock granularity appears to be "
	    "less than one microsecond.\n");
	quantum = 1;
    }

    streamqueue.enqueueWriteBuffer(Buffer_A, CL_TRUE, 0, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE, A);
    streamqueue.finish();
    
    cl::Event e;
    t = mysecond();
	streamqueue.enqueueTask(testkernel, NULL, &e);
	err=e.wait();	
    t = 1.0E6 * (mysecond() - t);

	streamqueue.enqueueReadBuffer(Buffer_A, CL_TRUE, 0, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE, A);
    err=streamqueue.finish();
    

    printf("Each test below will take on the order"
	" of %d microseconds.\n", (int) t  );
    printf("   (= %d clock ticks)\n", (int) (t/quantum) );
    printf("Increase the size of the arrays if this shows that\n");
    printf("you are not getting at least 20 clock ticks per test.\n");

    printf(HLINE);

    printf("WARNING -- The above is only a rough guideline.\n");
    printf("For best results, please be sure you know the\n");
    printf("precision of your system timer.\n");
    printf(HLINE);

	for (int k=0; k < NTIMES; k++) {
        std::cout << "Execute iteration " << (k + 1) << " of " << NTIMES << std::endl;
	    //Write data to device
	    times[4][k] = mysecond();
        streamqueue.enqueueWriteBuffer(Buffer_A, CL_FALSE, 0, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE, A);
	    streamqueue.enqueueWriteBuffer(Buffer_B, CL_FALSE, 0, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE, B);	
	    streamqueue.enqueueWriteBuffer(Buffer_C, CL_FALSE, 0, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE, C);
	    err = streamqueue.finish();
        times[4][k] = mysecond() - times[4][k];

        assert(err==CL_SUCCESS);

		times[0][k] = mysecond();
		streamqueue.enqueueTask(copykernel, NULL, &e);
		err=e.wait();
		times[0][k] = mysecond() - times[0][k];

		assert(err==CL_SUCCESS);
		
		times[1][k] = mysecond();
		streamqueue.enqueueTask(scalarkernel, NULL, &e);
		err=e.wait();
		times[1][k] = mysecond() - times[1][k];
		assert(err==CL_SUCCESS);
		
		times[2][k] = mysecond();
		streamqueue.enqueueTask(addkernel, NULL, &e);
		err=e.wait();
		times[2][k] = mysecond() - times[2][k];
		assert(err==CL_SUCCESS);
		
		times[3][k] = mysecond();
		streamqueue.enqueueTask(triadkernel, NULL, &e);
		err=e.wait();
		times[3][k] = mysecond() - times[3][k];
		assert(err==CL_SUCCESS);
        
        // read the output
        times[5][k] = mysecond();
	    streamqueue.enqueueReadBuffer(Buffer_A, CL_FALSE, 0, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE, A);
	    streamqueue.enqueueReadBuffer(Buffer_B, CL_FALSE, 0, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE, B);
	    streamqueue.enqueueReadBuffer(Buffer_C, CL_FALSE, 0, sizeof(STREAM_TYPE)*STREAM_ARRAY_SIZE, C);
	    err=streamqueue.finish();
        times[5][k] = mysecond() - times[5][k];
        assert(err==CL_SUCCESS);

	}	

/*	--- SUMMARY --- */

    for (k=1; k<NTIMES; k++) /* note -- skip first iteration */
	{
	for (j=0; j<6; j++)
	    {
	    avgtime[j] = avgtime[j] + times[j][k];
	    mintime[j] = MIN(mintime[j], times[j][k]);
	    maxtime[j] = MAX(maxtime[j], times[j][k]);
	    }
	}
    
    printf("Function    Best Rate MB/s  Avg time     Min time     Max time\n");
    for (j=0; j<6; j++) {
		avgtime[j] = avgtime[j]/(double)(NTIMES-1);

		printf("%s%12.1f  %11.6f  %11.6f  %11.6f\n", label[j].c_str(),
	       1.0E-06 * bytes[j]/mintime[j],
	       avgtime[j],
	       mintime[j],
	       maxtime[j]);
    }
    printf(HLINE);

    /* --- Check Results --- */
    checkSTREAMresults();
    printf(HLINE);
    return 0;
}

# define	M	20

int
checktick()
    {
    int		i, minDelta, Delta;
    double	t1, t2, timesfound[M];

/*  Collect a sequence of M unique time values from the system. */

    for (i = 0; i < M; i++) {
	t1 = mysecond();
	while( ((t2=mysecond()) - t1) < 1.0E-6 )
	    ;
	timesfound[i] = t1 = t2;
	}

/*
 * Determine the minimum difference between these M values.
 * This result will be our estimate (in microseconds) for the
 * clock granularity.
 */

    minDelta = 1000000;
    for (i = 1; i < M; i++) {
	Delta = (int)( 1.0E6 * (timesfound[i]-timesfound[i-1]));
	minDelta = MIN(minDelta, MAX(Delta,0));
	}

   return(minDelta);
    }



/* A gettimeofday routine to give access to the wall
   clock timer on most UNIX-like systems.  */

#include <sys/time.h>

double mysecond()
{
        struct timeval tp;
        struct timezone tzp;
        int i;

        i = gettimeofday(&tp,&tzp);
        return ( (double) tp.tv_sec + (double) tp.tv_usec * 1.e-6 );
}

#ifndef abs
#define abs(a) ((a) >= 0 ? (a) : -(a))
#endif
void checkSTREAMresults ()
{
	STREAM_TYPE aj,bj,cj,scalar;
	STREAM_TYPE aSumErr,bSumErr,cSumErr;
	STREAM_TYPE aAvgErr,bAvgErr,cAvgErr;
	double epsilon;
	ssize_t	j;
	int	k,ierr,err;

    /* reproduce initialization */
	aj = 1.0;
	bj = 2.0;
	cj = 0.0;
    /* a[] is modified during timing check */
	aj = 2.0E0 * aj;
    /* now execute timing loop */
	scalar = 3.0;
	for (k=0; k<NTIMES; k++)
        {
            cj = aj;
            bj = scalar*cj;
            cj = aj+bj;
            aj = bj+scalar*cj;
        }

    /* accumulate deltas between observed and expected results */
	aSumErr = 0.0;
	bSumErr = 0.0;
	cSumErr = 0.0;
	for (j=0; j<STREAM_ARRAY_SIZE; j++) {
		aSumErr += abs(A[j] - aj);
		bSumErr += abs(B[j] - bj);
		cSumErr += abs(C[j] - cj);
		// if (j == 417) printf("Index 417: c[j]: %f, cj: %f\n",c[j],cj);	// MCCALPIN
	}
	aAvgErr = aSumErr / (STREAM_TYPE) STREAM_ARRAY_SIZE;
	bAvgErr = bSumErr / (STREAM_TYPE) STREAM_ARRAY_SIZE;
	cAvgErr = cSumErr / (STREAM_TYPE) STREAM_ARRAY_SIZE;

	if (sizeof(STREAM_TYPE) == 4) {
		epsilon = 1.e-6;
	}
	else if (sizeof(STREAM_TYPE) == 8) {
		epsilon = 1.e-13;
	}
	else {
		printf("WEIRD: sizeof(STREAM_TYPE) = %lu\n",sizeof(STREAM_TYPE));
		epsilon = 1.e-6;
	}

	err = 0;
	if (abs(aAvgErr/aj) > epsilon) {
		err++;
		printf ("Failed Validation on array a[], AvgRelAbsErr > epsilon (%e)\n",epsilon);
		printf ("     Expected Value: %e, AvgAbsErr: %e, AvgRelAbsErr: %e\n",aj,aAvgErr,abs(aAvgErr)/aj);
		ierr = 0;
		for (j=0; j<STREAM_ARRAY_SIZE; j++) {
			if (abs(A[j]/aj-1.0) > epsilon) {
				ierr++;
#ifdef VERBOSE
				if (ierr < 10) {
					printf("         array a: index: %ld, expected: %e, observed: %e, relative error: %e\n",
						j,aj,A[j],abs((aj-A[j])/aAvgErr));
				}
#endif
			}
		}
		printf("     For array a[], %d errors were found.\n",ierr);
	}
	if (abs(bAvgErr/bj) > epsilon) {
		err++;
		printf ("Failed Validation on array b[], AvgRelAbsErr > epsilon (%e)\n",epsilon);
		printf ("     Expected Value: %e, AvgAbsErr: %e, AvgRelAbsErr: %e\n",bj,bAvgErr,abs(bAvgErr)/bj);
		printf ("     AvgRelAbsErr > Epsilon (%e)\n",epsilon);
		ierr = 0;
		for (j=0; j<STREAM_ARRAY_SIZE; j++) {
			if (abs(B[j]/bj-1.0) > epsilon) {
				ierr++;
#ifdef VERBOSE
				if (ierr < 10) {
					printf("         array b: index: %ld, expected: %e, observed: %e, relative error: %e\n",
						j,bj,B[j],abs((bj-B[j])/bAvgErr));
				}
#endif
			}
		}
		printf("     For array b[], %d errors were found.\n",ierr);
	}
	if (abs(cAvgErr/cj) > epsilon) {
		err++;
		printf ("Failed Validation on array c[], AvgRelAbsErr > epsilon (%e)\n",epsilon);
		printf ("     Expected Value: %e, AvgAbsErr: %e, AvgRelAbsErr: %e\n",cj,cAvgErr,abs(cAvgErr)/cj);
		printf ("     AvgRelAbsErr > Epsilon (%e)\n",epsilon);
		ierr = 0;
		for (j=0; j<STREAM_ARRAY_SIZE; j++) {
			if (abs(C[j]/cj-1.0) > epsilon) {
				ierr++;
#ifdef VERBOSE
				if (ierr < 10) {
					printf("         array c: index: %ld, expected: %e, observed: %e, relative error: %e\n",
						j,cj,C[j],abs((cj-C[j])/cAvgErr));
				}
#endif
			}
		}
		printf("     For array c[], %d errors were found.\n",ierr);
	}
	if (err == 0) {
		printf ("Solution Validates: avg error less than %e on all three arrays\n",epsilon);
	}
#ifdef VERBOSE
	printf ("Results Validation Verbose Results: \n");
	printf ("    Expected a(1), b(1), c(1): %f %f %f \n",aj,bj,cj);
	printf ("    Observed a(1), b(1), c(1): %f %f %f \n",A[1],B[1],C[1]);
	printf ("    Rel Errors on a, b, c:     %e %e %e \n",abs(aAvgErr/aj),abs(bAvgErr/bj),abs(cAvgErr/cj));
#endif
}
