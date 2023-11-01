/*
 * Name:
 *  blackparrot_fpga_host_read_to_fifo.sv
 *
 * Description:
 *  This module muxes fifo interfaces to an AXIL read interface.
 *
 * Constraints:
 *
 */

`include "bsg_defines.v"

module blackparrot_fpga_host_read_to_fifo
 import bsg_axi_pkg::*;
 #(parameter S_AXIL_ADDR_WIDTH = 64
   , parameter S_AXIL_DATA_WIDTH = 32
   , parameter CSR_ELS_P = 1
   , parameter logic [S_AXIL_ADDR_WIDTH-1:0] csr_addr_p [CSR_ELS_P-1:0] = '{0}
   )
  (input                                           s_axil_aclk
   , input                                         s_axil_aresetn

   , input [S_AXIL_ADDR_WIDTH-1:0]                 s_axil_araddr
   , input                                         s_axil_arvalid
   , output logic                                  s_axil_arready
   , input [2:0]                                   s_axil_arprot

   , output logic [S_AXIL_DATA_WIDTH-1:0]          s_axil_rdata
   , output logic                                  s_axil_rvalid
   , input                                         s_axil_rready
   , output logic [1:0]                            s_axil_rresp

   , input [CSR_ELS_P-1:0]                         fifo_v_i
   , output logic [CSR_ELS_P-1:0]                  fifo_yumi_o
   , input [CSR_ELS_P-1:0][S_AXIL_DATA_WIDTH-1:0]  fifo_data_i
   );

  // unused AXIL interface signals
  wire ar_unused = &{s_axil_arprot};

  wire reset = ~s_axil_aresetn;
  wire clk = s_axil_aclk;

  // register the read address
  logic addr_v, addr_yumi;
  logic [S_AXIL_ADDR_WIDTH-1:0] addr;
  bsg_two_fifo
    #(.width_p(S_AXIL_ADDR_WIDTH))
    addr_fifo
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(s_axil_arvalid)
      ,.data_i(s_axil_araddr)
      ,.ready_o(s_axil_arready)
      ,.v_o(addr_v)
      ,.data_o(addr)
      ,.yumi_i(addr_yumi)
      );

  // read response
  // fixed priority arbitration from lo to hi

  // per-CSR request generation
  // pick channel based on CSR address from address fifo
  for (genvar i = 0; i < CSR_ELS_P; i++) begin
    assign csr_req[i] = (addr == csr_addr_p[i]);
  end
  logic [CSR_ELS_P-1:0] csr_req, csr_grant;
  bsg_arb_fixed
    #(.inputs_p(CSR_ELS_P)
      ,.lo_to_hi_p(1)
      )
    fixed_arbiter
     (.ready_i(addr_v)
      ,.reqs_i(csr_req)
      ,.grants_o(csr_grant)
      );
  // valid read with matching address and valid data on input
  wire csr_read_valid = |(csr_grant & fifo_v_i);
  // invalid read detection
  // address is valid but does not match any of the CSR addresses
  wire csr_read_invalid = addr_v & ~(|csr_req);

  // AXIL read response outputs
  assign s_axil_rvalid = csr_read_valid | csr_read_invalid;
  assign s_axil_rresp = e_axi_resp_okay;
  // valid read data from selected CSR fifo else send 0
  bsg_mux_one_hot
    #(.width_p(S_AXIL_DATA_WIDTH)
      ,.els_p(CSR_ELS_P+1)
      )
    fifo_data_mux
     (.data_i({fifo_data_i, S_AXIL_DATA_WIDTH'(1'b0)})
      ,.sel_one_hot_i({csr_grant, csr_read_invalid})
      ,.data_o(s_axil_rdata)
      );

  // consume address fifo and data fifo
  // address consumed when any response sends
  assign addr_yumi = s_axil_rvalid & s_axil_rready;
  // data consumes only for channel selected
  for (genvar i = 0; i < CSR_ELS_P; i++) begin
    assign fifo_yumi_o[i] = fifo_v_i[i] & csr_grant[i] & s_axil_rvalid & s_axil_rready;
  end


endmodule

