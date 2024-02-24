/*
 * Name:
 *  bp_nonsynth_axi_fpga_host.sv
 *
 * Description:
 *   This module instantiates the synthesizable BP FGPA Host alongside an nonsynth bootrom.
 *
 */

`include "bsg_defines.sv"

module bp_nonsynth_axi_fpga_host
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

   , parameter bootrom_els_p = 2048
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

  // AR/R arbitration
  logic                              s_axi_arvalid_host;
  logic                              s_axi_arready_host;

  logic                              s_axi_arvalid_bootrom;
  logic                              s_axi_arready_bootrom;

  logic [S_AXI_DATA_WIDTH-1:0]       s_axi_rdata_host;
  logic                              s_axi_rvalid_host;
  logic                              s_axi_rready_host;
  logic [S_AXI_ID_WIDTH-1:0]         s_axi_rid_host;
  logic                              s_axi_rlast_host;
  logic [1:0]                        s_axi_rresp_host;

  logic [S_AXI_DATA_WIDTH-1:0]       s_axi_rdata_bootrom;
  logic                              s_axi_rvalid_bootrom;
  logic                              s_axi_rready_bootrom;
  logic [S_AXI_ID_WIDTH-1:0]         s_axi_rid_bootrom;
  logic                              s_axi_rlast_bootrom;
  logic [1:0]                        s_axi_rresp_bootrom;

  typedef enum logic [1:0] {
    e_ready
    ,e_host
    ,e_bootrom
  } state_e;
  state_e state_r, state_n;

  always_ff @(posedge s_axi_aclk) begin
    if (~s_axi_aresetn) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

  wire araddr_bootrom = s_axi_araddr >= 'h110000;

  always_comb begin
    s_axi_arvalid_host = 1'b0;
    s_axi_arvalid_bootrom = 1'b0;
    s_axi_arready = 1'b0;

    s_axi_rvalid = 1'b0;
    s_axi_rready_host = 1'b0;
    s_axi_rready_bootrom = 1'b0;

    s_axi_rdata = s_axi_rdata_host;
    s_axi_rid = s_axi_rid_host;
    s_axi_rlast = s_axi_rlast_host;
    s_axi_rresp = s_axi_rresp_host;

    case (state_r)
      e_ready: begin
        s_axi_arready = s_axi_arready_host & s_axi_arready_bootrom;
        s_axi_arvalid_host = s_axi_arvalid & ~araddr_bootrom;
        s_axi_arvalid_bootrom = s_axi_arvalid & araddr_bootrom;
        state_n = (s_axi_arvalid & s_axi_arready)
                  ? araddr_bootrom
                    ? e_bootrom
                    : e_host
                  : state_r;
      end
      e_host: begin
        s_axi_rvalid = s_axi_rvalid_host;
        s_axi_rready_host = s_axi_rready;
        s_axi_rdata = s_axi_rdata_host;
        s_axi_rid   = s_axi_rid_host;
        s_axi_rlast = s_axi_rlast_host;
        s_axi_rresp = s_axi_rresp_host;
        state_n = (s_axi_rvalid & s_axi_rready & s_axi_rlast) ? e_ready : state_r;
      end
      e_bootrom: begin
        s_axi_rvalid = s_axi_rvalid_bootrom;
        s_axi_rready_bootrom = s_axi_rready;
        s_axi_rdata = s_axi_rdata_bootrom;
        s_axi_rid   = s_axi_rid_bootrom;
        s_axi_rlast = s_axi_rlast_bootrom;
        s_axi_rresp = s_axi_rresp_bootrom;
        state_n = (s_axi_rvalid & s_axi_rready & s_axi_rlast) ? e_ready : state_r;
      end
      default: begin
      end
    endcase
  end

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
      ,.BP_MMIO_ELS(BP_MMIO_ELS)
      ,.nbf_opcode_width_p(nbf_opcode_width_p)
      ,.nbf_addr_width_p(nbf_addr_width_p)
      ,.nbf_data_width_p(nbf_data_width_p)
      )
    fpga_host
    (// Host to BP
     .m_axi_aclk(m_axi_aclk)
     ,.m_axi_aresetn(m_axi_aresetn)
     ,.m_axi_awaddr(m_axi_awaddr)
     ,.m_axi_awvalid(m_axi_awvalid)
     ,.m_axi_awready(m_axi_awready)
     ,.m_axi_awid(m_axi_awid)
     ,.m_axi_awlock(m_axi_awlock)
     ,.m_axi_awcache(m_axi_awcache)
     ,.m_axi_awprot(m_axi_awprot)
     ,.m_axi_awlen(m_axi_awlen)
     ,.m_axi_awsize(m_axi_awsize)
     ,.m_axi_awburst(m_axi_awburst)
     ,.m_axi_awqos(m_axi_awqos)
     ,.m_axi_awregion(m_axi_awregion)
     ,.m_axi_wdata(m_axi_wdata)
     ,.m_axi_wvalid(m_axi_wvalid)
     ,.m_axi_wready(m_axi_wready)
     ,.m_axi_wlast(m_axi_wlast)
     ,.m_axi_wstrb(m_axi_wstrb)
     ,.m_axi_bvalid(m_axi_bvalid)
     ,.m_axi_bready(m_axi_bready)
     ,.m_axi_bid(m_axi_bid)
     ,.m_axi_bresp(m_axi_bresp)
     ,.m_axi_araddr(m_axi_araddr)
     ,.m_axi_arvalid(m_axi_arvalid)
     ,.m_axi_arready(m_axi_arready)
     ,.m_axi_arid(m_axi_arid)
     ,.m_axi_arlock(m_axi_arlock)
     ,.m_axi_arcache(m_axi_arcache)
     ,.m_axi_arprot(m_axi_arprot)
     ,.m_axi_arlen(m_axi_arlen)
     ,.m_axi_arsize(m_axi_arsize)
     ,.m_axi_arburst(m_axi_arburst)
     ,.m_axi_arqos(m_axi_arqos)
     ,.m_axi_arregion(m_axi_arregion)
     ,.m_axi_rdata(m_axi_rdata)
     ,.m_axi_rvalid(m_axi_rvalid)
     ,.m_axi_rready(m_axi_rready)
     ,.m_axi_rid(m_axi_rid)
     ,.m_axi_rlast(m_axi_rlast)
     ,.m_axi_rresp(m_axi_rresp)
     // BP to Host
     ,.s_axi_aclk(s_axi_aclk)
     ,.s_axi_aresetn(s_axi_aresetn)
     ,.s_axi_awaddr(s_axi_awaddr)
     ,.s_axi_awvalid(s_axi_awvalid)
     ,.s_axi_awready(s_axi_awready)
     ,.s_axi_awid(s_axi_awid)
     ,.s_axi_awlock(s_axi_awlock)
     ,.s_axi_awcache(s_axi_awcache)
     ,.s_axi_awprot(s_axi_awprot)
     ,.s_axi_awlen(s_axi_awlen)
     ,.s_axi_awsize(s_axi_awsize)
     ,.s_axi_awburst(s_axi_awburst)
     ,.s_axi_awqos(s_axi_awqos)
     ,.s_axi_awregion(s_axi_awregion)
     ,.s_axi_wdata(s_axi_wdata)
     ,.s_axi_wvalid(s_axi_wvalid)
     ,.s_axi_wready(s_axi_wready)
     ,.s_axi_wlast(s_axi_wlast)
     ,.s_axi_wstrb(s_axi_wstrb)
     ,.s_axi_bvalid(s_axi_bvalid)
     ,.s_axi_bready(s_axi_bready)
     ,.s_axi_bid(s_axi_bid)
     ,.s_axi_bresp(s_axi_bresp)
     ,.s_axi_araddr(s_axi_araddr)
     ,.s_axi_arvalid(s_axi_arvalid_host)
     ,.s_axi_arready(s_axi_arready_host)
     ,.s_axi_arid(s_axi_arid)
     ,.s_axi_arlock(s_axi_arlock)
     ,.s_axi_arcache(s_axi_arcache)
     ,.s_axi_arprot(s_axi_arprot)
     ,.s_axi_arlen(s_axi_arlen)
     ,.s_axi_arsize(s_axi_arsize)
     ,.s_axi_arburst(s_axi_arburst)
     ,.s_axi_arqos(s_axi_arqos)
     ,.s_axi_arregion(s_axi_arregion)
     ,.s_axi_rdata(s_axi_rdata_host)
     ,.s_axi_rvalid(s_axi_rvalid_host)
     ,.s_axi_rready(s_axi_rready_host)
     ,.s_axi_rid(s_axi_rid_host)
     ,.s_axi_rlast(s_axi_rlast_host)
     ,.s_axi_rresp(s_axi_rresp_host)
     ,.*
     );

  // Bootrom
  // shares AR/R channel of BP I/O Out to FPGA Host
  bp_nonsynth_axi_bootrom
    #(.S_AXI_ADDR_WIDTH(S_AXI_ADDR_WIDTH)
      ,.S_AXI_DATA_WIDTH(S_AXI_DATA_WIDTH)
      ,.S_AXI_ID_WIDTH(S_AXI_ID_WIDTH)
      ,.bootrom_els_p(bootrom_els_p)
      )
    nonsynth_bootrom
    (// BP to Bootrom
     .s_axi_aclk(s_axi_aclk)
     ,.s_axi_aresetn(s_axi_aresetn)
     ,.s_axi_awaddr(s_axi_awaddr)
     ,.s_axi_awvalid(1'b0)
     ,.s_axi_awready()
     ,.s_axi_awid(s_axi_awid)
     ,.s_axi_awlock(s_axi_awlock)
     ,.s_axi_awcache(s_axi_awcache)
     ,.s_axi_awprot(s_axi_awprot)
     ,.s_axi_awlen(s_axi_awlen)
     ,.s_axi_awsize(s_axi_awsize)
     ,.s_axi_awburst(s_axi_awburst)
     ,.s_axi_awqos(s_axi_awqos)
     ,.s_axi_awregion(s_axi_awregion)
     ,.s_axi_wdata(s_axi_wdata)
     ,.s_axi_wvalid(1'b0)
     ,.s_axi_wready()
     ,.s_axi_wlast(s_axi_wlast)
     ,.s_axi_wstrb(s_axi_wstrb)
     ,.s_axi_bvalid()
     ,.s_axi_bready(1'b0)
     ,.s_axi_bid()
     ,.s_axi_bresp()
     ,.s_axi_araddr(s_axi_araddr)
     ,.s_axi_arvalid(s_axi_arvalid_bootrom)
     ,.s_axi_arready(s_axi_arready_bootrom)
     ,.s_axi_arid(s_axi_arid)
     ,.s_axi_arlock(s_axi_arlock)
     ,.s_axi_arcache(s_axi_arcache)
     ,.s_axi_arprot(s_axi_arprot)
     ,.s_axi_arlen(s_axi_arlen)
     ,.s_axi_arsize(s_axi_arsize)
     ,.s_axi_arburst(s_axi_arburst)
     ,.s_axi_arqos(s_axi_arqos)
     ,.s_axi_arregion(s_axi_arregion)
     ,.s_axi_rdata(s_axi_rdata_bootrom)
     ,.s_axi_rvalid(s_axi_rvalid_bootrom)
     ,.s_axi_rready(s_axi_rready_bootrom)
     ,.s_axi_rid(s_axi_rid_bootrom)
     ,.s_axi_rlast(s_axi_rlast_bootrom)
     ,.s_axi_rresp(s_axi_rresp_bootrom)
     );

endmodule

