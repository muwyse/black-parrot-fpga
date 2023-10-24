/*
 * Name:
 *  blackparrot_fpga_host_mmio.sv
 *
 * Description:
 *   This module provides a CSR-based host for BlackParrot in an FPGA. It connects to
 *   BlackParrot's I/O out port and provides FIFO in and out interfaces for MMIO.
 *
 * Constraints:
 *   Incoming I/O (s_axi_*) transactions must be no larger than 64-bits in a single
 *   transfer and the address must be naturally aligned to the request size. The I/O
 *   converters do not check or enforce this condition, the sender must guarantee it.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module blackparrot_fpga_host
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_axi_pkg::*;
 #(parameter S_AXI_ADDR_WIDTH = 64 // must be 64
   , parameter S_AXI_DATA_WIDTH = 64 // must be 64
   , parameter S_AXI_ID_WIDTH = 4

   , parameter fifo_data_width_p = 32 // must be 32 or 64

   , parameter BP_MMIO_ELS = 64
   )
   (//======================== BlackParrot I/O Out to Host ========================
   input                                       s_axi_aclk
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

   //======================== Host CSR FIFOs ========================
   // MMIO Request from BP to Host
   , output logic                              mmio_v_o
   , output logic [fifo_data_width_p-1:0]      mmio_data_o
   , input                                     mmio_yumi_i
   // MMIO Request Count
   , output logic [fifo_data_width_p-1:0]      mmio_data_count_o
   // MMIO Response from Host to BP
   // Requests to read-only addresses return data on this interface
   // 32b data returned per read request
   , input                                     mmio_v_i
   , input [fifo_data_width_p-1:0]             mmio_data_i
   , output logic                              mmio_ready_and_o
   );

  wire reset = ~s_axi_aresetn;
  wire clk = s_axi_aclk;

  // BP MMIO Response Buffer
  // Host software enqueues
  logic mmio_resp_v_lo, mmio_resp_yumi_li;
  logic [fifo_data_width_p-1:0] mmio_resp_data_lo;
  bsg_fifo_1r1w_small
    #(.width_p(fifo_data_width_p), .els_p(BP_MMIO_ELS))
    mmio_response_buffer
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(mmio_v_i)
      ,.data_i(mmio_data_i)
      ,.ready_o(mmio_ready_and_o)
      ,.v_o(mmio_resp_v_lo)
      ,.data_o(mmio_resp_data_lo)
      ,.yumi_i(mmio_resp_yumi_li)
      );

  // BP MMIO Request Buffer
  // FSM enqueues address then data to this FIFO, which is read by Host software
  logic mmio_req_v_li, mmio_req_ready_and_lo;
  logic [fifo_data_width_p-1:0] mmio_req_data_li;
  bsg_fifo_1r1w_small
    #(.width_p(fifo_data_width_p), .els_p(BP_MMIO_ELS))
    mmio_request_buffer
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(mmio_req_v_li)
      ,.data_i(mmio_req_data_li)
      ,.ready_o(mmio_req_ready_and_lo)
      ,.v_o(mmio_v_o)
      ,.data_o(mmio_data_o)
      ,.yumi_i(mmio_yumi_i)
      );

  // BP I/O Out Buffer Counter
  logic [`BSG_WIDTH(BP_MMIO_ELS)-1:0] mmio_data_count_lo;
  assign mmio_data_count_o = fifo_data_width_p'(mmio_data_count_lo);
  bsg_counter_up_down
    #(.max_val_p(BP_MMIO_ELS)
      ,.init_val_p(0)
      ,.max_step_p(1)
      )
    mmio_request_counter
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.up_i(mmio_req_v_li & mmio_req_ready_and_lo)
      ,.down_i(mmio_yumi_i)
      ,.count_o(mmio_data_count_lo);

  // BlackParrot I/O Out AXI to FIFO (BP MMIO Requests)
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
      );

  // MMIO FSM
  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
    end
  end

  always_comb begin
  end

endmodule

