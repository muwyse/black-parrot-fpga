# SPDX-License-Identifier: BSD-3-Clause
#
# Makefile
#
# Top-level Makefile for BlackParrot FPGA test
#

TOP ?= $(shell git rev-parse --show-toplevel)

# Setup paths for this repo
include $(TOP)/Makefile.common
# Pull in tools (Verilator)
include $(BLACKPARROT_TOOLS_DIR)/Makefile.common
# test params
include Makefile.params

export TEST_DIR = $(BASE_DIR)/test
export TEST_TOP = testbench
export TEST_FLIST = $(TEST_DIR)/test.flist
export TEST_NAME = fpga

export BP_IP_SRC_DIR = $(BASE_DIR)/blackparrot/src
export BP_FPGA_HOST_IP_SRC_DIR = $(BASE_DIR)/blackparrot_fpga_host/src

###############
### Linting ###
###############

export LINT_DIR      = $(TEST_DIR)/$(TEST_NAME).lint
export LINT_FLIST    = $(LINT_DIR)/lint.flist
export LINT_CONFIG   = $(LINT_DIR)/config.vlt
export LINT_LOG      = $(LINT_DIR)/lint.log
export LINT_TOP     ?= $(TEST_TOP)

$(LINT_FLIST): $(TEST_FLIST)
	cat $(TEST_FLIST) | envsubst > $@

$(LINT_CONFIG):
	cat $(VV_CONFIG_BASE) | envsubst > $@

################
### Building ###
################

export BUILD_DIR      = $(TEST_DIR)/$(TEST_NAME).build
export VV_FLIST       = $(BUILD_DIR)/build.flist
export VV_CONFIG      = $(BUILD_DIR)/config.vlt
export VV_LOG         = $(BUILD_DIR)/build.log
export VV_TOP        ?= $(TEST_TOP)

$(VV_FLIST): $(TEST_FLIST)
	cat $(TEST_FLIST) | envsubst > $@

$(VV_CONFIG):
	cat $(VV_CONFIG_BASE) | envsubst > $@

##################
### Simulation ###
##################

export SIM_DIR        = $(TEST_DIR)/$(TEST_NAME).sim
export SIM_LOG        = $(SIM_DIR)/sim.log

### Include tool Makefile
include $(MAKE_DIR)/Makefile.verilator
