# SPDX-License-Identifier: BSD-3-Clause
#
# Makefile
#
# Top-level Makefile for BlackParrot FPGA test
#

TOP ?= $(shell git rev-parse --show-toplevel)

# cosim
export CHECKPOINT_P ?= 0
export COSIM_P ?= 1
export COSIM_MEMSIZE_P ?= 256
export COSIM_INSTR_P ?= 0

# tracing
export COMMIT_TRACE_P ?= 0

export CFG ?= e_bp_default_cfg

export RISCV_TARGET ?= riscv64-unknown-linux-gnu

# testbench stuff
export TEST_TOP = testbench
export TEST_NAME = ip-test

include $(TOP)/test/Makefile.test

# test params
include $(TEST_DIR)/Makefile.params

export BP_IP_SRC_DIR = $(BASE_DIR)/blackparrot/src
export BP_FPGA_HOST_IP_SRC_DIR = $(BASE_DIR)/blackparrot_fpga_host/src

################################################################################
### Bootrom and program files + NBF
################################################################################

NBF = $(BASE_DIR)/software/nbf.py
NBF_NCPUS ?= 1
NBF_MEM_SIZE ?= 256
NBF_BOOTROM ?= bootrom.mem
NBF_BOOTROM_SIZE ?= 64
NBF_UCODE ?=
NBF_SKIP_ZEROS ?= 1
NBF_BOOT_PC ?=
NBF_CONFIG ?= 0
NBF_DEBUG ?= 1
NBF_VERIFY ?= 0
NBF_START_CACHED ?= 1

NBF_FLAGS = --ncpus $(NBF_NCPUS) --data_width 64
NBF_FLAGS += --bootrom $(NBF_BOOTROM) --bootrom_size $(NBF_BOOTROM_SIZE)
ifneq ($(NBF_UCODE),)
NBF_FLAGS += --ucode $(NBF_UCODE)
endif
ifneq ($(NBF_BOOT_PC),)
NBF_FLAGS += --boot_pc $(NBF_BOOT_PC)
endif
ifeq ($(NBF_SKIP_ZEROS),1)
NBF_FLAGS += --skip_zeros
endif
ifeq ($(NBF_CONFIG),1)
NBF_FLAGS += --config
endif
ifeq ($(NBF_DEBUG),1)
NBF_FLAGS += --debug
endif
ifeq ($(NBF_VERIFY),1)
NBF_FLAGS += --verify
endif
ifeq ($(NBF_START_CACHED),1)
NBF_FLAGS += --start_cached
endif
NBF_FLAGS += --mem_size $(NBF_MEM_SIZE)

BOOTROM_RISCV ?= $(BP_SDK_DIR)/prog/bootrom/bootrom.riscv

PROG ?= hello_world
SUITE ?= bp-tests
PROG_RISCV = $(BP_SDK_DIR)/prog/$(SUITE)/$(PROG).riscv

RISCV_OBJCOPY ?= $(CROSS_COMPILE)objcopy
RISCV_OBJDUMP ?= $(CROSS_COMPILE)objdump

%.mem: %.riscv
	$(RISCV_OBJCOPY) -O verilog $< $@

%.bin: %.riscv
	$(RISCV_OBJCOPY) -O binary $< $@

%.dump: %.riscv
	$(RISCV_OBJDUMP) -D -t $< > $@

%.nbf: %.mem
	python $(NBF) $(NBF_FLAGS) --mem $< > $@

%.elf: %.riscv
	cp $< $@

$(TEST_DIR)/prog.riscv: $(PROG_RISCV)
	cp $< $@

$(TEST_DIR)/bootrom.riscv: $(BOOTROM_RISCV)
	cp $< $@

SIM_COLLATERAL = $(TEST_DIR)/bootrom.riscv $(TEST_DIR)/bootrom.dump $(TEST_DIR)/bootrom.mem
SIM_COLLATERAL += $(TEST_DIR)/bootrom.bin
SIM_COLLATERAL += $(TEST_DIR)/prog.riscv $(TEST_DIR)/prog.dump $(TEST_DIR)/prog.mem
SIM_COLLATERAL += $(TEST_DIR)/prog.elf $(TEST_DIR)/prog.nbf $(TEST_DIR)/prog.bin
sim_prep: $(SIM_COLLATERAL)

sim_prep_clean:
	rm -f $(SIM_COLLATERAL)

clean: sim_prep_clean

################################################################################
### Common
################################################################################

PROG_NBF ?= prog.nbf
PROG_ELF = $(PROG_NBF:.nbf=.elf)

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
	sed "s/BP_CFG_FLOWVAR/$(CFG)/g" $(TESTBENCH) > $(VV_LINT_DIR)/$(TEST_TOP).sv
	@echo $(VV_LINT_DIR)/$(TEST_TOP).sv >> $@

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
	sed "s/BP_CFG_FLOWVAR/$(CFG)/g" $(TESTBENCH) > $(VV_BUILD_DIR)/$(TEST_TOP).sv
	@echo $(VV_BUILD_DIR)/$(TEST_TOP).sv >> $@

$(VV_CONFIG):
	cat $(VV_CONFIG_BASE) | envsubst > $@

##################
### Simulation ###
##################

export VV_SIM_DIR     = $(TEST_DIR)/$(TEST_NAME).sim.vv
export VV_SIM_LOG     = $(VV_SIM_DIR)/sim.log

pre_sim.vv:
	cp $(TEST_DIR)/$(PROG_NBF) $(VV_SIM_DIR)/$(PROG_NBF)
	cp $(TEST_DIR)/$(PROG_ELF) $(VV_SIM_DIR)/$(PROG_ELF)

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
	sed "s/BP_CFG_FLOWVAR/$(CFG)/g" $(TESTBENCH) > $(VCS_LINT_DIR)/$(TEST_TOP).sv
	@echo $(VCS_LINT_DIR)/$(TEST_TOP).sv >> $@

################
### Building ###
################

export VCS_BUILD_DIR   = $(TEST_DIR)/$(TEST_NAME).build.vcs
export VCS_FLIST       = $(VCS_BUILD_DIR)/build.flist
export VCS_LOG         = $(VCS_BUILD_DIR)/build.log
export VCS_TOP        ?= $(TEST_TOP)

$(VCS_FLIST): $(TEST_FLIST)
	cat $(TEST_FLIST) | envsubst > $@
	sed "s/BP_CFG_FLOWVAR/$(CFG)/g" $(TESTBENCH) > $(VCS_BUILD_DIR)/$(TEST_TOP).sv
	@echo $(VCS_BUILD_DIR)/$(TEST_TOP).sv >> $@

##################
### Simulation ###
##################

# VCS uses the BUILD_DIR as the SIM_DIR
export VCS_SIM_LOG     = $(VCS_BUILD_DIR)/sim.log

pre_sim.vcs:
	cp $(TEST_DIR)/$(PROG_NBF) $(VCS_BUILD_DIR)/$(PROG_NBF)
	cp $(TEST_DIR)/$(PROG_ELF) $(VCS_BUILD_DIR)/$(PROG_ELF)

### Include tool Makefile
include $(MAKE_DIR)/Makefile.vcs

################################################################################
### Global
################################################################################

