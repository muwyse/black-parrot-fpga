/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * AXI4 interface
 */

interface AXI4
  #(parameter AXI_ADDR_WIDTH = 64
    ,parameter AXI_DATA_DITH = 64
    ,parameter AXI_ID_WIDTH = 1
  )
  (
  input logic aclk
  ,input logic aresetn
  );

  // AW
  logic [AXI_ADDR_WIDTH-1:0]       awaddr;
  logic                            awvalid;
  logic                            awready;
  logic [AXI_ID_WIDTH-1:0]         awid;
  logic                            awlock;
  logic [3:0]                      awcache;
  logic [2:0]                      awprot;
  logic [7:0]                      awlen;
  logic [2:0]                      awsize;
  logic [1:0]                      awburst;
  logic [3:0]                      awqos;
  logic [3:0]                      awregion;

  // W
  logic [AXI_DATA_WIDTH-1:0]       wdata;
  logic                            wvalid;
  logic                            wready;
  logic                            wlast;
  logic [(AXI_DATA_WIDTH/8)-1:0]   wstrb;

  // B
  logic                            bvalid;
  logic                            bready;
  logic [AXI_ID_WIDTH-1:0]         bid;
  logic [1:0]                      bresp;

  // AR
  logic [AXI_ADDR_WIDTH-1:0]       araddr;
  logic                            arvalid;
  logic                            arready;
  logic [AXI_ID_WIDTH-1:0]         arid;
  logic                            arlock;
  logic [3:0]                      arcache;
  logic [2:0]                      arprot;
  logic [7:0]                      arlen;
  logic [2:0]                      arsize;
  logic [1:0]                      arburst;
  logic [3:0]                      arqos;
  logic [3:0]                      arregion;

  // R
  logic [AXI_DATA_WIDTH-1:0]       rdata;
  logic                            rvalid;
  logic                            rready;
  logic [AXI_ID_WIDTH-1:0]         rid;
  logic                            rlast;
  logic [1:0]                      rresp;

  modport Manager (
    input aclk, aresetn,
    output awaddr, awvalid, awid, awlock, awcache, awprot, awlen, awsize, awburst, awqos, awregion,
    input awready,
    output wdata, wvalid, wlast, wstrb,
    input wready,
    input bvalid, bid, bresp,
    output bready,
    output araddr, arvalid, arid, arlock, arcache, arprot, arlen, arsize, arburst, arqos, arregion,
    input arready,
    input rdata, rvalid, rid, rlast, rresp
    output rready
  );

  modport Subordinate (
    input aclkn, aresetn,
    input awaddr, awvalid, awid, awlock, awcache, awprot, awlen, awsize, awburst, awqos, awregion,
    output awready,
    input wdata, wvalid, wlast, wstrb,
    output wready,
    output bvalid, bid, bresp,
    input bready,
    input araddr, arvalid, arid, arlock, arcache, arprot, arlen, arsize, arburst, arqos, arregion,
    output arready,
    output rdata, rvalid, rid, rlast, rresp
    input rready
  );

  modport Monitor (
    input aclkn, aresetn,
    input awaddr, awvalid, awid, awlock, awcache, awprot, awlen, awsize, awburst, awqos, awregion,
    input awready,
    input wdata, wvalid, wlast, wstrb,
    input wready,
    input bvalid, bid, bresp,
    input bready,
    input araddr, arvalid, arid, arlock, arcache, arprot, arlen, arsize, arburst, arqos, arregion,
    input arready,
    input rdata, rvalid, rid, rlast, rresp
    input rready
  );

  // verification tasks

  //synthesis translate_off
  //synthesis translate_on

endinterface: AXI4
