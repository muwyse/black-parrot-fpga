/*
 * Name:
 *  axi4_top.sv
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

module axi4_top
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_axi_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter m_axi_addr_width_p = 64
   , parameter m_axi_data_width_p = 64
   , parameter m_axi_id_width_p = 4
   , localparam m_axi_mask_width_lp = m_axi_data_width_p>>3

   , parameter s_axi_addr_width_p = 64
   , parameter s_axi_data_width_p = 64
   , parameter s_axi_id_width_p = 4
   , localparam s_axi_mask_width_lp = s_axi_data_width_p>>3

   , parameter m01_axi_addr_width_p = 32
   , parameter m01_axi_data_width_p = 64
   , parameter m01_axi_id_width_p = 4
   , localparam m01_axi_mask_width_lp = m01_axi_data_width_p>>3

   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   )
  (// clk and reset are associated with the AXI interfaces (aclk and ~aresetn)
   input                                       clk_i
   , input                                     reset_i
   , input                                     rt_clk_i

   , input [did_width_p-1:0]                   my_did_i
   , input [did_width_p-1:0]                   host_did_i

   //======================== Outgoing I/O ========================
   , output logic [m_axi_addr_width_p-1:0]     m_axi_awaddr_o
   , output logic                              m_axi_awvalid_o
   , input                                     m_axi_awready_i
   , output logic [m_axi_id_width_p-1:0]       m_axi_awid_o
   , output logic                              m_axi_awlock_o
   , output logic [3:0]                        m_axi_awcache_o
   , output logic [2:0]                        m_axi_awprot_o
   , output logic [7:0]                        m_axi_awlen_o
   , output logic [2:0]                        m_axi_awsize_o
   , output logic [1:0]                        m_axi_awburst_o
   , output logic [3:0]                        m_axi_awqos_o
   , output logic [3:0]                        m_axi_awregion_o

   , output logic [m_axi_data_width_p-1:0]     m_axi_wdata_o
   , output logic                              m_axi_wvalid_o
   , input                                     m_axi_wready_i
   , output logic                              m_axi_wlast_o
   , output logic [m_axi_mask_width_lp-1:0]    m_axi_wstrb_o

   , input                                     m_axi_bvalid_i
   , output logic                              m_axi_bready_o
   , input [m_axi_id_width_p-1:0]              m_axi_bid_i
   , input [1:0]                               m_axi_bresp_i

   , output logic [m_axi_addr_width_p-1:0]     m_axi_araddr_o
   , output logic                              m_axi_arvalid_o
   , input                                     m_axi_arready_i
   , output logic [m_axi_id_width_p-1:0]       m_axi_arid_o
   , output logic                              m_axi_arlock_o
   , output logic [3:0]                        m_axi_arcache_o
   , output logic [2:0]                        m_axi_arprot_o
   , output logic [7:0]                        m_axi_arlen_o
   , output logic [2:0]                        m_axi_arsize_o
   , output logic [1:0]                        m_axi_arburst_o
   , output logic [3:0]                        m_axi_arqos_o
   , output logic [3:0]                        m_axi_arregion_o

   , input [m_axi_data_width_p-1:0]            m_axi_rdata_i
   , input                                     m_axi_rvalid_i
   , output logic                              m_axi_rready_o
   , input [m_axi_id_width_p-1:0]              m_axi_rid_i
   , input                                     m_axi_rlast_i
   , input [1:0]                               m_axi_rresp_i

   //======================== Incoming I/O ========================
   , input [s_axi_addr_width_p-1:0]            s_axi_awaddr_i
   , input                                     s_axi_awvalid_i
   , output logic                              s_axi_awready_o
   , input [s_axi_id_width_p-1:0]              s_axi_awid_i
   , input                                     s_axi_awlock_i
   , input [3:0]                               s_axi_awcache_i
   , input [2:0]                               s_axi_awprot_i
   , input [7:0]                               s_axi_awlen_i
   , input [2:0]                               s_axi_awsize_i
   , input [1:0]                               s_axi_awburst_i
   , input [3:0]                               s_axi_awqos_i
   , input [3:0]                               s_axi_awregion_i

   , input [s_axi_data_width_p-1:0]            s_axi_wdata_i
   , input                                     s_axi_wvalid_i
   , output logic                              s_axi_wready_o
   , input                                     s_axi_wlast_i
   , input [s_axi_mask_width_lp-1:0]           s_axi_wstrb_i

   , output logic                              s_axi_bvalid_o
   , input                                     s_axi_bready_i
   , output logic [s_axi_id_width_p-1:0]       s_axi_bid_o
   , output logic [1:0]                        s_axi_bresp_o

   , input [s_axi_addr_width_p-1:0]            s_axi_araddr_i
   , input                                     s_axi_arvalid_i
   , output logic                              s_axi_arready_o
   , input [s_axi_id_width_p-1:0]              s_axi_arid_i
   , input                                     s_axi_arlock_i
   , input [3:0]                               s_axi_arcache_i
   , input [2:0]                               s_axi_arprot_i
   , input [7:0]                               s_axi_arlen_i
   , input [2:0]                               s_axi_arsize_i
   , input [1:0]                               s_axi_arburst_i
   , input [3:0]                               s_axi_arqos_i
   , input [3:0]                               s_axi_arregion_i

   , output logic [s_axi_data_width_p-1:0]     s_axi_rdata_o
   , output logic                              s_axi_rvalid_o
   , input                                     s_axi_rready_i
   , output logic [s_axi_id_width_p-1:0]       s_axi_rid_o
   , output logic                              s_axi_rlast_o
   , output logic [1:0]                        s_axi_rresp_o

   //======================== Outgoing Memory ========================
   , output logic [m01_axi_addr_width_p-1:0]   m01_axi_awaddr_o
   , output logic                              m01_axi_awvalid_o
   , input                                     m01_axi_awready_i
   , output logic [m01_axi_id_width_p-1:0]     m01_axi_awid_o
   , output logic                              m01_axi_awlock_o
   , output logic [3:0]                        m01_axi_awcache_o
   , output logic [2:0]                        m01_axi_awprot_o
   , output logic [7:0]                        m01_axi_awlen_o
   , output logic [2:0]                        m01_axi_awsize_o
   , output logic [1:0]                        m01_axi_awburst_o
   , output logic [3:0]                        m01_axi_awqos_o
   , output logic [3:0]                        m01_axi_awregion_o

   , output logic [m01_axi_data_width_p-1:0]   m01_axi_wdata_o
   , output logic                              m01_axi_wvalid_o
   , input                                     m01_axi_wready_i
   , output logic                              m01_axi_wlast_o
   , output logic [m01_axi_mask_width_lp-1:0]  m01_axi_wstrb_o

   , input                                     m01_axi_bvalid_i
   , output logic                              m01_axi_bready_o
   , input [m01_axi_id_width_p-1:0]            m01_axi_bid_i
   , input [1:0]                               m01_axi_bresp_i

   , output logic [m01_axi_addr_width_p-1:0]   m01_axi_araddr_o
   , output logic                              m01_axi_arvalid_o
   , input                                     m01_axi_arready_i
   , output logic [m01_axi_id_width_p-1:0]     m01_axi_arid_o
   , output logic                              m01_axi_arlock_o
   , output logic [3:0]                        m01_axi_arcache_o
   , output logic [2:0]                        m01_axi_arprot_o
   , output logic [7:0]                        m01_axi_arlen_o
   , output logic [2:0]                        m01_axi_arsize_o
   , output logic [1:0]                        m01_axi_arburst_o
   , output logic [3:0]                        m01_axi_arqos_o
   , output logic [3:0]                        m01_axi_arregion_o

   , input [m01_axi_data_width_p-1:0]          m01_axi_rdata_i
   , input                                     m01_axi_rvalid_i
   , output logic                              m01_axi_rready_o
   , input [m01_axi_id_width_p-1:0]            m01_axi_rid_i
   , input                                     m01_axi_rlast_i
   , input [1:0]                               m01_axi_rresp_i
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
    (.*);

endmodule
