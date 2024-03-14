/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Name:
 *  blackparrot.sv
 *
 * Description:
 *   This module wraps a BP processor with AXI4 interfaces on both of its I/O interfaces
 *   and the memory interface. Ordering and flow control of traffic is enforced by
 *   the bp_me_axi_manager|subordinate modules.
 *
 * Constraints:
 *   This wrapper supports 8, 16, 32, and 64-bit AXI I/O operations on AXI interfaces
 *   with 64-bit data channel width. Only one inbound or outbound I/O operation is
 *   processed at a time (i.e., all I/O is serialized) to guarantee correctness.
 *
 *   bedrock_fill_width_p and m|s_axi_data_width_p must all be 64-bits
 *   Incoming I/O (s_axi_*) transactions must be no larger than 64-bits in a single
 *   transfer and the address must be naturally aligned to the request size. The I/O
 *   converters do not check or enforce this condition, the sender must guarantee it.
 *   Outbound I/O (m_axi_*) generates transactions no larger than 64-bits with a single
 *   data transfer using naturally aligned addresses and the INCR burst type.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module blackparrot
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_axi_pkg::*;
 #(parameter M_AXI_ADDR_WIDTH = 64
   , parameter M_AXI_DATA_WIDTH = 64
   , parameter M_AXI_ID_WIDTH = 4

   , parameter S_AXI_ADDR_WIDTH = 64
   , parameter S_AXI_DATA_WIDTH = 64
   , parameter S_AXI_ID_WIDTH = 4

   , parameter M01_AXI_ADDR_WIDTH = 64
   , parameter M01_AXI_DATA_WIDTH = 128
   , parameter M01_AXI_ID_WIDTH = 4

   , parameter DID = 0
   , parameter HOST_DID = 16'hFFFF
`ifdef SIMULATION
   , parameter bp_params_e bp_params_p = e_bp_default_cfg
`endif
   , parameter [63:0] DRAM_BASE_ADDR = 64'h0
   )
  (//======================== Outgoing I/O ========================
   input                                       m_axi_aclk
   , input                                     m_axi_aresetn
   , output logic [M_AXI_ADDR_WIDTH-1:0]       m_axi_awaddr
   , output logic                              m_axi_awvalid
   , input                                     m_axi_awready
   , output logic [M_AXI_ID_WIDTH-1:0]         m_axi_awid
   , output logic                              m_axi_awlock
   , output logic [3:0]                        m_axi_awcache
   , output logic [2:0]                        m_axi_awprot
   , output logic [7:0]                        m_axi_awlen
   , output logic [2:0]                        m_axi_awsize
   , output logic [1:0]                        m_axi_awburst
   , output logic [3:0]                        m_axi_awqos
   , output logic [3:0]                        m_axi_awregion

   , output logic [M_AXI_DATA_WIDTH-1:0]       m_axi_wdata
   , output logic                              m_axi_wvalid
   , input                                     m_axi_wready
   , output logic                              m_axi_wlast
   , output logic [(M_AXI_DATA_WIDTH/8)-1:0]   m_axi_wstrb

   , input                                     m_axi_bvalid
   , output logic                              m_axi_bready
   , input [M_AXI_ID_WIDTH-1:0]                m_axi_bid
   , input [1:0]                               m_axi_bresp

   , output logic [M_AXI_ADDR_WIDTH-1:0]       m_axi_araddr
   , output logic                              m_axi_arvalid
   , input                                     m_axi_arready
   , output logic [M_AXI_ID_WIDTH-1:0]         m_axi_arid
   , output logic                              m_axi_arlock
   , output logic [3:0]                        m_axi_arcache
   , output logic [2:0]                        m_axi_arprot
   , output logic [7:0]                        m_axi_arlen
   , output logic [2:0]                        m_axi_arsize
   , output logic [1:0]                        m_axi_arburst
   , output logic [3:0]                        m_axi_arqos
   , output logic [3:0]                        m_axi_arregion

   , input [M_AXI_DATA_WIDTH-1:0]              m_axi_rdata
   , input                                     m_axi_rvalid
   , output logic                              m_axi_rready
   , input [M_AXI_ID_WIDTH-1:0]                m_axi_rid
   , input                                     m_axi_rlast
   , input [1:0]                               m_axi_rresp

   //======================== Incoming I/O ========================
   , input                                     s_axi_aclk
   , input                                     s_axi_aresetn
   , input [S_AXI_ADDR_WIDTH-1:0]              s_axi_awaddr
   , input                                     s_axi_awvalid
   , output logic                              s_axi_awready
   , input [S_AXI_ID_WIDTH-1:0]                s_axi_awid
   , input                                     s_axi_awlock
   , input [3:0]                               s_axi_awcache
   , input [2:0]                               s_axi_awprot
   , input [7:0]                               s_axi_awlen
   , input [2:0]                               s_axi_awsize
   , input [1:0]                               s_axi_awburst
   , input [3:0]                               s_axi_awqos
   , input [3:0]                               s_axi_awregion

   , input [S_AXI_DATA_WIDTH-1:0]              s_axi_wdata
   , input                                     s_axi_wvalid
   , output logic                              s_axi_wready
   , input                                     s_axi_wlast
   , input [(S_AXI_DATA_WIDTH/8)-1:0]          s_axi_wstrb

   , output logic                              s_axi_bvalid
   , input                                     s_axi_bready
   , output logic [S_AXI_ID_WIDTH-1:0]         s_axi_bid
   , output logic [1:0]                        s_axi_bresp

   , input [S_AXI_ADDR_WIDTH-1:0]              s_axi_araddr
   , input                                     s_axi_arvalid
   , output logic                              s_axi_arready
   , input [S_AXI_ID_WIDTH-1:0]                s_axi_arid
   , input                                     s_axi_arlock
   , input [3:0]                               s_axi_arcache
   , input [2:0]                               s_axi_arprot
   , input [7:0]                               s_axi_arlen
   , input [2:0]                               s_axi_arsize
   , input [1:0]                               s_axi_arburst
   , input [3:0]                               s_axi_arqos
   , input [3:0]                               s_axi_arregion

   , output logic [S_AXI_DATA_WIDTH-1:0]       s_axi_rdata
   , output logic                              s_axi_rvalid
   , input                                     s_axi_rready
   , output logic [S_AXI_ID_WIDTH-1:0]         s_axi_rid
   , output logic                              s_axi_rlast
   , output logic [1:0]                        s_axi_rresp

   //======================== Outgoing Memory ========================
   , input                                     m01_axi_aclk
   , input                                     m01_axi_aresetn
   , output logic [M01_AXI_ADDR_WIDTH-1:0]     m01_axi_awaddr
   , output logic                              m01_axi_awvalid
   , input                                     m01_axi_awready
   , output logic [M01_AXI_ID_WIDTH-1:0]       m01_axi_awid
   , output logic                              m01_axi_awlock
   , output logic [3:0]                        m01_axi_awcache
   , output logic [2:0]                        m01_axi_awprot
   , output logic [7:0]                        m01_axi_awlen
   , output logic [2:0]                        m01_axi_awsize
   , output logic [1:0]                        m01_axi_awburst
   , output logic [3:0]                        m01_axi_awqos
   , output logic [3:0]                        m01_axi_awregion

   , output logic [M01_AXI_DATA_WIDTH-1:0]     m01_axi_wdata
   , output logic                              m01_axi_wvalid
   , input                                     m01_axi_wready
   , output logic                              m01_axi_wlast
   , output logic [(M01_AXI_DATA_WIDTH/8)-1:0] m01_axi_wstrb

   , input                                     m01_axi_bvalid
   , output logic                              m01_axi_bready
   , input [M01_AXI_ID_WIDTH-1:0]              m01_axi_bid
   , input [1:0]                               m01_axi_bresp

   , output logic [M01_AXI_ADDR_WIDTH-1:0]     m01_axi_araddr
   , output logic                              m01_axi_arvalid
   , input                                     m01_axi_arready
   , output logic [M01_AXI_ID_WIDTH-1:0]       m01_axi_arid
   , output logic                              m01_axi_arlock
   , output logic [3:0]                        m01_axi_arcache
   , output logic [2:0]                        m01_axi_arprot
   , output logic [7:0]                        m01_axi_arlen
   , output logic [2:0]                        m01_axi_arsize
   , output logic [1:0]                        m01_axi_arburst
   , output logic [3:0]                        m01_axi_arqos
   , output logic [3:0]                        m01_axi_arregion

   , input [M01_AXI_DATA_WIDTH-1:0]            m01_axi_rdata
   , input                                     m01_axi_rvalid
   , output logic                              m01_axi_rready
   , input [M01_AXI_ID_WIDTH-1:0]              m01_axi_rid
   , input                                     m01_axi_rlast
   , input [1:0]                               m01_axi_rresp
   );

  wire reset = ~s_axi_aresetn;
  wire clk = s_axi_aclk;
  wire rt_clk = s_axi_aclk;

  wire [15:0] did = 16'(DID);
  wire [15:0] host_did = 16'(HOST_DID);

`ifndef SIMULATION
  localparam bp_params_e bp_params_p = e_bp_default_cfg;
`endif

  logic [M01_AXI_ADDR_WIDTH-1:0] mem_axi_araddr;
  logic [M01_AXI_ADDR_WIDTH-1:0] mem_axi_awaddr;

  bp_axi4_top
    #(.bp_params_p(bp_params_p)
     ,.m_axi_addr_width_p(M_AXI_ADDR_WIDTH)
     ,.m_axi_data_width_p(M_AXI_DATA_WIDTH)
     ,.m_axi_id_width_p(M_AXI_ID_WIDTH)
     ,.s_axi_addr_width_p(S_AXI_ADDR_WIDTH)
     ,.s_axi_data_width_p(S_AXI_DATA_WIDTH)
     ,.s_axi_id_width_p(S_AXI_ID_WIDTH)
     ,.m01_axi_addr_width_p(M01_AXI_ADDR_WIDTH)
     ,.m01_axi_data_width_p(M01_AXI_DATA_WIDTH)
     ,.m01_axi_id_width_p(M01_AXI_ID_WIDTH)
     )
    blackparrot
    (.clk_i(clk)
     ,.reset_i(reset)
     ,.rt_clk_i(rt_clk)
     ,.my_did_i(did)
     ,.host_did_i(host_did)
     ,.m_axi_awaddr_o(m_axi_awaddr)
     ,.m_axi_awvalid_o(m_axi_awvalid)
     ,.m_axi_awready_i(m_axi_awready)
     ,.m_axi_awid_o(m_axi_awid)
     ,.m_axi_awlock_o(m_axi_awlock)
     ,.m_axi_awcache_o(m_axi_awcache)
     ,.m_axi_awprot_o(m_axi_awprot)
     ,.m_axi_awlen_o(m_axi_awlen)
     ,.m_axi_awsize_o(m_axi_awsize)
     ,.m_axi_awburst_o(m_axi_awburst)
     ,.m_axi_awqos_o(m_axi_awqos)
     ,.m_axi_awregion_o(m_axi_awregion)
     ,.m_axi_wdata_o(m_axi_wdata)
     ,.m_axi_wvalid_o(m_axi_wvalid)
     ,.m_axi_wready_i(m_axi_wready)
     ,.m_axi_wlast_o(m_axi_wlast)
     ,.m_axi_wstrb_o(m_axi_wstrb)
     ,.m_axi_bvalid_i(m_axi_bvalid)
     ,.m_axi_bready_o(m_axi_bready)
     ,.m_axi_bid_i(m_axi_bid)
     ,.m_axi_bresp_i(m_axi_bresp)
     ,.m_axi_araddr_o(m_axi_araddr)
     ,.m_axi_arvalid_o(m_axi_arvalid)
     ,.m_axi_arready_i(m_axi_arready)
     ,.m_axi_arid_o(m_axi_arid)
     ,.m_axi_arlock_o(m_axi_arlock)
     ,.m_axi_arcache_o(m_axi_arcache)
     ,.m_axi_arprot_o(m_axi_arprot)
     ,.m_axi_arlen_o(m_axi_arlen)
     ,.m_axi_arsize_o(m_axi_arsize)
     ,.m_axi_arburst_o(m_axi_arburst)
     ,.m_axi_arqos_o(m_axi_arqos)
     ,.m_axi_arregion_o(m_axi_arregion)
     ,.m_axi_rdata_i(m_axi_rdata)
     ,.m_axi_rvalid_i(m_axi_rvalid)
     ,.m_axi_rready_o(m_axi_rready)
     ,.m_axi_rid_i(m_axi_rid)
     ,.m_axi_rlast_i(m_axi_rlast)
     ,.m_axi_rresp_i(m_axi_rresp)
     ,.s_axi_awaddr_i(s_axi_awaddr)
     ,.s_axi_awvalid_i(s_axi_awvalid)
     ,.s_axi_awready_o(s_axi_awready)
     ,.s_axi_awid_i(s_axi_awid)
     ,.s_axi_awlock_i(s_axi_awlock)
     ,.s_axi_awcache_i(s_axi_awcache)
     ,.s_axi_awprot_i(s_axi_awprot)
     ,.s_axi_awlen_i(s_axi_awlen)
     ,.s_axi_awsize_i(s_axi_awsize)
     ,.s_axi_awburst_i(s_axi_awburst)
     ,.s_axi_awqos_i(s_axi_awqos)
     ,.s_axi_awregion_i(s_axi_awregion)
     ,.s_axi_wdata_i(s_axi_wdata)
     ,.s_axi_wvalid_i(s_axi_wvalid)
     ,.s_axi_wready_o(s_axi_wready)
     ,.s_axi_wlast_i(s_axi_wlast)
     ,.s_axi_wstrb_i(s_axi_wstrb)
     ,.s_axi_bvalid_o(s_axi_bvalid)
     ,.s_axi_bready_i(s_axi_bready)
     ,.s_axi_bid_o(s_axi_bid)
     ,.s_axi_bresp_o(s_axi_bresp)
     ,.s_axi_araddr_i(s_axi_araddr)
     ,.s_axi_arvalid_i(s_axi_arvalid)
     ,.s_axi_arready_o(s_axi_arready)
     ,.s_axi_arid_i(s_axi_arid)
     ,.s_axi_arlock_i(s_axi_arlock)
     ,.s_axi_arcache_i(s_axi_arcache)
     ,.s_axi_arprot_i(s_axi_arprot)
     ,.s_axi_arlen_i(s_axi_arlen)
     ,.s_axi_arsize_i(s_axi_arsize)
     ,.s_axi_arburst_i(s_axi_arburst)
     ,.s_axi_arqos_i(s_axi_arqos)
     ,.s_axi_arregion_i(s_axi_arregion)
     ,.s_axi_rdata_o(s_axi_rdata)
     ,.s_axi_rvalid_o(s_axi_rvalid)
     ,.s_axi_rready_i(s_axi_rready)
     ,.s_axi_rid_o(s_axi_rid)
     ,.s_axi_rlast_o(s_axi_rlast)
     ,.s_axi_rresp_o(s_axi_rresp)
     ,.m01_axi_awaddr_o(mem_axi_awaddr)
     ,.m01_axi_awvalid_o(m01_axi_awvalid)
     ,.m01_axi_awready_i(m01_axi_awready)
     ,.m01_axi_awid_o(m01_axi_awid)
     ,.m01_axi_awlock_o(m01_axi_awlock)
     ,.m01_axi_awcache_o(m01_axi_awcache)
     ,.m01_axi_awprot_o(m01_axi_awprot)
     ,.m01_axi_awlen_o(m01_axi_awlen)
     ,.m01_axi_awsize_o(m01_axi_awsize)
     ,.m01_axi_awburst_o(m01_axi_awburst)
     ,.m01_axi_awqos_o(m01_axi_awqos)
     ,.m01_axi_awregion_o(m01_axi_awregion)
     ,.m01_axi_wdata_o(m01_axi_wdata)
     ,.m01_axi_wvalid_o(m01_axi_wvalid)
     ,.m01_axi_wready_i(m01_axi_wready)
     ,.m01_axi_wlast_o(m01_axi_wlast)
     ,.m01_axi_wstrb_o(m01_axi_wstrb)
     ,.m01_axi_bvalid_i(m01_axi_bvalid)
     ,.m01_axi_bready_o(m01_axi_bready)
     ,.m01_axi_bid_i(m01_axi_bid)
     ,.m01_axi_bresp_i(m01_axi_bresp)
     ,.m01_axi_araddr_o(mem_axi_araddr)
     ,.m01_axi_arvalid_o(m01_axi_arvalid)
     ,.m01_axi_arready_i(m01_axi_arready)
     ,.m01_axi_arid_o(m01_axi_arid)
     ,.m01_axi_arlock_o(m01_axi_arlock)
     ,.m01_axi_arcache_o(m01_axi_arcache)
     ,.m01_axi_arprot_o(m01_axi_arprot)
     ,.m01_axi_arlen_o(m01_axi_arlen)
     ,.m01_axi_arsize_o(m01_axi_arsize)
     ,.m01_axi_arburst_o(m01_axi_arburst)
     ,.m01_axi_arqos_o(m01_axi_arqos)
     ,.m01_axi_arregion_o(m01_axi_arregion)
     ,.m01_axi_rdata_i(m01_axi_rdata)
     ,.m01_axi_rvalid_i(m01_axi_rvalid)
     ,.m01_axi_rready_o(m01_axi_rready)
     ,.m01_axi_rid_i(m01_axi_rid)
     ,.m01_axi_rlast_i(m01_axi_rlast)
     ,.m01_axi_rresp_i(m01_axi_rresp)
     );

  assign m01_axi_araddr = mem_axi_araddr - DRAM_BASE_ADDR;
  assign m01_axi_awaddr = mem_axi_awaddr - DRAM_BASE_ADDR;

endmodule

