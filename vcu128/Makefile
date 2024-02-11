# SPDX-License-Identifier: BSD-3-Clause
#
# Makefile
#
# Top-level Makefile for BlackParrot IP packaging
#

TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common
include $(BLACKPARROT_TOOLS_DIR)/Makefile.common

export BASE_DIR           := $(abspath $(TOP))
export PROJECT_BASE_DIR   := $(BASE_DIR)/vcu128
export XDC_DIR            := $(PROJECT_BASE_DIR)/xdc
export PART               ?= xcvu37p-fsvh2892-2L-e-es1
export BOARD_PART         ?= xilinx.com:vcu128_es:part0:1.1
export PROJECT_NAME        = vcu128_bp
export PROJECT_DIR         = $(PROJECT_BASE_DIR)/$(PROJECT_NAME)
export PROJECT_XDC         = $(XDC_DIR)/design_1.xdc

PROJECT_TCL                = $(PROJECT_BASE_DIR)/create_project.tcl

script_dir := $(abspath $(TOP)/script)
generate_tcl := $(script_dir)/generate_bitstream.tcl
program_tcl := $(script_dir)/program_fpga.tcl
bit_dir := $(PROJECT_BASE_DIR)/bit

BP_IP = blackparrot_ip
BP_IP_DIR = $(BASE_DIR)/blackparrot
BP_HOST_IP = blackparrot_fpga_host_ip
BP_HOST_IP_DIR = $(BASE_DIR)/blackparrot_fpga_host

get_ip:
	cp $(BP_IP_DIR)/$(BP_IP).tar.gz $(PROJECT_BASE_DIR)/
	cp $(BP_HOST_IP_DIR)/$(BP_HOST_IP).tar.gz $(PROJECT_BASE_DIR)/
	find $(PROJECT_BASE_DIR) -name '*.tar.gz' -exec tar xzvf "{}" \;

clean_ip:
	rm -f $(PROJECT_BASE_DIR)/*.tar.gz
	rm -rf $(PROJECT_BASE_DIR)/$(BP_IP)
	rm -rf $(PROJECT_BASE_DIR)/$(BP_HOST_IP)


project: clean_project
	$(vivado_bin) -source $(PROJECT_TCL) -mode batch

clean_project:
	rm -rf $(PROJECT_DIR)

DATE:=$(shell date +"%c")
BITFILE ?= $(bit_dir)/design_1_wrapper.bit
program_fpga:
	sudo $(vivado_bin) -mode batch -source $(program_tcl) -tclargs --bitfile $(BITFILE)
	@echo "$(DATE): $(shell readlink -f $(BITFILE))" > last_programmed.txt
	@echo "$(shell md5sum $(BITFILE))" >> last_programmed.txt

check_device:
	@lspci -vvv | grep -qE "Xilinx" && echo "FPGA found!" || "FPGA not found...try rebooting"

JOBS ?= 8
generate_bitstream:
	$(vivado_bin) -mode batch -source $(generate_tcl) -tclargs --project_name $(PROJECT_NAME) --jobs $(JOBS)

clean: clean_project clean_ip
	rm -f vivado*
	rm -rf .Xil/
