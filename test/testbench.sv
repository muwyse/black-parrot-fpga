/*
 * Name:
 *   testbench.sv
 *
 * Description:
 *   testbench for BP and BP FPGA Host IP
 *
 */

`ifndef SIM_CLK_PERIOD
`define SIM_CLK_PERIOD 10
`endif

module testbench
  #()
  (input bit clk_i
   ,input bit reset_i
   );

  // define params
  localparam M_AXI_ADDR_WIDTH = 64;
  localparam M_AXI_DATA_WIDTH = 64;
  localparam M_AXI_ID_WIDTH = 4;

  localparam S_AXI_ADDR_WIDTH = 64;
  localparam S_AXI_DATA_WIDTH = 64;
  localparam S_AXI_ID_WIDTH = 4;

  localparam M01_AXI_ADDR_WIDTH = 32;
  localparam M01_AXI_DATA_WIDTH = 64;
  localparam M01_AXI_ID_WIDTH = 4;

  // driver to host

  // host to bp

  // bp to host

  // bp to mem

  // driver

  // host
  blackparrot_fpga_host
    #()
    host
    ();

  // bp
  blackparrot
    #()
    bp
    ();

  // mem

endmodule
