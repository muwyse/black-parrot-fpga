/*
 * Name:
 *  bp_nonsynth_axi_bootrom.sv
 *
 * Description:
 *   This module is a nonsynthesizable bootrom connected to an S_AXI AR/R interface.
 *
 */

`include "bsg_defines.sv"

module bp_nonsynth_axi_bootrom
 import bsg_axi_pkg::*;
 #( parameter S_AXI_ADDR_WIDTH = 64 // must be 64
   , parameter S_AXI_DATA_WIDTH = 64 // must be 64
   , parameter S_AXI_ID_WIDTH = 4
   , parameter bootrom_els_p = 1024
   )
  (//======================== BlackParrot I/O Out ========================
   input                                       s_axi_aclk
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
   );

  localparam dword_width_gp = 64;

  wire reset = ~s_axi_aresetn;
  wire clk = s_axi_aclk;

  // AXI to FIFO converter
  logic [S_AXI_ADDR_WIDTH-1:0] axi_addr;
  logic axi_v, axi_yumi;
  logic [2:0] axi_size;
  logic resp_v, resp_ready_and;
  logic [S_AXI_DATA_WIDTH-1:0] resp_data;

  bp_axi_to_fifo
    #(.s_axi_data_width_p(S_AXI_DATA_WIDTH)
      ,.s_axi_addr_width_p(S_AXI_ADDR_WIDTH)
      ,.s_axi_id_width_p(S_AXI_ID_WIDTH)
      )
    bp_to_fifo
     (.clk_i(clk)
      ,.reset_i(reset)
      // to FSM
      ,.data_o(/* unused */)
      ,.addr_o(axi_addr)
      ,.v_o(axi_v)
      ,.w_o(/* unused */)
      ,.wmask_o(/* unused */)
      ,.size_o(axi_size)
      ,.yumi_i(axi_yumi)
      // response from FSM
      ,.data_i(resp_data)
      ,.v_i(resp_v)
      ,.w_i(1'b0)
      ,.ready_and_o(resp_ready_and)
      // from S_AXI
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

  // Bootrom

  // one read at a time
  logic bootrom_r_v, bootrom_r_set, bootrom_r_clear;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   control_reg
    (.clk_i(clk)
    ,.reset_i(reset)
    ,.set_i(bootrom_r_set)
    ,.clear_i(bootrom_r_clear)
    ,.data_o(bootrom_r_v)
    );

  logic [S_AXI_ADDR_WIDTH-1:0] addr_lo;
  logic [2:0] size_lo;
  bsg_dff_reset_en
   #(.width_p(S_AXI_ADDR_WIDTH+3))
   transaction_reg
    (.clk_i(clk)
    ,.reset_i(reset)
    ,.en_i(bootrom_r_set)
    ,.data_i({axi_addr, axi_size})
    ,.data_o({addr_lo, size_lo})
    );


  assign bootrom_r_set = axi_v & ~bootrom_r_v;
  assign axi_yumi = axi_v & ~bootrom_r_v;
  assign bootrom_r_clear = resp_v & resp_ready_and;

  localparam lg_bootrom_els_lp = `BSG_SAFE_CLOG2(bootrom_els_p);
  bit [dword_width_gp-1:0] bootrom_data_lo;
  bit [lg_bootrom_els_lp-1:0] bootrom_addr_li;
  bit [7:0] bootrom_mem [0:8*bootrom_els_p-1];

  initial $readmemh("bootrom.mem", bootrom_mem);
  assign bootrom_addr_li = addr_lo[3+:lg_bootrom_els_lp];

  assign bootrom_data_lo = {
    bootrom_mem[8*bootrom_addr_li+7]
    ,bootrom_mem[8*bootrom_addr_li+6]
    ,bootrom_mem[8*bootrom_addr_li+5]
    ,bootrom_mem[8*bootrom_addr_li+4]
    ,bootrom_mem[8*bootrom_addr_li+3]
    ,bootrom_mem[8*bootrom_addr_li+2]
    ,bootrom_mem[8*bootrom_addr_li+1]
    ,bootrom_mem[8*bootrom_addr_li+0]
    };

  // Convert to little endian
  wire [dword_width_gp-1:0] bootrom_data_reverse = {<<8{bootrom_data_lo}};

  logic [dword_width_gp-1:0] bootrom_final_lo;
  bsg_bus_pack
   #(.in_width_p(dword_width_gp))
   bootrom_pack
    (.data_i(bootrom_data_lo)
     ,.size_i(size_lo)
     ,.sel_i(addr_lo[0+:3])
     ,.data_o(bootrom_final_lo)
     );

  assign resp_data = bootrom_final_lo;
  assign resp_v = bootrom_r_v;

endmodule

