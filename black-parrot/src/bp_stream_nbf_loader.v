/**
 *  bp_stream_nbf_loader.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"

module bp_stream_nbf_loader

  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_me_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)

  ,parameter stream_addr_width_p = 32
  // must be 32
  ,parameter stream_data_width_p = 32
  ,localparam m_axil_addr_width_p = stream_addr_width_p
  ,localparam m_axil_data_width_p = stream_data_width_p
  ,localparam m_axil_mask_width_lp = (m_axil_addr_width_p/8)

  ,parameter nbf_opcode_width_p = 8
  ,parameter nbf_addr_width_p = paddr_width_p
  ,parameter nbf_data_width_p = dword_width_gp

  ,localparam nbf_width_lp = nbf_opcode_width_p + nbf_addr_width_p + nbf_data_width_p
  ,localparam nbf_num_flits_lp = `BSG_CDIV(nbf_width_lp, stream_data_width_p)
  )

  (input                                    clk_i
  ,input                                    reset_i
  ,output logic                             done_o

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

  ,input                                        stream_v_i
  ,input  [stream_data_width_p-1:0]             stream_data_i
  ,output logic                                 stream_ready_o
  );

  // sink bresp as they arrive, but don't couple bvalid and bready
  always_ff @(posedge clk_i) begin
    m_axil_bready_o <= m_axil_bvalid_i;
  end

  wire unused = &{m_axil_bresp_i, m_axil_arready_i, m_axil_rdata_i, m_axil_rresp_i, m_axil_rvalid_i};

  // nbf credit counter
  logic [`BSG_WIDTH(io_noc_max_credits_p)-1:0] credit_count_lo;
  wire credits_full_lo  = (credit_count_lo == io_noc_max_credits_p);
  wire credits_empty_lo = (credit_count_lo == '0);

  bsg_flow_counter
    #(.els_p(io_noc_max_credits_p))
    nbf_counter
    (.clk_i  (clk_i)
    ,.reset_i(reset_i)
    ,.v_i    (m_axil_wvalid_o & m_axil_wready_i)
    ,.ready_i(1'b1)
    ,.yumi_i (m_axil_bvalid_i)
    ,.count_o(credit_count_lo)
    );

  // bp_nbf packet
  typedef struct packed {
    logic [nbf_opcode_width_p-1:0] opcode;
    logic [nbf_addr_width_p-1:0]   addr;
    logic [nbf_data_width_p-1:0]   data;
  } bp_nbf_s;

  // NBF from SIPO
  logic incoming_nbf_v_lo, incoming_nbf_yumi_li;
  logic [nbf_num_flits_lp-1:0][stream_data_width_p-1:0] incoming_nbf;
  bp_nbf_s curr_nbf;
  assign curr_nbf = nbf_width_lp'(incoming_nbf);

  // SIPO that consumes stream interface and produces NBF for loader FSM
  bsg_serial_in_parallel_out_full
    #(.width_p(stream_data_width_p)
     ,.els_p  (nbf_num_flits_lp)
     )
    sipo
    (.clk_i  (clk_i)
    ,.reset_i(reset_i)
    ,.v_i    (stream_v_i)
    ,.ready_o(stream_ready_o)
    ,.data_i (stream_data_i)
    ,.data_o (incoming_nbf)
    ,.v_o    (incoming_nbf_v_lo)
    ,.yumi_i (incoming_nbf_yumi_li)
    );

  // NBF commands: read (not supported), write, fence (wait for credit drain), finish
  typedef enum logic [1:0] {
    e_nbf_ready
    ,e_nbf_hi
    ,e_finish
  } state_e;
  state_e state_r, state_n;

  assign done_o = (state_r == e_done) & credits_empty_lo;

  logic addr_set, addr_clear, addr_sent;
  bsg_dff_reset_set_clear
    #(.width_p(1), .clear_over_set_p(1))
    addr_sent_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(addr_set)
    ,.clear_i(addr_clear)
    ,.data_o(addr_sent)
    );
  assign addr_set = m_axil_awvalid_o & m_axil_awready_i;

  logic data_set, data_clear, data_sent;
  bsg_dff_reset_set_clear
    #(.width_p(1), .clear_over_set_p(1))
    data_sent_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(data_set)
    ,.clear_i(data_clear)
    ,.data_o(data_sent)
    );
  assign data_set = m_axil_wvalid_o & m_axil_wready_i;

  // combinational
  always_comb begin

    state_n = state_r;

    addr_clear = '0;
    data_clear = '0;

    // stub AR and R channels
    m_axil_araddr_o = '0;
    m_axil_arprot_0 = '0;
    m_axil_arvalid_o = '0;
    m_axil_rready_o = '0;

    m_axil_awvalid_o = '0;
    m_axil_awprot_o = '0;
    m_axil_awaddr_o = curr_nbf.addr;

    m_axil_wvalid_o = '0;
    m_axil_wstrb_o = '1; // only 32b or 64b writes, but 32b channel so all lanes active
    m_axil_wdata_o = curr_nbf.data[0+:stream_data_width_p];

    incoming_nbf_yumi_li = 1'b0;

    case (state_r)
      e_nbf_ready: begin
        case (curr_nbf.opcode)
          8'h2: begin // 32b write
            m_axil_awvalid_o = incoming_nbf_v_lo & ~addr_sent;
            m_axil_wvalid_o = incoming_nbf_v_lo & ~data_sent & ~credits_full_lo;
            incoming_nbf_yumi_li = incoming_nbf_v_lo & (addr_sent & data_sent);
            addr_clear = incoming_nbf_yumi_li;
            data_clear = incoming_nbf_yumi_li;
          end
          8'h3: begin // 64b write, do low 32b write here
            m_axil_awvalid_o = incoming_nbf_v_lo & ~addr_sent;
            m_axil_wvalid_o = incoming_nbf_v_lo & ~data_sent & ~credits_full_lo;
            addr_clear = addr_sent & data_sent;
            data_clear = addr_sent & data_sent;
            state_n = (addr_sent & data_sent) ? e_nbf_hi : state_r;
          end
          8'hFE: begin
            incoming_nbf_yumi_li = incoming_nbf_v_lo & credits_empty_lo;
          end
          8'hFF: begin
            incoming_nbf_yumi_li = incoming_nbf_v_lo & credits_empty_lo;
            state_n = incoming_nbf_yumi_li ? e_done : state_r;
          end
          default: begin
            state_n = state_r;
          end
        endcase
      end
      // for 64b writes, write the high 32b
      e_nbf_hi: begin
        m_axil_awvalid_o = incoming_nbf_v_lo & ~addr_sent;
        m_axil_awaddr_o = curr_nbf.addr + 'h4;
        m_axil_wvalid_o = incoming_nbf_v_lo & ~data_sent & ~credits_full_lo;
        m_axil_wdata_o = curr_nbf.data[stream_data_width_p+:stream_data_width_p];
        state_n = (addr_sent & data_sent) ? e_nbf_ready : state_r;
        incoming_nbf_yumi_li = incoming_nbf_v_lo & (addr_sent & data_sent);
        addr_clear = incoming_nbf_yumi_li;
        data_clear = incoming_nbf_yumi_li;
      end
      e_done: begin
        state_n = state_r;
        incoming_nbf_yumi_li = incoming_nbf_v_lo;
      end
      default: begin
        state_n = state_r;
      end
    endcase

  // sequential
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_nbf_ready;
    end else begin
      state_r <= state_n;
    end
  end

endmodule
