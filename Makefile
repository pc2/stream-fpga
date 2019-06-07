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

$(info ***************************)
$(info Collected information)

# Check Quartus version
ifndef QUARTUS_VERSION
    $(error QUARTUS_VERSION not defined! Quartus seems not to be set up correctly)
else
    $(info QUARTUS_VERSION     = $(QUARTUS_VERSION))
endif

QUARTUS_MAJOR_VERSION := $(shell echo $(QUARTUS_VERSION) | cut -d "." -f 1)

# OpenCL compile and link flags.
AOCL_COMPILE_CONFIG := $(shell $(AOCL) compile-config )
AOCL_LINK_CONFIG := $(shell $(AOCL) link-config )

KERNEL_SRCS := stream_kernels.cl
KERNEL_INPUTS = $(KERNEL_SRCS:.cl=.aocx)

BOARD := p520_hpc_sg280l

BIN_DIR := bin/

ifdef BUILD_SUFFIX
    $(info BUILD_SUFFIX        = $(BUILD_SUFFIX))
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

$(info BOARD               = $(BOARD))
$(info TARGET              = $(TARGET))
$(info KERNEL_TARGET       = $(KERNEL_TARGET).aocx)

$(info ***************************)

default: info
	$(error No target specified)

info:
	$(info *************************************************)
	$(info Please specify one ore more of the listed targets)
	$(info *************************************************)
	$(info Host Code:)
	$(info no_interleave_host           = Host that is trying to put every array on a separate memory bank on the FPGA)
	$(info host                         = Use memory interleaving to store the arrays on the FPGA)
	$(info *************************************************)
	$(info Kernels:)
	$(info kernel                       = Compile kernels without special flags)
	$(info emulate_kernel               = Compile kernels for emulation)
	$(info kernel_profile               = Compile kernels with profiling information enabled)
	$(info no_interleave_kernel         = Compile kernels without memory interleaving)
	$(info no_interleave_kernel_profile = Compile kernels without memory interleaving and profiling information enabled)
	$(info ************************************************)
	$(info info                         = Print this list of available targets)
	$(info ************************************************)

host: 
	$(MKDIR_P) $(BIN_DIR)
	$(CXX) -DQUARTUS_MAJOR_VERSION=$(QUARTUS_MAJOR_VERSION) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE) -DSTREAM_FPGA_KERNEL=\"$(KERNEL_TARGET).aocx\" \
		      $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)

no_interleave_host: 
	$(MKDIR_P) $(BIN_DIR)
	$(CXX)  -DQUARTUS_MAJOR_VERSION=$(QUARTUS_MAJOR_VERSION) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE) -DSTREAM_FPGA_KERNEL=\"$(KERNEL_TARGET).aocx\" \
		      -DNO_INTERLEAVING  $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)_no_interleaving

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
