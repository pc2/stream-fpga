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
CXX := g++
AOC := aoc
AOCL := aocl
MKDIR_P := mkdir -p

$(info ***************************)
$(info Collected information:)

# Check Quartus version
ifndef QUARTUS_VERSION
    $(error QUARTUS_VERSION not defined! Please set this variable to the targeted Quartus version.)
else
    $(info QUARTUS_VERSION     = $(QUARTUS_VERSION))
endif

QUARTUS_MAJOR_VERSION := $(shell echo $(QUARTUS_VERSION) | cut -d "." -f 1)

# OpenCL compile and link flags.
AOCL_COMPILE_CONFIG := $(shell $(AOCL) compile-config )
AOCL_LINK_CONFIG := $(shell $(AOCL) link-config )

STREAM_ARRAY_SIZE := 50000000
BOARD := p520_max_sg280l
STREAM_TYPE := double
UNROLL_COUNT := 8
OFFSET := 0
NTIMES := 10

BIN_DIR := bin/

ifdef BUILD_SUFFIX
    $(info BUILD_SUFFIX        = $(BUILD_SUFFIX))
	EXT_BUILD_SUFFIX := _$(BUILD_SUFFIX)
endif

ALL_AOC_FLAGS := $(AOC_FLAGS) -board=$(BOARD) -DSTREAM_TYPE=$(STREAM_TYPE) -DUNROLL_COUNT=$(UNROLL_COUNT)
CXX_FLAGS = --std=c++11

KERNEL_SRCS := stream_kernels.cl
KERNEL_INPUTS = $(KERNEL_SRCS:.cl=.aocx)

SRCS := stream_fpga.cpp
TARGET := $(SRCS:.cpp=)$(EXT_BUILD_SUFFIX)
KERNEL_TARGET := $(KERNEL_SRCS:.cl=)$(EXT_BUILD_SUFFIX)

COMMON_FLAGS := -DQUARTUS_MAJOR_VERSION=$(QUARTUS_MAJOR_VERSION)
HOST_FLAGS := -DSTREAM_FPGA_KERNEL=\"$(KERNEL_TARGET).aocx\" -DSTREAM_TYPE=cl_$(STREAM_TYPE) -DOFFSET=$(OFFSET) -DSTREAM_ARRAY_SIZE=$(STREAM_ARRAY_SIZE) -DNTIMES=$(NTIMES)


$(info BOARD               = $(BOARD))
$(info SRCS                = $(SRCS))
$(info KERNEL_SRCS         = $(KERNEL_SRCS))
$(info STREAM_ARRAY_SIZE   = $(STREAM_ARRAY_SIZE))
$(info STREAM_TYPE         = $(STREAM_TYPE))
$(info UNROLL_COUNT        = $(UNROLL_COUNT))
$(info NTIMES              = $(NTIMES))
$(info OFFSET              = $(OFFSET))
ifdef AOC_FLAGS
$(info AOC_FLAGS           = $(AOC_FLAGS))
endif
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
	$(info kernel_emulate               = Compile kernels for emulation)
	$(info kernel_report                = Generate report for kernels)
	$(info kernel_profile               = Compile kernels with profiling information enabled)
	$(info no_interleave_kernel         = Compile kernels without memory interleaving)
	$(info no_interleave_kernel_profile = Compile kernels without memory interleaving and profiling information enabled)
	$(info ************************************************)
	$(info run_emu                		= Build and run emulation kernels and host code)
	$(info ************************************************)
	$(info info                         = Print this list of available targets)
	$(info ************************************************)

host:
	$(MKDIR_P) $(BIN_DIR)
	$(CXX) $(CXX_FLAGS) $(COMMON_FLAGS) $(HOST_FLAGS) \
		      $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)

no_interleave_host:
	$(MKDIR_P) $(BIN_DIR)
	$(CXX) $(CXX_FLAGS) $(COMMON_FLAGS) $(HOST_FLAGS) \
		      -DNO_INTERLEAVING  $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(BIN_DIR)$(TARGET)_no_interleaving

kernel: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(ALL_AOC_FLAGS) $(COMMON_FLAGS) -o $(BIN_DIR)$(KERNEL_TARGET) $(KERNEL_SRCS)

kernel_emulate: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(ALL_AOC_FLAGS) -march=emulator -o $(BIN_DIR)$(KERNEL_TARGET)_emulate $(KERNEL_SRCS)

kernel_report: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(ALL_AOC_FLAGS) -report -rtl -o $(BIN_DIR)$(KERNEL_TARGET)_report $(KERNEL_SRCS)

kernel_profile: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(ALL_AOC_FLAGS) $(COMMON_FLAGS) -profile -o $(BIN_DIR)$(KERNEL_TARGET)_profile $(KERNEL_SRCS)

no_interleave_kernel_profile: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(ALL_AOC_FLAGS) $(COMMON_FLAGS) -profile -no-interleaving=default -o $(BIN_DIR)$(KERNEL_TARGET)_profile_no_interleaving $(KERNEL_SRCS)

no_interleave_kernel: $(KERNEL_SRCS)
	$(MKDIR_P) $(BIN_DIR)
	$(AOC) $(ALL_AOC_FLAGS) $(COMMON_FLAGS) -no-interleaving=default -o $(BIN_DIR)$(KERNEL_TARGET)_no_interleaving $(KERNEL_SRCS)

run_emu: kernel_emulate host
	cd bin && CL_CONTEXT_EMULATOR_DEVICE_INTELFPGA=1 ./$(TARGET) $(KERNEL_TARGET)_emulate.aocx

cleanhost:
	rm -f $(BIN_DIR)$(TARGET)

cleanall: cleanhost
	rm -f *.aoco *.aocr *.aocx *.source
	rm -rf $(KERNEL_SRCS:.cl=)
	rm -rf $(BIN_DIR)
