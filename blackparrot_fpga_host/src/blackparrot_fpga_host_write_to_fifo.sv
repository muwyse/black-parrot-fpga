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

`include "bsg_defines.v"

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

  typedef enum logic [1:0] {
    e_ready
    ,e_sink
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

  always_comb begin
    state_n = state_r;

    s_axil_awready = 1'b0;
    s_axil_wready = 1'b0;

    s_axil_bvalid = 1'b0;
    s_axil_bresp = e_axi_resp_okay;

    fifo_v_o = '0;
    fifo_data_o = s_axil_wdata;

    case (state_r)
      // send data to FIFO
      e_ready: begin
        for (int i = 0; i < CSR_ELS_P; i++) begin
          fifo_v_o[i] = s_axil_awvalid & s_axil_wvalid & (s_axil_awaddr == csr_addr_p[i]);
        end
        // sink the AXIL write when fifo handshake occurs or if no fifo_v_o raised, indicating
        // no CSR address matched
        state_n = |(fifo_v_o & fifo_ready_and_i) | ~(|fifo_v_o)
                  ? e_sink
                  : state_r;
      end
      // sink the AXIL write
      e_sink: begin
        s_axil_awready = 1'b1;
        s_axil_wready = 1'b1;
        state_n = e_resp;
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

