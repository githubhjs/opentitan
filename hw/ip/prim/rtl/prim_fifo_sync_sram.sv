// Author: HUANGJS@gmail.com //
`include "prim_assert.sv"

module prim_fifo_sync_sram #(
  parameter int unsigned SramDw = 32,
  parameter int unsigned SramAw = 12,
  parameter int unsigned Depth = 16
)(
  input  logic               clk_i,
  input  logic               rst_ni,

  // Write interface
  input  logic               wr_en_i,
  input  logic [SramDw-1:0] wr_data_i,
  output logic              wr_ready_o,

  // Read interface
  input  logic               rd_en_i,
  output logic [SramDw-1:0] rd_data_o,
  output logic              rd_valid_o,

  // SRAM interface
  output logic              sram_req_o,
  output logic              sram_write_o,
  output logic [SramAw-1:0] sram_addr_o,
  output logic [SramDw-1:0] sram_wdata_o,
  input  logic [SramDw-1:0] sram_rdata_i,
  input  logic              sram_rvalid_i
);

  logic [SramAw-1:0] wr_ptr, rd_ptr;
  logic fifo_full, fifo_empty;
  logic [SramAw:0] depth;

  logic incr_wr_ptr, incr_rd_ptr;

  prim_fifo_sync_cnt #(
    .Depth(1 << SramAw),
    .Secure(1'b0),
    .NeverClears(1'b1)
  ) u_ptr_cnt (
    .clk_i,
    .rst_ni,
    .clr_i(1'b0),
    .incr_wptr_i(incr_wr_ptr),
    .incr_rptr_i(incr_rd_ptr),
    .wptr_o(wr_ptr),
    .rptr_o(rd_ptr),
    .full_o(fifo_full),
    .empty_o(fifo_empty),
    .depth_o(depth),
    .err_o()
  );

  assign wr_ready_o = !fifo_full;

  assign incr_wr_ptr = wr_en_i && !fifo_full;
  assign incr_rd_ptr = sram_rvalid_i && rd_en_i && !fifo_empty;

  assign sram_write_o = incr_wr_ptr;
  assign sram_req_o   = incr_wr_ptr || (rd_en_i && !fifo_empty);
  assign sram_wdata_o = wr_data_i;
  assign sram_addr_o  = incr_wr_ptr ? wr_ptr : rd_ptr;

  assign rd_valid_o = sram_rvalid_i && rd_en_i && !fifo_empty;
  assign rd_data_o  = sram_rdata_i;

endmodule

`ifdef tb_prim_fifo_sync_sram
`timescale 1ns/1ps

module tb_prim_fifo_sync_sram;
  parameter SramDw = 32;
  parameter SramAw = 4;
  parameter Depth  = 16;

  logic clk;
  logic rst_n;

  logic               wr_en;
  logic [SramDw-1:0]  wr_data;
  logic               wr_ready;

  logic               rd_en;
  logic [SramDw-1:0]  rd_data;
  logic               rd_valid;

  logic               sram_req;
  logic               sram_write;
  logic [SramAw-1:0]  sram_addr;
  logic [SramDw-1:0]  sram_wdata;
  logic [SramDw-1:0]  sram_rdata;
  logic               sram_rvalid;

  // Simulated SRAM storage
  logic [SramDw-1:0] sram_mem [0:(1 << SramAw)-1];

  // Clock generation
  always #5 clk = ~clk;

  // DUT
  prim_fifo_sync_sram #(
    .SramDw(SramDw),
    .SramAw(SramAw),
    .Depth (Depth)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .wr_en_i(wr_en),
    .wr_data_i(wr_data),
    .wr_ready_o(wr_ready),
    .rd_en_i(rd_en),
    .rd_data_o(rd_data),
    .rd_valid_o(rd_valid),
    .sram_req_o(sram_req),
    .sram_write_o(sram_write),
    .sram_addr_o(sram_addr),
    .sram_wdata_o(sram_wdata),
    .sram_rdata_i(sram_rdata),
    .sram_rvalid_i(sram_rvalid)
  );

  // SRAM behavior
  always_ff @(posedge clk) begin
    if (sram_req && sram_write) begin
      sram_mem[sram_addr] <= sram_wdata;
      sram_rvalid <= 0;
    end else if (sram_req && !sram_write) begin
      sram_rdata <= sram_mem[sram_addr];
      sram_rvalid <= 1;
    end else begin
      sram_rvalid <= 0;
    end
  end

  initial begin
    clk = 0;
    rst_n = 0;
    wr_en = 0;
    wr_data = 0;
    rd_en = 0;
    sram_rdata = 0;
    sram_rvalid = 0;

    repeat (5) @(posedge clk);
    rst_n = 1;

    // Write data
    for (int i = 0; i < 10; i++) begin
      @(posedge clk);
      wr_en = 1;
      wr_data = i;
      wait (wr_ready);
    end
    @(posedge clk);
    wr_en = 0;

    // Read data
    for (int i = 0; i < 10; i++) begin
      @(posedge clk);
      rd_en = 1;
      wait (rd_valid);
      $display("Read data: %0d", rd_data);
    end
    @(posedge clk);
    rd_en = 0;

    $finish;
  end

endmodule
`endif
