# SPDX-License-Identifier: BSD-3-Clause
#
# create_project.cl
#
# Build VCU128 project
#

# project properties
set project_dir      $::env(PROJECT_DIR)
set project_name     $::env(PROJECT_NAME)
set project_xdc      $::env(PROJECT_XDC)
set part             $::env(PART)

create_project -force -part ${part} ${project_name} ${project_dir}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set file "[file normalize ${project_xdc}]"
set file_added [add_files -norecurse -fileset [get_filesets constrs_1] [list $file]]
set file ${project_xdc}
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property file_type XDC $file_obj

# Set 'constrs_1' fileset properties
set_property target_part ${part} [get_filesets constrs_1]

# Proc to create BD design_1
proc cr_bd_design_1 { parentCell } {

  # CHANGE DESIGN NAME HERE
  set design_name design_1

  common::send_msg_id "BD_TCL-003" "INFO" "Currently there is no design <$design_name> in project, so creating one..."

  create_bd_design $design_name

  set bCheckIPsPassed 1
  ##################################################################
  # CHECK IPs
  ##################################################################
  set bCheckIPs 1
  if { $bCheckIPs == 1 } {
     set list_check_ips "\
  xilinx.com:ip:axi_clock_converter:2.1\
  BlackParrot:ip:blackparrot:1.0\
  BlackParrot:ip:blackparrot_fpga_host:1.0\
  xilinx.com:ip:clk_wiz:6.0\
  xilinx.com:ip:hbm:1.0\
  xilinx.com:ip:ila:6.2\
  xilinx.com:ip:proc_sys_reset:5.0\
  xilinx.com:ip:smartconnect:1.0\
  xilinx.com:ip:util_ds_buf:2.1\
  xilinx.com:ip:xdma:4.1\
  "

   set list_ips_missing ""
   common::send_msg_id "BD_TCL-006" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_msg_id "BD_TCL-115" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

  }

  if { $bCheckIPsPassed != 1 } {
    common::send_msg_id "BD_TCL-1003" "WARNING" "Will not continue with creation of design due to the error(s) above."
    return 3
  }

  variable script_folder

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set SAPB_0_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:apb_rtl:1.0 SAPB_0_0 ]

  set SAPB_1_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:apb_rtl:1.0 SAPB_1_0 ]

  set pci_express_x4 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x4 ]

  set pcie_refclk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {100000000} \
   ] $pcie_refclk


  # Create ports
  set pcie_perstn [ create_bd_port -dir I -type rst pcie_perstn ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $pcie_perstn
  set rstn [ create_bd_port -dir I -type rst rstn ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $rstn

  # Create instance: axi_clock_converter_0, and set properties
  set axi_clock_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 axi_clock_converter_0 ]
  set_property -dict [ list \
   CONFIG.ACLK_ASYNC {1} \
   CONFIG.PROTOCOL {AXI4LITE} \
   CONFIG.SYNCHRONIZATION_STAGES {3} \
 ] $axi_clock_converter_0

  # Create instance: axi_clock_converter_1, and set properties
  set axi_clock_converter_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 axi_clock_converter_1 ]
  set_property -dict [ list \
   CONFIG.ACLK_ASYNC {1} \
   CONFIG.ADDR_WIDTH {33} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {64} \
   CONFIG.ID_WIDTH {6} \
   CONFIG.PROTOCOL {AXI4} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.WUSER_WIDTH {0} \
 ] $axi_clock_converter_1

  # Create instance: blackparrot_0, and set properties
  set blackparrot_0 [ create_bd_cell -type ip -vlnv BlackParrot:ip:blackparrot:1.0 blackparrot_0 ]
  set_property -dict [ list \
   CONFIG.M01_AXI_ADDR_WIDTH {33} \
 ] $blackparrot_0

  # Create instance: blackparrot_fpga_host_0, and set properties
  set blackparrot_fpga_host_0 [ create_bd_cell -type ip -vlnv BlackParrot:ip:blackparrot_fpga_host:1.0 blackparrot_fpga_host_0 ]

  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [ list \
   CONFIG.CLKOUT1_JITTER {123.073} \
   CONFIG.CLKOUT1_PHASE_ERROR {85.928} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.0000} \
   CONFIG.CLKOUT2_JITTER {107.111} \
   CONFIG.CLKOUT2_PHASE_ERROR {85.928} \
   CONFIG.CLKOUT2_USED {true} \
   CONFIG.CLKOUT3_JITTER {107.111} \
   CONFIG.CLKOUT3_PHASE_ERROR {85.928} \
   CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {100.000} \
   CONFIG.CLKOUT3_USED {true} \
   CONFIG.CLKOUT4_JITTER {89.528} \
   CONFIG.CLKOUT4_PHASE_ERROR {85.928} \
   CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {250.000} \
   CONFIG.CLKOUT4_USED {true} \
   CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} \
   CONFIG.MMCM_CLKOUT0_DIVIDE_F {20.000} \
   CONFIG.MMCM_CLKOUT1_DIVIDE {10} \
   CONFIG.MMCM_CLKOUT2_DIVIDE {10} \
   CONFIG.MMCM_CLKOUT3_DIVIDE {4} \
   CONFIG.MMCM_DIVCLK_DIVIDE {1} \
   CONFIG.NUM_OUT_CLKS {4} \
   CONFIG.PRIM_SOURCE {Global_buffer} \
   CONFIG.USE_LOCKED {false} \
   CONFIG.USE_RESET {false} \
 ] $clk_wiz_0

  # Create instance: hbm_0, and set properties
  set hbm_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:hbm:1.0 hbm_0 ]
  set_property -dict [ list \
   CONFIG.HBM_MMCM_FBOUT_MULT0 {70} \
   CONFIG.USER_APB_PCLK_0 {100} \
   CONFIG.USER_AXI_CLK_FREQ {250} \
   CONFIG.USER_CLK_SEL_LIST0 {AXI_00_ACLK} \
   CONFIG.USER_CLK_SEL_LIST1 {AXI_16_ACLK} \
   CONFIG.USER_HBM_DENSITY {8GB} \
   CONFIG.USER_HBM_STACK {2} \
   CONFIG.USER_MC0_ECC_BYPASS {true} \
   CONFIG.USER_MC0_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC0_REORDER_EN {false} \
   CONFIG.USER_MC0_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC10_ECC_BYPASS {true} \
   CONFIG.USER_MC10_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC10_REORDER_EN {false} \
   CONFIG.USER_MC10_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC11_ECC_BYPASS {true} \
   CONFIG.USER_MC11_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC11_REORDER_EN {false} \
   CONFIG.USER_MC11_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC12_ECC_BYPASS {true} \
   CONFIG.USER_MC12_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC12_REORDER_EN {false} \
   CONFIG.USER_MC12_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC13_ECC_BYPASS {true} \
   CONFIG.USER_MC13_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC13_REORDER_EN {false} \
   CONFIG.USER_MC13_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC14_ECC_BYPASS {true} \
   CONFIG.USER_MC14_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC14_REORDER_EN {false} \
   CONFIG.USER_MC14_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC15_ECC_BYPASS {true} \
   CONFIG.USER_MC15_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC15_REORDER_EN {false} \
   CONFIG.USER_MC15_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC1_ECC_BYPASS {true} \
   CONFIG.USER_MC1_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC1_REORDER_EN {false} \
   CONFIG.USER_MC1_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC2_ECC_BYPASS {true} \
   CONFIG.USER_MC2_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC2_REORDER_EN {false} \
   CONFIG.USER_MC2_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC3_ECC_BYPASS {true} \
   CONFIG.USER_MC3_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC3_REORDER_EN {false} \
   CONFIG.USER_MC3_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC4_ECC_BYPASS {true} \
   CONFIG.USER_MC4_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC4_REORDER_EN {false} \
   CONFIG.USER_MC4_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC5_ECC_BYPASS {true} \
   CONFIG.USER_MC5_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC5_REORDER_EN {false} \
   CONFIG.USER_MC5_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC6_ECC_BYPASS {true} \
   CONFIG.USER_MC6_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC6_REORDER_EN {false} \
   CONFIG.USER_MC6_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC7_ECC_BYPASS {true} \
   CONFIG.USER_MC7_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC7_REORDER_EN {false} \
   CONFIG.USER_MC7_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC8_ECC_BYPASS {true} \
   CONFIG.USER_MC8_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC8_REORDER_EN {false} \
   CONFIG.USER_MC8_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC9_ECC_BYPASS {true} \
   CONFIG.USER_MC9_MAINTAIN_COHERENCY {false} \
   CONFIG.USER_MC9_REORDER_EN {false} \
   CONFIG.USER_MC9_REORDER_QUEUE_EN {false} \
   CONFIG.USER_MC_ENABLE_01 {TRUE} \
   CONFIG.USER_MC_ENABLE_02 {TRUE} \
   CONFIG.USER_MC_ENABLE_03 {TRUE} \
   CONFIG.USER_MC_ENABLE_04 {TRUE} \
   CONFIG.USER_MC_ENABLE_05 {TRUE} \
   CONFIG.USER_MC_ENABLE_06 {TRUE} \
   CONFIG.USER_MC_ENABLE_07 {TRUE} \
   CONFIG.USER_MC_ENABLE_08 {TRUE} \
   CONFIG.USER_MC_ENABLE_09 {TRUE} \
   CONFIG.USER_MC_ENABLE_10 {TRUE} \
   CONFIG.USER_MC_ENABLE_11 {TRUE} \
   CONFIG.USER_MC_ENABLE_12 {TRUE} \
   CONFIG.USER_MC_ENABLE_13 {TRUE} \
   CONFIG.USER_MC_ENABLE_14 {TRUE} \
   CONFIG.USER_MC_ENABLE_15 {TRUE} \
   CONFIG.USER_MC_ENABLE_APB_01 {TRUE} \
   CONFIG.USER_MEMORY_DISPLAY {8192} \
   CONFIG.USER_PHY_ENABLE_08 {TRUE} \
   CONFIG.USER_PHY_ENABLE_09 {TRUE} \
   CONFIG.USER_PHY_ENABLE_10 {TRUE} \
   CONFIG.USER_PHY_ENABLE_11 {TRUE} \
   CONFIG.USER_PHY_ENABLE_12 {TRUE} \
   CONFIG.USER_PHY_ENABLE_13 {TRUE} \
   CONFIG.USER_PHY_ENABLE_14 {TRUE} \
   CONFIG.USER_PHY_ENABLE_15 {TRUE} \
   CONFIG.USER_SAXI_00 {true} \
   CONFIG.USER_SAXI_01 {false} \
   CONFIG.USER_SAXI_02 {false} \
   CONFIG.USER_SAXI_03 {false} \
   CONFIG.USER_SAXI_04 {false} \
   CONFIG.USER_SAXI_05 {false} \
   CONFIG.USER_SAXI_06 {false} \
   CONFIG.USER_SAXI_07 {false} \
   CONFIG.USER_SAXI_08 {false} \
   CONFIG.USER_SAXI_09 {false} \
   CONFIG.USER_SAXI_10 {false} \
   CONFIG.USER_SAXI_11 {false} \
   CONFIG.USER_SAXI_12 {false} \
   CONFIG.USER_SAXI_13 {false} \
   CONFIG.USER_SAXI_14 {false} \
   CONFIG.USER_SAXI_15 {false} \
   CONFIG.USER_SAXI_16 {true} \
   CONFIG.USER_SAXI_17 {false} \
   CONFIG.USER_SAXI_18 {false} \
   CONFIG.USER_SAXI_19 {false} \
   CONFIG.USER_SAXI_20 {false} \
   CONFIG.USER_SAXI_21 {false} \
   CONFIG.USER_SAXI_22 {false} \
   CONFIG.USER_SAXI_23 {false} \
   CONFIG.USER_SAXI_24 {false} \
   CONFIG.USER_SAXI_25 {false} \
   CONFIG.USER_SAXI_26 {false} \
   CONFIG.USER_SAXI_27 {false} \
   CONFIG.USER_SAXI_28 {false} \
   CONFIG.USER_SAXI_29 {false} \
   CONFIG.USER_SAXI_30 {false} \
   CONFIG.USER_SAXI_31 {false} \
   CONFIG.USER_SINGLE_STACK_SELECTION {LEFT} \
   CONFIG.USER_SWITCH_ENABLE_00 {TRUE} \
   CONFIG.USER_SWITCH_ENABLE_01 {TRUE} \
   CONFIG.USER_TEMP_POLL_CNT_0 {100000} \
 ] $hbm_0

  # Create instance: ila_0, and set properties
  set ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_0 ]
  set_property -dict [ list \
   CONFIG.ALL_PROBE_SAME_MU_CNT {2} \
   CONFIG.C_PROBE0_MU_CNT {2} \
   CONFIG.C_PROBE10_MU_CNT {2} \
   CONFIG.C_PROBE11_MU_CNT {2} \
   CONFIG.C_PROBE12_MU_CNT {2} \
   CONFIG.C_PROBE13_MU_CNT {2} \
   CONFIG.C_PROBE14_MU_CNT {2} \
   CONFIG.C_PROBE15_MU_CNT {2} \
   CONFIG.C_PROBE16_MU_CNT {2} \
   CONFIG.C_PROBE17_MU_CNT {2} \
   CONFIG.C_PROBE18_MU_CNT {2} \
   CONFIG.C_PROBE19_MU_CNT {2} \
   CONFIG.C_PROBE1_MU_CNT {2} \
   CONFIG.C_PROBE20_MU_CNT {2} \
   CONFIG.C_PROBE21_MU_CNT {2} \
   CONFIG.C_PROBE22_MU_CNT {2} \
   CONFIG.C_PROBE23_MU_CNT {2} \
   CONFIG.C_PROBE24_MU_CNT {2} \
   CONFIG.C_PROBE25_MU_CNT {2} \
   CONFIG.C_PROBE26_MU_CNT {2} \
   CONFIG.C_PROBE27_MU_CNT {2} \
   CONFIG.C_PROBE28_MU_CNT {2} \
   CONFIG.C_PROBE29_MU_CNT {2} \
   CONFIG.C_PROBE2_MU_CNT {2} \
   CONFIG.C_PROBE30_MU_CNT {2} \
   CONFIG.C_PROBE31_MU_CNT {2} \
   CONFIG.C_PROBE32_MU_CNT {2} \
   CONFIG.C_PROBE33_MU_CNT {2} \
   CONFIG.C_PROBE34_MU_CNT {2} \
   CONFIG.C_PROBE35_MU_CNT {2} \
   CONFIG.C_PROBE36_MU_CNT {2} \
   CONFIG.C_PROBE37_MU_CNT {2} \
   CONFIG.C_PROBE38_MU_CNT {2} \
   CONFIG.C_PROBE39_MU_CNT {2} \
   CONFIG.C_PROBE3_MU_CNT {2} \
   CONFIG.C_PROBE40_MU_CNT {2} \
   CONFIG.C_PROBE41_MU_CNT {2} \
   CONFIG.C_PROBE42_MU_CNT {2} \
   CONFIG.C_PROBE43_MU_CNT {2} \
   CONFIG.C_PROBE4_MU_CNT {2} \
   CONFIG.C_PROBE5_MU_CNT {2} \
   CONFIG.C_PROBE6_MU_CNT {2} \
   CONFIG.C_PROBE7_MU_CNT {2} \
   CONFIG.C_PROBE8_MU_CNT {2} \
   CONFIG.C_PROBE9_MU_CNT {2} \
 ] $ila_0

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]

  # Create instance: proc_sys_reset_2, and set properties
  set proc_sys_reset_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_2 ]

  # Create instance: proc_sys_reset_3, and set properties
  set proc_sys_reset_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_3 ]

  # Create instance: smartconnect_0, and set properties
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property -dict [ list \
   CONFIG.NUM_MI {2} \
   CONFIG.NUM_SI {1} \
 ] $smartconnect_0

  # Create instance: util_ds_buf_0, and set properties
  set util_ds_buf_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 util_ds_buf_0 ]
  set_property -dict [ list \
   CONFIG.C_BUF_TYPE {IBUFDSGTE} \
 ] $util_ds_buf_0

  # Create instance: xdma_0, and set properties
  set xdma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.1 xdma_0 ]
  set_property -dict [ list \
   CONFIG.PF0_DEVICE_ID_mqdma {9034} \
   CONFIG.PF2_DEVICE_ID_mqdma {9034} \
   CONFIG.PF3_DEVICE_ID_mqdma {9034} \
   CONFIG.axi_data_width {128_bit} \
   CONFIG.axilite_master_en {true} \
   CONFIG.axilite_master_scale {Kilobytes} \
   CONFIG.axilite_master_size {64} \
   CONFIG.axisten_freq {250} \
   CONFIG.en_gt_selection {true} \
   CONFIG.mode_selection {Advanced} \
   CONFIG.pcie_blk_locn {PCIE4C_X1Y0} \
   CONFIG.pf0_device_id {9014} \
   CONFIG.pf0_msix_cap_pba_bir {BAR_1} \
   CONFIG.pf0_msix_cap_table_bir {BAR_1} \
   CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
   CONFIG.pl_link_cap_max_link_width {X4} \
   CONFIG.plltype {QPLL1} \
   CONFIG.select_quad {GTY_Quad_227} \
 ] $xdma_0

  # Create interface connections
  connect_bd_intf_net -intf_net SAPB_0_0_1 [get_bd_intf_ports SAPB_0_0] [get_bd_intf_pins hbm_0/SAPB_0]
  connect_bd_intf_net -intf_net SAPB_1_0_1 [get_bd_intf_ports SAPB_1_0] [get_bd_intf_pins hbm_0/SAPB_1]
  connect_bd_intf_net -intf_net axi_clock_converter_0_M_AXI [get_bd_intf_pins axi_clock_converter_0/M_AXI] [get_bd_intf_pins blackparrot_fpga_host_0/s_axil]
  connect_bd_intf_net -intf_net axi_clock_converter_1_M_AXI [get_bd_intf_pins axi_clock_converter_1/M_AXI] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net blackparrot_0_m_axi [get_bd_intf_pins blackparrot_0/m_axi] [get_bd_intf_pins blackparrot_fpga_host_0/s_axi]
  connect_bd_intf_net -intf_net blackparrot_fpga_host_0_m_axi [get_bd_intf_pins blackparrot_0/s_axi] [get_bd_intf_pins blackparrot_fpga_host_0/m_axi]
  connect_bd_intf_net -intf_net pcie_refclk_1 [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
  connect_bd_intf_net -intf_net s_axi_1 [get_bd_intf_pins axi_clock_converter_1/S_AXI] [get_bd_intf_pins blackparrot_0/m01_axi]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axi_1] [get_bd_intf_pins axi_clock_converter_1/S_AXI] [get_bd_intf_pins ila_0/SLOT_0_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins hbm_0/SAXI_00] [get_bd_intf_pins smartconnect_0/M00_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M01_AXI [get_bd_intf_pins hbm_0/SAXI_16] [get_bd_intf_pins smartconnect_0/M01_AXI]
  connect_bd_intf_net -intf_net xdma_0_M_AXI_LITE [get_bd_intf_pins axi_clock_converter_0/S_AXI] [get_bd_intf_pins xdma_0/M_AXI_LITE]
  connect_bd_intf_net -intf_net xdma_0_pcie_mgt [get_bd_intf_ports pci_express_x4] [get_bd_intf_pins xdma_0/pcie_mgt]

  # Create port connections
  connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins axi_clock_converter_0/m_axi_aclk] [get_bd_pins axi_clock_converter_1/s_axi_aclk] [get_bd_pins blackparrot_0/m01_axi_aclk] [get_bd_pins blackparrot_0/m_axi_aclk] [get_bd_pins blackparrot_0/s_axi_aclk] [get_bd_pins blackparrot_fpga_host_0/m_axi_aclk] [get_bd_pins blackparrot_fpga_host_0/s_axi_aclk] [get_bd_pins blackparrot_fpga_host_0/s_axil_aclk] [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins ila_0/clk] [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
  connect_bd_net -net clk_wiz_0_clk_out2 [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins hbm_0/HBM_REF_CLK_0] [get_bd_pins hbm_0/HBM_REF_CLK_1]
  connect_bd_net -net clk_wiz_0_clk_out3 [get_bd_pins clk_wiz_0/clk_out3] [get_bd_pins hbm_0/APB_0_PCLK] [get_bd_pins hbm_0/APB_1_PCLK] [get_bd_pins proc_sys_reset_2/slowest_sync_clk]
  connect_bd_net -net clk_wiz_0_clk_out4 [get_bd_pins axi_clock_converter_1/m_axi_aclk] [get_bd_pins clk_wiz_0/clk_out4] [get_bd_pins hbm_0/AXI_00_ACLK] [get_bd_pins hbm_0/AXI_16_ACLK] [get_bd_pins proc_sys_reset_3/slowest_sync_clk] [get_bd_pins smartconnect_0/aclk]
  connect_bd_net -net pcie_perstn_1 [get_bd_ports pcie_perstn] [get_bd_pins xdma_0/sys_rst_n]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins axi_clock_converter_0/m_axi_aresetn] [get_bd_pins axi_clock_converter_1/s_axi_aresetn] [get_bd_pins blackparrot_0/m01_axi_aresetn] [get_bd_pins blackparrot_0/m_axi_aresetn] [get_bd_pins blackparrot_0/s_axi_aresetn] [get_bd_pins blackparrot_fpga_host_0/m_axi_aresetn] [get_bd_pins blackparrot_fpga_host_0/s_axi_aresetn] [get_bd_pins blackparrot_fpga_host_0/s_axil_aresetn] [get_bd_pins proc_sys_reset_1/peripheral_aresetn]
  connect_bd_net -net proc_sys_reset_2_peripheral_aresetn [get_bd_pins hbm_0/APB_0_PRESET_N] [get_bd_pins hbm_0/APB_1_PRESET_N] [get_bd_pins proc_sys_reset_2/peripheral_aresetn]
  connect_bd_net -net proc_sys_reset_3_peripheral_aresetn [get_bd_pins axi_clock_converter_1/m_axi_aresetn] [get_bd_pins hbm_0/AXI_00_ARESET_N] [get_bd_pins hbm_0/AXI_16_ARESET_N] [get_bd_pins proc_sys_reset_3/peripheral_aresetn] [get_bd_pins smartconnect_0/aresetn]
  connect_bd_net -net reset_1 [get_bd_ports rstn] [get_bd_pins proc_sys_reset_1/ext_reset_in] [get_bd_pins proc_sys_reset_2/ext_reset_in] [get_bd_pins proc_sys_reset_3/ext_reset_in]
  connect_bd_net -net util_ds_buf_0_IBUF_DS_ODIV2 [get_bd_pins util_ds_buf_0/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]
  connect_bd_net -net util_ds_buf_0_IBUF_OUT [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
  connect_bd_net -net xdma_0_axi_aclk [get_bd_pins axi_clock_converter_0/s_axi_aclk] [get_bd_pins clk_wiz_0/clk_in1] [get_bd_pins xdma_0/axi_aclk]
  connect_bd_net -net xdma_0_axi_aresetn [get_bd_pins axi_clock_converter_0/s_axi_aresetn] [get_bd_pins proc_sys_reset_1/aux_reset_in] [get_bd_pins proc_sys_reset_2/aux_reset_in] [get_bd_pins proc_sys_reset_3/aux_reset_in] [get_bd_pins xdma_0/axi_aresetn]

  # Create address segments
  create_bd_addr_seg -range 0x00010000000000000000 -offset 0x00000000 [get_bd_addr_spaces blackparrot_0/m_axi] [get_bd_addr_segs blackparrot_fpga_host_0/s_axi/mem] SEG_blackparrot_fpga_host_0_mem
  create_bd_addr_seg -range 0x08000000 -offset 0x00000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM00] SEG_hbm_0_HBM_MEM00
  create_bd_addr_seg -range 0x08000000 -offset 0x10000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM01] SEG_hbm_0_HBM_MEM01
  create_bd_addr_seg -range 0x08000000 -offset 0x20000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM02] SEG_hbm_0_HBM_MEM02
  create_bd_addr_seg -range 0x08000000 -offset 0x08000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM00] SEG_hbm_0_HBM_MEM002
  create_bd_addr_seg -range 0x08000000 -offset 0x30000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM03] SEG_hbm_0_HBM_MEM03
  create_bd_addr_seg -range 0x08000000 -offset 0x40000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM04] SEG_hbm_0_HBM_MEM04
  create_bd_addr_seg -range 0x08000000 -offset 0x50000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM05] SEG_hbm_0_HBM_MEM05
  create_bd_addr_seg -range 0x08000000 -offset 0x60000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM06] SEG_hbm_0_HBM_MEM06
  create_bd_addr_seg -range 0x08000000 -offset 0x70000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM07] SEG_hbm_0_HBM_MEM07
  create_bd_addr_seg -range 0x08000000 -offset 0x80000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM08] SEG_hbm_0_HBM_MEM08
  create_bd_addr_seg -range 0x08000000 -offset 0x90000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM09] SEG_hbm_0_HBM_MEM09
  create_bd_addr_seg -range 0x08000000 -offset 0xA0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM10] SEG_hbm_0_HBM_MEM10
  create_bd_addr_seg -range 0x08000000 -offset 0xB0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM11] SEG_hbm_0_HBM_MEM11
  create_bd_addr_seg -range 0x08000000 -offset 0xC0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM12] SEG_hbm_0_HBM_MEM12
  create_bd_addr_seg -range 0x08000000 -offset 0xD0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM13] SEG_hbm_0_HBM_MEM13
  create_bd_addr_seg -range 0x08000000 -offset 0xE0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM14] SEG_hbm_0_HBM_MEM14
  create_bd_addr_seg -range 0x08000000 -offset 0xF0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM15] SEG_hbm_0_HBM_MEM15
  create_bd_addr_seg -range 0x08000000 -offset 0x18000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM01] SEG_hbm_0_HBM_MEM015
  create_bd_addr_seg -range 0x08000000 -offset 0x000100000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM16] SEG_hbm_0_HBM_MEM16
  create_bd_addr_seg -range 0x08000000 -offset 0x000110000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM17] SEG_hbm_0_HBM_MEM17
  create_bd_addr_seg -range 0x08000000 -offset 0x000120000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM18] SEG_hbm_0_HBM_MEM18
  create_bd_addr_seg -range 0x08000000 -offset 0x000130000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM19] SEG_hbm_0_HBM_MEM19
  create_bd_addr_seg -range 0x08000000 -offset 0x000140000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM20] SEG_hbm_0_HBM_MEM20
  create_bd_addr_seg -range 0x08000000 -offset 0x000150000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM21] SEG_hbm_0_HBM_MEM21
  create_bd_addr_seg -range 0x08000000 -offset 0x000160000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM22] SEG_hbm_0_HBM_MEM22
  create_bd_addr_seg -range 0x08000000 -offset 0x000170000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM23] SEG_hbm_0_HBM_MEM23
  create_bd_addr_seg -range 0x08000000 -offset 0x000180000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM24] SEG_hbm_0_HBM_MEM24
  create_bd_addr_seg -range 0x08000000 -offset 0x000190000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM25] SEG_hbm_0_HBM_MEM25
  create_bd_addr_seg -range 0x08000000 -offset 0x0001A0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM26] SEG_hbm_0_HBM_MEM26
  create_bd_addr_seg -range 0x08000000 -offset 0x0001B0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM27] SEG_hbm_0_HBM_MEM27
  create_bd_addr_seg -range 0x08000000 -offset 0x0001C0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM28] SEG_hbm_0_HBM_MEM28
  create_bd_addr_seg -range 0x08000000 -offset 0x28000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM02] SEG_hbm_0_HBM_MEM028
  create_bd_addr_seg -range 0x08000000 -offset 0x0001D0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM29] SEG_hbm_0_HBM_MEM29
  create_bd_addr_seg -range 0x08000000 -offset 0x0001E0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM30] SEG_hbm_0_HBM_MEM30
  create_bd_addr_seg -range 0x08000000 -offset 0x0001F0000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM31] SEG_hbm_0_HBM_MEM31
  create_bd_addr_seg -range 0x08000000 -offset 0x38000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM03] SEG_hbm_0_HBM_MEM0311
  create_bd_addr_seg -range 0x08000000 -offset 0x48000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM04] SEG_hbm_0_HBM_MEM0414
  create_bd_addr_seg -range 0x08000000 -offset 0x58000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM05] SEG_hbm_0_HBM_MEM0517
  create_bd_addr_seg -range 0x08000000 -offset 0x68000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM06] SEG_hbm_0_HBM_MEM0620
  create_bd_addr_seg -range 0x08000000 -offset 0x78000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM07] SEG_hbm_0_HBM_MEM0723
  create_bd_addr_seg -range 0x08000000 -offset 0x88000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM08] SEG_hbm_0_HBM_MEM0826
  create_bd_addr_seg -range 0x08000000 -offset 0x98000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM09] SEG_hbm_0_HBM_MEM0929
  create_bd_addr_seg -range 0x08000000 -offset 0xA8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM10] SEG_hbm_0_HBM_MEM1032
  create_bd_addr_seg -range 0x08000000 -offset 0xB8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM11] SEG_hbm_0_HBM_MEM1135
  create_bd_addr_seg -range 0x08000000 -offset 0xC8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM12] SEG_hbm_0_HBM_MEM1238
  create_bd_addr_seg -range 0x08000000 -offset 0xD8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM13] SEG_hbm_0_HBM_MEM1341
  create_bd_addr_seg -range 0x08000000 -offset 0xE8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM14] SEG_hbm_0_HBM_MEM1444
  create_bd_addr_seg -range 0x08000000 -offset 0xF8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM15] SEG_hbm_0_HBM_MEM1547
  create_bd_addr_seg -range 0x08000000 -offset 0x000108000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM16] SEG_hbm_0_HBM_MEM1650
  create_bd_addr_seg -range 0x08000000 -offset 0x000118000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM17] SEG_hbm_0_HBM_MEM1753
  create_bd_addr_seg -range 0x08000000 -offset 0x000128000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM18] SEG_hbm_0_HBM_MEM1856
  create_bd_addr_seg -range 0x08000000 -offset 0x000138000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM19] SEG_hbm_0_HBM_MEM1959
  create_bd_addr_seg -range 0x08000000 -offset 0x000148000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM20] SEG_hbm_0_HBM_MEM2062
  create_bd_addr_seg -range 0x08000000 -offset 0x000158000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM21] SEG_hbm_0_HBM_MEM2165
  create_bd_addr_seg -range 0x08000000 -offset 0x000168000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM22] SEG_hbm_0_HBM_MEM2268
  create_bd_addr_seg -range 0x08000000 -offset 0x000178000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM23] SEG_hbm_0_HBM_MEM2371
  create_bd_addr_seg -range 0x08000000 -offset 0x000188000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM24] SEG_hbm_0_HBM_MEM2474
  create_bd_addr_seg -range 0x08000000 -offset 0x000198000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM25] SEG_hbm_0_HBM_MEM2577
  create_bd_addr_seg -range 0x08000000 -offset 0x0001A8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM26] SEG_hbm_0_HBM_MEM2680
  create_bd_addr_seg -range 0x08000000 -offset 0x0001B8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM27] SEG_hbm_0_HBM_MEM2783
  create_bd_addr_seg -range 0x08000000 -offset 0x0001C8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM28] SEG_hbm_0_HBM_MEM2886
  create_bd_addr_seg -range 0x08000000 -offset 0x0001D8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM29] SEG_hbm_0_HBM_MEM2989
  create_bd_addr_seg -range 0x08000000 -offset 0x0001E8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM30] SEG_hbm_0_HBM_MEM3092
  create_bd_addr_seg -range 0x08000000 -offset 0x0001F8000000 [get_bd_addr_spaces blackparrot_0/m01_axi] [get_bd_addr_segs hbm_0/SAXI_16/HBM_MEM31] SEG_hbm_0_HBM_MEM3195
  create_bd_addr_seg -range 0x00010000000000000000 -offset 0x00000000 [get_bd_addr_spaces blackparrot_fpga_host_0/m_axi] [get_bd_addr_segs blackparrot_0/s_axi/mem] SEG_blackparrot_0_mem
  create_bd_addr_seg -range 0x00010000 -offset 0x44A00000 [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs blackparrot_fpga_host_0/s_axil/mem] SEG_blackparrot_fpga_host_0_mem

  # Exclude Address Segments
  create_bd_addr_seg -range 0x00400000 -offset 0x00000000 [get_bd_addr_spaces SAPB_0_0] [get_bd_addr_segs hbm_0/SAPB_0/Reg] SEG_hbm_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs SAPB_0_0/SEG_hbm_0_Reg]

  create_bd_addr_seg -range 0x00400000 -offset 0x00000000 [get_bd_addr_spaces SAPB_1_0] [get_bd_addr_segs hbm_0/SAPB_1/Reg] SEG_hbm_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs SAPB_1_0/SEG_hbm_0_Reg]


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
  close_bd_design $design_name
}
# End of cr_bd_design_1()

set ip_repo_paths [get_property ip_repo_paths [current_fileset]]
lappend ip_repo_paths ./blackparrot_ip
lappend ip_repo_paths ./blackparrot_fpga_host_ip
set_property ip_repo_paths $ip_repo_paths [current_fileset]
update_ip_catalog

cr_bd_design_1 ""
set_property REGISTERED_WITH_MANAGER "1" [get_files design_1.bd ]
set_property SYNTH_CHECKPOINT_MODE "Hierarchical" [get_files design_1.bd ]

set top_file [make_wrapper -files [get_files design_1.bd] -top]
add_files -norecurse ${top_file}
set_property -name "top" -value "design_1_wrapper" -objects [get_filesets sources_1]
