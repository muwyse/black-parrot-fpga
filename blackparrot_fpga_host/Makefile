# SPDX-License-Identifier: BSD-3-Clause
#
# Makefile
#
# Top-level Makefile for BlackParrot IP packaging
#

TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common
include $(BLACKPARROT_TOOLS_DIR)/Makefile.common

export IP_NAME             = blackparrot_fpga_host
export IP_DIR             := $(BASE_DIR)/$(IP_NAME)
export IP_PROJECT_NAME     = $(IP_NAME)_ip_proj
export IP_PROJECT_DIR      = $(IP_DIR)/$(IP_PROJECT_NAME)
export IP_SRC_DIR          = $(IP_DIR)/src
export IP_TOP              = $(IP_NAME)
export IP_BASE_FLIST       = $(IP_DIR)/base.flist
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

export IP_TAR_GZ           = $(IP_NAME)_ip.tar.gz

###############
### Linting ###
###############

export LINT_DIR      = $(IP_DIR)/$(IP_NAME).lint
export LINT_FLIST    = $(LINT_DIR)/lint.flist
export LINT_CONFIG   = $(LINT_DIR)/config.vlt
export LINT_LOG      = $(LINT_DIR)/lint.log
export LINT_TOP     ?= $(IP_TOP)

$(LINT_FLIST): $(IP_FLIST)
	cp $(IP_FLIST) $(LINT_FLIST)

$(LINT_CONFIG):
	cat $(VV_CONFIG_BASE) | envsubst > $@

include $(MAKE_DIR)/Makefile.verilator

################
### Building ###
################

export BUILD_DIR = $(IP_DIR)/$(IP_NAME).build

ip_flist: $(IP_FLIST)
$(IP_FLIST): $(IP_BASE_FLIST)
	# substitute paths in BP flist
	cat $^ | envsubst >> $@
	# swap in memories that infer incorrectly in FPGA
	sed -i "/bsg_mem_1rw_sync_mask_write_bit.sv/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_bit_synth.sv/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte.sv/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte_synth.sv/d" $@
	echo "$(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.sv" >> $@
	echo "$(BASE_SRC_DIR)/bsg_mem_1rw_sync_mask_write_byte.sv" >> $@
	echo "$(BASE_SRC_DIR)/bytewrite_bram.v" >> $@

build_ip: clean_ip $(IP_FLIST)
	vivado -source $(BUILD_IP_TCL) -mode batch

pack_ip:
	tar -czvf $(IP_TAR_GZ) $(IP_NAME)_ip

clean_ip:
	rm -rf $(IP_EXP_DIR)
	rm -rf $(IP_PROJECT_DIR)
	rm -f $(IP_TAR_GZ)
	rm -f $(IP_FLIST)

clean: clean_lint clean_ip
	rm -f vivado*
