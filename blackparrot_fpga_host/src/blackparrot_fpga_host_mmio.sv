/*
 * Name:
 *  blackparrot_fpga_host_mmio.sv
 *
 * Description:
 *   This module provides a CSR-based host for BlackParrot in an FPGA. It connects to
 *   BlackParrot's I/O out port and provides FIFO in and out interfaces for MMIO.
 *
 * Constraints:
 *   - FIFO data width must be 32b
 *   - BP I/O requests must be at most 32b in size
 *
 */

`include "bsg_defines.sv"

module blackparrot_fpga_host_mmio
 #(parameter S_AXI_ADDR_WIDTH = 64 // must be 64
   , parameter S_AXI_DATA_WIDTH = 64 // must be 64
   , parameter S_AXI_ID_WIDTH = 4

   , parameter fifo_data_width_p = 32 // must be 32

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
   , output logic                              mmio_data_count_v_o
   , output logic [fifo_data_width_p-1:0]      mmio_data_count_o
   , input                                     mmio_data_count_yumi_i
   // MMIO Response from Host to BP
   // Requests to read-only addresses return data on this interface
   // 32b data returned per read request
   , input                                     mmio_v_i
   , input [fifo_data_width_p-1:0]             mmio_data_i
   , output logic                              mmio_ready_and_o
   );

  wire reset = ~s_axi_aresetn;
  wire clk = s_axi_aclk;

  // BlackParrot I/O Out AXI to FIFO (BP MMIO Requests)
  logic [S_AXI_DATA_WIDTH-1:0] axi_data;
  logic [S_AXI_ADDR_WIDTH-1:0] axi_addr;
  logic axi_v, axi_w, axi_yumi;
  logic [2:0] axi_size;
  logic resp_v, resp_w, resp_ready_and;
  logic [S_AXI_DATA_WIDTH-1:0] resp_data;

  bp_axi_to_fifo
    #(.s_axi_data_width_p(S_AXI_DATA_WIDTH)
      ,.s_axi_addr_width_p(S_AXI_ADDR_WIDTH)
      ,.s_axi_id_width_p(S_AXI_ID_WIDTH)
      )
    bp_to_fifo
     (.clk_i(clk)
      ,.reset_i(reset)
      // to FSM
      ,.data_o(axi_data)
      ,.addr_o(axi_addr)
      ,.v_o(axi_v)
      ,.w_o(axi_w)
      ,.wmask_o(/* unused */)
      ,.size_o(axi_size)
      ,.yumi_i(axi_yumi)
      // response from FSM
      ,.data_i(resp_data)
      ,.v_i(resp_v)
      ,.w_i(resp_w)
      ,.ready_and_o(resp_ready_and)
      // from S_AXI
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
      ,.ready_param_o(mmio_req_ready_and_lo)
      ,.v_o(mmio_v_o)
      ,.data_o(mmio_data_o)
      ,.yumi_i(mmio_yumi_i)
      );

  // BP I/O Out Buffer Counter
  logic [`BSG_WIDTH(BP_MMIO_ELS)-1:0] mmio_data_count_lo;
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
      ,.count_o(mmio_data_count_lo)
      );
  // MMIO data count is a simple register - always valid
  wire unused = &{mmio_data_count_yumi_i};
  assign mmio_data_count_v_o = 1'b1;
  assign mmio_data_count_o = fifo_data_width_p'(mmio_data_count_lo);

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
      ,.ready_param_o(mmio_ready_and_o)
      ,.v_o(mmio_resp_v_lo)
      ,.data_o(mmio_resp_data_lo)
      ,.yumi_i(mmio_resp_yumi_li)
      );

  // MMIO FSM
  typedef enum logic [1:0] {
    e_addr
    ,e_data
    ,e_read_resp
    ,e_write_resp
  } state_e;
  state_e state_r, state_n;

  always_ff @(posedge clk) begin
    if (reset) begin
      state_r <= e_addr;
    end else begin
      state_r <= state_n;
    end
  end

  wire [2:0] axi_byte_offset = axi_addr[0+:3];
  logic [fifo_data_width_p-1:0] selected_data;
  localparam size_width_lp = `BSG_WIDTH((`BSG_SAFE_CLOG2(S_AXI_DATA_WIDTH/8)));
  bsg_bus_pack
    #(.in_width_p(S_AXI_DATA_WIDTH)
      ,.out_width_p(fifo_data_width_p)
      )
    mmio_req_data_picker
     (.data_i(axi_data)
      ,.sel_i(axi_byte_offset)
      ,.size_i(axi_size[0+:size_width_lp])
      ,.data_o(selected_data)
      );

  always_comb begin
    state_n = state_r;
    mmio_req_v_li = 1'b0;
    mmio_req_data_li = '0;
    mmio_resp_yumi_li = 1'b0;
    axi_yumi = 1'b0;
    resp_v = 1'b0;
    resp_w = 1'b0;
    resp_data = {2{mmio_resp_data_lo}};

    case (state_r)
      // send 32b address to BP MMIO Request Buffer
      // do not consume the bp_axi_to_fifo output until data sends
      e_addr: begin
        mmio_req_v_li = axi_v;
        mmio_req_data_li = axi_addr[0+:fifo_data_width_p];
        state_n = (mmio_req_v_li & mmio_req_ready_and_lo) ? e_data : state_r;
      end
      // send 32b data to BP MMIO Request Buffer
      e_data: begin
        mmio_req_v_li = axi_v;
        mmio_req_data_li = selected_data;
        axi_yumi = (mmio_req_v_li & mmio_req_ready_and_lo);
        state_n = (mmio_req_v_li & mmio_req_ready_and_lo)
                  ? axi_w
                    ? e_write_resp
                    : e_read_resp
                  : state_r;
      end
      // for reads, wait for BP MMIO Response Buffer
      e_read_resp: begin
        resp_v = mmio_resp_v_lo;
        mmio_resp_yumi_li = resp_v & resp_ready_and;
        state_n = mmio_resp_yumi_li ? e_addr : state_r;
      end
      // for writes, enqueue a null response
      e_write_resp: begin
        resp_v = 1'b1;
        resp_w = 1'b1;
        resp_data = '0;
        state_n = (resp_v & resp_ready_and) ? e_addr : state_r;
      end
      default: begin
      end
    endcase
  end

endmodule

