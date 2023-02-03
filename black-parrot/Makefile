# SPDX-License-Identifier: BSD-3-Clause
#
# Makefile
#
# Top-level Makefile for BlackParrot IP packaging
#

TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export BP_PROJECT_DIR := $(abspath $(TOP)/black-parrot)
export IP_NAME         = blackparrot
export IP_DIR          = $(BP_PROJECT_DIR)/$(IP_NAME)_ip
export IP_TOP          = $(IP_NAME)
export IP_FLIST        = $(BP_PROJECT_DIR)/ip.flist
export IP_PROPERTY_TCL = $(BP_PROJECT_DIR)/bp_ip.tcl
export IP_VENDOR       = BlackParrot
export IP_VENDOR_NAME  = $(IP_VENDOR)
export IP_LIBRARY      = ip
export IP_VERSION      = 1.0
export IP_TAXONOMY     = {/Embedded_Processing/Processor}
export PART           ?= NONE
export PROJECT_NAME    = $(IP_NAME)_ip_proj
export PROJECT_DIR     = $(BP_PROJECT_DIR)/$(PROJECT_NAME)

BASE_FLIST             = $(BP_PROJECT_DIR)/base.flist
IP_TAR_GZ              = $(IP_NAME)_ip.tar.gz

# TODO: SRAM swaps, add BP flist as dependency
flist: $(IP_FLIST)
$(IP_FLIST): $(BASE_FLIST)
	echo "creating flist"
	# substitute paths in BP flist
	cat $^ | envsubst >> $@
	# swap in memories that infer incorrectly in FPGA

build_ip: clean | $(IP_FLIST)
	vivado -source $(BUILD_IP_TCL) -mode batch

pack_ip:
	tar -czvf $(IP_TAR_GZ) $(IP_NAME)_ip

clean_ip:
	rm -rf $(IP_DIR)
	rm -f $(IP_TAR_GZ)

clean: clean_ip

