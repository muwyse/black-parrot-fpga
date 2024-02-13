/*
 * Name:
 *  bp_nonsynth_axi_nbf_loader.sv
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

  localparam [M_AXIL_ADDR_WIDTH-1:0] nbf_resp_cnt_addr_lp = M_AXIL_ADDR_WIDTH'('h10);
  localparam [M_AXIL_ADDR_WIDTH-1:0] nbf_resp_addr_lp = M_AXIL_ADDR_WIDTH'('h14);

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
  wire is_nbf_read = curr_nbf.opcode == 8'h12;

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

  enum logic [4:0] {
    e_reset, e_send, e_addr, e_data, e_done
    ,e_read_count, e_read_count_resp, e_read_data, e_read_data_resp
  } state_n, state_r;
  wire is_send = (state_r == e_send);
  wire is_addr = (state_r == e_addr);
  wire is_data = (state_r == e_data);
  wire is_done = (state_r == e_done);
  assign done_o = is_done;

  // address and data sends
  wire send_addr = m_axil_awvalid & m_axil_awready;
  wire send_data = m_axil_wvalid & m_axil_wready;
  wire send_rd_addr = m_axil_arvalid & m_axil_arready;

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
  // move to e_read
  wire goto_read_count = is_nbf_read & next_nbf;

  always_comb begin

    // sink write responses
    m_axil_bready = 1'b1;

    m_axil_awvalid = 1'b0;
    m_axil_awaddr = nbf_host_addr_p;
    m_axil_awprot = '0;

    m_axil_wvalid = 1'b0;
    m_axil_wdata = curr_nbf_words[nbf_word_r];
    m_axil_wstrb = '1;

    m_axil_arvalid = 1'b0;
    m_axil_araddr = nbf_resp_cnt_addr_lp;
    m_axil_arprot = '0;

    m_axil_rready = 1'b0;

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
                  : goto_read_count
                    ? e_read_count
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
                  : goto_read_count
                    ? e_read_count
                    : send_addr
                      ? e_send
                      : e_addr;
      end
      e_data: begin
        m_axil_wvalid = 1'b1;
        state_n = goto_done
                  ? e_done
                  : goto_read_count
                    ? e_read_count
                    : send_data
                      ? e_send
                      : e_addr;
      end
      e_read_count: begin
        m_axil_araddr = nbf_resp_cnt_addr_lp;
        m_axil_arvalid = 1'b1;
        state_n = send_rd_addr ? e_read_count_resp : state_r;
      end
      e_read_count_resp: begin
        m_axil_rready = 1'b1;
        state_n = m_axil_rvalid
                  ? (m_axil_rdata > 'h0)
                    ? e_read_data
                    : e_read_count
                  : state_r;
      end
      e_read_data: begin
        m_axil_araddr = nbf_resp_addr_lp;
        m_axil_arvalid = 1'b1;
        state_n = send_rd_addr ? e_read_data_resp : state_r;
      end
      e_read_data_resp: begin
        m_axil_rready = 1'b1;
        state_n = m_axil_rvalid
                  ? e_send
                  : state_r;
      end
      e_done: begin
        // do nothing
      end
      default: begin
        // do nothing
      end
    endcase
  end

  localparam timeout_p = 10000;
  logic [`BSG_SAFE_CLOG2(timeout_p+1)-1:0] timeout_r;
  bsg_counter_clear_up
   #(.max_val_p(timeout_p), .init_val_p(0))
   nbf_timeout_counter
    (.clk_i(m_axil_aclk)
     ,.reset_i(reset)
     ,.clear_i(next_nbf)
     ,.up_i(1'b1)
     ,.count_o(timeout_r)
     );

  always_ff @(negedge m_axil_aclk) begin
    if ((m_axil_rvalid & m_axil_rready) && (state_r == e_read_data_resp)) begin
      $display("NBF read        : %x", m_axil_rdata);
    end
    if (next_nbf && (nbf_index_r % 10000 == 0)) begin
      $display("NBF heartbeat   : %d [%x] (%p)", nbf_index_r, curr_nbf, curr_nbf);
    end
    if (timeout_r == timeout_p) begin
      $display("timeout on loader writes");
      $finish();
    end
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

