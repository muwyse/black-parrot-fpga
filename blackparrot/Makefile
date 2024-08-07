# SPDX-License-Identifier: BSD-3-Clause
#
# Makefile
#
# Top-level Makefile for BlackParrot IP packaging
#

TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common
include $(BP_TOOLS_DIR)/Makefile.common

export IP_NAME             = blackparrot
export IP_DIR              = $(BASE_DIR)/$(IP_NAME)
export IP_PROJECT_NAME     = $(IP_NAME)_ip_proj
export IP_PROJECT_DIR      = $(IP_DIR)/$(IP_PROJECT_NAME)
export IP_SRC_DIR          = $(IP_DIR)/src
export IP_TOP              = $(IP_NAME)
export IP_BASE_FLIST       = $(IP_DIR)/base.flist
export IP_COMMON_FLIST     = $(IP_DIR)/ip_base.flist
export IP_FLIST            = $(IP_DIR)/ip.flist
export IP_PROPERTY_TCL     = $(IP_DIR)/ip.tcl
export IP_VENDOR           = BlackParrot
export IP_VENDOR_NAME      = $(IP_VENDOR)
export IP_LIBRARY          = ip
export IP_VERSION          = 1.0
export IP_TAXONOMY         = {/Embedded_Processing/Processor}
export IP_EXP_DIR          = $(IP_DIR)/$(IP_NAME)_ip
export PART               ?= xcvu37p-fsvh2892-2L-e-es1
export BOARD_PART         ?= xilinx.com:vcu128_es:part0:1.1

export IP_TOP_FILE         = $(IP_SRC_DIR)/$(IP_TOP).sv

export CFG                ?= e_bp_default_cfg

BP_FLIST                   = $(BP_TOP_DIR)/syn/flist.vcs
export IP_TAR_GZ           = $(IP_NAME)_ip.tar.gz

################################################################################
### Verilator
################################################################################

###############
### Linting ###
###############

export VERILATOR_LINT_DIR      = $(IP_DIR)/$(IP_NAME).lint.verilator
export VERILATOR_LINT_FLIST    = $(VERILATOR_LINT_DIR)/lint.flist
export VERILATOR_LINT_CONFIG   = $(VERILATOR_LINT_DIR)/config.vlt
export VERILATOR_LINT_LOG      = $(VERILATOR_LINT_DIR)/lint.log
export VERILATOR_LINT_TOP     ?= $(IP_TOP)

export VERILATOR_BUILD_DIR     = $(IP_DIR)/$(IP_NAME).build.verilator
export VERILATOR_SIM_DIR       = $(IP_DIR)/$(IP_NAME).sim.verilator

$(VERILATOR_LINT_FLIST): $(IP_COMMON_FLIST)
	cp $< $@
	sed "s/BP_CFG_FLOWVAR/$(CFG)/g" $(IP_TOP_FILE) > $(VERILATOR_LINT_DIR)/$(IP_TOP).sv
	@echo $(VERILATOR_LINT_DIR)/$(IP_TOP).sv >> $@

$(VERILATOR_LINT_CONFIG):
	cat $(VERILATOR_CONFIG_BASE) | envsubst > $@

include $(MAKE_DIR)/Makefile.verilator

################################################################################
### VCS
################################################################################

###############
### Linting ###
###############

export VCS_LINT_DIR      = $(IP_DIR)/$(IP_NAME).lint.vcs
export VCS_LINT_FLIST    = $(VCS_LINT_DIR)/lint.flist
export VCS_LINT_LOG      = $(VCS_LINT_DIR)/lint.log
export VCS_LINT_TOP     ?= $(IP_TOP)

export VCS_BUILD_DIR     = $(IP_DIR)/$(IP_NAME).build.vcs

$(VCS_LINT_FLIST): $(IP_COMMON_FLIST)
	cp $< $@
	sed "s/BP_CFG_FLOWVAR/$(CFG)/g" $(IP_TOP_FILE) > $(VCS_LINT_DIR)/$(IP_TOP).sv
	@echo $(VCS_LINT_DIR)/$(IP_TOP).sv >> $@

### Include tool Makefile
include $(MAKE_DIR)/Makefile.vcs

################
### Building ###
################

export BUILD_DIR = $(IP_DIR)/$(IP_NAME).build
$(BUILD_DIR):
	mkdir -p $@

ip_common_flist: $(IP_COMMON_FLIST)
$(IP_COMMON_FLIST): $(BP_FLIST) $(IP_BASE_FLIST)
	# substitute paths in BP flist
	cat $^ | envsubst >> $@
	# swap in memories that infer incorrectly in FPGA
	sed -i "/bsg_mem_1rw_sync_mask_write_bit.sv/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_bit_synth.sv/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte.sv/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte_synth.sv/d" $@
	echo "$(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.sv" >> $@
	echo "$(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_from_1r1w.sv" >> $@
	echo "$(BASE_SRC_DIR)/bsg_mem_1rw_sync_mask_write_byte.sv" >> $@
	echo "$(BASE_SRC_DIR)/bytewrite_bram.v" >> $@

ip_flist: $(IP_FLIST)
$(IP_FLIST): $(IP_COMMON_FLIST) | $(BUILD_DIR)
	cp $< $@
	# Harden synchronizers and clock muxes
	sed -i "s#.*bsg_launch_sync_sync.sv#$(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_async/bsg_launch_sync_sync.sv#g" $@
	sed -i "s#.*bsg_mux.sv#$(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_misc/bsg_mux.sv#g" $@
	sed "s/BP_CFG_FLOWVAR/$(CFG)/g" $(IP_TOP_FILE) > $(BUILD_DIR)/$(IP_TOP).sv
	@echo $(BUILD_DIR)/$(IP_TOP).sv >> $@

build_ip: clean_ip | $(IP_FLIST)
	vivado -source $(BUILD_IP_TCL) -mode batch

pack_ip:
	tar -czvf $(IP_TAR_GZ) $(IP_NAME)_ip

clean_ip:
	rm -rf $(IP_EXP_DIR)
	rm -rf $(IP_PROJECT_DIR)
	rm -rf $(BUILD_DIR)
	rm -f $(IP_TAR_GZ)
	rm -f $(IP_FLIST)
	rm -f $(IP_COMMON_FLIST)
	rm -f vivado*

clean: clean_ip

