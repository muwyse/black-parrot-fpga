/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Name:
 *  bsg_nonsynth_axi_mem_tracer.sv
 *
 * Description:
 *  This module traces reads and writes in bsg_nonsynth_axi_mem.sv
 */

`include "bsg_defines.sv"

module bsg_nonsynth_axi_mem_tracer
  #(parameter axi_addr_width_p = 64
   ,parameter axi_data_width_p = 64
   ,parameter mem_els_p = 64
   ,parameter trace_file_p = "mem"

   ,localparam lg_mem_els_lp = `BSG_SAFE_CLOG2(mem_els_p)
   ,localparam axi_strb_width_lp = (axi_data_width_p>>3)
   )
  (
   input logic               clk_i
   ,input logic              reset_i

   ,input logic                         wr_v_i
   ,input logic [lg_mem_els_lp-1:0]     wr_idx_i
   ,input logic [axi_data_width_p-1:0]  wr_data_raw_i
   ,input logic [axi_data_width_p-1:0]  wr_data_i

   ,input logic                         rd_v_i
   ,input logic [lg_mem_els_lp-1:0]     rd_idx_i
   ,input logic [axi_data_width_p-1:0]  rd_data_i

   );

  integer file;
  string file_name;

  wire delay_li = reset_i;
  always_ff @(negedge delay_li)
    begin
      file_name = $sformatf("%s.trace", trace_file_p);
      file      = $fopen(file_name, "w");
    end

  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (wr_v_i) begin
        $fdisplay(file, "%16t WR %d %H %H"
                  ,$time
                  ,wr_idx_i
                  ,wr_data_raw_i
                  ,wr_data_i
                  );
      end
      if (rd_v_i) begin
        $fdisplay(file, "%16t RD %d %H"
                  ,$time
                  ,rd_idx_i
                  ,rd_data_i
                  );
      end
    end
  end

endmodule

