
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"

module bp_stream_host

  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_me_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)

  ,parameter stream_addr_width_p = 32
  ,parameter stream_data_width_p = 32
  ,localparam m_axil_addr_width_p = stream_addr_width_p
  ,localparam m_axil_data_width_p = stream_data_width_p
  ,localparam m_axil_mask_width_lp = (m_axil_addr_width_p/8)
  ,localparam s_axil_addr_width_p = stream_addr_width_p
  ,localparam s_axil_data_width_p = stream_data_width_p
  ,localparam s_axil_mask_width_lp = (s_axil_addr_width_p/8)

  ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
  )

  (input                                        clk_i
  ,input                                        reset_i
  ,output logic                                 prog_done_o

  // I/O to BP
  ,output logic [m_axil_addr_width_p-1:0]       m_axil_awaddr_o
  ,output [2:0]                                 m_axil_awprot_o
  ,output logic                                 m_axil_awvalid_o
  ,input                                        m_axil_awready_i

  ,output logic [m_axil_data_width_p-1:0]       m_axil_wdata_o
  ,output logic [m_axil_mask_width_lp-1:0]      m_axil_wstrb_o
  ,output logic                                 m_axil_wvalid_o
  ,input                                        m_axil_wready_i

  ,input [1:0]                                  m_axil_bresp_i
  ,input                                        m_axil_bvalid_i
  ,output logic                                 m_axil_bready_o

  ,output logic [m_axil_addr_width_p-1:0]       m_axil_araddr_o
  ,output [2:0]                                 m_axil_arprot_o
  ,output logic                                 m_axil_arvalid_o
  ,input                                        m_axil_arready_i

  ,input [m_axil_data_width_p-1:0]              m_axil_rdata_i
  ,input [1:0]                                  m_axil_rresp_i
  ,input                                        m_axil_rvalid_i
  ,output logic                                 m_axil_rready_o

  // I/O from BP
  ,input [s_axil_addr_width_p-1:0]              s_axil_awaddr_i
  ,input [2:0]                                  s_axil_awprot_i
  ,input                                        s_axil_awvalid_i
  ,output logic                                 s_axil_awready_o

  ,input [s_axil_data_width_p-1:0]              s_axil_wdata_i
  ,input [s_axil_mask_width_lp-1:0]             s_axil_wstrb_i
  ,input                                        s_axil_wvalid_i
  ,output logic                                 s_axil_wready_o

  ,output [1:0]                                 s_axil_bresp_o
  ,output logic                                 s_axil_bvalid_o
  ,input                                        s_axil_bready_i

  ,input [s_axil_addr_width_p-1:0]              s_axil_araddr_i
  ,input [2:0]                                  s_axil_arprot_i
  ,input                                        s_axil_arvalid_i
  ,output logic                                 s_axil_arready_o

  ,output logic [s_axil_data_width_p-1:0]       s_axil_rdata_o
  ,output [1:0]                                 s_axil_rresp_o
  ,output logic                                 s_axil_rvalid_o
  ,input                                        s_axil_rready_i

  ,input                                        stream_v_i
  ,input  [stream_addr_width_p-1:0]             stream_addr_i
  ,input  [stream_data_width_p-1:0]             stream_data_i
  ,output logic                                 stream_yumi_o

  ,output logic                                 stream_v_o
  ,output logic [stream_data_width_p-1:0]       stream_data_o
  ,input                                        stream_ready_i
  );

  // AXI-Lite address map
  //
  // Host software should send data to specific addresses for
  // specific purposes
  //
  logic nbf_v_li, mmio_v_li;
  logic nbf_ready_lo, mmio_ready_lo;;

  assign nbf_v_li  = stream_v_i & (stream_addr_i == 32'h00000010);
  assign mmio_v_li = stream_v_i & (stream_addr_i == 32'h00000020);

  assign stream_yumi_o = (nbf_v_li & nbf_ready_lo) | (mmio_v_li & mmio_ready_lo);

  // nbf loader
  bp_stream_nbf_loader
    #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(stream_data_width_p)
     ,.stream_addr_width_p(stream_addr_width_p)
     )
    nbf_loader
    (.clk_i          (clk_i)
    ,.reset_i        (reset_i)
    ,.done_o         (prog_done_o)

    ,.stream_v_i     (nbf_v_li)
    ,.stream_data_i  (stream_data_i)
    ,.stream_ready_o (nbf_ready_lo)

    ,.*
    );

  // mmio
  bp_stream_mmio
    #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(stream_data_width_p)
     ,.stream_addr_width_p(stream_addr_width_p)
     )
    mmio
    (.clk_i           (clk_i)
    ,.reset_i         (reset_i)

    ,.stream_v_i      (mmio_v_li)
    ,.stream_data_i   (stream_data_i)
    ,.stream_ready_o  (mmio_ready_lo)

    ,.stream_v_o      (stream_v_o)
    ,.stream_data_o   (stream_data_o)
    ,.stream_yumi_i   (stream_v_o & stream_ready_i)

    ,.*
    );

endmodule

