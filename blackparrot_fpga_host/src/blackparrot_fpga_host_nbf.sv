/*
 * Name:
 *  blackparrot_fpga_host_nbf.sv
 *
 * Description:
 *  This module deserializes NBF commands arriving on the fifo interface and
 *  generates AXI read and write transactions to BP.
 *
 * Constraints:
 *  - only supports NBF writes of 4 or 8 bytes, Fence, and Finish
 *  - NBF address and data width must both be 64b
 *
 */

`include "bsg_defines.v"

module blackparrot_fpga_host_nbf
 #(parameter M_AXI_ADDR_WIDTH = 64 // must be 64
   , parameter M_AXI_DATA_WIDTH = 64 // must be 64
   , parameter M_AXI_ID_WIDTH = 4

   , parameter fifo_data_width_p = 32 // must be 32 or 64

   , parameter nbf_opcode_width_p = 8
   , parameter nbf_addr_width_p = M_AXI_ADDR_WIDTH // must be 64
   , parameter nbf_data_width_p = M_AXI_DATA_WIDTH // must be 64

   , parameter nbf_credits_p = 64
   )
  (//======================== Host to BlackParrot I/O In ========================
   input                                       m_axi_aclk
   , input                                     m_axi_aresetn

   , output logic [M_AXI_ADDR_WIDTH-1:0]       m_axi_awaddr
   , output logic                              m_axi_awvalid
   , input                                     m_axi_awready
   , output logic [M_AXI_ID_WIDTH-1:0]         m_axi_awid
   , output logic                              m_axi_awlock
   , output logic [3:0]                        m_axi_awcache
   , output logic [2:0]                        m_axi_awprot
   , output logic [7:0]                        m_axi_awlen
   , output logic [2:0]                        m_axi_awsize
   , output logic [1:0]                        m_axi_awburst
   , output logic [3:0]                        m_axi_awqos
   , output logic [3:0]                        m_axi_awregion

   , output logic [M_AXI_DATA_WIDTH-1:0]       m_axi_wdata
   , output logic                              m_axi_wvalid
   , input                                     m_axi_wready
   , output logic                              m_axi_wlast
   , output logic [(M_AXI_DATA_WIDTH/8)-1:0]   m_axi_wstrb

   , input                                     m_axi_bvalid
   , output logic                              m_axi_bready
   , input [M_AXI_ID_WIDTH-1:0]                m_axi_bid
   , input [1:0]                               m_axi_bresp

   , output logic [M_AXI_ADDR_WIDTH-1:0]       m_axi_araddr
   , output logic                              m_axi_arvalid
   , input                                     m_axi_arready
   , output logic [M_AXI_ID_WIDTH-1:0]         m_axi_arid
   , output logic                              m_axi_arlock
   , output logic [3:0]                        m_axi_arcache
   , output logic [2:0]                        m_axi_arprot
   , output logic [7:0]                        m_axi_arlen
   , output logic [2:0]                        m_axi_arsize
   , output logic [1:0]                        m_axi_arburst
   , output logic [3:0]                        m_axi_arqos
   , output logic [3:0]                        m_axi_arregion

   , input [M_AXI_DATA_WIDTH-1:0]              m_axi_rdata
   , input                                     m_axi_rvalid
   , output logic                              m_axi_rready
   , input [M_AXI_ID_WIDTH-1:0]                m_axi_rid
   , input                                     m_axi_rlast
   , input [1:0]                               m_axi_rresp

   //======================== NBF via FIFO from Host ========================
   , input                                     nbf_v_i
   , input [fifo_data_width_p-1:0]             nbf_data_i
   , output logic                              nbf_ready_and_o
   );

  wire reset = ~m_axi_aresetn;
  wire clk = m_axi_aclk;

  // M AXI Write credit counter
  logic [`BSG_WIDTH(nbf_credits_p)-1:0] m_axi_write_count;
  wire m_axi_credits_empty = (m_axi_write_count == '0);
  bsg_flow_counter
    #(.els_p(nbf_credits_p))
    m_axi_write_counter
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(m_axi_awvalid)
      ,.ready_i(m_axi_awready)
      ,.yumi_i(m_axi_bvalid & m_axi_bready)
      ,.count_o(m_axi_write_count)
      );

  // NBF SIPO
  localparam nbf_width_lp = nbf_opcode_width_p + nbf_addr_width_p + nbf_data_width_p;
  localparam nbf_flits_lp = `BSG_CDIV(nbf_width_lp, fifo_data_width_p);
  logic nbf_v_lo, nbf_yumi_li;
  logic [(nbf_flits_lp*fifo_data_width_p)-1:0] nbf_lo;

  typedef struct packed {
    logic [nbf_opcode_width_p-1:0] opcode;
    logic [nbf_addr_width_p-1:0]   addr;
    logic [nbf_data_width_p-1:0]   data;
  } bp_nbf_s;
  bp_nbf_s nbf;
  assign nbf = nbf_width_lp'(nbf_lo);

  bsg_serial_in_parallel_out_full
    #(.width_p(fifo_data_width_p)
      ,.els_p(nbf_flits_lp)
      )
    nbf_sipo
     (.clk_i(clk)
      ,.reset_i(reset)
      // from AXIL write channel
      ,.v_i(nbf_v_i)
      ,.ready_o(nbf_ready_and_o)
      ,.data_i(nbf_data_i)
      // to NBF FSM
      ,.data_o(nbf_lo)
      ,.v_o(nbf_v_lo)
      ,.yumi_i(nbf_yumi_li)
      );

  logic [M_AXI_DATA_WIDTH-1:0] m_axi_data;
  logic [M_AXI_ADDR_WIDTH-1:0] m_axi_addr;
  logic m_axi_v, m_axi_ready_and, m_axi_w;
  logic [2:0] m_axi_size;
  logic [(M_AXI_DATA_WIDTH/8)-1:0] m_axi_wmask;

  // BlackParrot FIFO to AXI (BP I/O In)
  bp_me_fifo_to_axi
    #(.m_axi_data_width_p(M_AXI_DATA_WIDTH)
      ,.m_axi_addr_width_p(M_AXI_ADDR_WIDTH)
      ,.m_axi_id_width_p(M_AXI_ID_WIDTH)
      )
    fifo_to_bp
     (.clk_i(clk)
      ,.reset_i(reset)
      // FIFO commands
      ,.data_i(m_axi_data)
      ,.addr_i(m_axi_addr)
      ,.v_i(m_axi_v)
      ,.w_i(m_axi_w)
      ,.wmask_i(m_axi_wmask)
      ,.size_i(m_axi_size)
      ,.ready_and_o(m_axi_ready_and)
      // FIFO read responses - unused because host only issues writes to BP
      ,.data_o(/* unused */)
      ,.v_o(/* unused */)
      ,.ready_and_i(1'b1)
      // M AXI
      ,.m_axi_awaddr_o(m_axi_awaddr)
      ,.m_axi_awvalid_o(m_axi_awvalid)
      ,.m_axi_awready_i(m_axi_awready)
      ,.m_axi_awid_o(m_axi_awid)
      ,.m_axi_awlock_o(m_axi_awlock)
      ,.m_axi_awcache_o(m_axi_awcache)
      ,.m_axi_awprot_o(m_axi_awprot)
      ,.m_axi_awlen_o(m_axi_awlen)
      ,.m_axi_awsize_o(m_axi_awsize)
      ,.m_axi_awburst_o(m_axi_awburst)
      ,.m_axi_awqos_o(m_axi_awqos)
      ,.m_axi_awregion_o(m_axi_awregion)
      ,.m_axi_wdata_o(m_axi_wdata)
      ,.m_axi_wvalid_o(m_axi_wvalid)
      ,.m_axi_wready_i(m_axi_wready)
      ,.m_axi_wlast_o(m_axi_wlast)
      ,.m_axi_wstrb_o(m_axi_wstrb)
      ,.m_axi_bvalid_i(m_axi_bvalid)
      ,.m_axi_bready_o(m_axi_bready)
      ,.m_axi_bid_i(m_axi_bid)
      ,.m_axi_bresp_i(m_axi_bresp)
      ,.m_axi_araddr_o(m_axi_araddr)
      ,.m_axi_arvalid_o(m_axi_arvalid)
      ,.m_axi_arready_i(m_axi_arready)
      ,.m_axi_arid_o(m_axi_arid)
      ,.m_axi_arlock_o(m_axi_arlock)
      ,.m_axi_arcache_o(m_axi_arcache)
      ,.m_axi_arprot_o(m_axi_arprot)
      ,.m_axi_arlen_o(m_axi_arlen)
      ,.m_axi_arsize_o(m_axi_arsize)
      ,.m_axi_arburst_o(m_axi_arburst)
      ,.m_axi_arqos_o(m_axi_arqos)
      ,.m_axi_arregion_o(m_axi_arregion)
      ,.m_axi_rdata_i(m_axi_rdata)
      ,.m_axi_rvalid_i(m_axi_rvalid)
      ,.m_axi_rready_o(m_axi_rready)
      ,.m_axi_rid_i(m_axi_rid)
      ,.m_axi_rlast_i(m_axi_rlast)
      ,.m_axi_rresp_i(m_axi_rresp)
      );

  wire [7:0] nbf_data_idx = {5'b0, nbf.addr[0+:3]} << 3;

  always_comb begin
    m_axi_v = 1'b0;
    m_axi_w = 1'b1;
    m_axi_wmask = '1; // unused by bp_me_fifo_to_axi
    m_axi_data = nbf.data;
    m_axi_addr = nbf.addr;
    m_axi_size = 3'b011;

    nbf_yumi_li = 1'b0;

    case (nbf.opcode)
      // 32b write
      8'h2: begin
        m_axi_v = nbf_v_lo;
        nbf_yumi_li = m_axi_v & m_axi_ready_and;
        m_axi_size = 3'b010;
        m_axi_data = (nbf.addr[0+:3] == 3'b0)
                     ? {nbf.data[0+:32], nbf.data[0+:32]}
                     : {nbf.data[32+:32], nbf.data[32+:32]};
      end
      // 64b write
      8'h3: begin
        m_axi_v = nbf_v_lo;
        nbf_yumi_li = m_axi_v & m_axi_ready_and;
      end
      // Fence and Finish
      // sink after all write responses received
      8'hFE
      ,8'hFF: begin
        nbf_yumi_li = nbf_v_lo & m_axi_credits_empty;
      end
      // sink anything else
      default: begin
        nbf_yumi_li = nbf_v_lo;
      end
    endcase
  end

endmodule

