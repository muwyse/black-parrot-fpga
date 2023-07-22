/*
 *  Name:
 *    design_1_wrapper.sv
 *
 *  Description:
 *    Top-level wrapper for multicore BP on FPGA.
 *
 *    Parameters:
 *    bp_params_p - specifies number of cores and CCE type, and all BP parameters
 */

// Original header:
//Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2019.1 (lin64) Build 2552052 Fri May 24 14:47:09 MDT 2019
//Date        : Sun Mar 22 22:52:07 2020
//Host        : dhcp196-212.ece.uw.edu running 64-bit CentOS Linux release 7.7.1908 (Core)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

module lint_top_test

 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bsg_cache_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_multicore_8_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   // I/O In
   , localparam s_axi_addr_width_p   = 64
   , localparam s_axi_id_width_p     = 6
   , localparam s_axi_data_width_p   = 64
   , localparam s_axi_strb_width_p   = (s_axi_data_width_p/8)

   // I/O Out
   , localparam m_axi_addr_width_p   = 64
   , localparam m_axi_id_width_p     = 6
   , localparam m_axi_data_width_p   = 64
   , localparam m_axi_strb_width_p   = (m_axi_data_width_p/8)

   // Memory
   , localparam m01_axi_addr_width_p   = 33
   , localparam m01_axi_id_width_p     = 6
   , localparam m01_axi_data_width_p   = 64
   , localparam m01_axi_strb_width_p   = (m01_axi_data_width_p/8)
   )
   (rstn
    , bp_clk
    );

  // FPGA device I/O signals
  input wire rstn;
  input wire bp_clk;

  // Clock and Reset for BP domain
  // AXIL M and AXI S are in this domain
  wire [0:0]bp_rstn;

  // I/O In
  wire [s_axi_addr_width_p-1:0]s_axi_awaddr;
  wire [1:0]s_axi_awburst;
  wire [3:0]s_axi_awcache;
  wire [s_axi_id_width_p-1:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [3:0]s_axi_awregion;
  wire [2:0]s_axi_awsize;
  wire s_axi_awvalid;

  wire [s_axi_id_width_p-1:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire s_axi_bvalid;

  wire [s_axi_data_width_p-1:0]s_axi_rdata;
  wire [s_axi_id_width_p-1:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire s_axi_rvalid;

  wire [s_axi_data_width_p-1:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [s_axi_strb_width_p-1:0]s_axi_wstrb;
  wire s_axi_wvalid;

  // I/O Out
  wire [m_axi_addr_width_p-1:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [m_axi_id_width_p-1:0]m_axi_awid;
  wire [7:0]m_axi_awlen;
  wire [0:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [3:0]m_axi_awregion;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;

  wire [m_axi_id_width_p-1:0]m_axi_bid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;

  wire [m_axi_data_width_p-1:0]m_axi_rdata;
  wire [m_axi_id_width_p-1:0]m_axi_rid;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;

  wire [m_axi_data_width_p-1:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [m_axi_strb_width_p-1:0]m_axi_wstrb;
  wire m_axi_wvalid;

  // Memory
  wire [m01_axi_addr_width_p-1:0]m01_axi_awaddr;
  wire [1:0]m01_axi_awburst;
  wire [3:0]m01_axi_awcache;
  wire [m01_axi_id_width_p-1:0]m01_axi_awid;
  wire [7:0]m01_axi_awlen;
  wire [0:0]m01_axi_awlock;
  wire [2:0]m01_axi_awprot;
  wire [3:0]m01_axi_awqos;
  wire m01_axi_awready;
  wire [3:0]m01_axi_awregion;
  wire [2:0]m01_axi_awsize;
  wire m01_axi_awvalid;

  wire [m01_axi_id_width_p-1:0]m01_axi_bid;
  wire m01_axi_bready;
  wire [1:0]m01_axi_bresp;
  wire m01_axi_bvalid;

  wire [m01_axi_data_width_p-1:0]m01_axi_rdata;
  wire [m01_axi_id_width_p-1:0]m01_axi_rid;
  wire m01_axi_rlast;
  wire m01_axi_rready;
  wire [1:0]m01_axi_rresp;
  wire m01_axi_rvalid;

  wire [m01_axi_data_width_p-1:0]m01_axi_wdata;
  wire m01_axi_wlast;
  wire m01_axi_wready;
  wire [m01_axi_strb_width_p-1:0]m01_axi_wstrb;
  wire m01_axi_wvalid;

  // BlackParrot instantiation
  // BP memory connects to BD s_axi
  // BP I/O are managed by BD m_axi_lite (host issues read/write commands)
  //   and BP's ports are connected to a FPGA-based host module

  // BP domain reset
  logic bp_reset;
  bsg_dff
   #(.width_p(1))
    mig_dff
    (.clk_i (bp_clk)
     ,.data_i(~bp_rstn)
     ,.data_o(bp_reset)
     );

  bp_axi4_top
    #(.bp_params_p(bp_params_p)
     ,.m_axi_addr_width_p(m_axi_addr_width_p)
     ,.m_axi_data_width_p(m_axi_data_width_p)
     ,.m_axi_id_width_p(m_axi_id_width_p)
     ,.s_axi_addr_width_p(s_axi_addr_width_p)
     ,.s_axi_data_width_p(s_axi_data_width_p)
     ,.s_axi_id_width_p(s_axi_id_width_p)
     ,.m01_axi_addr_width_p(m01_axi_addr_width_p)
     ,.m01_axi_data_width_p(m01_axi_data_width_p)
     ,.m01_axi_id_width_p(m01_axi_id_width_p)
     )
    blackparrot
    (.clk_i(bp_clk)
    ,.reset_i(bp_reset)
    ,.rt_clk_i(bp_clk)

    ,.my_did_i('0)
    ,.host_did_i('1)

    // I/O Out
    ,.m_axi_awvalid_o(m_axi_awvalid)
    ,.m_axi_awready_i(m_axi_awready)
    ,.m_axi_awaddr_o(m_axi_awaddr)
    ,.m_axi_awburst_o(m_axi_awburst)
    ,.m_axi_awcache_o(m_axi_awcache)
    ,.m_axi_awid_o(m_axi_awid)
    ,.m_axi_awlen_o(m_axi_awlen)
    ,.m_axi_awlock_o(m_axi_awlock)
    ,.m_axi_awprot_o(m_axi_awprot)
    ,.m_axi_awqos_o(m_axi_awqos)
    ,.m_axi_awregion_o(m_axi_awregion)
    ,.m_axi_awsize_o(m_axi_awsize)

    ,.m_axi_wvalid_o(m_axi_wvalid)
    ,.m_axi_wready_i(m_axi_wready)
    ,.m_axi_wdata_o(m_axi_wdata)
    ,.m_axi_wlast_o(m_axi_wlast)
    ,.m_axi_wstrb_o(m_axi_wstrb)

    ,.m_axi_bvalid_i(m_axi_bvalid)
    ,.m_axi_bready_o(m_axi_bready)
    ,.m_axi_bid_i(m_axi_bid)
    ,.m_axi_bresp_i(m_axi_bresp)

    ,.m_axi_arvalid_o(m_axi_arvalid)
    ,.m_axi_arready_i(m_axi_arready)
    ,.m_axi_araddr_o(m_axi_araddr)
    ,.m_axi_arburst_o(m_axi_arburst)
    ,.m_axi_arcache_o(m_axi_arcache)
    ,.m_axi_arid_o(m_axi_arid)
    ,.m_axi_arlen_o(m_axi_arlen)
    ,.m_axi_arlock_o(m_axi_arlock)
    ,.m_axi_arprot_o(m_axi_arprot)
    ,.m_axi_arqos_o(m_axi_arqos)
    ,.m_axi_arregion_o(m_axi_arregion)
    ,.m_axi_arsize_o(m_axi_arsize)

    ,.m_axi_rvalid_i(m_axi_rvalid)
    ,.m_axi_rready_o(m_axi_rready)
    ,.m_axi_rdata_i(m_axi_rdata)
    ,.m_axi_rid_i(m_axi_rid)
    ,.m_axi_rlast_i(m_axi_rlast)
    ,.m_axi_rresp_i(m_axi_rresp)

    // I/O In
    ,.s_axi_awvalid_i(s_axi_awvalid)
    ,.s_axi_awready_o(s_axi_awready)
    ,.s_axi_awaddr_i(s_axi_awaddr)
    ,.s_axi_awburst_i(s_axi_awburst)
    ,.s_axi_awcache_i(s_axi_awcache)
    ,.s_axi_awid_i(s_axi_awid)
    ,.s_axi_awlen_i(s_axi_awlen)
    ,.s_axi_awlock_i(s_axi_awlock)
    ,.s_axi_awprot_i(s_axi_awprot)
    ,.s_axi_awqos_i(s_axi_awqos)
    ,.s_axi_awregion_i(s_axi_awregion)
    ,.s_axi_awsize_i(s_axi_awsize)

    ,.s_axi_wvalid_i(s_axi_wvalid)
    ,.s_axi_wready_o(s_axi_wready)
    ,.s_axi_wdata_i(s_axi_wdata)
    ,.s_axi_wlast_i(s_axi_wlast)
    ,.s_axi_wstrb_i(s_axi_wstrb)

    ,.s_axi_bvalid_o(s_axi_bvalid)
    ,.s_axi_bready_i(s_axi_bready)
    ,.s_axi_bid_o(s_axi_bid)
    ,.s_axi_bresp_o(s_axi_bresp)

    ,.s_axi_arvalid_i(s_axi_arvalid)
    ,.s_axi_arready_o(s_axi_arready)
    ,.s_axi_araddr_i(s_axi_araddr)
    ,.s_axi_arburst_i(s_axi_arburst)
    ,.s_axi_arcache_i(s_axi_arcache)
    ,.s_axi_arid_i(s_axi_arid)
    ,.s_axi_arlen_i(s_axi_arlen)
    ,.s_axi_arlock_i(s_axi_arlock)
    ,.s_axi_arprot_i(s_axi_arprot)
    ,.s_axi_arqos_i(s_axi_arqos)
    ,.s_axi_arregion_i(s_axi_arregion)
    ,.s_axi_arsize_i(s_axi_arsize)

    ,.s_axi_rvalid_o(s_axi_rvalid)
    ,.s_axi_rready_i(s_axi_rready)
    ,.s_axi_rdata_o(s_axi_rdata)
    ,.s_axi_rid_o(s_axi_rid)
    ,.s_axi_rlast_o(s_axi_rlast)
    ,.s_axi_rresp_o(s_axi_rresp)

    // to memory
    ,.m01_axi_awvalid_o(m01_axi_awvalid)
    ,.m01_axi_awready_i(m01_axi_awready)
    ,.m01_axi_awaddr_o(m01_axi_awaddr)
    ,.m01_axi_awburst_o(m01_axi_awburst)
    ,.m01_axi_awcache_o(m01_axi_awcache)
    ,.m01_axi_awid_o(m01_axi_awid)
    ,.m01_axi_awlen_o(m01_axi_awlen)
    ,.m01_axi_awlock_o(m01_axi_awlock)
    ,.m01_axi_awprot_o(m01_axi_awprot)
    ,.m01_axi_awqos_o(m01_axi_awqos)
    ,.m01_axi_awregion_o(m01_axi_awregion)
    ,.m01_axi_awsize_o(m01_axi_awsize)

    ,.m01_axi_wvalid_o(m01_axi_wvalid)
    ,.m01_axi_wready_i(m01_axi_wready)
    ,.m01_axi_wdata_o(m01_axi_wdata)
    ,.m01_axi_wlast_o(m01_axi_wlast)
    ,.m01_axi_wstrb_o(m01_axi_wstrb)

    ,.m01_axi_bvalid_i(m01_axi_bvalid)
    ,.m01_axi_bready_o(m01_axi_bready)
    ,.m01_axi_bid_i(m01_axi_bid)
    ,.m01_axi_bresp_i(m01_axi_bresp)

    ,.m01_axi_arvalid_o(m01_axi_arvalid)
    ,.m01_axi_arready_i(m01_axi_arready)
    ,.m01_axi_araddr_o(m01_axi_araddr)
    ,.m01_axi_arburst_o(m01_axi_arburst)
    ,.m01_axi_arcache_o(m01_axi_arcache)
    ,.m01_axi_arid_o(m01_axi_arid)
    ,.m01_axi_arlen_o(m01_axi_arlen)
    ,.m01_axi_arlock_o(m01_axi_arlock)
    ,.m01_axi_arprot_o(m01_axi_arprot)
    ,.m01_axi_arqos_o(m01_axi_arqos)
    ,.m01_axi_arregion_o(m01_axi_arregion)
    ,.m01_axi_arsize_o(m01_axi_arsize)

    ,.m01_axi_rvalid_i(m01_axi_rvalid)
    ,.m01_axi_rready_o(m01_axi_rready)
    ,.m01_axi_rdata_i(m01_axi_rdata)
    ,.m01_axi_rid_i(m01_axi_rid)
    ,.m01_axi_rlast_i(m01_axi_rlast)
    ,.m01_axi_rresp_i(m01_axi_rresp)
    );

endmodule
