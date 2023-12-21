/*
 * Name:
 *  blackparrot_fpga_host_write_to_fifo.sv
 *
 * Description:
 *  This module demuxes an AXIL write interface into fifo interfaces.
 *
 * Constraints:
 *
 */

`include "bsg_defines.sv"

module blackparrot_fpga_host_write_to_fifo
 import bsg_axi_pkg::*;
 #(parameter S_AXIL_ADDR_WIDTH = 64
   , parameter S_AXIL_DATA_WIDTH = 32
   , parameter CSR_ELS_P = 1
   , parameter logic [S_AXIL_ADDR_WIDTH-1:0] csr_addr_p [CSR_ELS_P-1:0] = '{0}
   )
  (input                                       s_axil_aclk
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

   , output logic [CSR_ELS_P-1:0]              fifo_v_o
   , input        [CSR_ELS_P-1:0]              fifo_ready_and_i
   , output logic [S_AXIL_DATA_WIDTH-1:0]      fifo_data_o
   );

  wire reset = ~s_axil_aresetn;
  wire clk = s_axil_aclk;

  // register the write address
  wire aw_unused = &{s_axil_awprot};
  logic addr_v, addr_yumi;
  logic [S_AXIL_ADDR_WIDTH-1:0] addr;
  bsg_two_fifo
    #(.width_p(S_AXIL_ADDR_WIDTH))
    addr_fifo
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(s_axil_awvalid)
      ,.data_i(s_axil_awaddr)
      ,.ready_param_o(s_axil_awready)
      ,.v_o(addr_v)
      ,.data_o(addr)
      ,.yumi_i(addr_yumi)
      );

  // register the write data
  wire w_unused = &{s_axil_wstrb};
  logic data_v, data_yumi;
  logic [S_AXIL_DATA_WIDTH-1:0] data;
  bsg_two_fifo
    #(.width_p(S_AXIL_DATA_WIDTH))
    data_fifo
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(s_axil_wvalid)
      ,.data_i(s_axil_wdata)
      ,.ready_param_o(s_axil_wready)
      ,.v_o(data_v)
      ,.data_o(data)
      ,.yumi_i(data_yumi)
      );

  typedef enum logic {
    e_ready
    ,e_resp
  } state_e;
  state_e state_r, state_n;

  always_ff @(posedge clk) begin
    if (reset) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

  // per-CSR address comparison
  logic [CSR_ELS_P-1:0] csr_match;
  // per-CSR valid: fifo_v_o
  // AXIL transaction matches a defined CSR
  wire csr_send = |(fifo_v_o & fifo_ready_and_i);
  // AXIL transaction does not match any defined CSR
  wire csr_invalid = addr_v & data_v & ~(|fifo_v_o);

  always_comb begin
    state_n = state_r;

    addr_yumi = 1'b0;
    data_yumi = 1'b0;

    s_axil_bvalid = 1'b0;
    s_axil_bresp = e_axi_resp_okay;

    fifo_v_o = '0;
    fifo_data_o = data;

    case (state_r)
      // send data to FIFO
      e_ready: begin
        for (int i = 0; i < CSR_ELS_P; i++) begin
          csr_match[i] = (addr == csr_addr_p[i]);
          fifo_v_o[i] = addr_v & data_v & csr_match[i];
        end
        // sink the transaction when sending on FIFO interface or no CSR match detected
        addr_yumi = csr_send | csr_invalid;
        data_yumi = addr_yumi;
        state_n = addr_yumi
                  ? e_resp
                  : state_r;
      end
      // send the AXIL response
      e_resp: begin
        s_axil_bvalid = 1'b1;
        state_n = s_axil_bready ? e_ready : state_r;
      end
      default: begin
        state_n = state_r;
      end
    endcase
  end

endmodule

