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

  // design parameters
  localparam M_AXI_ADDR_WIDTH = 64;
  localparam M_AXI_DATA_WIDTH = 64;
  localparam M_AXI_ID_WIDTH = 4;

  localparam S_AXI_ADDR_WIDTH = 64;
  localparam S_AXI_DATA_WIDTH = 64;
  localparam S_AXI_ID_WIDTH = 4;

  localparam M01_AXI_ADDR_WIDTH = 32;
  localparam M01_AXI_DATA_WIDTH = 64;
  localparam M01_AXI_ID_WIDTH = 4;

  localparam S_AXIL_ADDR_WIDTH = 64;
  localparam S_AXIL_DATA_WIDTH = 32;

  localparam DID = 0;
  localparam HOST_DID = 16'hFFFF;

  localparam HOST_MMIO_ELS = 64;

  localparam nbf_opcode_width_p = 8;
  localparam nbf_addr_width_p = 64;
  localparam nbf_data_width_p = 64;

  // TODO: how big can the ram be?
  // ram size is MEM_ELS * M01_AXI_DATA_WIDTH
  localparam MEM_ELS = 1024;

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
      )
    host
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

  // test driver
  // TODO: drives an m_axil interface to issue commands to fpga host
  // commands conform to fpga host interface
  logic loader_done;
  bp_nonsynth_axi_nbf_loader
    #(.M_AXIL_ADDR_WIDTH(S_AXIL_ADDR_WIDTH)
      ,.M_AXIL_DATA_WIDTH(S_AXIL_DATA_WIDTH)
      ,.M_AXIL_CREDITS(64)
      ,.nbf_filename_p("prog.nbf")
      ,.nbf_host_addr_p(64'h0)
      )
    loader
    (.m_axil_aclk(s_axil_aclk)
     ,.m_axil_aresetn(s_axil_aresetn)
     ,.m_axil_awaddr(s_axil_awaddr)
     ,.m_axil_awvalid(s_axil_awvalid)
     ,.m_axil_awready(s_axil_awready)
     ,.m_axil_awprot(s_axil_awprot)
     ,.m_axil_wdata(s_axil_wdata)
     ,.m_axil_wvalid(s_axil_wvalid)
     ,.m_axil_wready(s_axil_wready)
     ,.m_axil_wstrb(s_axil_wstrb)
     ,.m_axil_bvalid(s_axil_bvalid)
     ,.m_axil_bready(s_axil_bready)
     ,.m_axil_bresp(s_axil_bresp)
     ,.m_axil_araddr(s_axil_araddr)
     ,.m_axil_arvalid(s_axil_arvalid)
     ,.m_axil_arready(s_axil_arready)
     ,.m_axil_arprot(s_axil_arprot)
     ,.m_axil_rdata(s_axil_rdata)
     ,.m_axil_rvalid(s_axil_rvalid)
     ,.m_axil_rready(s_axil_rready)
     ,.m_axil_rresp(s_axil_rresp)
     ,.done_o(loader_done)
     );

endmodule
