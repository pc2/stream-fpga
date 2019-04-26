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
CXX := g++
AOC := aoc

BOARD := p520_hpc_sg280l

##
# Change aoc params to the ones desired (emulation,simulation,synthesis).
#
#AOC_PARAMS := -march=emulator
AOC_PARAMS := -board=$(BOARD) 

ifdef PROFILE
	AOC_PARAMS += -profile
endif

ifdef REPORT
	AOC_PARAMS += -rtl -report
endif
ifdef EMULATE
	AOC_PARAMS := -march=emulator
endif

TARGET := stream_fpga
KERNEL_SRCS := stream_kernels.cl
KERNEL_INPUTS = $(KERNEL_SRCS:.cl=.aocx)

SRCS := $(TARGET).cpp

all: $(TARGET) $(KERNEL_INPUTS)

$(TARGET): 
	$(CXX) $(AOCL_COMPILE_CONFIG) $(SRCS) $(AOCL_LINK_CONFIG) -o $(TARGET)

%.aocx: %.cl
	$(AOC) $(AOC_PARAMS) $<


clean:
	rm -f $(TARGET)

cleanall: clean
	rm -f *.aoco *.aocr *.aocx 
	rm -rf $(KERNEL_SRCS:.cl=)
