/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Name:
 *  bp_nonsynth_axi_host.sv
 *
 * Description:
 *  This module polls the BP MMIO out buffers using M_AXIL read channel.
 *  It can respond to limited reads using M_AXIL write channel to send
 *  responses to the MMIO response buffer (offset 0x4)
 *
 */

`include "bsg_defines.sv"

module bp_nonsynth_axi_host
  import bp_common_pkg::*;
  #(parameter M_AXIL_ADDR_WIDTH = 64
   ,parameter M_AXIL_DATA_WIDTH = 32 // must be 32
   ,parameter M_AXIL_CREDITS = 64
   ,parameter timeout_p = 10000
   ,parameter logic [63:0] mmio_in_host_addr_p = 64'h4
   ,parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
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

   ,input logic                              en_i
   ,output logic                             done_o
   );

  wire reset = ~m_axil_aresetn;

  // M_AXIL R buffer
  logic resp_v, resp_yumi;
  logic [M_AXIL_DATA_WIDTH-1:0] resp_data;
  bsg_two_fifo
    #(.width_p(M_AXIL_DATA_WIDTH))
    read_fifo
     (.clk_i(m_axil_aclk)
      ,.reset_i(reset)
      ,.v_i(m_axil_rvalid)
      ,.ready_param_o(m_axil_rready)
      ,.data_i(m_axil_rdata)
      ,.data_o(resp_data)
      ,.v_o(resp_v)
      ,.yumi_i(resp_yumi)
      );

  // credit flow control
  logic [`BSG_WIDTH(M_AXIL_CREDITS)-1:0] credit_count_lo;
  bsg_flow_counter
   #(.els_p(M_AXIL_CREDITS))
   mmio_fc
    (.clk_i(m_axil_aclk)
     ,.reset_i(reset)

     ,.v_i(m_axil_arvalid)
     ,.ready_param_i(m_axil_arready)

     ,.yumi_i(m_axil_rvalid & m_axil_rready)
     ,.count_o(credit_count_lo)
     );
  wire credits_full_lo = (credit_count_lo == M_AXIL_CREDITS);
  wire credits_empty_lo = (credit_count_lo == '0);

  // SIPO for MMIO commands from FPGA Host
  // The polling FSM will enqueue (addr, data) pairs into this SIPO
  logic sipo_v_li, sipo_ready_and_lo;
  logic sipo_v_lo, sipo_yumi_li;
  logic [1:0][M_AXIL_DATA_WIDTH-1:0] sipo_data_lo;
  bsg_serial_in_parallel_out_full
    #(.width_p(M_AXIL_DATA_WIDTH)
      ,.els_p(2)
      )
    mmio_sipo
     (.clk_i(m_axil_aclk)
      ,.reset_i(reset)
      ,.v_i(sipo_v_li)
      ,.data_i(resp_data)
      ,.ready_and_o(sipo_ready_and_lo)
      ,.v_o(sipo_v_lo)
      ,.data_o(sipo_data_lo)
      ,.yumi_i(sipo_yumi_li)
      );

  enum logic [2:0] {
    e_reset
    ,e_poll
    ,e_poll_resp
    ,e_read_addr
    ,e_read_data
    ,e_read_addr_resp
    ,e_read_data_resp
    } poll_state_n, poll_state_r;

  wire send_addr = m_axil_arvalid & m_axil_arready;
  wire req_cnt_v = (resp_data >= 'd2);

  // MMIO Poll FSM: poll the MMIO request channel in the FPGA Host
  // This FSM never terminates. It repeatedly polls the request buffer count register
  // and if there are at least two entries, it reads the first two elements, which
  // are an (addr, data) tuple representing an MMIO command issued by a BP core to the
  // MMIO host. The (addr, data) tuple is forwarded into the MMIO SIPO in this module
  // which has its output immediately sunk. Per-core finish bits are set on finish commands.
  // Nonsynth monitoring logic will print out putchar requests from the BP cores.
  // The testbench should call the $finish() task when after this module raises done_o.
  localparam [M_AXIL_ADDR_WIDTH-1:0] mmio_req_cnt_addr_lp = M_AXIL_ADDR_WIDTH'('h8);
  localparam [M_AXIL_ADDR_WIDTH-1:0] mmio_req_addr_lp = M_AXIL_ADDR_WIDTH'('hC);
  always_comb begin
    m_axil_araddr = '0;
    m_axil_arvalid = '0;
    m_axil_arprot = '0;

    resp_yumi = 1'b0;

    sipo_v_li = 1'b0;

    poll_state_n = poll_state_r;
    case (poll_state_r)
      e_reset: begin
        poll_state_n = reset ? poll_state_r : e_poll;
      end
      // check the number of elements in mmio buffer
      e_poll: begin
        m_axil_araddr = mmio_req_cnt_addr_lp;
        m_axil_arvalid = ~credits_full_lo;
        poll_state_n = send_addr ? e_poll_resp : poll_state_r;
      end
      e_poll_resp: begin
        resp_yumi = resp_v;
        poll_state_n = resp_v
                       ? req_cnt_v
                         ? e_read_addr
                         : e_poll
                       : poll_state_r;
      end
      // initiate two reads from mmio buffers
      e_read_addr: begin
        m_axil_araddr = mmio_req_addr_lp;
        m_axil_arvalid = ~credits_full_lo;
        poll_state_n = send_addr ? e_read_data : poll_state_r;
      end
      e_read_data: begin
        m_axil_araddr = mmio_req_addr_lp;
        m_axil_arvalid = ~credits_full_lo;
        poll_state_n = send_addr ? e_read_addr_resp : poll_state_r;
      end
      // forward address to SIPO
      e_read_addr_resp: begin
        sipo_v_li = resp_v;
        resp_yumi = sipo_v_li & sipo_ready_and_lo;
        poll_state_n = resp_yumi ? e_read_data_resp : poll_state_r;
      end
      // forward data to SIPO
      e_read_data_resp: begin
        sipo_v_li = resp_v;
        resp_yumi = sipo_v_li & sipo_ready_and_lo;
        poll_state_n = resp_yumi ? e_poll : poll_state_r;
      end
      default: begin
        // do nothing
      end
    endcase
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge m_axil_aclk) begin
    if (reset | ~en_i) begin
      poll_state_r <= e_reset;
    end else begin
      poll_state_r <= poll_state_n;
    end
  end


  // CMD processing
  // split MMIO request into address and data
  wire [M_AXIL_DATA_WIDTH-1:0] cmd_addr = {{(32-dev_addr_width_gp)'(1'b0)}, sipo_data_lo[0][0+:dev_addr_width_gp]};
  wire [M_AXIL_DATA_WIDTH-1:0] cmd_data = sipo_data_lo[1];

  // determine MMIO request
  wire putchar_w_v_li = sipo_v_lo & (cmd_addr inside {putchar_match_addr_gp});
  wire putch_core_w_v_li = sipo_v_lo & (cmd_addr inside {putch_core_match_addr_gp});
  wire finish_w_v_li = sipo_v_lo & (cmd_addr inside {finish_match_addr_gp});

  // MMIO reads
  wire paramrom_addr_match_li = (cmd_addr inside {paramrom_match_addr_gp});
  wire paramrom_r_v_li = sipo_v_lo & paramrom_addr_match_li;
  wire paramrom_cc_x_dim = (cmd_addr[0+:12] & 12'hFFF) == 12'h000;
  wire paramrom_cc_y_dim = (cmd_addr[0+:12] & 12'hFFF) == 12'h004;

  typedef enum logic[1:0] {
    e_resp_ready
    ,e_resp_send_addr
    ,e_resp_send_data
  } resp_state_e;
  resp_state_e resp_state_r, resp_state_n;

  logic resp_sipo_yumi_li;
  assign sipo_yumi_li = resp_sipo_yumi_li | (sipo_v_lo & ~paramrom_addr_match_li);

  always_comb begin
    resp_sipo_yumi_li = 1'b0;

    m_axil_awaddr = mmio_in_host_addr_p;
    m_axil_awvalid = 1'b0;
    m_axil_awprot = '0;

    m_axil_wdata = 1'b0;
    m_axil_wdata = (paramrom_cc_x_dim)
                   ? num_core_p
                   : (paramrom_cc_y_dim)
                     ? 1
                     : 0;
    m_axil_wvalid = 1'b0;
    m_axil_wstrb = '1;

    // sink all write responses, unconditionally
    m_axil_bready = 1'b1;

    resp_state_n = resp_state_r;
    case (resp_state_r)
      e_resp_ready: begin
        m_axil_awvalid = paramrom_r_v_li;
        m_axil_wvalid = paramrom_r_v_li;
        resp_sipo_yumi_li = m_axil_wvalid & m_axil_wready & m_axil_awvalid & m_axil_awready;
        resp_state_n = resp_sipo_yumi_li
                       ? resp_state_r
                       : (m_axil_awvalid & m_axil_awready)
                         ? e_resp_send_data
                         : (m_axil_wvalid & m_axil_wready)
                           ? e_resp_send_addr
                           : resp_state_r;
      end
      e_resp_send_addr: begin
        m_axil_awvalid = paramrom_r_v_li;
        resp_sipo_yumi_li = m_axil_awvalid & m_axil_awready;
        resp_state_n = resp_sipo_yumi_li ? e_resp_ready : resp_state_r;
      end
      e_resp_send_data: begin
        m_axil_wvalid = paramrom_r_v_li;
        resp_sipo_yumi_li = m_axil_wvalid & m_axil_wready;
        resp_state_n = resp_sipo_yumi_li ? e_resp_ready : resp_state_r;
      end
      default: begin
        // do nothing
      end
    endcase
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge m_axil_aclk) begin
    if (reset | ~en_i) begin
      resp_state_r <= e_resp_ready;
    end else begin
      resp_state_r <= resp_state_n;
    end
  end


  // extract core ID from MMIO address
  localparam byte_offset_width_lp = 3;
  localparam lg_num_core_lp = `BSG_SAFE_CLOG2(num_core_p);
  wire [lg_num_core_lp-1:0] addr_core_enc = cmd_addr[byte_offset_width_lp+:lg_num_core_lp];

  // finish tracking
  logic [num_core_p-1:0] finish_r;
  wire [num_core_p-1:0] finish_set = finish_w_v_li ? (1'b1 << addr_core_enc) : '0;
  bsg_dff_reset_set_clear
    #(.width_p(num_core_p))
    finish_reg
     (.clk_i(m_axil_aclk)
      ,.reset_i(reset)
      ,.set_i(finish_set)
      ,.clear_i('0)
      ,.data_o(finish_r)
      );
  assign done_o = &(finish_r);

  integer tmp;
  integer stdout[num_core_p];
  integer stdout_global;

  always_ff @(negedge reset) begin
    for (integer j = 0; j < num_core_p; j++) begin
      tmp = $fopen($sformatf("stdout_%0x.txt", j), "w");
      stdout[j] = tmp;
    end
    stdout_global = $fopen("stdout_global.txt", "w");
  end

  integer ret;
  always_ff @(negedge m_axil_aclk) begin
    if (putchar_w_v_li) begin
      $write("%c", cmd_data[0+:8]);
      $fwrite(stdout_global, "%c", cmd_data[0+:8]);
    end

    if (putch_core_w_v_li) begin
      $write("%c", cmd_data[0+:8]);
      $fwrite(stdout[addr_core_enc], "%c", cmd_data[0+:8]);
    end

    for (integer i = 0; i < num_core_p; i++) begin
      // PASS when returned value in finish packet is zero
      if (finish_set[i] & (cmd_data[0+:8] == 8'(0)))
        $display("[CORE%0x FSH] PASS", i);
      // FAIL when returned value in finish packet is non-zero
      if (finish_set[i] & (cmd_data[0+:8] != 8'(0)))
        $display("[CORE%0x FSH] FAIL", i);
    end

    if (&finish_r) begin
      $display("All cores finished!");
    end
  end

  final begin
    $fclose(stdout_global);
    for (integer j = 0; j < num_core_p; j++) begin
      $fclose(stdout[j]);
    end
    $system("stty echo");
  end

  bp_nonsynth_if_monitor
    #(.timeout_p(timeout_p)
     ,.els_p(2)
     ,.dev_p("host")
     )
    m_axil_timeout
     (.clk_i(m_axil_aclk)
     ,.reset_i(reset)
     ,.en_i(~done_o)
     ,.v_i({m_axil_arvalid, m_axil_rvalid})
     ,.ready_and_i({m_axil_arready, m_axil_rready})
     );

endmodule

