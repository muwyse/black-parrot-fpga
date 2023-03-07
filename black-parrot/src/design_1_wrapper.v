/*
 *  Name:
 *    design_1_wrapper.sv
 *
 *  Description:
 *    Top-level wrapper for multicore BP on FPGA.
 *
 *    Parameters:
 *    bp_params_p - specifies number of cores and CCE type, and all BP parameters
 */

// Original header:
//Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2019.1 (lin64) Build 2552052 Fri May 24 14:47:09 MDT 2019
//Date        : Sun Mar 22 22:52:07 2020
//Host        : dhcp196-212.ece.uw.edu running 64-bit CentOS Linux release 7.7.1908 (Core)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

module design_1_wrapper

 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bsg_cache_pkg::*;

 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam s_axi_addr_width_p   = 33
   , localparam s_axi_id_width_p     = 6
   , localparam s_axi_data_width_p   = 256
   , localparam s_axi_strb_width_p   = (s_axi_data_width_p/8)
   , localparam s_axi_burst_len_p    = 2

   , localparam m_axi_addr_width_p   = 32
   , localparam m_axi_data_width_p   = 32
   , localparam m_axi_strb_width_p   = (m_axi_data_width_p/8)
   , localparam m_axi_buffer_els_p   = 16
   )
   (pci_express_x4_rxn
    , pci_express_x4_rxp
    , pci_express_x4_txn
    , pci_express_x4_txp
    , pcie_perstn
    , pcie_refclk_clk_n
    , pcie_refclk_clk_p
    , rstn
    , led
    );

  // FPGA device I/O signals
  input wire [3:0] pci_express_x4_rxn;
  input wire [3:0] pci_express_x4_rxp;
  output wire [3:0] pci_express_x4_txn;
  output wire [3:0] pci_express_x4_txp;
  input wire pcie_perstn;
  input wire [0:0] pcie_refclk_clk_n;
  input wire [0:0] pcie_refclk_clk_p;
  input wire rstn;
  output wire [7:0] led;

  // TODO: unused here, remove BD outputs?
  // PCIe signals from block design
  wire pcie_clk;
  wire pcie_lnk_up;
  wire [0:0]pcie_rstn;

  // Clock and Reset for BP domain
  // AXIL M and AXI S are in this domain
  wire bp_clk;
  wire [0:0]bp_rstn;

  // AXIL M from PC Host for BP I/O
  wire [m_axi_addr_width_p-1:0]m_axi_lite_araddr;
  wire [2:0]m_axi_lite_arprot;
  wire m_axi_lite_arready;
  wire m_axi_lite_arvalid;
  wire [m_axi_addr_width_p-1:0]m_axi_lite_awaddr;
  wire [2:0]m_axi_lite_awprot;
  wire m_axi_lite_awready;
  wire m_axi_lite_awvalid;
  wire m_axi_lite_bready;
  wire [1:0]m_axi_lite_bresp;
  wire m_axi_lite_bvalid;
  wire [m_axi_data_width_p-1:0]m_axi_lite_rdata;
  wire m_axi_lite_rready;
  wire [1:0]m_axi_lite_rresp;
  wire m_axi_lite_rvalid;
  wire [m_axi_data_width_p-1:0]m_axi_lite_wdata;
  wire m_axi_lite_wready;
  wire [m_axi_strb_width_p-1:0]m_axi_lite_wstrb;
  wire m_axi_lite_wvalid;

  // AXI S from BP to HBM
  wire [daddr_width_p-1:0] s_axi_araddr_addr;
  wire [`BSG_SAFE_CLOG2(num_cce_p)-1:0] s_axi_araddr_cache_id;
  wire [s_axi_addr_width_p-1:0]s_axi_araddr;
  wire [1:0]s_axi_arburst;
  wire [3:0]s_axi_arcache;
  wire [0:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [3:0]s_axi_arregion;
  wire [2:0]s_axi_arsize;
  wire s_axi_arvalid;

  wire [daddr_width_p-1:0] s_axi_awaddr_addr;
  wire [`BSG_SAFE_CLOG2(num_cce_p)-1:0] s_axi_awaddr_cache_id;
  wire [s_axi_addr_width_p-1:0]s_axi_awaddr;
  wire [1:0]s_axi_awburst;
  wire [3:0]s_axi_awcache;
  wire [0:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [3:0]s_axi_awregion;
  wire [2:0]s_axi_awsize;
  wire s_axi_awvalid;

  wire [0:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire s_axi_bvalid;

  wire [s_axi_data_width_p-1:0]s_axi_rdata;
  wire [0:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire s_axi_rvalid;

  wire [s_axi_data_width_p-1:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [s_axi_strb_width_p-1:0]s_axi_wstrb;
  wire s_axi_wvalid;

  // HBM S_APB
  // mostly unused, except for apb_complete
  wire apb_complete;
  wire [21:0]s_apb_paddr = '0;
  wire s_apb_penable = 1'b0;
  wire [31:0]s_apb_prdata;
  wire s_apb_pready;
  wire s_apb_psel = 1'b0;
  wire s_apb_pslverr;
  wire [31:0]s_apb_pwdata = '0;
  wire s_apb_pwrite = 1'b0;

  // AXIL M to FIFO
  wire m_axi_lite_v_lo, m_axi_lite_yumi_li;
  wire [m_axi_addr_width_p-1:0] m_axi_lite_addr_lo;
  wire m_axi_lite_v_li, m_axi_lite_ready_lo;
  wire [m_axi_data_width_p-1:0] m_axi_lite_data_li, m_axi_lite_data_lo;

  // BP domain reset
  logic bp_reset;
  bsg_dff
   #(.width_p(1))
    mig_dff
    (.clk_i (bp_clk)
     ,.data_i(~bp_rstn | ~apb_complete)
     ,.data_o(bp_reset)
     );

  // m_axi_lite adapter
  bsg_m_axi_lite_to_fifo_sync
   #(.addr_width_p(m_axi_addr_width_p)
    ,.data_width_p(m_axi_data_width_p)
    ,.buffer_size_p(m_axi_buffer_els_p)
    )
    m_axi_lite_adapter
    (.clk_i     (bp_clk)
     ,.reset_i  (bp_reset)
     // read address
     ,.araddr_i (m_axi_lite_araddr)
     ,.arprot_i (m_axi_lite_arprot)
     ,.arready_o(m_axi_lite_arready)
     ,.arvalid_i(m_axi_lite_arvalid)
     // read data
     ,.rdata_o  (m_axi_lite_rdata)
     ,.rready_i (m_axi_lite_rready)
     ,.rresp_o  (m_axi_lite_rresp)
     ,.rvalid_o (m_axi_lite_rvalid)
     // write address
     ,.awaddr_i (m_axi_lite_awaddr)
     ,.awprot_i (m_axi_lite_awprot)
     ,.awready_o(m_axi_lite_awready)
     ,.awvalid_i(m_axi_lite_awvalid)
     // write data
     ,.wdata_i  (m_axi_lite_wdata)
     ,.wready_o (m_axi_lite_wready)
     ,.wstrb_i  (m_axi_lite_wstrb)
     ,.wvalid_i (m_axi_lite_wvalid)
     // write response
     ,.bready_i (m_axi_lite_bready)
     ,.bresp_o  (m_axi_lite_bresp)
     ,.bvalid_o (m_axi_lite_bvalid)
     // fifo output
     ,.v_o      (m_axi_lite_v_lo)
     ,.addr_o   (m_axi_lite_addr_lo)
     ,.data_o   (m_axi_lite_data_lo)
     ,.yumi_i   (m_axi_lite_yumi_li)
     // fifo input
     ,.v_i      (m_axi_lite_v_li)
     ,.data_i   (m_axi_lite_data_li)
     ,.ready_o  (m_axi_lite_ready_lo)
     );

  `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_noc_ral_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_noc_ral_link_s);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

  bp_io_noc_ral_link_s proc_fwd_link_li, proc_fwd_link_lo;
  bp_io_noc_ral_link_s proc_rev_link_li, proc_rev_link_lo;
  bp_io_noc_ral_link_s stub_fwd_link_li, stub_rev_link_li;
  bp_io_noc_ral_link_s stub_fwd_link_lo, stub_rev_link_lo;
  bp_mem_noc_ral_link_s [mc_x_dim_p-1:0] mem_dma_link_lo, mem_dma_link_li;

  assign stub_fwd_link_li  = '0;
  assign stub_rev_link_li = '0;

  wire [did_width_p-1:0] did_li = 1;
  wire [did_width_p-1:0] host_did_li = '1;

  bp_multicore
   #(.bp_params_p(bp_params_p))
   multicore
    (.core_clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.core_reset_i(reset_i)

     ,.coh_clk_i(clk_i)
     ,.coh_reset_i(reset_i)

     ,.io_clk_i(clk_i)
     ,.io_reset_i(reset_i)

     ,.mem_clk_i(clk_i)
     ,.mem_reset_i(reset_i)

     ,.my_did_i(did_li)
     ,.host_did_i(host_did_li)

     ,.io_fwd_link_i({proc_fwd_link_li, stub_fwd_link_li})
     ,.io_fwd_link_o({proc_fwd_link_lo, stub_fwd_link_lo})

     ,.io_rev_link_i({proc_rev_link_li, stub_rev_link_li})
     ,.io_rev_link_o({proc_rev_link_lo, stub_rev_link_lo})

     ,.mem_dma_link_o(mem_dma_link_lo)
     ,.mem_dma_link_i(mem_dma_link_li)
     );

  wire [io_noc_cord_width_p-1:0] dst_cord_lo = 1;

  bp_io_noc_ral_link_s send_cmd_link_lo, send_resp_link_li;
  bp_io_noc_ral_link_s recv_cmd_link_li, recv_resp_link_lo;
  assign recv_cmd_link_li   = '{data          : proc_fwd_link_lo.data
                                ,v            : proc_fwd_link_lo.v
                                ,ready_and_rev: proc_rev_link_lo.ready_and_rev
                                };
  assign proc_fwd_link_li   = '{data          : send_cmd_link_lo.data
                                ,v            : send_cmd_link_lo.v
                                ,ready_and_rev: recv_resp_link_lo.ready_and_rev
                                };

  assign send_resp_link_li  = '{data          : proc_rev_link_lo.data
                                ,v            : proc_rev_link_lo.v
                                ,ready_and_rev: proc_fwd_link_lo.ready_and_rev
                                };
  assign proc_rev_link_li  = '{data           : recv_resp_link_lo.data
                                ,v            : recv_resp_link_lo.v
                                ,ready_and_rev: send_cmd_link_lo.ready_and_rev
                                };

  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [io_data_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_header_v_li, mem_fwd_header_ready_and_lo;
  logic mem_fwd_data_v_li, mem_fwd_data_ready_and_lo;
  logic mem_fwd_last_li, mem_fwd_has_data_li;

  bp_bedrock_mem_rev_header_s mem_rev_header_lo;
  logic [io_data_width_p-1:0] mem_rev_data_lo;
  logic mem_rev_header_v_lo, mem_rev_header_ready_and_li;
  logic mem_rev_data_v_lo, mem_rev_data_ready_and_li;
  logic mem_rev_last_lo, mem_rev_has_data_lo;

  bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
  logic [io_data_width_p-1:0] mem_fwd_data_lo;
  logic mem_fwd_header_v_lo, mem_fwd_header_ready_and_li;
  logic mem_fwd_data_v_lo, mem_fwd_data_ready_and_li;
  logic mem_fwd_last_lo, mem_fwd_has_data_lo;

  bp_bedrock_mem_rev_header_s mem_rev_header_li;
  logic [io_data_width_p-1:0] mem_rev_data_li;
  logic mem_rev_header_v_li, mem_rev_header_ready_and_lo;
  logic mem_rev_data_v_li, mem_rev_data_ready_and_lo;
  logic mem_rev_last_li, mem_rev_has_data_li;

  // TODO: this file was deleted from BP repo in 5de8f838be
  // replaced with wh-burst module (one for each link)
  bp_me_bedrock_mem_to_link
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(io_noc_flit_width_p)
     ,.cord_width_p(io_noc_cord_width_p)
     ,.cid_width_p(io_noc_cid_width_p)
     ,.len_width_p(io_noc_len_width_p)
     ,.payload_mask_p(mem_fwd_payload_mask_gp)
     )
   send_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dst_cord_i(dst_cord_lo)
     ,.dst_cid_i('0)

     ,.mem_header_i(mem_fwd_header_li)
     ,.mem_header_v_i(mem_fwd_header_v_li)
     ,.mem_header_ready_and_o(mem_fwd_header_ready_and_lo)
     ,.mem_has_data_i(mem_fwd_has_data_li)
     ,.mem_data_i(mem_fwd_data_li)
     ,.mem_data_v_i(mem_fwd_data_v_li)
     ,.mem_data_ready_and_o(mem_fwd_data_ready_and_lo)
     ,.mem_last_i(mem_fwd_last_li)

     ,.mem_header_o(mem_rev_header_lo)
     ,.mem_header_v_o(mem_rev_header_v_lo)
     ,.mem_header_ready_and_i(mem_rev_header_ready_and_li)
     ,.mem_has_data_o(mem_rev_has_data_lo)
     ,.mem_data_o(mem_rev_data_lo)
     ,.mem_data_v_o(mem_rev_data_v_lo)
     ,.mem_data_ready_and_i(mem_rev_data_ready_and_li)
     ,.mem_last_o(mem_rev_last_lo)

     ,.link_o(send_cmd_link_lo)
     ,.link_i(send_resp_link_li)
     );

  bp_me_bedrock_mem_to_link
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(io_noc_flit_width_p)
     ,.cord_width_p(io_noc_cord_width_p)
     ,.cid_width_p(io_noc_cid_width_p)
     ,.len_width_p(io_noc_len_width_p)
     ,.payload_mask_p(mem_rev_payload_mask_gp)
     )
   recv_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dst_cord_i(mem_rev_header_li.payload.did)
     ,.dst_cid_i('0)

     ,.mem_header_o(mem_fwd_header_lo)
     ,.mem_header_v_o(mem_fwd_header_v_lo)
     ,.mem_header_ready_and_i(mem_fwd_header_ready_and_li)
     ,.mem_has_data_o(mem_fwd_has_data_lo)
     ,.mem_data_o(mem_fwd_data_lo)
     ,.mem_data_v_o(mem_fwd_data_v_lo)
     ,.mem_data_ready_and_i(mem_fwd_data_ready_and_li)
     ,.mem_last_o(mem_fwd_last_lo)

     ,.mem_header_i(mem_rev_header_li)
     ,.mem_header_v_i(mem_rev_header_v_li)
     ,.mem_header_ready_and_o(mem_rev_header_ready_and_lo)
     ,.mem_has_data_i(mem_rev_has_data_li)
     ,.mem_data_i(mem_rev_data_li)
     ,.mem_data_v_i(mem_rev_data_v_li)
     ,.mem_data_ready_and_o(mem_rev_data_ready_and_lo)
     ,.mem_last_i(mem_rev_last_li)

     ,.link_i(recv_cmd_link_li)
     ,.link_o(recv_resp_link_lo)
     );

  `declare_bsg_cache_wh_header_flit_s(mem_noc_flit_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, mem_noc_cid_width_p);
  localparam dma_per_col_lp = num_cce_p/mc_x_dim_p*l2_banks_p;
  bsg_cache_dma_pkt_s [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_pkt_lo;
  logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_data_v_lo, dma_data_yumi_li;
  logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_data_v_li, dma_data_ready_and_lo;
  for (genvar i = 0; i < mc_x_dim_p; i++)
    begin : column
      bsg_cache_wh_header_flit_s header_flit;
      assign header_flit = mem_dma_link_lo[i].data;
      wire [`BSG_SAFE_CLOG2(dma_per_col_lp)-1:0] dma_id_li =
        l2_banks_p*(header_flit.src_cord-1)+header_flit.src_cid;
      bsg_wormhole_to_cache_dma_fanout
       #(.wh_flit_width_p(mem_noc_flit_width_p)
         ,.wh_cid_width_p(mem_noc_cid_width_p)
         ,.wh_len_width_p(mem_noc_len_width_p)
         ,.wh_cord_width_p(mem_noc_cord_width_p)

         ,.num_dma_p(dma_per_col_lp)
         ,.dma_addr_width_p(daddr_width_p)
         ,.dma_burst_len_p(l2_block_size_in_fill_p)
         )
       wh_to_cache_dma
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.wh_link_sif_i(mem_dma_link_lo[i])
         ,.wh_dma_id_i(dma_id_li)
         ,.wh_link_sif_o(mem_dma_link_li[i])

         ,.dma_pkt_o(dma_pkt_lo[i])
         ,.dma_pkt_v_o(dma_pkt_v_lo[i])
         ,.dma_pkt_yumi_i(dma_pkt_yumi_li[i])

         ,.dma_data_i(dma_data_li[i])
         ,.dma_data_v_i(dma_data_v_li[i])
         ,.dma_data_ready_and_o(dma_data_ready_and_lo[i])

         ,.dma_data_o(dma_data_lo[i])
         ,.dma_data_v_o(dma_data_v_lo[i])
         ,.dma_data_yumi_i(dma_data_yumi_li[i])
         );
    end
  // Transpose the DMA IDs
  for (genvar i = 0; i < num_cce_p; i++)
    begin : rof1
      for (genvar j = 0; j < l2_banks_p; j++)
        begin : rof2
          localparam col_lp     = i%mc_x_dim_p;
          localparam col_pos_lp = (i/mc_x_dim_p)*l2_banks_p+j;

          assign c2a_dma_pkt_lo[i][j] = dma_pkt_lo[col_lp][col_pos_lp];
          assign c2a_dma_pkt_v_lo[i][j] = dma_pkt_v_lo[col_lp][col_pos_lp];
          assign dma_pkt_yumi_li[col_lp][col_pos_lp] = c2a_dma_pkt_ready_and_li[i][j] & c2a_dma_pkt_v_lo[i][j];

          assign c2a_dma_data_lo[i][j] = dma_data_lo[col_lp][col_pos_lp];
          assign c2a_dma_data_v_lo[i][j] = dma_data_v_lo[col_lp][col_pos_lp];
          assign dma_data_yumi_li[col_lp][col_pos_lp] = c2a_dma_data_ready_and_li[i][j] & c2a_dma_data_v_lo[i][j];

          assign dma_data_li[col_lp][col_pos_lp] = c2a_dma_data_li[i][j];
          assign dma_data_v_li[col_lp][col_pos_lp] = c2a_dma_data_v_li[i][j];
          assign c2a_dma_data_ready_and_lo[i][j] = dma_data_ready_and_lo[col_lp][col_pos_lp];
        end
    end

  // Unswizzle the dram
  bsg_cache_dma_pkt_s [num_cce_p-1:0][l2_banks_p-1:0] c2a_dma_pkt;
  for (genvar i = 0; i < num_cce_p; i++)
    begin : rof3
      for (genvar j = 0; j < l2_banks_p; j++)
        begin : address_hash
          logic [daddr_width_p-1:0] daddr_lo;
          bp_me_dram_hash_decode
           #(.bp_params_p(bp_params_p))
            dma_addr_hash
            (.daddr_i(c2a_dma_pkt_lo[i][j].addr)
             ,.daddr_o(c2a_dma_pkt[i][j].addr)
             );
          assign c2a_dma_pkt[i][j].write_not_read = c2a_dma_pkt_lo[i][j].write_not_read;
          assign c2a_dma_pkt[i][j].mask = c2a_dma_pkt_lo[i][j].mask;
        end
    end

   bsg_cache_to_axi
    #(.addr_width_p(daddr_width_p)
      ,.data_width_p(l2_fill_width_p)
      ,.mask_width_p(l2_block_size_in_words_p)
      ,.block_size_in_words_p(l2_block_size_in_fill_p)
      ,.num_cache_p(num_cce_p*l2_banks_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_id_width_p(axi_id_width_p)
      ,.axi_burst_len_p(l2_block_width_p/axi_data_width_p)
      ,.axi_burst_type_p(e_axi_burst_incr)
      )
    cache2axi
     (.clk_i(bp_clk)
      ,.reset_i(bp_reset)

      ,.dma_pkt_i(c2a_dma_pkt)
      ,.dma_pkt_v_i(c2a_dma_pkt_v_lo)
      ,.dma_pkt_yumi_o(c2a_dma_pkt_ready_and_li)

      ,.dma_data_o(c2a_dma_data_li)
      ,.dma_data_v_o(c2a_dma_data_v_li)
      ,.dma_data_ready_i(c2a_dma_data_ready_and_lo)

      ,.dma_data_i(c2a_dma_data_lo)
      ,.dma_data_v_i(c2a_dma_data_v_lo)
      ,.dma_data_yumi_o(c2a_dma_data_ready_and_li)

      ,.axi_awid_o      (s_axi_awid)
      ,.axi_awaddr_addr_o    (s_axi_awaddr_addr)
      ,.axi_awaddr_cache_id_o(s_axi_awaddr_cache_id)
      ,.axi_awlen_o     (s_axi_awlen)
      ,.axi_awsize_o    (s_axi_awsize)
      ,.axi_awburst_o   (s_axi_awburst)
      ,.axi_awcache_o   (s_axi_awcache)
      ,.axi_awprot_o    (s_axi_awprot)
      ,.axi_awlock_o    (s_axi_awlock)
      ,.axi_awvalid_o   (s_axi_awvalid)
      ,.axi_awready_i   (s_axi_awready)

      ,.axi_wdata_o     (s_axi_wdata)
      ,.axi_wstrb_o     (s_axi_wstrb)
      ,.axi_wlast_o     (s_axi_wlast)
      ,.axi_wvalid_o    (s_axi_wvalid)
      ,.axi_wready_i    (s_axi_wready)

      ,.axi_bid_i       (s_axi_bid)
      ,.axi_bresp_i     (s_axi_bresp)
      ,.axi_bvalid_i    (s_axi_bvalid)
      ,.axi_bready_o    (s_axi_bready)

      ,.axi_arid_o      (s_axi_arid)
      ,.axi_araddr_addr_o    (s_axi_araddr_addr)
      ,.axi_araddr_cache_id_o(s_axi_araddr_cache_id)
      ,.axi_arlen_o     (s_axi_arlen)
      ,.axi_arsize_o    (s_axi_arsize)
      ,.axi_arburst_o   (s_axi_arburst)
      ,.axi_arcache_o   (s_axi_arcache)
      ,.axi_arprot_o    (s_axi_arprot)
      ,.axi_arlock_o    (s_axi_arlock)
      ,.axi_arvalid_o   (s_axi_arvalid)
      ,.axi_arready_i   (s_axi_arready)

      ,.axi_rid_i       (s_axi_rid)
      ,.axi_rdata_i     (s_axi_rdata)
      ,.axi_rresp_i     (s_axi_rresp)
      ,.axi_rlast_i     (s_axi_rlast)
      ,.axi_rvalid_i    (s_axi_rvalid)
      ,.axi_rready_o    (s_axi_rready)
      );

  logic nbf_done_lo;
  bp_stream_host
   #(.bp_params_p(bp_params_p)
     ,.stream_addr_width_p(m_axi_addr_width_p)
     ,.stream_data_width_p(m_axi_data_width_p)
     )
    host
    (.clk_i(bp_clk)
     ,.reset_i(bp_reset)
     ,.prog_done_o(nbf_done_lo)

     // IO from BP (recv_link)
     ,.mem_fwd_header_i(mem_fwd_header_lo)
     ,.mem_fwd_header_v_i(mem_fwd_header_v_lo)
     ,.mem_fwd_header_ready_and_o(mem_fwd_header_ready_and_li)
     ,.mem_fwd_has_data_i(mem_fwd_has_data_lo)
     ,.mem_fwd_data_i(mem_fwd_data_lo)
     ,.mem_fwd_data_v_i(mem_fwd_data_v_lo)
     ,.mem_fwd_data_ready_and_o(mem_fwd_data_ready_and_li)
     ,.mem_fwd_last_i(mem_fwd_last_lo)

     ,.mem_rev_header_o(mem_rev_header_li)
     ,.mem_rev_header_v_o(mem_rev_header_v_li)
     ,.mem_rev_header_ready_and_i(mem_rev_header_ready_and_lo)
     ,.mem_rev_has_data_o(mem_rev_has_data_li)
     ,.mem_rev_data_o(mem_rev_data_li)
     ,.mem_rev_data_v_o(mem_rev_data_v_li)
     ,.mem_rev_data_ready_and_i(mem_rev_data_ready_and_lo)
     ,.mem_rev_last_o(mem_rev_last_li)

     // IO to BP (send_link)
     ,.mem_fwd_header_o(mem_fwd_header_li)
     ,.mem_fwd_header_v_o(mem_fwd_header_v_li)
     ,.mem_fwd_header_ready_and_i(mem_fwd_header_ready_and_lo)
     ,.mem_fwd_has_data_o(mem_fwd_has_data_li)
     ,.mem_fwd_data_o(mem_fwd_data_li)
     ,.mem_fwd_data_v_o(mem_fwd_data_v_li)
     ,.mem_fwd_data_ready_and_i(mem_fwd_data_ready_and_lo)
     ,.mem_fwd_last_o(mem_fwd_last_li)

     ,.mem_rev_header_i(mem_rev_header_lo)
     ,.mem_rev_header_v_i(mem_rev_header_v_lo)
     ,.mem_rev_header_ready_and_o(mem_rev_header_ready_and_li)
     ,.mem_rev_has_data_i(mem_rev_has_data_lo)
     ,.mem_rev_data_i(mem_rev_data_lo)
     ,.mem_rev_data_v_i(mem_rev_data_v_lo)
     ,.mem_rev_data_ready_and_o(mem_rev_data_ready_and_li)
     ,.mem_rev_last_i(mem_rev_last_lo)

     ,.stream_v_i(m_axi_lite_v_lo)
     ,.stream_addr_i(m_axi_lite_addr_lo)
     ,.stream_data_i(m_axi_lite_data_lo)
     ,.stream_yumi_o(m_axi_lite_yumi_li)

     ,.stream_v_o(m_axi_lite_v_li)
     ,.stream_data_o(m_axi_lite_data_li)
     ,.stream_ready_i(m_axi_lite_ready_lo)
     );

  // subtract dram_base_addr_gp from axi addresses
  // S_AXI memory is at address 0x0, but BP issues address to DRAM at 0x8000_0000
  assign s_axi_awaddr = s_axi_awaddr_addr[0+:s_axi_addr_width_p] ^ dram_base_addr_gp;
  assign s_axi_araddr = s_axi_araddr_addr[0+:s_axi_addr_width_p] ^ dram_base_addr_gp;

  // s_axi port
  // not supported
  assign s_axi_arqos    = '0;
  assign s_axi_arregion = '0;
  assign s_axi_awqos    = '0;
  assign s_axi_awregion = '0;

  design_1 design_1_i
    (
     // external reset pin
     .reset(~rstn),

     // PCIe to/from PC Host
     .pcie_refclk_clk_n(pcie_refclk_clk_n),
     .pcie_refclk_clk_p(pcie_refclk_clk_p),
     .pcie_perstn(pcie_perstn),
     .pci_express_x4_rxn(pci_express_x4_rxn),
     .pci_express_x4_rxp(pci_express_x4_rxp),
     .pci_express_x4_txn(pci_express_x4_txn),
     .pci_express_x4_txp(pci_express_x4_txp),
     // PCIe to design
     .pcie_clk(pcie_clk),
     .pcie_rstn(pcie_rstn),
     .pcie_lnk_up(pcie_lnk_up),

     // Clock and Reset for BP domain
     // AXIL M and AXI S are in this domain
     .mig_clk(bp_clk),
     .mig_rstn(bp_rstn),

     // AXIL M from PC Host for BP I/O
     .m_axi_lite_araddr(m_axi_lite_araddr),
     .m_axi_lite_arprot(m_axi_lite_arprot),
     .m_axi_lite_arready(m_axi_lite_arready),
     .m_axi_lite_arvalid(m_axi_lite_arvalid),
     .m_axi_lite_awaddr(m_axi_lite_awaddr),
     .m_axi_lite_awprot(m_axi_lite_awprot),
     .m_axi_lite_awready(m_axi_lite_awready),
     .m_axi_lite_awvalid(m_axi_lite_awvalid),
     .m_axi_lite_bready(m_axi_lite_bready),
     .m_axi_lite_bresp(m_axi_lite_bresp),
     .m_axi_lite_bvalid(m_axi_lite_bvalid),
     .m_axi_lite_rdata(m_axi_lite_rdata),
     .m_axi_lite_rready(m_axi_lite_rready),
     .m_axi_lite_rresp(m_axi_lite_rresp),
     .m_axi_lite_rvalid(m_axi_lite_rvalid),
     .m_axi_lite_wdata(m_axi_lite_wdata),
     .m_axi_lite_wready(m_axi_lite_wready),
     .m_axi_lite_wstrb(m_axi_lite_wstrb),
     .m_axi_lite_wvalid(m_axi_lite_wvalid),

     // AXI S from BP to HBM
     .s_axi_araddr(s_axi_araddr),
     .s_axi_arburst(s_axi_arburst),
     .s_axi_arcache(s_axi_arcache),
     .s_axi_arid(s_axi_arid),
     .s_axi_arlen(s_axi_arlen),
     .s_axi_arlock(s_axi_arlock),
     .s_axi_arprot(s_axi_arprot),
     .s_axi_arqos(s_axi_arqos),
     .s_axi_arready(s_axi_arready),
     .s_axi_arregion(s_axi_arregion),
     .s_axi_arsize(s_axi_arsize),
     .s_axi_arvalid(s_axi_arvalid),
     .s_axi_awaddr(s_axi_awaddr),
     .s_axi_awburst(s_axi_awburst),
     .s_axi_awcache(s_axi_awcache),
     .s_axi_awid(s_axi_awid),
     .s_axi_awlen(s_axi_awlen),
     .s_axi_awlock(s_axi_awlock),
     .s_axi_awprot(s_axi_awprot),
     .s_axi_awqos(s_axi_awqos),
     .s_axi_awready(s_axi_awready),
     .s_axi_awregion(s_axi_awregion),
     .s_axi_awsize(s_axi_awsize),
     .s_axi_awvalid(s_axi_awvalid),
     .s_axi_bid(s_axi_bid),
     .s_axi_bready(s_axi_bready),
     .s_axi_bresp(s_axi_bresp),
     .s_axi_bvalid(s_axi_bvalid),
     .s_axi_rdata(s_axi_rdata),
     .s_axi_rid(s_axi_rid),
     .s_axi_rlast(s_axi_rlast),
     .s_axi_rready(s_axi_rready),
     .s_axi_rresp(s_axi_rresp),
     .s_axi_rvalid(s_axi_rvalid),
     .s_axi_wdata(s_axi_wdata),
     .s_axi_wlast(s_axi_wlast),
     .s_axi_wready(s_axi_wready),
     .s_axi_wstrb(s_axi_wstrb),
     .s_axi_wvalid(s_axi_wvalid),

     // HBM S_APB
     // mostly unused, except for apb_complete
     .apb_complete(apb_complete),
     .s_apb_paddr(s_apb_paddr),
     .s_apb_penable(s_apb_penable),
     .s_apb_prdata(s_apb_prdata),
     .s_apb_pready(s_apb_pready),
     .s_apb_psel(s_apb_psel),
     .s_apb_pslverr(s_apb_pslverr),
     .s_apb_pwdata(s_apb_pwdata),
     .s_apb_pwrite(s_apb_pwrite)
     );

  // LEDs
  assign led[0] = pcie_lnk_up;
  assign led[1] = apb_complete;

  // breathing
  logic led_breath;
  logic [31:0] led_counter_r;
  assign led[2] = led_breath;
  always_ff @(posedge bp_clk)
    if (bp_reset)
      begin
        led_counter_r <= '0;
        led_breath <= 1'b0;
      end
    else
      begin
        led_counter_r <= (led_counter_r == 32'd12500000)? '0 : led_counter_r + 1;
        led_breath <= (led_counter_r == 32'd12500000)? ~led_breath : led_breath;
      end
  // pcie stream host (NBF and MMIO)
  assign led[3] = nbf_done_lo;

  // reset pin
  assign led[4] = ~rstn;
  assign led[5] = ~rstn;
  assign led[6] = rstn;
  assign led[7] = rstn;

endmodule
