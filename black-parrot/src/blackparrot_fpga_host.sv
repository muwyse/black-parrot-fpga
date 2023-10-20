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

   , input [S_AXI_ADDR_WIDTH-1:0]              s_axil_awaddr
   , input                                     s_axil_awvalid
   , output logic                              s_axil_awready
   , input [2:0]                               s_axil_awprot

   , input [S_AXI_DATA_WIDTH-1:0]              s_axil_wdata
   , input                                     s_axil_wvalid
   , output logic                              s_axil_wready
   , input [(S_AXI_DATA_WIDTH/8)-1:0]          s_axil_wstrb

   , output logic                              s_axil_bvalid
   , input                                     s_axil_bready
   , output logic [1:0]                        s_axil_bresp

   , input [S_AXI_ADDR_WIDTH-1:0]              s_axil_araddr
   , input                                     s_axil_arvalid
   , output logic                              s_axil_arready
   , input [2:0]                               s_axil_arprot

   , output logic [S_AXI_DATA_WIDTH-1:0]       s_axil_rdata
   , output logic                              s_axil_rvalid
   , input                                     s_axil_rready
   , output logic [1:0]                        s_axil_rresp

   );

  wire reset = ~s_axi_aresetn;
  wire clk = s_axi_aclk;

  // Host AXIL to FIFO
  bsg_axil_fifo_client
    #()
    host_to_fifo
     (
      );

  // BlackParrot AXI to FIFO (BP I/O Out)
  bp_me_axi_to_fifo
    #()
    bp_to_fifo
     (
      );

  // BlackParrot FIFO to AXI (BP I/O In)
  bp_me_fifo_to_axi
    #()
    fifo_to_bp
     (
      );

  // BP I/O In Buffer (Host to BP MMIO)
  bsg_fifo_1r1w_small
    #(.width_p(), .els_p())
    mmio_in_buffer
     (
      );

  // BP I/O Out Buffer (BP to Host MMIO)
  bsg_fifo_1r1w_small
    #(.width_p(), .els_p())
    mmio_out_buffer
     (
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

  // Host Write FSM
//`define CSR_NBF 'h0
//`define CSR_HOST_TO_BP 'h4
  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
    end
  end

  always_comb begin
  end

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

