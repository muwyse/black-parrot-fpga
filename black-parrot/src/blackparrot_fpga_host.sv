/*
 * Name:
 *  blackparrot_fpga_host.sv
 *
 * Description:
 *   This module provides a CSR-based host for BlackParrot in an FPGA. It connects to
 *   BlackParrot's I/O in and out ports and provides an AXI Subordinate port for the
 *   host to issue commands.
 *
 *   Ordering and flow control of traffic is enforced by
 *   the bp_me_axi_manager|subordinate modules.
 *
 * Constraints:
 *   This wrapper supports 8, 16, 32, and 64-bit AXI I/O operations on AXI interfaces
 *   with 64-bit data channel width. I/O operations to and from BlackParrot are buffered, as
 *   are commands to and from the host.
 *
 *   Incoming I/O (s_axi_*) transactions must be no larger than 64-bits in a single
 *   transfer and the address must be naturally aligned to the request size. The I/O
 *   converters do not check or enforce this condition, the sender must guarantee it.
 *   Outbound I/O (m_axi_*) generates transactions no larger than 64-bits with a single
 *   data transfer using naturally aligned addresses and the INCR burst type.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

// host writes
`define CSR_NBF 'h0
`define CSR_HOST_TO_BP 'h4
// host reads
`define CSR_BP_TO_HOST_CNT 'h8
`define CSR_BP_TO_HOST 'hC

module blackparrot_fpga_host
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

   , parameter S_AXIL_ADDR_WIDTH = 64
   , parameter S_AXIL_DATA_WIDTH = 32

   , parameter nbf_opcode_width_p = 8
   , parameter nbf_addr_width_p = 64
   , parameter nbf_data_width_p = 64
   )
  (//======================== BlackParrot I/O In ========================
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

   //======================== BlackParrot I/O Out ========================
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

   //======================== Host Commands ========================
   , input                                     s_axil_aclk
   , input                                     s_axil_aresetn

   , input [S_AXIL_ADDR_WIDTH-1:0]             s_axil_awaddr
   , input                                     s_axil_awvalid
   , output logic                              s_axil_awready
   , input [2:0]                               s_axil_awprot

   , input [S_AXIL_DATA_WIDTH-1:0]             s_axil_wdata
   , input                                     s_axil_wvalid
   , output logic                              s_axil_wready
   , input [(S_AXIL_DATA_WIDTH/8)-1:0]         s_axil_wstrb

   , output logic                              s_axil_bvalid
   , input                                     s_axil_bready
   , output logic [1:0]                        s_axil_bresp

   , input [S_AXIL_ADDR_WIDTH-1:0]             s_axil_araddr
   , input                                     s_axil_arvalid
   , output logic                              s_axil_arready
   , input [2:0]                               s_axil_arprot

   , output logic [S_AXIL_DATA_WIDTH-1:0]      s_axil_rdata
   , output logic                              s_axil_rvalid
   , input                                     s_axil_rready
   , output logic [1:0]                        s_axil_rresp

   );

  wire reset = ~s_axi_aresetn;
  wire clk = s_axi_aclk;

  // Host AXIL to FIFO
  bsg_axil_fifo_client
    #(.axil_data_width_p(S_AXIL_DATA_WIDTH)
      ,.axil_addr_width_p(S_AXIL_ADDR_WIDTH)
      )
    host_to_fifo
     (.clk_i(clk)
      ,.reset_i(reset)
      // FIFO
      ,.data_o()
      ,.addr_o()
      ,.v_o()
      ,.w_o()
      ,.wmask_o()
      ,.ready_and_i()
      ,.data_i()
      ,.v_i()
      ,.ready_and_o()
      // AXIL
      ,.s_axil_awaddr_i(s_axil_awaddr)
      ,.s_axil_awvalid_i(s_axil_awvalid)
      ,.s_axil_awready_o(s_axil_awready)
      ,.s_axil_awprot_i(s_axil_awprot)
      ,.s_axil_wdata_i(s_axil_wdata)
      ,.s_axil_wvalid_i(s_axil_wvalid)
      ,.s_axil_wready_o(s_axil_wready)
      ,.s_axil_wstrb_i(s_axil_wstrb)
      ,.s_axil_bvalid_o(s_axil_bvalid)
      ,.s_axil_bready_i(s_axil_bready)
      ,.s_axil_bresp_o(s_axil_bresp)
      ,.s_axil_araddr_i(s_axil_araddr)
      ,.s_axil_arvalid_i(s_axil_arvalid)
      ,.s_axil_arready_o(s_axil_arready)
      ,.s_axil_arprot_i(s_axil_arprot)
      ,.s_axil_rdata_o(s_axil_rdata)
      ,.s_axil_rvalid_o(s_axil_rvalid)
      ,.s_axil_rready_i(s_axil_rready)
      ,.s_axil_rresp_o(s_axil_rresp)
      );

  // BlackParrot AXI to FIFO (BP I/O Out)
  bp_me_axi_to_fifo
    #(.s_axi_data_width_p(S_AXI_DATA_WIDTH)
      ,.s_axi_addr_width_p(S_AXI_ADDR_WIDTH)
      ,.s_axi_id_width_p(S_AXI_ID_WIDTH)
      )
    bp_to_fifo
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.data_o
      ,.addr_o
      ,.v_o
      ,.w_o
      ,.wmask_o
      ,.size_o
      ,.ready_and_i
      ,.data_i
      ,.v_i
      ,.w_i
      ,.ready_and_o
      ,.s_axi_awaddr_i(s_axi_awaddr_i)
      ,.s_axi_awvalid_i(s_axi_awvalid_i)
      ,.s_axi_awready_o(s_axi_awready_o)
      ,.s_axi_awid_i(s_axi_awid_i)
      ,.s_axi_awlock_i(s_axi_awlock_i)
      ,.s_axi_awcache_i(s_axi_awcache_i)
      ,.s_axi_awprot_i(s_axi_awprot_i)
      ,.s_axi_awlen_i(s_axi_awlen_i)
      ,.s_axi_awsize_i(s_axi_awsize_i)
      ,.s_axi_awburst_i(s_axi_awburst_i)
      ,.s_axi_awqos_i(s_axi_awqos_i)
      ,.s_axi_awregion_i(s_axi_awregion_i)
      ,.s_axi_wdata_i(s_axi_wdata_i)
      ,.s_axi_wvalid_i(s_axi_wvalid_i)
      ,.s_axi_wready_o(s_axi_wready_o)
      ,.s_axi_wlast_i(s_axi_wlast_i)
      ,.s_axi_wstrb_i(s_axi_wstrb_i)
      ,.s_axi_bvalid_o(s_axi_bvalid_o)
      ,.s_axi_bready_i(s_axi_bready_i)
      ,.s_axi_bid_o(s_axi_bid_o)
      ,.s_axi_bresp_o(s_axi_bresp_o)
      ,.s_axi_araddr_i(s_axi_araddr_i)
      ,.s_axi_arvalid_i(s_axi_arvalid_i)
      ,.s_axi_arready_o(s_axi_arready_o)
      ,.s_axi_arid_i(s_axi_arid_i)
      ,.s_axi_arlock_i(s_axi_arlock_i)
      ,.s_axi_arcache_i(s_axi_arcache_i)
      ,.s_axi_arprot_i(s_axi_arprot_i)
      ,.s_axi_arlen_i(s_axi_arlen_i)
      ,.s_axi_arsize_i(s_axi_arsize_i)
      ,.s_axi_arburst_i(s_axi_arburst_i)
      ,.s_axi_arqos_i(s_axi_arqos_i)
      ,.s_axi_arregion_i(s_axi_arregion_i)
      ,.s_axi_rdata_o(s_axi_rdata_o)
      ,.s_axi_rvalid_o(s_axi_rvalid_o)
      ,.s_axi_rready_i(s_axi_rready_i)
      ,.s_axi_rid_o(s_axi_rid_o)
      ,.s_axi_rlast_o(s_axi_rlast_o)
      ,.s_axi_rresp_o(s_axi_rresp_o)
      );

  // BlackParrot FIFO to AXI (BP I/O In)
  bp_me_fifo_to_axi
    #(.m_axi_data_width_p(M_AXI_DATA_WIDTH)
      ,.m_axi_addr_width_p(M_AXI_ADDR_WIDTH)
      ,.m_axi_id_width_p(M_AXI_ID_WIDTH)
      )
    fifo_to_bp
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.data_i
      ,.addr_i
      ,.v_i
      ,.w_i
      ,.wmask_i
      ,.size_i
      ,.ready_and_o
      ,.data_o
      ,.v_o
      ,.ready_and_i
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
      );

  // BP I/O In Buffer (Host to BP MMIO)
  bsg_fifo_1r1w_small
    #(.width_p(), .els_p())
    mmio_in_buffer
     (.clk_i(clk)
      ,.reset_i(reset)
      );

  // BP I/O Out Buffer (BP to Host MMIO)
  bsg_fifo_1r1w_small
    #(.width_p(), .els_p())
    mmio_out_buffer
     (.clk_i(clk)
      ,.reset_i(reset)
      );

  // NBF SIPO
  localparam nbf_width_lp = nbf_opcode_width_p + nbf_addr_width_p + nbf_data_width_p;
  localparam nbf_flits_lp = `BSG_CDIV(nbf_width_lp, S_AXIL_DATA_WIDTH);
  logic nbf_v_li, nbf_ready_lo;
  logic [S_AXIL_DATA_WIDTH-1:0] nbf_data_li;
  logic nbf_v_lo, nbf_yumi_li;
  logic [(nbf_flits_lp*S_AXIL_DATA_WIDTH)-1:0] nbf_lo;
  bsg_serial_in_parallel_out_full
    #(.width_p(S_AXIL_DATA_WIDTH)
      ,.els_p(nbf_flits_lp)
      )
    nbf_sipo
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(nbf_v_li)
      ,.ready_o(nbf_ready_lo)
      ,.data_i(nbf_data_li)
      ,.data_o(nbf_lo)
      ,.v_o(nbf_v_lo)
      ,.yumi_i(nbf_yumi_li)
      );

  // Host Read FSM
//`define CSR_BP_TO_HOST_CNT 'h8
//`define CSR_BP_TO_HOST 'hC
  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
    end
  end

  always_comb begin
  end

  // NBF FSM
  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
    end
  end

  always_comb begin
  end

  // MMIO FSM
  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
    end
  end

  always_comb begin
  end

endmodule

