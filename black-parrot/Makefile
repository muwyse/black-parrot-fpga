# SPDX-License-Identifier: BSD-3-Clause
#
# Makefile
#
# Top-level Makefile for BlackParrot IP packaging
#

TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export BP_PROJECT_DIR     := $(abspath $(TOP)/black-parrot)
export BP_PROJECT_SRC_DIR := $(BP_PROJECT_DIR)/src
export IP_NAME             = blackparrot
export IP_DIR              = $(BP_PROJECT_DIR)/$(IP_NAME)_ip
export IP_TOP              = $(IP_NAME)
export IP_FLIST            = $(BP_PROJECT_DIR)/ip.flist
export IP_PROPERTY_TCL     = $(BP_PROJECT_DIR)/bp_ip.tcl
export IP_VENDOR           = BlackParrot
export IP_VENDOR_NAME      = $(IP_VENDOR)
export IP_LIBRARY          = ip
export IP_VERSION          = 1.0
export IP_TAXONOMY         = {/Embedded_Processing/Processor}
export PART               ?= NONE
export PROJECT_NAME        = $(IP_NAME)_ip_proj
export PROJECT_DIR         = $(BP_PROJECT_DIR)/$(PROJECT_NAME)

BASE_FLIST                 = $(BP_PROJECT_DIR)/base.flist
BP_FLIST                   = $(BP_TOP_DIR)/syn/flist.vcs
IP_TAR_GZ                  = $(IP_NAME)_ip.tar.gz

flist: $(IP_FLIST)
$(IP_FLIST): $(BASE_FLIST) $(BP_FLIST)
	echo "creating flist"
	# substitute paths in BP flist
	cat $^ | envsubst >> $@
	# swap in memories that infer incorrectly in FPGA
	sed -i "/bsg_mem_1rw_sync_mask_write_bit.v/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_bit_synth.v/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte.v/d" $@
	sed -i "/bsg_mem_1rw_sync_mask_write_byte_synth.v/d" $@
	echo "$(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v" >> $@
	echo "$(BP_PROJECT_SRC_DIR)/bsg_mem_1rw_sync_mask_write_byte.v" >> $@
	echo "$(BP_PROJECT_SRC_DIR)/bytewrite_ram.v" >> $@

build_ip: clean | $(IP_FLIST)
	vivado -source $(BUILD_IP_TCL) -mode batch

pack_ip:
	tar -czvf $(IP_TAR_GZ) $(IP_NAME)_ip

clean_ip:
	rm -rf $(IP_DIR)
	rm -f $(IP_TAR_GZ)

clean: clean_ip

