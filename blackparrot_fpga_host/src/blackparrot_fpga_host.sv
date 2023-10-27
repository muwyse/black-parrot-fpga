/*
 * Name:
 *  blackparrot_fpga_host.sv
 *
 * Description:
 *   This module provides a CSR-based host for BlackParrot in an FPGA. It connects to
 *   BlackParrot's I/O in and out ports and provides an AXI Subordinate port for the
 *   host to issue commands. Host software interacts with the FPGA Host using 32b read and
 *   write operations to CSRs. Each CSR is read-only or write-only and has a unique address.
 *
 *   There are four modules within the FPGA Host:
 *   - Write to FIFO: converts S_AXIL Write channel to FIFO CSR interfaces
 *   - Read to FIFO: converts S_AXIL Read channel to FIFO CSR interfaces
 *   - NBF: handles Host to BP communication by parsing serialized NBF packets
 *   - MMIO: handles BP to Host MMIO
 *
 * Constraints:
 *   - All CSRs are 32b
 *   - All CSRs are either read-only or write-only
 *   - Each CSR is made visible through a FIFO interface. Some CSRs are backed by actual FIFOs
 *     but others are simple registers. Simple registers are always valid and always ready for
 *     reading and writing.
 *
 *   Incoming I/O (s_axi_*) transactions must be no larger than 64-bits in a single
 *   transfer and the address must be naturally aligned to the request size. The I/O
 *   converters do not check or enforce this condition, the sender must guarantee it.
 *   Outbound I/O (m_axi_*) generates transactions no larger than 64-bits with a single
 *   data transfer using naturally aligned addresses and the INCR burst type.
 *
 */

`include "bsg_defines.v"

module blackparrot_fpga_host
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

  // connects host to BP MMIO out buffer
  // 'h8: BP MMIO out buffer count
  // 'hC: BP MMIO out buffer data
  localparam [S_AXIL_ADDR_WIDTH-1:0] mmio_req_cnt_addr_lp = S_AXIL_ADDR_WIDTH'('h8);
  localparam [S_AXIL_ADDR_WIDTH-1:0] mmio_req_addr_lp = S_AXIL_ADDR_WIDTH'('hC);
  localparam [S_AXIL_ADDR_WIDTH-1:0] axil_read_csr_lp [1:0] = '{mmio_req_addr_lp, mmio_req_cnt_addr_lp};
  logic mmio_req_v_lo, mmio_req_count_v_lo, mmio_req_yumi_li, mmio_req_count_yumi_li;
  logic [S_AXIL_DATA_WIDTH-1:0] mmio_req_data_lo, mmio_req_count_lo;
  blackparrot_fpga_host_read_to_fifo
    #(.S_AXIL_ADDR_WIDTH(S_AXIL_ADDR_WIDTH)
      ,.S_AXIL_DATA_WIDTH(S_AXIL_DATA_WIDTH)
      ,.CSR_ELS_P(2)
      ,.csr_addr_p(axil_read_csr_lp)
      )
    axil_read
     (.fifo_v_i({mmio_req_v_lo, mmio_req_count_v_lo})
      ,.fifo_yumi_o({mmio_req_yumi_li, mmio_req_count_yumi_li})
      ,.fifo_data_i({mmio_req_data_lo, mmio_req_count_lo})
      ,.*
      );

  // connects host writes to BP
  // 'h0: NBF SIPO
  // 'h4: BP MMIO in buffer
  localparam [S_AXIL_ADDR_WIDTH-1:0] nbf_addr_lp = S_AXIL_ADDR_WIDTH'('h0);
  localparam [S_AXIL_ADDR_WIDTH-1:0] mmio_resp_addr_lp = S_AXIL_ADDR_WIDTH'('h4);
  localparam [S_AXIL_ADDR_WIDTH-1:0] axil_write_csr_lp [1:0] = '{mmio_resp_addr_lp, nbf_addr_lp};
  logic mmio_resp_v_li, mmio_resp_ready_and_lo, nbf_v_li, nbf_ready_and_lo;
  logic [S_AXIL_DATA_WIDTH-1:0] fifo_data_li, mmio_resp_data_li, nbf_data_li;
  blackparrot_fpga_host_write_to_fifo
    #(.S_AXIL_ADDR_WIDTH(S_AXIL_ADDR_WIDTH)
      ,.S_AXIL_DATA_WIDTH(S_AXIL_DATA_WIDTH)
      ,.CSR_ELS_P(2)
      ,.csr_addr_p(axil_write_csr_lp)
      )
    axil_write
     (.fifo_v_o({mmio_resp_v_li, nbf_v_li})
      ,.fifo_ready_and_i({mmio_resp_ready_and_lo, nbf_ready_and_lo})
      ,.fifo_data_o(fifo_data_li)
      ,.*
      );
  assign mmio_resp_data_li = fifo_data_li;
  assign nbf_data_li = fifo_data_li;

  // MMIO
  // consumes S_AXI I/O from BP and makes available via CSRs to Host
  blackparrot_fpga_host_mmio
    #(.S_AXI_ADDR_WIDTH(S_AXI_ADDR_WIDTH)
      ,.S_AXI_DATA_WIDTH(S_AXI_DATA_WIDTH)
      ,.S_AXI_ID_WIDTH(S_AXI_ID_WIDTH)
      ,.fifo_data_width_p(S_AXIL_DATA_WIDTH)
      ,.BP_MMIO_ELS(BP_MMIO_ELS)
      )
    host_mmio
     (.mmio_v_o(mmio_req_v_lo)
      ,.mmio_data_o(mmio_req_data_lo)
      ,.mmio_yumi_i(mmio_req_yumi_li)
      ,.mmio_data_count_v_o(mmio_req_count_v_lo)
      ,.mmio_data_count_o(mmio_req_count_lo)
      ,.mmio_data_count_yumi_i(mmio_req_count_yumi_li)
      ,.mmio_v_i(mmio_resp_v_li)
      ,.mmio_data_i(mmio_resp_data_li)
      ,.mmio_ready_and_o(mmio_resp_ready_and_lo)
      ,.*
      );

  // NBF
  // consumes serialized NBF commands on FIFO and outputs M_AXI transactions to BP
  blackparrot_fpga_host_nbf
    #(.M_AXI_ADDR_WIDTH(M_AXI_ADDR_WIDTH)
      ,.M_AXI_DATA_WIDTH(M_AXI_DATA_WIDTH)
      ,.M_AXI_ID_WIDTH(M_AXI_ID_WIDTH)
      ,.fifo_data_width_p(S_AXIL_DATA_WIDTH)
      ,.nbf_opcode_width_p(nbf_opcode_width_p)
      ,.nbf_addr_width_p(nbf_addr_width_p)
      ,.nbf_data_width_p(nbf_data_width_p)
      )
    host_nbf
     (.nbf_v_i(nbf_v_li)
      ,.nbf_data_i(nbf_data_li)
      ,.nbf_ready_and_o(nbf_ready_and_lo)
      ,.*
      );

endmodule

