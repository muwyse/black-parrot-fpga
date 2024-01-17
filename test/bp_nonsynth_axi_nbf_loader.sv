/*
 * Name:
 *  bp_nonsynth_axi_nbf_loader.v
 *
 * Description:
 *  This module serializes NBF commands onto M_AXIL. The NBF command is read
 *  from the input file, split into M_AXIL_DATA_WIDTH chunks and then written
 *  to M_AXIL interface.
 *
 *  This module only issues writes.
 */

`include "bsg_defines.sv"

module bp_nonsynth_axi_nbf_loader
  #(parameter M_AXIL_ADDR_WIDTH = 64
   ,parameter M_AXIL_DATA_WIDTH = 32 // must be 32
   ,parameter M_AXIL_CREDITS = 64
   ,parameter nbf_filename_p = "prog.nbf"
   ,parameter logic [63:0] nbf_host_addr_p = 64'h0
   )
  (// M_AXIL
   input logic                               m_axil_aclk
   ,input logic                              m_axil_aresetn

   ,output logic [M_AXIL_ADDR_WIDTH-1:0]     m_axil_awaddr
   ,output logic                             m_axil_awvalid
   ,input logic                              m_axil_awready
   ,output logic [2:0]                       m_axil_awprot

   ,output logic [M_AXIL_DATA_WIDTH-1:0]     m_axil_wdata
   ,output logic                             m_axil_wvalid
   ,input logic                              m_axil_wready
   ,output logic [(M_AXIL_DATA_WIDTH/8)-1:0] m_axil_wstrb

   ,input logic                              m_axil_bvalid
   ,output logic                             m_axil_bready
   ,input logic [1:0]                        m_axil_bresp

   ,output logic [M_AXIL_ADDR_WIDTH-1:0]     m_axil_araddr
   ,output logic                             m_axil_arvalid
   ,input logic                              m_axil_arready
   ,output logic [2:0]                       m_axil_arprot

   ,input logic [M_AXIL_DATA_WIDTH-1:0]      m_axil_rdata
   ,input logic                              m_axil_rvalid
   ,output logic                             m_axil_rready
   ,input logic [1:0]                        m_axil_rresp

   ,output logic                             done_o
   );

  wire reset = ~m_axil_aresetn;

  localparam max_nbf_index_lp = 2**25;
  localparam nbf_index_width_lp = `BSG_SAFE_CLOG2(max_nbf_index_lp);
  localparam nbf_data_width_lp = 64; // must be 64
  localparam nbf_addr_width_lp = nbf_data_width_lp; // must be 64
  localparam nbf_opcode_width_lp = 8;
  localparam nbf_width_lp = nbf_opcode_width_lp + nbf_addr_width_lp + nbf_data_width_lp;
  localparam nbf_flits_lp = `BSG_CDIV(nbf_width_lp, M_AXIL_DATA_WIDTH);
  typedef struct packed
  {
    logic [nbf_opcode_width_lp-1:0] opcode;
    logic [nbf_addr_width_lp-1:0] addr;
    logic [nbf_data_width_lp-1:0] data;
  } bp_nbf_s;

  // read nbf file
  bp_nbf_s nbf [max_nbf_index_lp-1:0];
  initial $readmemh(nbf_filename_p, nbf);

  bp_nbf_s curr_nbf;
  logic [nbf_flits_lp-1:0][M_AXIL_DATA_WIDTH-1:0] curr_nbf_words;
  logic [nbf_index_width_lp-1:0] nbf_index_r;
  assign curr_nbf = nbf[nbf_index_r];
  assign curr_nbf_words = {{(M_AXIL_DATA_WIDTH-8){1'b0}}, curr_nbf};
  wire is_nbf_finish = curr_nbf.opcode == 8'hFF;

  // credit flow control
  logic [`BSG_WIDTH(M_AXIL_CREDITS)-1:0] credit_count_lo;
  bsg_flow_counter
   #(.els_p(M_AXIL_CREDITS))
   nbf_fc
    (.clk_i(m_axil_aclk)
     ,.reset_i(reset)

     ,.v_i(m_axil_awvalid)
     ,.ready_param_i(m_axil_awready)

     ,.yumi_i(m_axil_bvalid & m_axil_bready)
     ,.count_o(credit_count_lo)
     );
  wire credits_full_lo = (credit_count_lo == M_AXIL_CREDITS);
  //wire credits_empty_lo = (credit_count_lo == '0);

  // send all words of current NBF
  // go to next NBF
  enum logic [2:0] { e_reset, e_send, e_addr, e_data, e_done} state_n, state_r;
  wire is_send  = (state_r == e_send);
  wire is_addr  = (state_r == e_addr);
  wire is_data  = (state_r == e_data);
  wire is_done  = (state_r == e_done);
  assign done_o = is_done;

  // address and data sends
  wire send_addr = m_axil_awvalid & m_axil_awready;
  wire send_data = m_axil_wvalid & m_axil_wready;


  // NBF word counter
  logic nbf_word_clear, nbf_word_up;
  logic [`BSG_SAFE_CLOG2(nbf_flits_lp+1)-1:0] nbf_word_r;
  bsg_counter_clear_up
   #(.max_val_p(nbf_flits_lp), .init_val_p(0))
   nbf_word_counter
    (.clk_i(m_axil_aclk)
     ,.reset_i(reset)

     ,.clear_i(nbf_word_clear)
     ,.up_i(nbf_word_up)
     ,.count_o(nbf_word_r)
     );
  wire nbf_last_word = (nbf_word_r == nbf_flits_lp-1);
  // a word sends when both address and data have sent
  wire nbf_word_send = (is_send & send_addr & send_data) | (is_addr & send_addr) | (is_data & send_data);
  // increment word counter when sending, except on last word
  assign nbf_word_up = ~nbf_last_word & nbf_word_send;
  // increment nbf counter when sending last word
  wire next_nbf = nbf_last_word & nbf_word_send;
  // clear word counter when sending last word
  assign nbf_word_clear = next_nbf;

  bsg_counter_clear_up
   #(.max_val_p(max_nbf_index_lp-1), .init_val_p(0))
   nbf_counter
    (.clk_i(m_axil_aclk)
     ,.reset_i(reset)

     ,.clear_i(1'b0)
     ,.up_i(next_nbf)
     ,.count_o(nbf_index_r)
     );

  // move to e_done when current NBF is a Finish command and the last word sends
  wire goto_done = is_nbf_finish & next_nbf;

  always_comb begin
    // stub read channel
    m_axil_araddr = '0;
    m_axil_arvalid = '0;
    m_axil_arprot = '0;
    m_axil_rready = 1'b1;

    // sink write responses
    m_axil_bready = 1'b1;

    m_axil_awvalid = 1'b0;
    m_axil_awaddr = nbf_host_addr_p;
    m_axil_awprot = '0;

    m_axil_wvalid = 1'b0;
    m_axil_wdata = curr_nbf_words[nbf_word_r];
    m_axil_wstrb = '1;

    // send address and data
    // send address
    // send data
    // done

    state_n = state_r;
    case (state_r)
      e_reset: begin
        state_n = reset ? state_r : e_send;
      end
      e_send: begin
        m_axil_awvalid = ~credits_full_lo;
        m_axil_wvalid = ~credits_full_lo;
        state_n = goto_done
                  ? e_done
                  : send_addr & send_data
                    ? e_send
                    : send_addr
                      ? e_data
                      : send_data
                        ? e_addr
                        : e_send;
      end
      e_addr: begin
        m_axil_awvalid = 1'b1;
        state_n = goto_done
                  ? e_done
                  : send_addr
                    ? e_send
                    : e_addr;
      end
      e_data: begin
        m_axil_wvalid = 1'b1;
        state_n = goto_done
                  ? e_done
                  : send_data
                    ? e_send
                    : e_addr;
      end
      e_done: begin
        // do nothing
      end
      default: begin
        // do nothing
      end
    endcase
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge m_axil_aclk) begin
    if (reset) begin
      state_r <= e_reset;
    end else begin
      state_r <= state_n;
    end
  end

endmodule

