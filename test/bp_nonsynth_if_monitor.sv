/*
 * Name:
 *  bp_nonsynth_if_monitor.sv
 *
 * Description:
 *  This module monitors for timeouts on interfaces.
 */

`include "bsg_defines.sv"

module bp_nonsynth_if_monitor
  #(parameter timeout_p = 10000
   ,parameter els_p = 1
   ,parameter dev_p = "if"
   )
  (
   input logic               clk_i
   ,input logic              reset_i
   ,input logic              en_i
   ,input logic [els_p-1:0]  v_i
   ,input logic [els_p-1:0]  ready_and_i
   );

  logic [els_p-1:0][`BSG_SAFE_CLOG2(timeout_p+1)-1:0] timeout_r;
  logic [els_p-1:0] timeout;

  genvar i;
  generate
    for (i = 0; i < els_p; i++) begin
      bsg_counter_clear_up
       #(.max_val_p(timeout_p), .init_val_p(0))
       timeout_counter
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.clear_i(v_i[i] & ready_and_i[i])
         ,.up_i(v_i[i] & ~ready_and_i[i])
         ,.count_o(timeout_r[i])
         );
      assign timeout[i] = en_i & timeout_r[i] == timeout_p;
      always_ff @(negedge clk_i) begin
        if (timeout[i]) begin
          $display("%s: timeout[%d] detected", dev_p, i);
          $finish();
        end
      end
    end
  endgenerate

endmodule

