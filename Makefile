##
#  Author: Marius Meyer
#  eMail:  marius.meyer@upb.de
#  Date:   2019/04/05
#
#  This makefile compiles the STREAM benchmark for FPGA and its OpenCL kernels.
#  
#  Depending on the use case you may want to change certain lines to the ones
#  needed:
#      
#      1. Modify the used compile and link flags
#      2. Select the used compilers
#      3. Modify the parameters for kernel compilation.
#           - The default parameters are for the creation of emulated kernels
#           - You may want to specify the targeted boards
#
##


# OpenCL compile and link flags.
AOCL_COMPILE_CONFIG := $(shell aocl compile-config )
AOCL_LINK_CONFIG := $(shell aocl link-config )

# Used compilers for C code and OpenCL kernels
CXX := g++ --std=c++11
AOC := aoc
MKDIR_P := mkdir -p

KERNEL_SRCS := stream_kernels.cl
KERNEL_INPUTS = $(KERNEL_SRCS:.cl=.aocx)

BOARD := p520_hpc_sg280l
AOC_VERSION := 18.1.1_hpc

BIN_DIR := bin/

##
# Change aoc params to the ones desired (emulation,simulation,synthesis).
#
#AOC_PARAMS := -march=emulator
AOC_PARAMS := -board=$(BOARD) 

STREAM_ARRAY_SIZE := 100000000
SRCS := stream_fpga.cpp
TARGET := $(SRCS:.cpp=)
KERNEL_TARGET := $(KERNEL_SRCS:.cl=)$(OUTPUT_NAME)

all: host kernel

host: 
	$(MKDIR_P) $(BIN_DIR)
	$(CXX) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE)  $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)

no_interleaving_host: 
	$(MKDIR_P) $(BIN_DIR)
	$(CXX) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE) -DNO_INTERLEAVING  $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)_no_interleaving


kernel: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -o $(BIN_DIR)$(KERNEL_TARGET) $(KERNEL_SRCS)

emulate_kernel: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -march=emulator -o $(BIN_DIR)$(KERNEL_TARGET) $(KERNEL_SRCS)

kernel_profile: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -profile -p $(BIN_DIR)$(KERNEL_TARGET)_profile $(KERNEL_SRCS)

no_interleave_kernel_profile: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -profile -no-interleaving=default -p $(BIN_DIR)$(KERNEL_TARGET)_profile_no_interleaving $(KERNEL_SRCS)

no_interleave_kernel: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -no-interleaving=default -p $(BIN_DIR)$(KERNEL_TARGET)_no_interleaving $(KERNEL_SRCS)

cleanhost:
	rm -f $(BIN_DIR)$(TARGET)

cleanall: cleanhost
	rm -f *.aoco *.aocr *.aocx *.source
	rm -rf $(KERNEL_SRCS:.cl=)
	rm -rf $(BIN_DIR)
