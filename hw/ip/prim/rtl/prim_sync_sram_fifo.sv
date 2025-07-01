`include "prim_assert.sv"

module prim_sync_sram_fifo #(
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
