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

module design_1_wrapper

 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bsg_cache_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_multicore_4_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam s_axi_addr_width_p   = 33
   , localparam s_axi_id_width_p     = 6
   , localparam s_axi_len_width_p    = 8
   , localparam s_axi_size_width_p   = 3
   , localparam s_axi_data_width_p   = 256
   , localparam s_axi_strb_width_p   = (s_axi_data_width_p/8)
   , localparam s_axi_burst_len_p    = 2

   , localparam m_axil_addr_width_p   = 32
   , localparam m_axil_data_width_p   = 32
   , localparam m_axil_strb_width_p   = (m_axil_data_width_p/8)
   , localparam m_axil_buffer_els_p   = 16
   )
   (pci_express_x4_rxn
    , pci_express_x4_rxp
    , pci_express_x4_txn
    , pci_express_x4_txp
    , pcie_perstn
    , pcie_refclk_clk_n
    , pcie_refclk_clk_p
    , rstn
    , led
    );

  // FPGA device I/O signals
  input wire [3:0] pci_express_x4_rxn;
  input wire [3:0] pci_express_x4_rxp;
  output wire [3:0] pci_express_x4_txn;
  output wire [3:0] pci_express_x4_txp;
  input wire pcie_perstn;
  input wire [0:0] pcie_refclk_clk_n;
  input wire [0:0] pcie_refclk_clk_p;
  input wire rstn;
  output wire [7:0] led;

  // TODO: unused here, remove BD outputs?
  // PCIe signals from block design
  wire pcie_clk;
  wire pcie_lnk_up;
  wire [0:0]pcie_rstn;

  // Clock and Reset for BP domain
  // AXIL M and AXI S are in this domain
  wire bp_clk;
  wire [0:0]bp_rstn;

  // AXIL M from PC Host for BP I/O
  wire [m_axil_addr_width_p-1:0]m_axi_lite_araddr;
  wire [2:0]m_axi_lite_arprot;
  wire m_axi_lite_arready;
  wire m_axi_lite_arvalid;
  wire [m_axil_addr_width_p-1:0]m_axi_lite_awaddr;
  wire [2:0]m_axi_lite_awprot;
  wire m_axi_lite_awready;
  wire m_axi_lite_awvalid;
  wire m_axi_lite_bready;
  wire [1:0]m_axi_lite_bresp;
  wire m_axi_lite_bvalid;
  wire [m_axil_data_width_p-1:0]m_axi_lite_rdata;
  wire m_axi_lite_rready;
  wire [1:0]m_axi_lite_rresp;
  wire m_axi_lite_rvalid;
  wire [m_axil_data_width_p-1:0]m_axi_lite_wdata;
  wire m_axi_lite_wready;
  wire [m_axil_strb_width_p-1:0]m_axi_lite_wstrb;
  wire m_axi_lite_wvalid;

  // AXI S from BP to HBM
  wire [daddr_width_p-1:0] s_axi_araddr_addr;
  wire [`BSG_SAFE_CLOG2(num_cce_p)-1:0] s_axi_araddr_cache_id;
  wire [s_axi_addr_width_p-1:0]s_axi_araddr;
  wire [1:0]s_axi_arburst;
  wire [3:0]s_axi_arcache;
  wire [s_axi_id_width_p-1:0]s_axi_arid;
  wire [s_axi_len_width_p-1:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [3:0]s_axi_arregion;
  wire [s_axi_size_width_p-1:0]s_axi_arsize;
  wire s_axi_arvalid;

  wire [daddr_width_p-1:0] s_axi_awaddr_addr;
  wire [`BSG_SAFE_CLOG2(num_cce_p)-1:0] s_axi_awaddr_cache_id;
  wire [s_axi_addr_width_p-1:0]s_axi_awaddr;
  wire [1:0]s_axi_awburst;
  wire [3:0]s_axi_awcache;
  wire [s_axi_id_width_p-1:0]s_axi_awid;
  wire [s_axi_len_width_p-1:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [3:0]s_axi_awregion;
  wire [s_axi_size_width_p-1:0]s_axi_awsize;
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

  // HBM S_APB
  // mostly unused, except for apb_complete
  wire apb_complete;
  wire [21:0]s_apb_paddr = '0;
  wire s_apb_penable = 1'b0;
  wire [31:0]s_apb_prdata;
  wire s_apb_pready;
  wire s_apb_psel = 1'b0;
  wire s_apb_pslverr;
  wire [31:0]s_apb_pwdata = '0;
  wire s_apb_pwrite = 1'b0;

  // FPGA block design
  // contains HBM, XDMA, clocking
  design_1 design_1_i
    (
     // external reset pin
     .reset(~rstn),

     // PCIe to/from PC Host
     .pcie_refclk_clk_n(pcie_refclk_clk_n),
     .pcie_refclk_clk_p(pcie_refclk_clk_p),
     .pcie_perstn(pcie_perstn),
     .pci_express_x4_rxn(pci_express_x4_rxn),
     .pci_express_x4_rxp(pci_express_x4_rxp),
     .pci_express_x4_txn(pci_express_x4_txn),
     .pci_express_x4_txp(pci_express_x4_txp),
     // PCIe to design
     .pcie_clk(pcie_clk),
     .pcie_rstn(pcie_rstn),
     .pcie_lnk_up(pcie_lnk_up),

     // Clock and Reset for BP domain
     // AXIL M and AXI S are in this domain
     .mig_clk(bp_clk),
     .mig_rstn(bp_rstn),

     // AXIL M from PC Host for BP I/O
     .m_axi_lite_araddr(m_axi_lite_araddr),
     .m_axi_lite_arprot(m_axi_lite_arprot),
     .m_axi_lite_arready(m_axi_lite_arready),
     .m_axi_lite_arvalid(m_axi_lite_arvalid),
     .m_axi_lite_awaddr(m_axi_lite_awaddr),
     .m_axi_lite_awprot(m_axi_lite_awprot),
     .m_axi_lite_awready(m_axi_lite_awready),
     .m_axi_lite_awvalid(m_axi_lite_awvalid),
     .m_axi_lite_bready(m_axi_lite_bready),
     .m_axi_lite_bresp(m_axi_lite_bresp),
     .m_axi_lite_bvalid(m_axi_lite_bvalid),
     .m_axi_lite_rdata(m_axi_lite_rdata),
     .m_axi_lite_rready(m_axi_lite_rready),
     .m_axi_lite_rresp(m_axi_lite_rresp),
     .m_axi_lite_rvalid(m_axi_lite_rvalid),
     .m_axi_lite_wdata(m_axi_lite_wdata),
     .m_axi_lite_wready(m_axi_lite_wready),
     .m_axi_lite_wstrb(m_axi_lite_wstrb),
     .m_axi_lite_wvalid(m_axi_lite_wvalid),

     // AXI S from BP to HBM
     .s_axi_araddr(s_axi_araddr),
     .s_axi_arburst(s_axi_arburst),
     .s_axi_arcache(s_axi_arcache),
     .s_axi_arid(s_axi_arid),
     .s_axi_arlen(s_axi_arlen),
     .s_axi_arlock(s_axi_arlock),
     .s_axi_arprot(s_axi_arprot),
     .s_axi_arqos(s_axi_arqos),
     .s_axi_arready(s_axi_arready),
     .s_axi_arregion(s_axi_arregion),
     .s_axi_arsize(s_axi_arsize),
     .s_axi_arvalid(s_axi_arvalid),
     .s_axi_awaddr(s_axi_awaddr),
     .s_axi_awburst(s_axi_awburst),
     .s_axi_awcache(s_axi_awcache),
     .s_axi_awid(s_axi_awid),
     .s_axi_awlen(s_axi_awlen),
     .s_axi_awlock(s_axi_awlock),
     .s_axi_awprot(s_axi_awprot),
     .s_axi_awqos(s_axi_awqos),
     .s_axi_awready(s_axi_awready),
     .s_axi_awregion(s_axi_awregion),
     .s_axi_awsize(s_axi_awsize),
     .s_axi_awvalid(s_axi_awvalid),
     .s_axi_bid(s_axi_bid),
     .s_axi_bready(s_axi_bready),
     .s_axi_bresp(s_axi_bresp),
     .s_axi_bvalid(s_axi_bvalid),
     .s_axi_rdata(s_axi_rdata),
     .s_axi_rid(s_axi_rid),
     .s_axi_rlast(s_axi_rlast),
     .s_axi_rready(s_axi_rready),
     .s_axi_rresp(s_axi_rresp),
     .s_axi_rvalid(s_axi_rvalid),
     .s_axi_wdata(s_axi_wdata),
     .s_axi_wlast(s_axi_wlast),
     .s_axi_wready(s_axi_wready),
     .s_axi_wstrb(s_axi_wstrb),
     .s_axi_wvalid(s_axi_wvalid),

     // HBM S_APB
     // mostly unused, except for apb_complete
     .apb_complete(apb_complete),
     .s_apb_paddr(s_apb_paddr),
     .s_apb_penable(s_apb_penable),
     .s_apb_prdata(s_apb_prdata),
     .s_apb_pready(s_apb_pready),
     .s_apb_psel(s_apb_psel),
     .s_apb_pslverr(s_apb_pslverr),
     .s_apb_pwdata(s_apb_pwdata),
     .s_apb_pwrite(s_apb_pwrite)
     );

  // LEDs
  assign led[0] = pcie_lnk_up;
  assign led[1] = apb_complete;

  // breathing
  logic led_breath;
  logic [31:0] led_counter_r;
  assign led[2] = led_breath;
  always_ff @(posedge bp_clk)
    if (bp_reset)
      begin
        led_counter_r <= '0;
        led_breath <= 1'b0;
      end
    else
      begin
        led_counter_r <= (led_counter_r == 32'd12500000)? '0 : led_counter_r + 1;
        led_breath <= (led_counter_r == 32'd12500000)? ~led_breath : led_breath;
      end
  // pcie stream host (NBF and MMIO)
  logic nbf_done_lo;
  assign led[3] = nbf_done_lo;

  // reset pin
  assign led[4] = ~rstn;
  assign led[5] = ~rstn;
  assign led[6] = rstn;
  assign led[7] = rstn;

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
     ,.data_i(~bp_rstn | ~apb_complete)
     ,.data_o(bp_reset)
     );

  // subtract dram_base_addr_gp from axi addresses
  // S_AXI memory is at address 0x0, but BP issues address to DRAM at 0x8000_0000
  assign s_axi_awaddr = s_axi_awaddr_addr[0+:s_axi_addr_width_p] ^ dram_base_addr_gp;
  assign s_axi_araddr = s_axi_araddr_addr[0+:s_axi_addr_width_p] ^ dram_base_addr_gp;

  // s_axi port
  // not supported
  assign s_axi_arqos    = '0;
  assign s_axi_arregion = '0;
  assign s_axi_awqos    = '0;
  assign s_axi_awregion = '0;

  // BP I/O AXIL
  logic [m_axil_addr_width_p-1:0] bp_m_axil_awaddr_lo;
  logic [2:0] bp_m_axil_awprot_lo;
  logic bp_m_axil_awvalid_lo;
  logic bp_m_axil_awready_li;

  logic [m_axil_data_width_p-1:0] bp_m_axil_wdata_lo;
  logic [m_axil_strb_width_p-1:0] bp_m_axil_wstrb_lo;
  logic bp_m_axil_wvalid_lo;
  logic bp_m_axil_wready_li;

  logic [1:0] bp_m_axil_bresp_li;
  logic bp_m_axil_bvalid_li;
  logic bp_m_axil_bready_lo;

  logic [m_axil_addr_width_p-1:0] bp_m_axil_araddr_lo;
  logic [2:0] bp_m_axil_arprot_lo;
  logic bp_m_axil_arvalid_lo;
  logic bp_m_axil_arready_li;

  logic [m_axil_data_width_p-1:0] bp_m_axil_rdata_li;
  logic [1:0] bp_m_axil_rresp_li;
  logic bp_m_axil_rvalid_li;
  logic bp_m_axil_rready_lo;

  logic [m_axil_addr_width_p-1:0] bp_s_axil_awaddr_li;
  logic [2:0] bp_s_axil_awprot_li;
  logic bp_s_axil_awvalid_li;
  logic bp_s_axil_awready_lo;

  logic [m_axil_data_width_p-1:0] bp_s_axil_wdata_li;
  logic [m_axil_strb_width_p-1:0] bp_s_axil_wstrb_li;
  logic bp_s_axil_wvalid_li;
  logic bp_s_axil_wready_lo;

  logic [1:0] bp_s_axil_bresp_lo;
  logic bp_s_axil_bvalid_lo;
  logic bp_s_axil_bready_li;

  logic [m_axil_addr_width_p-1:0] bp_s_axil_araddr_li;
  logic [2:0] bp_s_axil_arprot_li;
  logic bp_s_axil_arvalid_li;
  logic bp_s_axil_arready_lo;

  logic [m_axil_data_width_p-1:0] bp_s_axil_rdata_lo;
  logic [1:0] bp_s_axil_rresp_lo;
  logic bp_s_axil_rvalid_lo;
  logic bp_s_axil_rready_li;

  bp_axi_top
    #(.bp_params_p(bp_params_p)
     ,.m_axil_addr_width_p(m_axil_addr_width_p)
     ,.m_axil_data_width_p(m_axil_data_width_p)
     ,.s_axil_addr_width_p(m_axil_addr_width_p)
     ,.s_axil_data_width_p(m_axil_data_width_p)
     ,.axi_addr_width_p(s_axi_addr_width_p)
     ,.axi_data_width_p(s_axi_data_width_p)
     ,.axi_id_width_p(s_axi_id_width_p)
     ,.axi_len_width_p(s_axi_len_width_p)
     ,.axi_size_width_p(s_axi_size_width_p)
     )
    blackparrot
    (.clk_i(bp_clk)
    ,.reset_i(bp_reset)
    ,.rt_clk_i(bp_clk)

    // I/O Out
    ,.m_axil_awaddr_o(bp_m_axil_awaddr_lo)
    ,.m_axil_awprot_o(bp_m_axil_awprot_lo)
    ,.m_axil_awvalid_o(bp_m_axil_awvalid_lo)
    ,.m_axil_awready_i(bp_m_axil_awready_li)

    ,.m_axil_wdata_o(bp_m_axil_wdata_lo)
    ,.m_axil_wstrb_o(bp_m_axil_wstrb_lo)
    ,.m_axil_wvalid_o(bp_m_axil_wvalid_lo)
    ,.m_axil_wready_i(bp_m_axil_wready_li)

    ,.m_axil_bresp_i(bp_m_axil_bresp_li)
    ,.m_axil_bvalid_i(bp_m_axil_bvalid_li)
    ,.m_axil_bready_o(bp_m_axil_bready_lo)

    ,.m_axil_araddr_o(bp_m_axil_araddr_lo)
    ,.m_axil_arprot_o(bp_m_axil_arprot_lo)
    ,.m_axil_arvalid_o(bp_m_axil_arvalid_lo)
    ,.m_axil_arready_i(bp_m_axil_arready_li)

    ,.m_axil_rdata_i(bp_m_axil_rdata_li)
    ,.m_axil_rresp_i(bp_m_axil_rresp_li)
    ,.m_axil_rvalid_i(bp_m_axil_rvalid_li)
    ,.m_axil_rready_o(bp_m_axil_rready_lo)

    // I/O In
    ,.s_axil_awaddr_i(bp_s_axil_awaddr_li)
    ,.s_axil_awprot_i(bp_s_axil_awprot_li)
    ,.s_axil_awvalid_i(bp_s_axil_awvalid_li)
    ,.s_axil_awready_o(bp_s_axil_awready_lo)

    ,.s_axil_wdata_i(bp_s_axil_wdata_li)
    ,.s_axil_wstrb_i(bp_s_axil_wstrb_li)
    ,.s_axil_wvalid_i(bp_s_axil_wvalid_li)
    ,.s_axil_wready_o(bp_s_axil_wready_lo)

    ,.s_axil_bresp_o(bp_s_axil_bresp_lo)
    ,.s_axil_bvalid_o(bp_s_axil_bvalid_lo)
    ,.s_axil_bready_i(bp_s_axil_bready_li)

    ,.s_axil_araddr_i(bp_s_axil_araddr_li)
    ,.s_axil_arprot_i(bp_s_axil_arprot_li)
    ,.s_axil_arvalid_i(bp_s_axil_arvalid_li)
    ,.s_axil_arready_o(bp_s_axil_arready_lo)

    ,.s_axil_rdata_o(bp_s_axil_rdata_lo)
    ,.s_axil_rresp_o(bp_s_axil_rresp_lo)
    ,.s_axil_rvalid_o(bp_s_axil_rvalid_lo)
    ,.s_axil_rready_i(bp_s_axil_rready_li)

    // to memory
    ,.m_axi_awvalid_o(s_axi_awvalid)
    ,.m_axi_awready_i(s_axi_awready)
    ,.m_axi_awaddr_o(s_axi_awaddr)
    ,.m_axi_awburst_o(s_axi_awburst)
    ,.m_axi_awcache_o(s_axi_awcache)
    ,.m_axi_awid_o(s_axi_awid)
    ,.m_axi_awlen_o(s_axi_awlen)
    ,.m_axi_awlock_o(s_axi_awlock)
    ,.m_axi_awprot_o(s_axi_awprot)
    ,.m_axi_awqos_o(s_axi_awqos)
    ,.m_axi_awregion_o(s_axi_awregion)
    ,.m_axi_awsize_o(s_axi_awsize)

    ,.m_axi_wvalid_o(s_axi_wvalid)
    ,.m_axi_wready_i(s_axi_wready)
    ,.m_axi_wdata_o(s_axi_wdata)
    ,.m_axi_wlast_o(s_axi_wlast)
    ,.m_axi_wstrb_o(s_axi_wstrb)

    ,.m_axi_bvalid_i(s_axi_bvalid)
    ,.m_axi_bready_o(s_axi_bready)
    ,.m_axi_bid_i(s_axi_bid)
    ,.m_axi_bresp_i(s_axi_bresp)

    ,.m_axi_arvalid_o(s_axi_arvalid)
    ,.m_axi_arready_i(s_axi_arready)
    ,.m_axi_araddr_o(s_axi_araddr)
    ,.m_axi_arburst_o(s_axi_arburst)
    ,.m_axi_arcache_o(s_axi_arcache)
    ,.m_axi_arid_o(s_axi_arid)
    ,.m_axi_arlen_o(s_axi_arlen)
    ,.m_axi_arlock_o(s_axi_arlock)
    ,.m_axi_arprot_o(s_axi_arprot)
    ,.m_axi_arqos_o(s_axi_arqos)
    ,.m_axi_arregion_o(s_axi_arregion)
    ,.m_axi_arsize_o(s_axi_arsize)

    ,.m_axi_rvalid_i(s_axi_rvalid)
    ,.m_axi_rready_o(s_axi_rready)
    ,.m_axi_rdata_i(s_axi_rdata)
    ,.m_axi_rid_i(s_axi_rid)
    ,.m_axi_rlast_i(s_axi_rlast)
    ,.m_axi_rresp_i(s_axi_rresp)
    );

  // AXIL M to FIFO
  wire stream_v_lo, stream_yumi_li;
  wire [m_axil_addr_width_p-1:0] stream_addr_lo;
  wire stream_v_li, stream_ready_lo;
  wire [m_axil_data_width_p-1:0] stream_data_li, stream_data_lo;

  // m_axi_lite adapter
  bsg_m_axi_lite_to_fifo_sync
   #(.addr_width_p(m_axil_addr_width_p)
    ,.data_width_p(m_axil_data_width_p)
    ,.buffer_size_p(m_axil_buffer_els_p)
    )
    m_axi_lite_adapter
    (.clk_i     (bp_clk)
     ,.reset_i  (bp_reset)
     // read address
     ,.araddr_i (m_axi_lite_araddr)
     ,.arprot_i (m_axi_lite_arprot)
     ,.arready_o(m_axi_lite_arready)
     ,.arvalid_i(m_axi_lite_arvalid)
     // read data
     ,.rdata_o  (m_axi_lite_rdata)
     ,.rready_i (m_axi_lite_rready)
     ,.rresp_o  (m_axi_lite_rresp)
     ,.rvalid_o (m_axi_lite_rvalid)
     // write address
     ,.awaddr_i (m_axi_lite_awaddr)
     ,.awprot_i (m_axi_lite_awprot)
     ,.awready_o(m_axi_lite_awready)
     ,.awvalid_i(m_axi_lite_awvalid)
     // write data
     ,.wdata_i  (m_axi_lite_wdata)
     ,.wready_o (m_axi_lite_wready)
     ,.wstrb_i  (m_axi_lite_wstrb)
     ,.wvalid_i (m_axi_lite_wvalid)
     // write response
     ,.bready_i (m_axi_lite_bready)
     ,.bresp_o  (m_axi_lite_bresp)
     ,.bvalid_o (m_axi_lite_bvalid)
     // fifo output
     ,.v_o      (stream_v_lo)
     ,.addr_o   (stream_addr_lo)
     ,.data_o   (stream_data_lo)
     ,.yumi_i   (stream_yumi_li)
     // fifo input
     ,.v_i      (stream_v_li)
     ,.data_i   (stream_data_li)
     ,.ready_o  (stream_ready_lo)
     );

  bp_stream_host
   #(.bp_params_p(bp_params_p)
     ,.stream_addr_width_p(m_axil_addr_width_p)
     ,.stream_data_width_p(m_axil_data_width_p)
     )
    host
    (.clk_i(bp_clk)
     ,.reset_i(bp_reset)
     ,.prog_done_o(nbf_done_lo)

     // I/O from BP
     ,.s_axil_awaddr_i(bp_m_axil_awaddr_lo)
     ,.s_axil_awprot_i(bp_m_axil_awprot_lo)
     ,.s_axil_awvalid_i(bp_m_axil_awvalid_lo)
     ,.s_axil_awready_o(bp_m_axil_awready_li)

     ,.s_axil_wdata_i(bp_m_axil_wdata_lo)
     ,.s_axil_wstrb_i(bp_m_axil_wstrb_lo)
     ,.s_axil_wvalid_i(bp_m_axil_wvalid_lo)
     ,.s_axil_wready_o(bp_m_axil_wready_li)

     ,.s_axil_bresp_o(bp_m_axil_bresp_li)
     ,.s_axil_bvalid_o(bp_m_axil_bvalid_li)
     ,.s_axil_bready_i(bp_m_axil_bready_lo)

     ,.s_axil_araddr_i(bp_m_axil_araddr_lo)
     ,.s_axil_arprot_i(bp_m_axil_arprot_lo)
     ,.s_axil_arvalid_i(bp_m_axil_arvalid_lo)
     ,.s_axil_arready_o(bp_m_axil_arready_li)

     ,.s_axil_rdata_o(bp_m_axil_rdata_li)
     ,.s_axil_rresp_o(bp_m_axil_rresp_li)
     ,.s_axil_rvalid_o(bp_m_axil_rvalid_li)
     ,.s_axil_rready_i(bp_m_axil_rready_lo)

     // I/O to BP
     ,.m_axil_awaddr_o(bp_s_axil_awaddr_li)
     ,.m_axil_awprot_o(bp_s_axil_awprot_li)
     ,.m_axil_awvalid_o(bp_s_axil_awvalid_li)
     ,.m_axil_awready_i(bp_s_axil_awready_lo)

     ,.m_axil_wdata_o(bp_s_axil_wdata_li)
     ,.m_axil_wstrb_o(bp_s_axil_wstrb_li)
     ,.m_axil_wvalid_o(bp_s_axil_wvalid_li)
     ,.m_axil_wready_i(bp_s_axil_wready_lo)

     ,.m_axil_bresp_i(bp_s_axil_bresp_lo)
     ,.m_axil_bvalid_i(bp_s_axil_bvalid_lo)
     ,.m_axil_bready_o(bp_s_axil_bready_li)

     ,.m_axil_araddr_o(bp_s_axil_araddr_li)
     ,.m_axil_arprot_o(bp_s_axil_arprot_li)
     ,.m_axil_arvalid_o(bp_s_axil_arvalid_li)
     ,.m_axil_arready_i(bp_s_axil_arready_lo)

     ,.m_axil_rdata_i(bp_s_axil_rdata_lo)
     ,.m_axil_rresp_i(bp_s_axil_rresp_lo)
     ,.m_axil_rvalid_i(bp_s_axil_rvalid_lo)
     ,.m_axil_rready_o(bp_s_axil_rready_li)

     // interface to AXIL FIFO
     ,.stream_v_i(stream_v_lo)
     ,.stream_addr_i(stream_addr_lo)
     ,.stream_data_i(stream_data_lo)
     ,.stream_yumi_o(stream_yumi_li)

     ,.stream_v_o(stream_v_li)
     ,.stream_data_o(stream_data_li)
     ,.stream_ready_i(stream_ready_lo)
     );

endmodule
