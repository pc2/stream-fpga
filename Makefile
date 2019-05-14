##
#  Author: Marius Meyer
#  eMail:  marius.meyer@upb.de
#  Date:   2019/04/05
#
#  This makefile compiles the STREAM benchmark for FPGA and its OpenCL kernels.
#  Currently only the  Intel(R) FPGA SDK for OpenCL(TM) utitlity is supported.
#  
#  Please read the README contained in this folder for more information and
#  instructions how to compile and execute the benchmark.

# Used compilers for C code and OpenCL kernels
CXX := g++ --std=c++11
AOC := aoc
AOCL := aocl
MKDIR_P := mkdir -p

# OpenCL compile and link flags.
AOCL_COMPILE_CONFIG := $(shell $(AOCL) compile-config )
AOCL_LINK_CONFIG := $(shell $(AOCL) link-config )

KERNEL_SRCS := stream_kernels.cl
KERNEL_INPUTS = $(KERNEL_SRCS:.cl=.aocx)

BOARD := p520_hpc_sg280l

BIN_DIR := bin/

ifdef BUILD_SUFFIX
	EXT_BUILD_SUFFIX := _$(BUILD_SUFFIX)
endif

##
# Change aoc params to the ones desired (emulation,simulation,synthesis).
#
#AOC_PARAMS := -march=emulator
AOC_PARAMS := -board=$(BOARD) 

STREAM_ARRAY_SIZE := 100000000
SRCS := stream_fpga.cpp
TARGET := $(SRCS:.cpp=)$(EXT_BUILD_SUFFIX)
KERNEL_TARGET := $(KERNEL_SRCS:.cl=)$(EXT_BUILD_SUFFIX)

all: host kernel

host: 
	$(MKDIR_P) $(BIN_DIR)
	$(CXX) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE) -DSTREAM_FPGA_KERNEL=\"$(KERNEL_TARGET).aocx\"  $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)

no_interleaving_host: 
	$(MKDIR_P) $(BIN_DIR)
	$(CXX) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE) -DSTREAM_FPGA_KERNEL=\"$(KERNEL_TARGET).aocx\" -DNO_INTERLEAVING  $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)_no_interleaving


kernel: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -o $(BIN_DIR)$(KERNEL_TARGET) $(KERNEL_SRCS)

emulate_kernel: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -march=emulator -o $(BIN_DIR)$(KERNEL_TARGET)_emulate $(KERNEL_SRCS)

kernel_profile: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -profile -o $(BIN_DIR)$(KERNEL_TARGET)_profile $(KERNEL_SRCS)

no_interleave_kernel_profile: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -profile -no-interleaving=default -o $(BIN_DIR)$(KERNEL_TARGET)_profile_no_interleaving $(KERNEL_SRCS)

no_interleave_kernel: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(AOC_PARAMS) -no-interleaving=default -o $(BIN_DIR)$(KERNEL_TARGET)_no_interleaving $(KERNEL_SRCS)

cleanhost:
	rm -f $(BIN_DIR)$(TARGET)

cleanall: cleanhost
	rm -f *.aoco *.aocr *.aocx *.source
	rm -rf $(KERNEL_SRCS:.cl=)
	rm -rf $(BIN_DIR)
