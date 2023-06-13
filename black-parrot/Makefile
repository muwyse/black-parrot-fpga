# SPDX-License-Identifier: BSD-3-Clause
#
# Makefile
#
# Top-level Makefile for BlackParrot IP packaging
#

TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common
include $(BLACKPARROT_TOOLS_DIR)/Makefile.common

export BASE_DIR           := $(abspath $(TOP)/black-parrot)
export PROJECT_SRC_DIR    := $(BASE_DIR)/src
export XDC_DIR            := $(BASE_DIR)/xdc
export IP_NAME             = blackparrot
export IP_PROJECT_NAME     = $(IP_NAME)_ip_proj
export IP_PROJECT_DIR      = $(BASE_DIR)/$(IP_PROJECT_NAME)
export IP_TOP              = $(IP_NAME)
export IP_FLIST            = $(BASE_DIR)/ip.flist
export IP_PROPERTY_TCL     = $(BASE_DIR)/bp_ip.tcl
export IP_VENDOR           = BlackParrot
export IP_VENDOR_NAME      = $(IP_VENDOR)
export IP_LIBRARY          = ip
export IP_VERSION          = 1.0
export IP_TAXONOMY         = {/Embedded_Processing/Processor}
export IP_DIR              = $(BASE_DIR)/$(IP_NAME)_ip
export PART               ?= xcvu37p-fsvh2892-2L-e-es1
export PROJECT_NAME        = vcu128_bp
export PROJECT_DIR         = $(BASE_DIR)/$(PROJECT_NAME)
export PROJECT_TOP         = fpga_top
export PROJECT_FLIST       = $(BASE_DIR)/project.flist
export PROJECT_XDC         = $(XDC_DIR)/design_1.xdc

BASE_FLIST                 = $(BASE_DIR)/base.flist
BP_FLIST                   = $(BP_TOP_DIR)/syn/flist.vcs
IP_TAR_GZ                  = $(IP_NAME)_ip.tar.gz
PROJECT_TCL                = $(BASE_DIR)/create_project.tcl

LINT_TOP                   = lint_top
LINT_FLIST                 = $(BASE_DIR)/lint.flist
LINT_LOG                   = $(BASE_DIR)/lint.log
LINT_CONFIG_BASE           = $(BASE_DIR)/lint_settings.verilator
LINT_CONFIG                = $(BASE_DIR)/config.vlt
LINT_OPTS = --lint-only -Wall -Wno-unoptflat --top-module $(LINT_TOP) -f $(LINT_FLIST) $(LINT_CONFIG)

project_flist: $(PROJECT_FLIST)
$(PROJECT_FLIST): $(BP_FLIST) $(BASE_FLIST)
	echo "creating flist"
	# substitute paths in BP flist
	cat $^ | envsubst >> $@
	# swap in memories that infer incorrectly in FPGA
	sed -i "/bsg_mem_1rw_sync_mask_write_bit.v/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_bit_synth.v/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte.v/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte_synth.v/d" $@
	echo "$(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v" >> $@
	echo "$(PROJECT_SRC_DIR)/bsg_mem_1rw_sync_mask_write_byte.v" >> $@
	echo "$(PROJECT_SRC_DIR)/bytewrite_bram.v" >> $@

project: clean_project | $(PROJECT_FLIST)
	vivado -source $(PROJECT_TCL) -mode batch

clean_project:
	rm -f $(PROJECT_FLIST)
	rm -rf $(PROJECT_DIR)

build_ip: clean_ip | $(IP_FLIST)
	vivado -source $(BUILD_IP_TCL) -mode batch

pack_ip:
	tar -czvf $(IP_TAR_GZ) $(IP_NAME)_ip

clean_ip:
	rm -rf $(IP_DIR)
	rm -f $(IP_TAR_GZ)

lint_flist: $(LINT_FLIST)
$(LINT_FLIST): $(BP_FLIST) $(BASE_FLIST)
	echo "creating flist"
	# substitute paths in BP flist
	cat $^ | envsubst >> $@
	# swap in memories that infer incorrectly in FPGA
	sed -i "/bsg_mem_1rw_sync_mask_write_bit.v/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_bit_synth.v/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte.v/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte_synth.v/d" $@
	sed -i "/fpga_top.sv/d" $@
	echo "$(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v" >> $@
	echo "$(PROJECT_SRC_DIR)/bsg_mem_1rw_sync_mask_write_byte.v" >> $@
	echo "$(PROJECT_SRC_DIR)/bytewrite_bram.v" >> $@
	echo "$(PROJECT_SRC_DIR)/$(LINT_TOP).sv" >> $@

$(LINT_CONFIG):
	cat $(LINT_CONFIG_BASE) | envsubst > $@

lint: $(LINT_FLIST) $(LINT_CONFIG)
	$(VERILATOR) $(LINT_OPTS) 2>&1 | tee -i $(LINT_LOG)

clean_lint:
	rm -f $(LINT_FLIST)
	rm -f $(LINT_LOG)

clean: clean_project clean_ip clean_lint
	rm -f vivado*
