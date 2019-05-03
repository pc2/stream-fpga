##
#  Author: Marius Meyer
#  eMail:  marius.meyer@upb.de
#  Date:   2019/04/05
#
#  This makefile compiles the STREAM benchmark for FPGA and its OpenCL kernels.
#  Currently only the  Intel(R) FPGA SDK for OpenCL(TM) utitlity is supported.
#  
#  #1 BUILD
#  ------------
#
#  Depending on the use case you may want to change certain lines:
#      
#      2. Give the location of the used compilers
#      3. Modify the parameters for kernel compilation.
#           - The default rule is to compile the host code and synthesize 
#             the kernel file.
#           - You may want to change the board name
#           - Also the kernel source file can be specified, if another one
#             should be used.
#           - Additional parameters may be added to aoc in AOC_PARAMS
#
#	To make it easier to generate different versions of the kernels, it
#	is possible to specify a variable BUILD_SUFFIX when executing make.
#	This suffix will be added to the kernel name after generation.
#	Example:
#		
#		make BUILD_SUFFIX=18.1.1
#
#	Will build the host and the kernel.
#	The kernel will be named stream_kernels_18.1.1 and the host
#	stream_fpga_18.1.1
#
#   #2 EXECUTION
#   -------------
#
#   The created host uses the kernel with the same build suffix by default.
#   It tries to load it from the same directory it is executed in.
#   
#       ./stream_fpga_18.1.1 
#
#   will try to load the kernel file with the name
#   stream_kernels_18.1.1.aocx by default.
#   Additionally, the executable will interpret the first argument given as
#   the path to the kernel that should be used.
#   For example to use the kernel 'other.aocx':
#
#   	./stream_fpga_18.1.1 other.aocx
#
#   Also, relative and absolute paths to the kernel can be given.
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
	$(CXX) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE) -DSTREAM_FPGA_KERNEL=$(KERNEL_TARGET).aocx  $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)

no_interleaving_host: 
	$(MKDIR_P) $(BIN_DIR)
	$(CXX) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE) -DSTREAM_FPGA_KERNEL=$(KERNEL_TARGET).aocx -DNO_INTERLEAVING  $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)_no_interleaving


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
