
TOP ?= $(shell git rev-parse --show-toplevel)

# Setup paths for this repo
include $(TOP)/Makefile.common
# Pull in tools (Verilator)
include $(BLACKPARROT_TOOLS_DIR)/Makefile.common

# TODO: refactor this Makefile into a common test makefile and a TB specific file
# test params
include Makefile.params

# Tools
CC ?= $(GCC)
VV ?= $(VERILATOR)

# Linting
LINT_DIR ?= lint
LINT_TOP ?= testbench
LINT_LOG ?= $(LINT_DIR)/lint.log
LINT_FLIST ?= $(LINT_DIR)/lint.flist
LINT_CONFIG ?= $(LINT_DIR)/config.vlt
LINT_OPTS = --lint-only -Wall -Wno-unoptflat -Wno-timescalemod
LINT_OPTS += --top-module $(LINT_TOP) -f $(LINT_FLIST) $(LINT_CONFIG)

TB_FLIST ?= test.flist

$(LINT_CONFIG):
	cat $(LINT_CONFIG_BASE) | envsubst > $@

# need to pull flists from IP blocks, add flist for current testbench
# may need non-env substituted flists for each IP block, which get combined and deduplicated
# to create a final flist for testbench/verilation
$(LINT_FLIST): $(IP_FLIST) $(TB_FLIST)
	cp $(IP_FLIST) $(LINT_FLIST)

lint: $(LINT_DIR)/lintsc
LINT_COLLATERAL = $(LINT_CONFIG) $(LINT_FLIST)
$(LINT_COLLATERAL): | $(LINT_DIR)
$(LINT_DIR)/lintsc: $(LINT_COLLATERAL)
	cd $(@D); $(VV) $(LINT_OPTS) $(HDL_PARAMS) $(HDL_DEFINES) 2>&1 | tee -i $(LINT_LOG)

# Directories
$(LINT_DIR):
	mkdir -p $@

lint_clean:
	rm -rf $(LINT_DIR)

# Simulation
VV_OPTS = --cc
VV_OPTS += -O1


