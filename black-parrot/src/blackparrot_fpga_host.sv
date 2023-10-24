/*
 * Name:
 *  blackparrot_fpga_host.sv
 *
 * Description:
 *   This module provides a CSR-based host for BlackParrot in an FPGA. It connects to
 *   BlackParrot's I/O in and out ports and provides an AXI Subordinate port for the
 *   host to issue commands.
 *
 *   Ordering and flow control of traffic is enforced by
 *   the bp_me_axi_manager|subordinate modules.
 *
 * Constraints:
 *   This wrapper supports 8, 16, 32, and 64-bit AXI I/O operations on AXI interfaces
 *   with 64-bit data channel width. I/O operations to and from BlackParrot are buffered, as
 *   are commands to and from the host.
 *
 *   Incoming I/O (s_axi_*) transactions must be no larger than 64-bits in a single
 *   transfer and the address must be naturally aligned to the request size. The I/O
 *   converters do not check or enforce this condition, the sender must guarantee it.
 *   Outbound I/O (m_axi_*) generates transactions no larger than 64-bits with a single
 *   data transfer using naturally aligned addresses and the INCR burst type.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

// host writes
`define CSR_NBF 'h0
`define CSR_HOST_TO_BP 'h4
// host reads
`define CSR_BP_TO_HOST_CNT 'h8
`define CSR_BP_TO_HOST 'hC

module blackparrot_fpga_host
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_axi_pkg::*;
 #(parameter M_AXI_ADDR_WIDTH = 64 // must be 64
   , parameter M_AXI_DATA_WIDTH = 64 // must be 64
   , parameter M_AXI_ID_WIDTH = 4

   , parameter S_AXI_ADDR_WIDTH = 64 // must be 64
   , parameter S_AXI_DATA_WIDTH = 64 // must be 64
   , parameter S_AXI_ID_WIDTH = 4

   , parameter S_AXIL_ADDR_WIDTH = 64
   , parameter S_AXIL_DATA_WIDTH = 32 // must be 32

   , parameter BP_MMIO_ELS = 64

   , parameter nbf_opcode_width_p = 8
   , parameter nbf_addr_width_p = 64 // must be 32 or 64
   , parameter nbf_data_width_p = 64 // must be 32 or 64
   )
  (//======================== BlackParrot I/O In ========================
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

   //======================== BlackParrot I/O Out ========================
   , input                                     s_axi_aclk
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

   //======================== Host Commands ========================
   , input                                     s_axil_aclk
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

   , input [S_AXIL_ADDR_WIDTH-1:0]             s_axil_araddr
   , input                                     s_axil_arvalid
   , output logic                              s_axil_arready
   , input [2:0]                               s_axil_arprot

   , output logic [S_AXIL_DATA_WIDTH-1:0]      s_axil_rdata
   , output logic                              s_axil_rvalid
   , input                                     s_axil_rready
   , output logic [1:0]                        s_axil_rresp

   );

  wire reset = ~s_axi_aresetn;
  wire clk = s_axi_aclk;

  // M AXI Write credit counter
  logic [`BSG_WIDTH(NBF_MAX_WRITES)-1:0] m_axi_write_count;
  wire m_axi_credits_empty = (m_axi_write_count == '0);
  bsg_flow_counter
    #(.els_p(NBF_MAX_WRITES))
    m_axi_write_counter
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(m_axi_awvalid)
      ,.ready_i(m_axi_awready)
      ,.yumi_i(m_axi_bvalid & m_axi_bready)
      ,.count_o(m_axi_write_count)
      );

  // BP I/O In Buffer (Host to BP MMIO)
  logic bp_mmio_in_v_li, bp_mmio_in_ready_and_lo, bp_mmio_in_v_lo, bp_mmio_in_yumi_li;
  logic [S_AXIL_DATA_WIDTH-1:0] bp_mmio_in_data_li, bp_mmio_in_data_lo;
  bsg_fifo_1r1w_small
    #(.width_p(), .els_p(BP_MMIO_ELS))
    mmio_in_buffer
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(bp_mmio_in_v_li)
      ,.data_i(bp_mmio_in_data_li)
      ,.ready_o(bp_mmio_in_ready_and_lo)
      ,.v_o(bp_mmio_in_v_lo)
      ,.data_o(bp_mmio_in_data_lo)
      ,.yumi_i(bp_mmio_in_yumi_li)
      );

  // NBF SIPO
  localparam nbf_width_lp = nbf_opcode_width_p + nbf_addr_width_p + nbf_data_width_p;
  localparam nbf_flits_lp = `BSG_CDIV(nbf_width_lp, S_AXIL_DATA_WIDTH);
  logic nbf_v_li, nbf_ready_lo;
  logic [S_AXIL_DATA_WIDTH-1:0] nbf_data_li;
  logic nbf_v_lo, nbf_yumi_li;
  logic [(nbf_flits_lp*S_AXIL_DATA_WIDTH)-1:0] nbf_lo;

  typedef struct packed {
    logic [nbf_opcode_width_p-1:0] opcode;
    logic [nbf_addr_width_p-1:0]   addr;
    logic [nbf_data_width_p-1:0]   data;
  } bp_nbf_s;
  bp_nbf_s nbf;
  assign nbf = nbf_width_lp'(nbf_lo);

  // BP I/O Out Buffer (BP to Host MMIO)
  logic bp_mmio_out_v_li, bp_mmio_out_ready_and_lo, bp_mmio_out_v_lo, bp_mmio_out_yumi_li;
  logic [S_AXIL_DATA_WIDTH-1:0] bp_mmio_out_data_li, bp_mmio_out_data_lo;
  bsg_fifo_1r1w_small
    #(.width_p(), .els_p(BP_MMIO_ELS))
    mmio_out_buffer
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.v_i(bp_mmio_out_v_li)
      ,.data_i(bp_mmio_out_data_li)
      ,.ready_o(bp_mmio_out_ready_and_lo)
      ,.v_o(bp_mmio_out_v_lo)
      ,.data_o(bp_mmio_out_data_lo)
      ,.yumi_i(bp_mmio_out_yumi_li)
      );

  // BP I/O Out Buffer Counter
  logic [`BSG_WIDTH(BP_MMIO_ELS)-1:0] bp_mmio_out_count_lo;
  wire [S_AXIL_DATA_WIDTH-1:0] bp_mmio_out_count = S_AXIL_DATA_WIDTH'(bp_mmio_out_count_lo);
  bsg_counter_up_down
    #(.max_val_p(BP_MMIO_ELS)
      ,.init_val_p(0)
      ,.max_step_p(1)
      )
    mmio_out_buffer_counter
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.up_i(bp_mmio_out_v_li & bp_mmio_out_ready_and_lo)
      ,.down_i(bp_mmio_out_yumi_li)
      ,.count_o(bp_mmio_out_count_lo);

  // connects host to BP MMIO out buffer
  // 'h8: BP MMIO out buffer count
  // 'hC: BP MMIO out buffer data
  localparam bp_mmio_out_cnt_addr_lp = S_AXIL_ADDR_WIDTH'h8;
  localparam bp_mmio_out_addr_lp = S_AXIL_ADDR_WIDTH'hC;
  logic bp_mmio_out_count_yumi;
  blackparrot_fpga_host_read_to_fifo
    #(.S_AXIL_ADDR_WIDTH(S_AXIL_ADDR_WIDTH)
      ,.S_AXIL_DATA_WIDTH(S_AXIL_DATA_WIDTH)
      ,.CSR_ELS_P(2)
      ,.csr_addr_p({bp_mmio_out_addr_lp, bp_mmio_out_cnt_addr_lp})
      )
    axil_read
     (.fifo_v_i({bp_mmio_out_v_lo, 1'b1})
      ,.fifo_yumi_o({bp_mmio_out_yumi_li, bp_mmio_out_count_yumi})
      ,.fifo_data_i({bp_mmio_out_data_lo, bp_mmio_out_count})
      ,.*
      );

  // connects host writes to BP
  // 'h0: NBF SIPO
  // 'h4: BP MMIO in buffer
  localparam nbf_addr_lp = S_AXIL_ADDR_WIDTH'h0;
  localparam bp_mmio_in_addr_lp = S_AXIL_ADDR_WIDTH'h4;
  blackparrot_fpga_host_write_to_fifo
    #(.S_AXIL_ADDR_WIDTH(S_AXIL_ADDR_WIDTH)
      ,.S_AXIL_DATA_WIDTH(S_AXIL_DATA_WIDTH)
      ,.CSR_ELS_P(2)
      ,.csr_addr_p({bp_mmio_in_addr_lp, nbf_addr_lp})
      )
    axil_write
     (.fifo_v_o({bp_mmio_in_v_li, nbf_v_li})
      ,.fifo_ready_and_i({bp_mmio_in_ready_and_lo, nbf_ready_lo})
      ,.fifo_data_o({bp_mmio_in_data_li, nbf_data_li})
      ,.*
      );

  // BlackParrot AXI to FIFO (BP I/O Out)
  bp_me_axi_to_fifo
    #(.s_axi_data_width_p(S_AXI_DATA_WIDTH)
      ,.s_axi_addr_width_p(S_AXI_ADDR_WIDTH)
      ,.s_axi_id_width_p(S_AXI_ID_WIDTH)
      )
    bp_to_fifo
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.data_o
      ,.addr_o
      ,.v_o
      ,.w_o
      ,.wmask_o
      ,.size_o
      ,.ready_and_i
      ,.data_i
      ,.v_i
      ,.w_i
      ,.ready_and_o
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

  // MMIO FSM
  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
    end
  end

  always_comb begin
  end

  // NBF SIPO
  bsg_serial_in_parallel_out_full
    #(.width_p(S_AXIL_DATA_WIDTH)
      ,.els_p(nbf_flits_lp)
      )
    nbf_sipo
     (.clk_i(clk)
      ,.reset_i(reset)
      // from AXIL write channel
      ,.v_i(nbf_v_li)
      ,.ready_o(nbf_ready_lo)
      ,.data_i(nbf_data_li)
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
      ,.v_o*/* unused */)
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

  // NBF FSM
  typedef enum logic [1:0] {
    e_nbf_ready
  } nbf_state_e;
  nbf_state_e nbf_state_r, nbf_state_n;

  always_ff @(posedge clk) begin
    if (reset) begin
      nbf_state_r <= e_nbf_ready;
    end else begin
      nbf_state_r <= nbf_state_n;
    end
  end

  // TODO: use address to pick word
  wire nbf_data_idx = '0;

  always_comb begin
    m_axi_v = 1'b0;
    m_axi_w = 1'b1;
    m_axi_wmask = '1; // unused by bp_me_fifo_to_axi
    m_axi_data = nbf.data;
    m_axi_addr = nbf.opcode;
    m_axi_size = 3'b011;

    nbf_yumi_li = 1'b0;

    case (nbf_state_r)
      e_nbf_ready: begin
        case (nbf.opcode)
          // 32b write
          8'h2: begin
            m_axi_v = nbf_v_lo;
            m_axi_size = 3'b010;
            // TODO: pack 32b data
            m_axi_data = {nbf.data[nbf_data_idx+:32], nbf.data[nbf_data_idx+:32]};
          end
          // 64b write
          8'h3: begin
            m_axi_v = nbf_v_lo;
          end
          // Fence
          8'hFE: begin
            nbf_yumi_li = nbf_v_lo & m_axi_credits_empty;
          end
          // sink Finish
          8'hFF: begin
            nbf_yumi_li = nbf_v_lo;
          end
          // sink anything else
          default: begin
            nbf_yumi_li = nbf_v_lo;
          end
        endcase
      end
      default: begin
      end
    endcase
  end

endmodule

