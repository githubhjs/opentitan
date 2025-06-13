// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Edge Detector

module jh_prim_edge_detector #(
  parameter int unsigned Width = 1,

  parameter logic [Width-1:0] ResetValue = '0,

  // EnSync
  //
  // Enable Synchronizer to the input signal.
  // It is assumed that the input signal is glitch free (registered input).
  parameter bit EnSync  = 1'b 1
) (
  input clk_p,
  input rst_n,

  input        [Width-1:0] d_i,
  output logic [Width-1:0] q_sync_o,

  output logic [Width-1:0] q_posedge_pulse_o,
  output logic [Width-1:0] q_negedge_pulse_o
);

  logic [Width-1:0] q_sync_d, q_sync_q;

  if (EnSync) begin : g_sync
    jh_prim_flop_2sync #(
      .Width (Width),
      .ResetValue (ResetValue)
    ) u_sync (
      .clk_p,
      .rst_n,
      .d_i,
      .q_o (q_sync_d)
    );
  end : g_sync
  else begin : g_nosync
    assign q_sync_d = d_i;
  end : g_nosync

  assign q_sync_o = q_sync_d;

  always_ff @(posedge clk_p or negedge rst_n) begin
    if (!rst_n) q_sync_q <= ResetValue;
    else         q_sync_q <= q_sync_d;
  end

  assign q_posedge_pulse_o = q_sync_d & ~q_sync_q;
  assign q_negedge_pulse_o = ~q_sync_d & q_sync_q;

endmodule : jh_prim_edge_detector
