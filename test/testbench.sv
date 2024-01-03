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
  (output bit reset_i
   );

  export "DPI-C" function get_sim_period;
  function int get_sim_period();
    return (`SIM_CLK_PERIOD);
  endfunction

  // use bit to deal with initial X->0 transition
  bit clk_i;

  bsg_nonsynth_clock_gen
   #(.cycle_time_p(`SIM_CLK_PERIOD))
   clock_gen
    (.o(clk_i));

  bsg_nonsynth_reset_gen
   #(.num_clocks_p(1)
     ,.reset_cycles_lo_p(0)
     ,.reset_cycles_hi_p(20)
     )
   reset_gen
    (.clk_i(clk_i)
     ,.async_reset_o(reset_i)
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

  // mem (bsg_nonsynth_axi_mem)

endmodule
