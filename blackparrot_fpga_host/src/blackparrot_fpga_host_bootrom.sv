/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Name:
 *  blackparrot_fpga_host_bootrom.sv
 *
 * Description:
 *   This module implements a bootrom that is housed within the BP FPGA Host.
 *   Writes come from the FPGA Host NBF (from host software)
 *   Reads come from the FPGA Host MMIO (from BP).
 *
 *   Writes have priority over reads.
 *   w_i indicates a valid write request, and v_i indicates valid read request.
 *   v_i is not raised for writes.
 *   All requests are ack'd with a yumi_o signal on the port.
 *   Read data becomes valid the cycle following the read request ack and remains
 *   valid until r_yumi_i is raised.
 *
 */

`include "bsg_defines.sv"

module blackparrot_fpga_host_bootrom
 import bsg_axi_pkg::*;
 #(parameter bootrom_width_p = 64 // must be 64
   , parameter bootrom_els_p = 8192 // 64 KiB default
   , localparam bootrom_addr_width_lp = `BSG_SAFE_CLOG2(bootrom_els_p)
   )
  (input                                       clk_i
   , input                                     reset_i

   // read port
   , input                                     v_i
   , input [bootrom_addr_width_lp-1:0]         r_addr_i
   , output logic                              r_yumi_o
   , output logic [bootrom_width_p-1:0]        data_o
   , output logic                              v_o
   , input                                     r_yumi_i

   // write port
   , input                                     w_i
   , input [bootrom_addr_width_lp-1:0]         w_addr_i
   , input [bootrom_width_p-1:0]               data_i
   , input [(bootrom_width_p/8)-1:0]           w_mask_i
   , output logic                              w_yumi_o
   );

  // favor writes over reads
  logic bootrom_v, bootrom_w;
  logic [bootrom_addr_width_lp-1:0] bootrom_addr;

  assign bootrom_v = (v_i | w_i) & ~v_o;
  assign bootrom_w = w_i;
  assign bootrom_addr = w_i ? w_addr_i : r_addr_i;
  assign r_yumi_o = v_i & ~w_i & ~v_o;
  assign w_yumi_o = w_i & ~v_o;

  // v_o occurs cycle following r_yumi_o
  bsg_dff_reset_set_clear
    #(.width_p(1))
    valid_reg
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(r_yumi_o)
     ,.clear_i(r_yumi_i)
     ,.data_o(v_o)
     );

  // Bootrom
  bsg_mem_1rw_sync_mask_write_byte
    #(.data_width_p(bootrom_width_p)
      ,.els_p(bootrom_els_p)
      ,.latch_last_read_p(1)
      )
    bootrom_mem
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(bootrom_v)
     ,.w_i(bootrom_w)
     ,.addr_i(bootrom_addr)
     ,.data_i(data_i)
     ,.write_mask_i(w_mask_i)
     ,.data_o(data_o)
     );

endmodule
