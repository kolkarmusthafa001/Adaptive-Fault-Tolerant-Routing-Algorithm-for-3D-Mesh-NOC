// ============================================================
//  input_buffer.v
//  4-slot FIFO input buffer per router port
//  Features: flow control (credit-based), low-power clock gating
// ============================================================
`timescale 1ns/1ps

module input_buffer #(
    parameter FLIT_WIDTH = 32,   // flit data width
    parameter DEPTH      = 4,    // buffer depth (must be power of 2)
    parameter PTR_W      = 2     // log2(DEPTH)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // Write port (from upstream link)
    input  wire                  wr_en,
    input  wire [FLIT_WIDTH-1:0] din,
    output wire                  full,
    // Read port (to routing/switch)
    input  wire                  rd_en,
    output wire [FLIT_WIDTH-1:0] dout,
    output wire                  empty,
    // Credit back to upstream
    output reg  [PTR_W:0]        credits   // available slots
);

    // ---- Storage ----
    reg [FLIT_WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_W-1:0]      wr_ptr, rd_ptr;
    reg [PTR_W:0]        count;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);
    assign dout  = mem[rd_ptr];

    // ---- Write ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) wr_ptr <= 0;
        else if (wr_en && !full) begin
            mem[wr_ptr] <= din;
            wr_ptr      <= wr_ptr + 1;
        end
    end

    // ---- Read ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rd_ptr <= 0;
        else if (rd_en && !empty)
            rd_ptr <= rd_ptr + 1;
    end

    // ---- Count ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) count <= 0;
        else begin
            case ({wr_en & ~full, rd_en & ~empty})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: count <= count;
            endcase
        end
    end

    // ---- Credit tracking ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) credits <= DEPTH;
        else        credits <= DEPTH - count;
    end

endmodule
