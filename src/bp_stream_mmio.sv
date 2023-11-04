/**
 *  bp_stream_mmio.v
 *
 * Converts IO Out requests (reads and writes)
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"


module bp_stream_mmio

  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_me_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)

  ,parameter stream_addr_width_p = 32
  // must be 32
  ,parameter stream_data_width_p = 32
  ,localparam s_axil_addr_width_p = stream_addr_width_p
  ,localparam s_axil_data_width_p = stream_data_width_p
  ,localparam s_axil_mask_width_lp = (s_axil_addr_width_p/8)
  )

  (input  clk_i
  ,input  reset_i

  // I/O from BP
  ,input [s_axil_addr_width_p-1:0]              s_axil_awaddr_i
  ,input [2:0]                                  s_axil_awprot_i
  ,input                                        s_axil_awvalid_i
  ,output logic                                 s_axil_awready_o

  ,input [s_axil_data_width_p-1:0]              s_axil_wdata_i
  ,input [s_axil_mask_width_lp-1:0]             s_axil_wstrb_i
  ,input                                        s_axil_wvalid_i
  ,output logic                                 s_axil_wready_o

  ,output logic [1:0]                           s_axil_bresp_o
  ,output logic                                 s_axil_bvalid_o
  ,input                                        s_axil_bready_i

  ,input [s_axil_addr_width_p-1:0]              s_axil_araddr_i
  ,input [2:0]                                  s_axil_arprot_i
  ,input                                        s_axil_arvalid_i
  ,output logic                                 s_axil_arready_o

  ,output logic [s_axil_data_width_p-1:0]       s_axil_rdata_o
  ,output logic [1:0]                           s_axil_rresp_o
  ,output logic                                 s_axil_rvalid_o
  ,input                                        s_axil_rready_i

  // read data response from PC host, passed to R channel
  ,input                                        stream_v_i
  ,input  [stream_data_width_p-1:0]             stream_data_i
  ,output logic                                 stream_ready_o

  // to PC host from AR and AW/W
  // MMIO from BP that are consumed by reads from PC host
  // every transaction is two beats: address then data
  // writes from BP provide valid data, reads provide invalid data
  ,output logic                                 stream_v_o
  ,output logic [stream_data_width_p-1:0]       stream_data_o
  ,input                                        stream_ready_i
  );

  // AW fifo
  logic awaddr_v_li, awaddr_yumi_lo;
  logic [s_axil_addr_width_p-1:0] awaddr_li;
  bsg_two_fifo
    #(.width_p(s_axil_addr_width_p))
    awaddr_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(s_axil_awaddr_i)
    ,.v_i(s_axil_awvalid_i)
    ,.ready_o(s_axil_awready_o)
    ,.data_o(awaddr_li)
    ,.v_o(awaddr_v_li)
    ,.yumi_i(awaddr_yumi_lo)
    );

  // W fifo
  logic wdata_v_li, wdata_yumi_lo;
  logic [s_axil_data_width_p-1:0] wdata_li;
  logic wready_lo, bready_lo;
  assign s_axil_wready_o = wready_lo & bready_lo;
  bsg_two_fifo
    #(.width_p(s_axil_data_width_p))
    wdata_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(s_axil_wdata_i)
    ,.v_i(s_axil_wvalid_i & bready_lo)
    ,.ready_o(wready_lo)
    ,.data_o(wdata_li)
    ,.v_o(wdata_v_li)
    ,.yumi_i(wdata_yumi_lo)
    );

  // B response fifo
  assign s_axil_bresp_o = 2'b00; // OKAY
  bsg_two_fifo
    #(.width_p(1))
    b_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i('0)
    ,.v_i(s_axil_wvalid_i & wready_lo)
    ,.ready_o(bready_lo)
    ,.data_o()
    ,.v_o(s_axil_bvalid_o)
    ,.yumi_i(s_axil_bvalid_o & s_axil_bready_i)
    );

  // AR fifo
  logic araddr_v_li, araddr_yumi_lo;
  logic [s_axil_addr_width_p-1:0] araddr_li;
  bsg_two_fifo
    #(.width_p(s_axil_addr_width_p))
    araddr_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(s_axil_araddr_i)
    ,.v_i(s_axil_arvalid_i)
    ,.ready_o(s_axil_arready_o)
    ,.data_o(araddr_li)
    ,.v_o(araddr_v_li)
    ,.yumi_i(araddr_yumi_lo)
    );

  // R fifo
  assign s_axil_rresp_o = 2'b00; // OKAY
  bsg_two_fifo
    #(.width_p(s_axil_data_width_p))
    rdata_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(stream_data_i)
    ,.v_i(stream_v_i)
    ,.ready_o(stream_ready_o)
    ,.data_o(s_axil_rdata_o)
    ,.v_o(s_axil_rvalid_o)
    ,.yumi_i(s_axil_rvalid_o & s_axil_rready_i)
    );

  // streaming out fifo
  // cycle 1: address from awaddr_li or araddr_li
  // cycle 2: data from wdata_li for writes or null for reads
  logic out_fifo_v_li, out_fifo_ready_lo;
  logic [stream_data_width_p-1:0] out_fifo_data_li;
  bsg_two_fifo
    #(.width_p(stream_data_width_p))
    out_fifo
    (.clk_i  (clk_i)
    ,.reset_i(reset_i)
    // reads and writes from BP
    ,.data_i (out_fifo_data_li)
    ,.v_i    (out_fifo_v_li)
    ,.ready_o(out_fifo_ready_lo)
    // to buffer for reading by PC host
    ,.data_o (stream_data_o)
    ,.v_o    (stream_v_o)
    ,.yumi_i (stream_v_o & stream_ready_i)
    );

  typedef enum logic [1:0] {
    e_addr
    ,e_write
    ,e_read
  } state_e;
  state_e state_r, state_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_addr;
    end else begin
      state_r <= state_n;
    end
  end

  always_comb begin
    state_n = state_r;

    out_fifo_v_li = 1'b0;
    out_fifo_data_li = '0;
    awaddr_yumi_lo = 1'b0;
    wdata_yumi_lo = 1'b0;
    araddr_yumi_lo = 1'b0;

    case (state_r)
      // send address to stream_*_o fifo
      // writes have priority over reads
      e_addr: begin
        out_fifo_v_li = awaddr_v_li | araddr_v_li;
        out_fifo_data_li = awaddr_v_li ? awaddr_li : araddr_li;

        awaddr_yumi_lo = awaddr_v_li & out_fifo_ready_lo;
        araddr_yumi_lo = ~awaddr_v_li & araddr_v_li & out_fifo_ready_lo;

        state_n = awaddr_yumi_lo
                  ? e_write
                  : araddr_yumi_lo
                    ? e_read
                    : state_r;
      end
      // send write data
      e_write: begin
        out_fifo_v_li = wdata_v_li;
        out_fifo_data_li = wdata_li;
        wdata_yumi_lo = out_fifo_v_li & out_fifo_ready_lo;
        state_n = wdata_yumi_lo ? e_addr : state_r;
      end
      // send null data for read
      e_read: begin
        out_fifo_v_li = 1'b1;
        out_fifo_data_li = '0;
        state_n = out_fifo_ready_lo ? e_addr : state_r;
      end
      default: begin
      end
    endcase
  end

endmodule
