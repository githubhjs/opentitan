// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "jh_prim_assert.svh"

module jh_prim_clock_div #(
  parameter int unsigned Divisor = 2,
  parameter logic ResetValue = 0
) (
  input clk_p,
  input rst_n,
  input step_down_req_i, // step down divisor by 2x
  output logic step_down_ack_o, // step down acknowledge
  input test_en_i,
  output logic clk_o
);


  // Only even divide is supported at the moment
  // For odd divide we need to introduce more parameters to control duty cycle
  `JH_ASSERT_INIT(DivEven_A, (Divisor % 2) == 0)

  // It is assumed the flops in this module are NOT on the scan-chain, as a result only
  // the input values are guarded
  logic step_down_req;
  assign step_down_req = test_en_i ? '0 : step_down_req_i;

  logic clk_pnt;

  if (Divisor == 2) begin : gen_div2
    logic q_p, q_n;

    jh_prim_flop # (
      .Width(1),
      .ResetValue(ResetValue)
    ) u_div2 (
      .clk_p,
      .rst_n,
      .d_i(q_n),
      .q_o(q_p)
    );

    jh_prim_clock_inv # (
      .HasScanMode(1'b0)
    ) u_inv (
      .clk_p(q_p),
      .scanmode_i('0),
      .clk_no(q_n)
    );

    logic step_down_nq;
    always_ff @(negedge clk_p or negedge rst_n) begin
      if (!rst_n) begin
        step_down_nq <= 1'b0;
      end else begin
        step_down_nq <= step_down_req;
      end
    end

    // make sure selection point is away from both edges
    jh_prim_clock_mux2 #(
      .NoFpgaBufG(1'b1)
    ) u_step_down_mux (
      .clk0_i(q_p),
      .clk1_i(clk_p),
      .sel_i(step_down_nq),
      .clk_o(clk_pnt)
    );

  assign step_down_ack_o = step_down_nq;

  end else begin : gen_div

    localparam int unsigned ToggleCnt = Divisor / 2;
    localparam int unsigned CntWidth = $clog2(ToggleCnt);
    logic [CntWidth-1:0] cnt;
    logic [CntWidth-1:0] limit;

    assign limit = !step_down_req       ? CntWidth'(ToggleCnt - 1) :
                   (ToggleCnt / 2) == 2 ? '0 : CntWidth'((ToggleCnt / 2) - 1);

    always_ff @(posedge clk_p or negedge rst_n) begin
      if (!rst_n) begin
        cnt <= '0;
        clk_pnt <= ResetValue;
      end else if (cnt >= limit) begin
        cnt <= '0;
        clk_pnt <= ~clk_o;
      end else begin
        cnt <= cnt + 1'b1;
      end
    end

    always_ff @(posedge clk_p or negedge rst_n) begin
      if (!rst_n) begin
        step_down_ack_o <= 1'b0;
      end else begin
        step_down_ack_o <= step_down_req;
      end
    end
  end

  // anchor points for constraints
  logic clk_muxed;
  jh_prim_clock_mux2 #(
    .NoFpgaBufG(1'b1)
  ) u_clk_mux (
    .clk0_i(clk_pnt),
    .clk1_i(clk_p),
    .sel_i('0),
    .clk_o(clk_muxed)
  );

  jh_prim_clock_buf u_clk_div_buf (
    .clk_p(clk_muxed),
    .clk_o
  );

endmodule
