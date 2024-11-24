/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
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

`include "bsg_defines.sv"

module testbench
  import bp_common_pkg::*;
  #(
    // design parameters
    parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
    `declare_bp_proc_params(bp_params_p)

    // COSIM parameters
    , parameter cosim_p          = 0
    , parameter checkpoint_p     = 0
    , parameter cosim_memsize_p  = 0
    , parameter cosim_instr_p    = 0
    // tracing parameters
    , parameter commit_trace_p   = 0
    , parameter cce_trace_p   = 0
    , parameter lce_trace_p   = 0
    )
  (output bit reset_i
   );

  bp_proc_param_s proc_param;
  assign proc_param = all_cfgs_gp[bp_params_p];

  initial begin
    $display("########### BP Parameter Verification ##############");
    `ifndef VERILATOR
    $display("bp_params_e %s: bp_proc_param_s %p", bp_params_p.name(), proc_param);
    `endif
    if (icache_fill_width_p != 64 || dcache_fill_width_p != 64 || acache_fill_width_p != 64)
      $error("Error: Cache fill widths must be 64b");
    if (bedrock_fill_width_p != 64)
      $error("Error: BedRock fill width must be 64b");
    if (l2_fill_width_p != 64 || l2_data_width_p != 64)
      $error("Error: L2 fill and data widths must be 64b");
    if (bedrock_block_width_p != 512 || l2_block_width_p != 512
        || dcache_block_width_p != 512 || icache_block_width_p != 512 || acache_block_width_p != 512)
      $error("Error: cache block widths must be 512b");
  end

  localparam timeout_p = 100000;

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

  bit cosim_clk_i, cosim_reset_i;
  bsg_nonsynth_clock_gen
   #(.cycle_time_p(`SIM_CLK_PERIOD/5))
   cosim_clk_gen
    (.o(cosim_clk_i));

  bsg_nonsynth_reset_gen
   #(.num_clocks_p(1)
     ,.reset_cycles_lo_p(0)
     ,.reset_cycles_hi_p(10)
     )
   cosim_reset_gen
    (.clk_i(cosim_clk_i)
     ,.async_reset_o(cosim_reset_i)
     );

  `ifndef VERILATOR
    initial
      begin
        $assertoff();
        @(posedge clk_i);
        @(negedge reset_i);
        $asserton();
      end
  `endif

  `ifdef VERILATOR_TRACE
    initial
      begin
        $dumpfile("dump.fst");
        $dumpvars;
      end
  `endif

  // test params
  localparam nbf_filename_p = "prog.nbf";

  localparam M_AXI_ADDR_WIDTH = 64;
  localparam M_AXI_DATA_WIDTH = 64;
  localparam M_AXI_ID_WIDTH = 4;

  localparam S_AXI_ADDR_WIDTH = 64;
  localparam S_AXI_DATA_WIDTH = 64;
  localparam S_AXI_ID_WIDTH = 4;

  localparam M01_AXI_ADDR_WIDTH = 64;
  localparam M01_AXI_DATA_WIDTH = 128;
  localparam M01_AXI_ID_WIDTH = 4;

  localparam S_AXIL_ADDR_WIDTH = 64;
  localparam S_AXIL_DATA_WIDTH = 32;

  localparam DID = 0;
  localparam HOST_DID = 16'hFFFF;

  localparam HOST_MMIO_ELS = 64;

  localparam nbf_opcode_width_p = 8;
  localparam nbf_addr_width_p = 64;
  localparam nbf_data_width_p = 64;

  localparam bootrom_width_p = 64;
  localparam bootrom_els_p = 8192;

  // 512 MiB
  // 2**29 bytes
  localparam MEM_ELS = (2**29)/(M01_AXI_DATA_WIDTH/8);

  //======================== BP to Host I/O ========================
  logic                              m_axi_aclk;
  logic                              m_axi_aresetn;
  logic [M_AXI_ADDR_WIDTH-1:0]       m_axi_awaddr;
  logic                              m_axi_awvalid;
  logic                              m_axi_awready;
  logic [M_AXI_ID_WIDTH-1:0]         m_axi_awid;
  logic                              m_axi_awlock;
  logic [3:0]                        m_axi_awcache;
  logic [2:0]                        m_axi_awprot;
  logic [7:0]                        m_axi_awlen;
  logic [2:0]                        m_axi_awsize;
  logic [1:0]                        m_axi_awburst;
  logic [3:0]                        m_axi_awqos;
  logic [3:0]                        m_axi_awregion;

  logic [M_AXI_DATA_WIDTH-1:0]       m_axi_wdata;
  logic                              m_axi_wvalid;
  logic                              m_axi_wready;
  logic                              m_axi_wlast;
  logic [(M_AXI_DATA_WIDTH/8)-1:0]   m_axi_wstrb;

  logic                              m_axi_bvalid;
  logic                              m_axi_bready;
  logic [M_AXI_ID_WIDTH-1:0]         m_axi_bid;
  logic [1:0]                        m_axi_bresp;

  logic [M_AXI_ADDR_WIDTH-1:0]       m_axi_araddr;
  logic                              m_axi_arvalid;
  logic                              m_axi_arready;
  logic [M_AXI_ID_WIDTH-1:0]         m_axi_arid;
  logic                              m_axi_arlock;
  logic [3:0]                        m_axi_arcache;
  logic [2:0]                        m_axi_arprot;
  logic [7:0]                        m_axi_arlen;
  logic [2:0]                        m_axi_arsize;
  logic [1:0]                        m_axi_arburst;
  logic [3:0]                        m_axi_arqos;
  logic [3:0]                        m_axi_arregion;

  logic [M_AXI_DATA_WIDTH-1:0]       m_axi_rdata;
  logic                              m_axi_rvalid;
  logic                              m_axi_rready;
  logic [M_AXI_ID_WIDTH-1:0]         m_axi_rid;
  logic                              m_axi_rlast;
  logic [1:0]                        m_axi_rresp;

  //======================== Host to BP I/O ========================
  logic                              s_axi_aclk;
  logic                              s_axi_aresetn;
  logic [S_AXI_ADDR_WIDTH-1:0]       s_axi_awaddr;
  logic                              s_axi_awvalid;
  logic                              s_axi_awready;
  logic [S_AXI_ID_WIDTH-1:0]         s_axi_awid;
  logic                              s_axi_awlock;
  logic [3:0]                        s_axi_awcache;
  logic [2:0]                        s_axi_awprot;
  logic [7:0]                        s_axi_awlen;
  logic [2:0]                        s_axi_awsize;
  logic [1:0]                        s_axi_awburst;
  logic [3:0]                        s_axi_awqos;
  logic [3:0]                        s_axi_awregion;

  logic [S_AXI_DATA_WIDTH-1:0]       s_axi_wdata;
  logic                              s_axi_wvalid;
  logic                              s_axi_wready;
  logic                              s_axi_wlast;
  logic [(S_AXI_DATA_WIDTH/8)-1:0]   s_axi_wstrb;

  logic                              s_axi_bvalid;
  logic                              s_axi_bready;
  logic [S_AXI_ID_WIDTH-1:0]         s_axi_bid;
  logic [1:0]                        s_axi_bresp;

  logic [S_AXI_ADDR_WIDTH-1:0]       s_axi_araddr;
  logic                              s_axi_arvalid;
  logic                              s_axi_arready;
  logic [S_AXI_ID_WIDTH-1:0]         s_axi_arid;
  logic                              s_axi_arlock;
  logic [3:0]                        s_axi_arcache;
  logic [2:0]                        s_axi_arprot;
  logic [7:0]                        s_axi_arlen;
  logic [2:0]                        s_axi_arsize;
  logic [1:0]                        s_axi_arburst;
  logic [3:0]                        s_axi_arqos;
  logic [3:0]                        s_axi_arregion;

  logic [S_AXI_DATA_WIDTH-1:0]       s_axi_rdata;
  logic                              s_axi_rvalid;
  logic                              s_axi_rready;
  logic [S_AXI_ID_WIDTH-1:0]         s_axi_rid;
  logic                              s_axi_rlast;
  logic [1:0]                        s_axi_rresp;

  //======================== BP to Memory ========================
  logic                              m01_axi_aclk;
  logic                              m01_axi_aresetn;
  logic [M01_AXI_ADDR_WIDTH-1:0]     m01_axi_awaddr;
  logic                              m01_axi_awvalid;
  logic                              m01_axi_awready;
  logic [M01_AXI_ID_WIDTH-1:0]       m01_axi_awid;
  logic                              m01_axi_awlock;
  logic [3:0]                        m01_axi_awcache;
  logic [2:0]                        m01_axi_awprot;
  logic [7:0]                        m01_axi_awlen;
  logic [2:0]                        m01_axi_awsize;
  logic [1:0]                        m01_axi_awburst;
  logic [3:0]                        m01_axi_awqos;
  logic [3:0]                        m01_axi_awregion;

  logic [M01_AXI_DATA_WIDTH-1:0]     m01_axi_wdata;
  logic                              m01_axi_wvalid;
  logic                              m01_axi_wready;
  logic                              m01_axi_wlast;
  logic [(M01_AXI_DATA_WIDTH/8)-1:0] m01_axi_wstrb;

  logic                              m01_axi_bvalid;
  logic                              m01_axi_bready;
  logic [M01_AXI_ID_WIDTH-1:0]       m01_axi_bid;
  logic [1:0]                        m01_axi_bresp;

  logic [M01_AXI_ADDR_WIDTH-1:0]     m01_axi_araddr;
  logic                              m01_axi_arvalid;
  logic                              m01_axi_arready;
  logic [M01_AXI_ID_WIDTH-1:0]       m01_axi_arid;
  logic                              m01_axi_arlock;
  logic [3:0]                        m01_axi_arcache;
  logic [2:0]                        m01_axi_arprot;
  logic [7:0]                        m01_axi_arlen;
  logic [2:0]                        m01_axi_arsize;
  logic [1:0]                        m01_axi_arburst;
  logic [3:0]                        m01_axi_arqos;
  logic [3:0]                        m01_axi_arregion;

  logic [M01_AXI_DATA_WIDTH-1:0]     m01_axi_rdata;
  logic                              m01_axi_rvalid;
  logic                              m01_axi_rready;
  logic [M01_AXI_ID_WIDTH-1:0]       m01_axi_rid;
  logic                              m01_axi_rlast;
  logic [1:0]                        m01_axi_rresp;

  //======================== Driver to Host ========================
  logic                              s_axil_aclk;
  logic                              s_axil_aresetn;

  logic [S_AXIL_ADDR_WIDTH-1:0]      s_axil_awaddr;
  logic                              s_axil_awvalid;
  logic                              s_axil_awready;
  logic [2:0]                        s_axil_awprot;

  logic [S_AXIL_DATA_WIDTH-1:0]      s_axil_wdata;
  logic                              s_axil_wvalid;
  logic                              s_axil_wready;
  logic [(S_AXIL_DATA_WIDTH/8)-1:0]  s_axil_wstrb;

  logic                              s_axil_bvalid;
  logic                              s_axil_bready;
  logic [1:0]                        s_axil_bresp;

  logic [S_AXIL_ADDR_WIDTH-1:0]      s_axil_araddr;
  logic                              s_axil_arvalid;
  logic                              s_axil_arready;
  logic [2:0]                        s_axil_arprot;

  logic [S_AXIL_DATA_WIDTH-1:0]      s_axil_rdata;
  logic                              s_axil_rvalid;
  logic                              s_axil_rready;
  logic [1:0]                        s_axil_rresp;

  // nbf loader to FPGA host
  logic [S_AXIL_ADDR_WIDTH-1:0]      nbf_s_axil_awaddr;
  logic                              nbf_s_axil_awvalid;
  logic                              nbf_s_axil_awready;
  logic [2:0]                        nbf_s_axil_awprot;

  logic [S_AXIL_DATA_WIDTH-1:0]      nbf_s_axil_wdata;
  logic                              nbf_s_axil_wvalid;
  logic                              nbf_s_axil_wready;
  logic [(S_AXIL_DATA_WIDTH/8)-1:0]  nbf_s_axil_wstrb;

  logic                              nbf_s_axil_bvalid;
  logic                              nbf_s_axil_bready;
  logic [1:0]                        nbf_s_axil_bresp;

  logic [S_AXIL_ADDR_WIDTH-1:0]      nbf_s_axil_araddr;
  logic                              nbf_s_axil_arvalid;
  logic                              nbf_s_axil_arready;
  logic [2:0]                        nbf_s_axil_arprot;

  logic [S_AXIL_DATA_WIDTH-1:0]      nbf_s_axil_rdata;
  logic                              nbf_s_axil_rvalid;
  logic                              nbf_s_axil_rready;
  logic [1:0]                        nbf_s_axil_rresp;

  // axi host to FPGA host
  logic [S_AXIL_ADDR_WIDTH-1:0]      host_s_axil_awaddr;
  logic                              host_s_axil_awvalid;
  logic                              host_s_axil_awready;
  logic [2:0]                        host_s_axil_awprot;

  logic [S_AXIL_DATA_WIDTH-1:0]      host_s_axil_wdata;
  logic                              host_s_axil_wvalid;
  logic                              host_s_axil_wready;
  logic [(S_AXIL_DATA_WIDTH/8)-1:0]  host_s_axil_wstrb;

  logic                              host_s_axil_bvalid;
  logic                              host_s_axil_bready;
  logic [1:0]                        host_s_axil_bresp;

  logic [S_AXIL_ADDR_WIDTH-1:0]      host_s_axil_araddr;
  logic                              host_s_axil_arvalid;
  logic                              host_s_axil_arready;
  logic [2:0]                        host_s_axil_arprot;

  logic [S_AXIL_DATA_WIDTH-1:0]      host_s_axil_rdata;
  logic                              host_s_axil_rvalid;
  logic                              host_s_axil_rready;
  logic [1:0]                        host_s_axil_rresp;

  // clocks and resets
  assign s_axi_aclk = clk_i;
  assign m_axi_aclk = clk_i;
  assign m01_axi_aclk = clk_i;
  assign s_axil_aclk = clk_i;
  assign s_axi_aresetn = ~reset_i;
  assign m_axi_aresetn = ~reset_i;
  assign m01_axi_aresetn = ~reset_i;
  assign s_axil_aresetn = ~reset_i;

  // host
  blackparrot_fpga_host
    #(.M_AXI_ADDR_WIDTH(M_AXI_ADDR_WIDTH)
      ,.M_AXI_DATA_WIDTH(M_AXI_DATA_WIDTH)
      ,.M_AXI_ID_WIDTH(M_AXI_ID_WIDTH)
      ,.S_AXI_ADDR_WIDTH(S_AXI_ADDR_WIDTH)
      ,.S_AXI_DATA_WIDTH(S_AXI_DATA_WIDTH)
      ,.S_AXI_ID_WIDTH(S_AXI_ID_WIDTH)
      ,.S_AXIL_ADDR_WIDTH(S_AXIL_ADDR_WIDTH)
      ,.S_AXIL_DATA_WIDTH(S_AXIL_DATA_WIDTH)
      ,.BP_MMIO_ELS(HOST_MMIO_ELS)
      ,.nbf_opcode_width_p(nbf_opcode_width_p)
      ,.nbf_addr_width_p(nbf_addr_width_p)
      ,.nbf_data_width_p(nbf_data_width_p)
      ,.bootrom_width_p(bootrom_width_p)
      ,.bootrom_els_p(bootrom_els_p)
      )
    fpga_host
    (// Host to BP
     .m_axi_aclk(s_axi_aclk)
     ,.m_axi_aresetn(s_axi_aresetn)
     ,.m_axi_awaddr(s_axi_awaddr)
     ,.m_axi_awvalid(s_axi_awvalid)
     ,.m_axi_awready(s_axi_awready)
     ,.m_axi_awid(s_axi_awid)
     ,.m_axi_awlock(s_axi_awlock)
     ,.m_axi_awcache(s_axi_awcache)
     ,.m_axi_awprot(s_axi_awprot)
     ,.m_axi_awlen(s_axi_awlen)
     ,.m_axi_awsize(s_axi_awsize)
     ,.m_axi_awburst(s_axi_awburst)
     ,.m_axi_awqos(s_axi_awqos)
     ,.m_axi_awregion(s_axi_awregion)
     ,.m_axi_wdata(s_axi_wdata)
     ,.m_axi_wvalid(s_axi_wvalid)
     ,.m_axi_wready(s_axi_wready)
     ,.m_axi_wlast(s_axi_wlast)
     ,.m_axi_wstrb(s_axi_wstrb)
     ,.m_axi_bvalid(s_axi_bvalid)
     ,.m_axi_bready(s_axi_bready)
     ,.m_axi_bid(s_axi_bid)
     ,.m_axi_bresp(s_axi_bresp)
     ,.m_axi_araddr(s_axi_araddr)
     ,.m_axi_arvalid(s_axi_arvalid)
     ,.m_axi_arready(s_axi_arready)
     ,.m_axi_arid(s_axi_arid)
     ,.m_axi_arlock(s_axi_arlock)
     ,.m_axi_arcache(s_axi_arcache)
     ,.m_axi_arprot(s_axi_arprot)
     ,.m_axi_arlen(s_axi_arlen)
     ,.m_axi_arsize(s_axi_arsize)
     ,.m_axi_arburst(s_axi_arburst)
     ,.m_axi_arqos(s_axi_arqos)
     ,.m_axi_arregion(s_axi_arregion)
     ,.m_axi_rdata(s_axi_rdata)
     ,.m_axi_rvalid(s_axi_rvalid)
     ,.m_axi_rready(s_axi_rready)
     ,.m_axi_rid(s_axi_rid)
     ,.m_axi_rlast(s_axi_rlast)
     ,.m_axi_rresp(s_axi_rresp)
     // BP to Host
     ,.s_axi_aclk(m_axi_aclk)
     ,.s_axi_aresetn(m_axi_aresetn)
     ,.s_axi_awaddr(m_axi_awaddr)
     ,.s_axi_awvalid(m_axi_awvalid)
     ,.s_axi_awready(m_axi_awready)
     ,.s_axi_awid(m_axi_awid)
     ,.s_axi_awlock(m_axi_awlock)
     ,.s_axi_awcache(m_axi_awcache)
     ,.s_axi_awprot(m_axi_awprot)
     ,.s_axi_awlen(m_axi_awlen)
     ,.s_axi_awsize(m_axi_awsize)
     ,.s_axi_awburst(m_axi_awburst)
     ,.s_axi_awqos(m_axi_awqos)
     ,.s_axi_awregion(m_axi_awregion)
     ,.s_axi_wdata(m_axi_wdata)
     ,.s_axi_wvalid(m_axi_wvalid)
     ,.s_axi_wready(m_axi_wready)
     ,.s_axi_wlast(m_axi_wlast)
     ,.s_axi_wstrb(m_axi_wstrb)
     ,.s_axi_bvalid(m_axi_bvalid)
     ,.s_axi_bready(m_axi_bready)
     ,.s_axi_bid(m_axi_bid)
     ,.s_axi_bresp(m_axi_bresp)
     ,.s_axi_araddr(m_axi_araddr)
     ,.s_axi_arvalid(m_axi_arvalid)
     ,.s_axi_arready(m_axi_arready)
     ,.s_axi_arid(m_axi_arid)
     ,.s_axi_arlock(m_axi_arlock)
     ,.s_axi_arcache(m_axi_arcache)
     ,.s_axi_arprot(m_axi_arprot)
     ,.s_axi_arlen(m_axi_arlen)
     ,.s_axi_arsize(m_axi_arsize)
     ,.s_axi_arburst(m_axi_arburst)
     ,.s_axi_arqos(m_axi_arqos)
     ,.s_axi_arregion(m_axi_arregion)
     ,.s_axi_rdata(m_axi_rdata)
     ,.s_axi_rvalid(m_axi_rvalid)
     ,.s_axi_rready(m_axi_rready)
     ,.s_axi_rid(m_axi_rid)
     ,.s_axi_rlast(m_axi_rlast)
     ,.s_axi_rresp(m_axi_rresp)
     ,.*
     );

  bp_nonsynth_if_monitor
    #(.timeout_p(timeout_p)
     ,.els_p(5)
     ,.dev_p("m_axi")
     )
    m_axi_timeout
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(1'b1)
     ,.v_i({m_axi_awvalid, m_axi_wvalid, m_axi_bvalid, m_axi_arvalid, m_axi_rvalid})
     ,.ready_and_i({m_axi_awready, m_axi_wready, m_axi_bready, m_axi_arready, m_axi_rready})
     );

  bp_nonsynth_if_monitor
    #(.timeout_p(timeout_p)
     ,.els_p(5)
     ,.dev_p("s_axi")
     )
    s_axi_timeout
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(1'b1)
     ,.v_i({s_axi_awvalid, s_axi_wvalid, s_axi_bvalid, s_axi_arvalid, s_axi_rvalid})
     ,.ready_and_i({s_axi_awready, s_axi_wready, s_axi_bready, s_axi_arready, s_axi_rready})
     );

  // bp
  blackparrot
    #(.M_AXI_ADDR_WIDTH(M_AXI_ADDR_WIDTH)
      ,.M_AXI_DATA_WIDTH(M_AXI_DATA_WIDTH)
      ,.M_AXI_ID_WIDTH(M_AXI_ID_WIDTH)
      ,.S_AXI_ADDR_WIDTH(S_AXI_ADDR_WIDTH)
      ,.S_AXI_DATA_WIDTH(S_AXI_DATA_WIDTH)
      ,.S_AXI_ID_WIDTH(S_AXI_ID_WIDTH)
      ,.M01_AXI_ADDR_WIDTH(M01_AXI_ADDR_WIDTH)
      ,.M01_AXI_DATA_WIDTH(M01_AXI_DATA_WIDTH)
      ,.M01_AXI_ID_WIDTH(M01_AXI_ID_WIDTH)
      ,.DID(DID)
      ,.HOST_DID(HOST_DID)
      ,.bp_params_p(bp_params_p)
      ,.DRAM_BASE_ADDR(dram_base_addr_gp)
      )
    bp
    (.*);

  // mem (bsg_nonsynth_axi_mem)
  bsg_nonsynth_axi_mem
    #(.axi_id_width_p(M01_AXI_ID_WIDTH)
      ,.axi_addr_width_p(M01_AXI_ADDR_WIDTH)
      ,.axi_data_width_p(M01_AXI_DATA_WIDTH)
      ,.axi_len_width_p(8)
      ,.mem_els_p(MEM_ELS)
      // TODO: simulation fails if init_data_p is not 0
      ,.init_data_p(32'h0)
      )
    axi_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.axi_awid_i(m01_axi_awid)
     ,.axi_awaddr_i(m01_axi_awaddr)
     ,.axi_awlen_i(m01_axi_awlen)
     ,.axi_awburst_i(m01_axi_awburst)
     ,.axi_awvalid_i(m01_axi_awvalid)
     ,.axi_awready_o(m01_axi_awready)
     ,.axi_wdata_i(m01_axi_wdata)
     ,.axi_wstrb_i(m01_axi_wstrb)
     ,.axi_wlast_i(m01_axi_wlast)
     ,.axi_wvalid_i(m01_axi_wvalid)
     ,.axi_wready_o(m01_axi_wready)
     ,.axi_bid_o(m01_axi_bid)
     ,.axi_bresp_o(m01_axi_bresp)
     ,.axi_bvalid_o(m01_axi_bvalid)
     ,.axi_bready_i(m01_axi_bready)
     ,.axi_arid_i(m01_axi_arid)
     ,.axi_araddr_i(m01_axi_araddr)
     ,.axi_arlen_i(m01_axi_arlen)
     ,.axi_arburst_i(m01_axi_arburst)
     ,.axi_arvalid_i(m01_axi_arvalid)
     ,.axi_arready_o(m01_axi_arready)
     ,.axi_rid_o(m01_axi_rid)
     ,.axi_rdata_o(m01_axi_rdata)
     ,.axi_rresp_o(m01_axi_rresp)
     ,.axi_rlast_o(m01_axi_rlast)
     ,.axi_rvalid_o(m01_axi_rvalid)
     ,.axi_rready_i(m01_axi_rready)
     );

  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (m01_axi_awvalid & m01_axi_awaddr >= 64'h10000000) begin
        $display("memory write above 256MiB: %x", m01_axi_awaddr);
        $finish();
      end
      if (m01_axi_arvalid & m01_axi_araddr >= 64'h10000000) begin
        $display("memory read above 256MiB: %x", m01_axi_awaddr);
        $finish();
      end
    end
  end


  bp_nonsynth_if_monitor
    #(.timeout_p(timeout_p)
     ,.els_p(5)
     ,.dev_p("m01_axi")
     )
    m01_axi_timeout
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(1'b1)
     ,.v_i({m01_axi_awvalid, m01_axi_wvalid, m01_axi_bvalid, m01_axi_arvalid, m01_axi_rvalid})
     ,.ready_and_i({m01_axi_awready, m01_axi_wready, m01_axi_bready, m01_axi_arready, m01_axi_rready})
     );

  // test driver
  logic loader_done;
  bp_nonsynth_axi_nbf_loader
    #(.M_AXIL_ADDR_WIDTH(S_AXIL_ADDR_WIDTH)
      ,.M_AXIL_DATA_WIDTH(S_AXIL_DATA_WIDTH)
      ,.M_AXIL_CREDITS(64)
      ,.nbf_filename_p(nbf_filename_p)
      ,.nbf_host_addr_p(64'h0)
      ,.timeout_p(timeout_p)
      )
    nbf_loader
    (.m_axil_aclk(s_axil_aclk)
     ,.m_axil_aresetn(s_axil_aresetn)
     // AW/W/B
     ,.m_axil_awaddr(nbf_s_axil_awaddr)
     ,.m_axil_awvalid(nbf_s_axil_awvalid)
     ,.m_axil_awready(nbf_s_axil_awready)
     ,.m_axil_awprot(nbf_s_axil_awprot)
     ,.m_axil_wdata(nbf_s_axil_wdata)
     ,.m_axil_wvalid(nbf_s_axil_wvalid)
     ,.m_axil_wready(nbf_s_axil_wready)
     ,.m_axil_wstrb(nbf_s_axil_wstrb)
     ,.m_axil_bvalid(nbf_s_axil_bvalid)
     ,.m_axil_bready(nbf_s_axil_bready)
     ,.m_axil_bresp(nbf_s_axil_bresp)
     // AR/R
     ,.m_axil_araddr(nbf_s_axil_araddr)
     ,.m_axil_arvalid(nbf_s_axil_arvalid)
     ,.m_axil_arready(nbf_s_axil_arready)
     ,.m_axil_arprot(nbf_s_axil_arprot)
     ,.m_axil_rdata(nbf_s_axil_rdata)
     ,.m_axil_rvalid(nbf_s_axil_rvalid)
     ,.m_axil_rready(nbf_s_axil_rready)
     ,.m_axil_rresp(nbf_s_axil_rresp)
     ,.done_o(loader_done)
     );

  // AXIL watchdog
  logic [`BSG_SAFE_CLOG2(timeout_p+1)-1:0] timeout_r;
  bsg_counter_clear_up
   #(.max_val_p(timeout_p), .init_val_p(0))
   nbf_timeout_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(s_axil_awvalid & s_axil_awready)
     ,.up_i(s_axil_awvalid & ~s_axil_awready)
     ,.count_o(timeout_r)
     );

  // nonsynth test host
  logic host_done;
  bp_nonsynth_axi_host
    #(.M_AXIL_ADDR_WIDTH(S_AXIL_ADDR_WIDTH)
      ,.M_AXIL_DATA_WIDTH(S_AXIL_DATA_WIDTH)
      ,.M_AXIL_CREDITS(64)
      ,.bp_params_p(bp_params_p)
      )
    nonsynth_host
    (.m_axil_aclk(s_axil_aclk)
     ,.m_axil_aresetn(s_axil_aresetn)
     // AW/W/B
     ,.m_axil_awaddr(host_s_axil_awaddr)
     ,.m_axil_awvalid(host_s_axil_awvalid)
     ,.m_axil_awready(host_s_axil_awready)
     ,.m_axil_awprot(host_s_axil_awprot)
     ,.m_axil_wdata(host_s_axil_wdata)
     ,.m_axil_wvalid(host_s_axil_wvalid)
     ,.m_axil_wready(host_s_axil_wready)
     ,.m_axil_wstrb(host_s_axil_wstrb)
     ,.m_axil_bvalid(host_s_axil_bvalid)
     ,.m_axil_bready(host_s_axil_bready)
     ,.m_axil_bresp(host_s_axil_bresp)
     // AR/R
     ,.m_axil_araddr(host_s_axil_araddr)
     ,.m_axil_arvalid(host_s_axil_arvalid)
     ,.m_axil_arready(host_s_axil_arready)
     ,.m_axil_arprot(host_s_axil_arprot)
     ,.m_axil_rdata(host_s_axil_rdata)
     ,.m_axil_rvalid(host_s_axil_rvalid)
     ,.m_axil_rready(host_s_axil_rready)
     ,.m_axil_rresp(host_s_axil_rresp)
     ,.en_i(loader_done)
     ,.done_o(host_done)
     );

  // NBF loader connects to s_axil until loader is done,
  // then host connects
  always_comb begin
    // default to NBF connected until loader done
    // AW
    s_axil_awaddr = nbf_s_axil_awaddr;
    s_axil_awvalid = nbf_s_axil_awvalid;
    s_axil_awprot = nbf_s_axil_awprot;
    nbf_s_axil_awready = s_axil_awready;
    // W
    s_axil_wvalid = nbf_s_axil_wvalid;
    s_axil_wdata = nbf_s_axil_wdata;
    s_axil_wstrb = nbf_s_axil_wstrb;
    nbf_s_axil_wready = s_axil_wready;
    // B
    s_axil_bready = nbf_s_axil_bready;
    nbf_s_axil_bvalid = s_axil_bvalid;
    nbf_s_axil_bresp = s_axil_bresp;
    // AR
    s_axil_araddr = nbf_s_axil_araddr;
    s_axil_arprot = nbf_s_axil_arprot;
    s_axil_arvalid = nbf_s_axil_arvalid;
    nbf_s_axil_arready = s_axil_arready;
    // R
    s_axil_rready = nbf_s_axil_rready;
    nbf_s_axil_rvalid = s_axil_rvalid;
    nbf_s_axil_rdata = s_axil_rdata;
    nbf_s_axil_rresp = s_axil_rresp;

    // connect to host when loader is done
    // defaults for inputs
    host_s_axil_awready = 1'b0;
    host_s_axil_wready = 1'b0;
    host_s_axil_bvalid = 1'b0;
    host_s_axil_bresp = s_axil_bresp;
    host_s_axil_arready = 1'b0;
    host_s_axil_rvalid = 1'b0;
    host_s_axil_rdata = s_axil_rdata;
    host_s_axil_rresp = s_axil_rresp;

    if (loader_done) begin
      // AW
      s_axil_awaddr = host_s_axil_awaddr;
      s_axil_awvalid = host_s_axil_awvalid;
      s_axil_awprot = host_s_axil_awprot;
      host_s_axil_awready = s_axil_awready;
      nbf_s_axil_awready = 1'b0;
      // W
      s_axil_wvalid = host_s_axil_wvalid;
      s_axil_wdata = host_s_axil_wdata;
      s_axil_wstrb = host_s_axil_wstrb;
      host_s_axil_wready = s_axil_wready;
      nbf_s_axil_wready = 1'b0;
      // B
      host_s_axil_bvalid = s_axil_bvalid;
      nbf_s_axil_bvalid = 1'b0;
      s_axil_bready = host_s_axil_bready;
      // AR
      s_axil_araddr = host_s_axil_araddr;
      s_axil_arprot = host_s_axil_arprot;
      s_axil_arvalid = host_s_axil_arvalid;
      host_s_axil_arready = s_axil_arready;
      nbf_s_axil_arready = 1'b0;
      // R
      s_axil_rready = host_s_axil_rready;
      nbf_s_axil_rvalid = 1'b0;
      host_s_axil_rvalid = s_axil_rvalid;
    end
  end

  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (host_done) begin
        $display("finish received by host");
        $finish();
      end
      if (timeout_r == timeout_p) begin
        $display("timeout on loader writes");
        $finish();
      end
    end
  end


  // profiling
  bind bp_be_top
    bp_nonsynth_watchdog
     #(.bp_params_p(bp_params_p)
       ,.stall_cycles_p(100000)
       ,.halt_cycles_p(100000)
       ,.heartbeat_instr_p(100000000)
       )
     watchdog
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)
       ,.wfi_i(director.is_wait)

       ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

       ,.npc_i(calculator.pipe_sys.csr.apc_r)
       ,.instret_i(calculator.commit_pkt_cast_o.instret)
       );

  logic core_profile_en_lo;
  assign core_profile_en_lo = 1'b1;
  bind bp_core_minimal
    bp_nonsynth_core_profiler
     #(.bp_params_p(bp_params_p))
      core_profiler
      (.clk_i(clk_i & testbench.core_profile_en_lo)
      ,.reset_i(reset_i)
      ,.freeze_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

      ,.mhartid_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

      ,.fe_queue_ready_and_i(fe.fe_queue_ready_and_i)

      ,.br_ovr_i(fe.pc_gen.ovr_btaken | fe.pc_gen.ovr_jmp)
      ,.ret_ovr_i(fe.pc_gen.ovr_ret)
      ,.realigner_i(1'b0)

      ,.icache_data_v_i(fe.icache.hit_v_o)
      ,.icache_v_i(fe.icache.v_i)
      ,.icache_yumi_i(fe.icache.yumi_o)

      ,.fe_cmd_nonattaboy_i(be.director.fe_cmd_v_li)
      ,.fe_queue_empty_i(be.scheduler.issue_queue.empty)

      ,.mispredict_i(be.director.npc_mismatch_v)
      ,.dcache_miss_i(be.calculator.pipe_mem.dcache.busy_o)
      ,.control_haz_i(be.detector.control_haz_v)
      ,.data_haz_i(be.detector.data_haz_v)
      ,.aux_dep_i((be.detector.dep_status_r[0].aux_iwb_v
                 | be.detector.dep_status_r[0].aux_fwb_v
                 ) & be.detector.data_haz_v
                )
      ,.load_dep_i((be.detector.dep_status_r[0].emem_iwb_v
                    | be.detector.dep_status_r[0].fmem_iwb_v
                    | be.detector.dep_status_r[1].fmem_iwb_v
                    | be.detector.dep_status_r[0].emem_fwb_v
                    | be.detector.dep_status_r[0].fmem_fwb_v
                    | be.detector.dep_status_r[1].fmem_fwb_v
                    ) & be.detector.data_haz_v
                   )
      ,.mul_dep_i((be.detector.dep_status_r[0].mul_iwb_v
                   | be.detector.dep_status_r[1].mul_iwb_v
                   | be.detector.dep_status_r[2].mul_iwb_v
                   ) & be.detector.data_haz_v
                  )
      ,.fma_dep_i((be.detector.dep_status_r[0].fma_fwb_v
                 | be.detector.dep_status_r[1].fma_fwb_v
                 | be.detector.dep_status_r[2].fma_fwb_v
                 | be.detector.dep_status_r[3].fma_fwb_v
                 ) & be.detector.data_haz_v
                )
      ,.sb_iraw_dep_i((be.detector.irs1_sb_raw_haz_v
                     | be.detector.irs2_sb_raw_haz_v
                     ) & be.detector.data_haz_v
                    )
      ,.sb_fraw_dep_i((be.detector.frs1_sb_raw_haz_v
                     | be.detector.frs2_sb_raw_haz_v
                     | be.detector.frs3_sb_raw_haz_v
                     ) & be.detector.data_haz_v
                    )
      ,.sb_iwaw_dep_i(be.detector.ird_sb_waw_haz_v & be.detector.data_haz_v)
      ,.sb_fwaw_dep_i(be.detector.frd_sb_waw_haz_v & be.detector.data_haz_v)
      ,.struct_haz_i(be.detector.struct_haz_v | be.scheduler.late_wb_yumi_o)
      ,.idiv_haz_i(be.detector.idiv_busy_i & be.detector.issue_pkt_cast_i.decode.pipe_long_v)
      ,.fdiv_haz_i(be.detector.fdiv_busy_i & be.detector.issue_pkt_cast_i.decode.pipe_long_v)
      ,.ptw_busy_i(be.scheduler.ptw_busy_lo)

      ,.retire_pkt_i(be.calculator.pipe_sys.retire_pkt)
      ,.commit_pkt_i(be.calculator.pipe_sys.commit_pkt_cast_o)
      );

  logic dcache_trace_en_lo;
  assign dcache_trace_en_lo = 1'b1;
  bind bp_be_dcache
    bp_be_nonsynth_dcache_tracer
     #(.bp_params_p(bp_params_p)
       ,.assoc_p(assoc_p)
       ,.sets_p(sets_p)
       ,.block_width_p(block_width_p)
       ,.fill_width_p(fill_width_p)
       ,.tag_width_p(tag_width_p)
       ,.id_width_p(id_width_p)
       )
     dcache_tracer
      (.clk_i(clk_i & testbench.dcache_trace_en_lo)
       ,.freeze_i(cfg_bus_cast_i.freeze)
       ,.mhartid_i(cfg_bus_cast_i.core_id)
       ,.*
       );

  wire cosim_en_lo = cosim_p ? 1'b1 : 1'b0;
  wire cmt_trace_en_lo = commit_trace_p ? 1'b1 : 1'b0;
  wire checkpoint_en_lo = checkpoint_p ? 1'b1 : 1'b0;
  bind bp_be_top
    bp_nonsynth_cosim
     #(.bp_params_p(bp_params_p))
     cosim
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

       // We want to pass these values as parameters, but cannot in Verilator 4.025
       // Parameter-resolved constants must not use dotted references
       ,.cosim_en_i(testbench.cosim_en_lo)
       ,.trace_en_i(testbench.cmt_trace_en_lo)
       ,.checkpoint_i(testbench.checkpoint_en_lo)
       ,.num_core_i(testbench.num_core_p)
       ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)
       ,.config_file_i('0) // unused by cosim
       ,.instr_cap_i(testbench.cosim_instr_p)
       ,.memsize_i(testbench.cosim_memsize_p)
       ,.amo_en_i(1'b1) // unused by cosim, now a default
       ,.finish_i(testbench.host_done)

       ,.decode_i(calculator.dispatch_pkt_cast_i.decode)

       ,.is_debug_mode_i(calculator.pipe_sys.csr.is_debug_mode)
       ,.commit_pkt_i(calculator.commit_pkt_cast_o)

       ,.priv_mode_i(calculator.pipe_sys.csr.priv_mode_r)
       ,.mstatus_i(calculator.pipe_sys.csr.mstatus_lo)
       ,.mcause_i(calculator.pipe_sys.csr.mcause_lo)
       ,.scause_i(calculator.pipe_sys.csr.scause_lo)

       ,.ird_w_v_i(scheduler.iwb_pkt_cast_i.ird_w_v)
       ,.ird_addr_i(scheduler.iwb_pkt_cast_i.rd_addr)
       ,.ird_data_i(scheduler.iwb_pkt_cast_i.rd_data)

       ,.frd_w_v_i(scheduler.fwb_pkt_cast_i.frd_w_v)
       ,.frd_addr_i(scheduler.fwb_pkt_cast_i.rd_addr)
       ,.frd_data_i(scheduler.fwb_pkt_cast_i.rd_data)

       ,.cache_req_yumi_i(calculator.pipe_mem.dcache.cache_req_yumi_i)
       ,.cache_req_nonblocking_i(calculator.pipe_mem.dcache.nonblocking_req)
       ,.cache_req_complete_i(calculator.pipe_mem.dcache.complete_recv)

       ,.cosim_clk_i(testbench.cosim_clk_i)
       ,.cosim_reset_i(testbench.cosim_reset_i)
       );

  wire lce_trace_en_lo = lce_trace_p ? 1'b1 : 1'b0;
  wire cce_trace_en_lo = cce_trace_p ? 1'b1 : 1'b0;
  if (cce_type_p != e_cce_uce) begin
    bind bp_cce_wrapper
      bp_me_nonsynth_cce_tracer
       #(.bp_params_p(bp_params_p))
       cce_tracer
        (.clk_i(clk_i & testbench.cce_trace_en_lo)
        ,.reset_i(reset_i)

        ,.cce_id_i(cfg_bus_cast_i.cce_id)

        // LCE-CCE Interface
        // BedRock Burst protocol: ready&valid
        ,.lce_req_header_i(lce_req_header_i)
        ,.lce_req_data_i(lce_req_data_i)
        ,.lce_req_v_i(lce_req_v_i)
        ,.lce_req_ready_and_i(lce_req_ready_and_o)

        ,.lce_cmd_header_i(lce_cmd_header_o)
        ,.lce_cmd_data_i(lce_cmd_data_o)
        ,.lce_cmd_v_i(lce_cmd_v_o)
        ,.lce_cmd_ready_and_i(lce_cmd_ready_and_i)

        ,.lce_resp_header_i(lce_resp_header_i)
        ,.lce_resp_data_i(lce_resp_data_i)
        ,.lce_resp_v_i(lce_resp_v_i)
        ,.lce_resp_ready_and_i(lce_resp_ready_and_o)

        // CCE-MEM Interface
        // BedRock Stream protocol: ready&valid
        ,.mem_rev_header_i(mem_rev_header_i)
        ,.mem_rev_data_i(mem_rev_data_i)
        ,.mem_rev_v_i(mem_rev_v_i)
        ,.mem_rev_ready_and_i(mem_rev_ready_and_o)

        ,.mem_fwd_header_i(mem_fwd_header_o)
        ,.mem_fwd_data_i(mem_fwd_data_o)
        ,.mem_fwd_v_i(mem_fwd_v_o)
        ,.mem_fwd_ready_and_i(mem_fwd_ready_and_i)
        );

    bind bp_lce
      bp_me_nonsynth_lce_tracer
        #(.bp_params_p(bp_params_p)
          ,.sets_p(sets_p)
          ,.assoc_p(assoc_p)
          ,.block_width_p(block_width_p)
          ,.fill_width_p(fill_width_p)
          ,.data_width_p(data_width_p)
          )
        lce_tracer
        (.clk_i(clk_i & testbench.lce_trace_en_lo)
        ,.reset_i(reset_i)

        ,.lce_id_i(lce_id_i)

        ,.lce_req_header_i(lce_req_header_o)
        ,.lce_req_data_i(lce_req_data_o)
        ,.lce_req_v_i(lce_req_v_o)
        ,.lce_req_ready_and_i(lce_req_ready_and_i)

        ,.lce_cmd_header_i(lce_cmd_header_i)
        ,.lce_cmd_data_i(lce_cmd_data_i)
        ,.lce_cmd_v_i(lce_cmd_v_i)
        ,.lce_cmd_ready_and_i(lce_cmd_ready_and_o)

        ,.lce_fill_header_i(lce_fill_header_i)
        ,.lce_fill_data_i(lce_fill_data_i)
        ,.lce_fill_v_i(lce_fill_v_i)
        ,.lce_fill_ready_and_i(lce_fill_ready_and_o)

        ,.lce_fill_o_header_i(lce_fill_header_o)
        ,.lce_fill_o_data_i(lce_fill_data_o)
        ,.lce_fill_o_v_i(lce_fill_v_o)
        ,.lce_fill_o_ready_and_i(lce_fill_ready_and_i)

        ,.lce_resp_header_i(lce_resp_header_o)
        ,.lce_resp_data_i(lce_resp_data_o)
        ,.lce_resp_v_i(lce_resp_v_o)
        ,.lce_resp_ready_and_i(lce_resp_ready_and_i)

        ,.cache_req_last_i(cache_req_last_o)
        );
  end

  wire mem_trace_en_lo = 1'b1;
  bind bsg_nonsynth_axi_mem
    bsg_nonsynth_axi_mem_tracer
      #(.axi_addr_width_p(axi_addr_width_p)
        ,.axi_data_width_p(axi_data_width_p)
        ,.mem_els_p(mem_els_p)
        ,.trace_file_p("mem")
        )
      axi_mem_tracer
      (.clk_i(clk_i & testbench.mem_trace_en_lo)
      ,.reset_i(reset_i)
      ,.wr_v_i(wfifo_yumi_li)
      ,.wr_idx_i(wr_ram_idx)
      ,.wr_data_raw_i(wfifo_data_lo)
      ,.wr_data_i(wfifo_data_lo)
      ,.rd_v_i(axi_rvalid_o & axi_rready_i)
      ,.rd_idx_i(rd_ram_idx)
      ,.rd_data_i(axi_rdata_o)
      );

endmodule
