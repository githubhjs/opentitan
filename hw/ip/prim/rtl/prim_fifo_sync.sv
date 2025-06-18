// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module prim_fifo_sync #(
  parameter int unsigned Width       = 16,
  parameter bit Pass                 = 1'b1,
  parameter int unsigned Depth       = 4,
  parameter bit OutputZeroIfEmpty    = 1'b1,
  parameter bit NeverClears          = 1'b0,
  parameter bit Secure               = 1'b0,
  localparam int          DepthW     = prim_util_pkg::vbits(Depth+1)
) (
  input                   clk_i,
  input                   rst_ni,
  input                   clr_i,
  input                   wvalid_i,
  output                  wready_o,
  input   [Width-1:0]     wdata_i,
  output                  rvalid_o,
  input                   rready_i,
  output  [Width-1:0]     rdata_o,
  output                  full_o,
  output  [DepthW-1:0]    depth_o,
  output                  err_o
);

  if (Depth == 0) begin : gen_passthru_fifo
    `ASSERT_INIT(paramCheckPass, Pass == 1)
    assign depth_o = 1'b0;
    assign rvalid_o = wvalid_i;
    assign rdata_o = wdata_i;
    assign wready_o = rready_i;
    assign full_o = 1'b1;
    assign err_o = 1'b0;

  end else if (Depth == 1) begin : gen_singleton_fifo

    logic full_d, full_q;
    assign full_o = full_q;
    assign depth_o = full_q;
    assign wready_o = ~full_q;

    logic rvalid_d, rvalid_q;
    assign rvalid_d = full_q || (Pass && wvalid_i);

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        full_q <= 1'b0;
        rvalid_q <= 1'b0;
      end else begin
        full_q <= (rvalid_q ? !rready_i : wvalid_i) && !clr_i;
        rvalid_q <= rvalid_d;
      end
    end

    logic [Width-1:0] storage;
    always_ff @(posedge clk_i) begin
      if (wvalid_i && wready_o) storage <= wdata_i;
    end

    logic [Width-1:0] rdata_int;
    assign rdata_int = (full_q || Pass == 1'b0) ? storage : wdata_i;
    assign rdata_o = (OutputZeroIfEmpty && !rvalid_q) ? Width'(0) : rdata_int;
    assign rvalid_o = rvalid_q;

    if (!Secure) begin : gen_not_secure
      assign err_o = 1'b0;
    end else begin : gen_secure
      logic inv_full;
      prim_flop #(.Width(1), .ResetValue(1'b1)) u_inv_full (
        .clk_i, .rst_ni, .d_i(~full_d), .q_o(inv_full)
      );
      logic err_d, err_q;
      assign err_d = ~(full_q ^ inv_full);
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) err_q <= 1'b0;
        else err_q <= err_d;
      end
      assign err_o = err_q;
    end

  end else begin : gen_normal_fifo

    localparam int unsigned PtrW = prim_util_pkg::vbits(Depth);

    logic [PtrW-1:0] fifo_wptr, fifo_rptr;
    logic fifo_incr_wptr, fifo_incr_rptr;
    logic fifo_empty, empty;

    logic under_rst;
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) under_rst <= 1'b1;
      else if (under_rst) under_rst <= ~under_rst;
    end

    assign wready_o = ~full_o & ~under_rst;

    prim_fifo_sync_cnt #(
      .Depth(Depth), .Secure(Secure), .NeverClears(NeverClears)
    ) u_fifo_cnt (
      .clk_i, .rst_ni, .clr_i,
      .incr_wptr_i(fifo_incr_wptr),
      .incr_rptr_i(fifo_incr_rptr),
      .wptr_o(fifo_wptr),
      .rptr_o(fifo_rptr),
      .full_o(full_o),
      .empty_o(fifo_empty),
      .depth_o(depth_o),
      .err_o(err_o)
    );

    assign fifo_incr_wptr = wvalid_i & wready_o;
    assign fifo_incr_rptr = rvalid_o & rready_i;

    logic [Depth-1:0][Width-1:0] storage;
    logic [Width-1:0] storage_rdata;
    assign storage_rdata = storage[fifo_rptr];

    always_ff @(posedge clk_i)
      if (fifo_incr_wptr)
        storage[fifo_wptr] <= wdata_i;

    logic [Width-1:0] rdata_int;
    assign rdata_int = (Pass && fifo_empty && wvalid_i) ? wdata_i : storage_rdata;
    assign empty = (Pass) ? (fifo_empty && ~wvalid_i) : fifo_empty;

    logic data_valid_d, data_valid_q;
    assign data_valid_d = (data_valid_q && !rready_i) || (wvalid_i && wready_o);

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) data_valid_q <= 1'b0;
      else if (clr_i) data_valid_q <= 1'b0;
      else data_valid_q <= data_valid_d;
    end

    assign rvalid_o = data_valid_q;
    assign rdata_o = (OutputZeroIfEmpty && empty) ? Width'(0) : rdata_int;

    `ASSERT(depthShallNotExceedParamDepth, !empty |-> depth_o <= DepthW'(Depth))
    `ASSERT(OnlyRvalidWhenNotUnderRst_A, rvalid_o -> ~under_rst)
  end

  if (NeverClears) begin : gen_never_clears
    `ASSERT(NeverClears_A, !clr_i)
  end

  `ASSERT_KNOWN_IF(DataKnown_A, rdata_o, rvalid_o)
  `ASSERT_KNOWN(DepthKnown_A, depth_o)
  `ASSERT_KNOWN(RvalidKnown_A, rvalid_o)
  `ASSERT_KNOWN(WreadyKnown_A, wready_o)

endmodule
