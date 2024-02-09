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

################################################################################
### Verilator
################################################################################

###############
### Linting ###
###############

export VV_LINT_DIR      = $(TEST_DIR)/$(TEST_NAME).lint.vv
export VV_LINT_FLIST    = $(VV_LINT_DIR)/lint.flist
export VV_LINT_CONFIG   = $(VV_LINT_DIR)/config.vlt
export VV_LINT_LOG      = $(VV_LINT_DIR)/lint.log
export VV_LINT_TOP     ?= $(TEST_TOP)

$(VV_LINT_FLIST): $(TEST_FLIST)
	cat $(TEST_FLIST) | envsubst > $@
	echo '$$TEST_DIR/test.cpp' | envsubst >> $@

$(VV_LINT_CONFIG):
	cat $(VV_CONFIG_BASE) | envsubst > $@

################
### Building ###
################

export VV_BUILD_DIR   = $(TEST_DIR)/$(TEST_NAME).build.vv
export VV_FLIST       = $(VV_BUILD_DIR)/build.flist
export VV_CONFIG      = $(VV_BUILD_DIR)/config.vlt
export VV_LOG         = $(VV_BUILD_DIR)/build.log
export VV_TOP        ?= $(TEST_TOP)

$(VV_FLIST): $(TEST_FLIST)
	cat $(TEST_FLIST) | envsubst > $@
	@echo "$(TEST_DIR)/test.cpp" >> $@

$(VV_CONFIG):
	cat $(VV_CONFIG_BASE) | envsubst > $@

##################
### Simulation ###
##################

export VV_SIM_DIR     = $(TEST_DIR)/$(TEST_NAME).sim.vv
export VV_SIM_LOG     = $(VV_SIM_DIR)/sim.log

### Include tool Makefile
include $(MAKE_DIR)/Makefile.verilator

################################################################################
### VCS
################################################################################

###############
### Linting ###
###############

export VCS_LINT_DIR      = $(TEST_DIR)/$(TEST_NAME).lint.vcs
export VCS_LINT_FLIST    = $(VCS_LINT_DIR)/lint.flist
export VCS_LINT_LOG      = $(VCS_LINT_DIR)/lint.log
export VCS_LINT_TOP     ?= $(TEST_TOP)

$(VCS_LINT_FLIST): $(TEST_FLIST)
	cat $(TEST_FLIST) | envsubst > $@

################
### Building ###
################

export VCS_BUILD_DIR   = $(TEST_DIR)/$(TEST_NAME).build.vcs
export VCS_FLIST       = $(VCS_BUILD_DIR)/build.flist
export VCS_CONFIG      = $(VCS_BUILD_DIR)/config.vlt
export VCS_LOG         = $(VCS_BUILD_DIR)/build.log
export VCS_TOP        ?= $(TEST_TOP)

$(VCS_FLIST): $(TEST_FLIST)
	cat $(TEST_FLIST) | envsubst > $@

##################
### Simulation ###
##################

# VCS uses the BUILD_DIR as the SIM_DIR
export VCS_SIM_LOG     = $(VCS_BUILD_DIR)/sim.log

### Include tool Makefile
include $(MAKE_DIR)/Makefile.vcs

################################################################################
### Global
################################################################################

clean:
	@echo "clean"

