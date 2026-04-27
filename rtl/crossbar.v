// ============================================================
//  crossbar.v
//  7x7 Non-Blocking Crossbar Switch Fabric
//  - Pure combinational (zero added latency)
//  - Mux-based implementation (synthesises to LUTs efficiently)
//  - One output can be driven by at most one input (guaranteed
//    by switch_allocator before crossbar is invoked)
// ============================================================
`timescale 1ns/1ps

module crossbar #(
    parameter FLIT_WIDTH = 32,
    parameter NUM_PORTS  = 7
)(
    // Input flits from all input buffers
    input  wire [FLIT_WIDTH-1:0] in_data  [0:NUM_PORTS-1],
    input  wire                  in_valid [0:NUM_PORTS-1],
    // Switch grant matrix from switch_allocator
    // grant[in][out] — one-hot per output
    input  wire [NUM_PORTS-1:0]  grant    [0:NUM_PORTS-1],
    // Output flits to output links
    output reg  [FLIT_WIDTH-1:0] out_data  [0:NUM_PORTS-1],
    output reg                   out_valid [0:NUM_PORTS-1]
);

    integer op, ip;

    always @(*) begin
        for (op = 0; op < NUM_PORTS; op = op+1) begin
            out_data[op]  = 0;
            out_valid[op] = 0;
            for (ip = 0; ip < NUM_PORTS; ip = ip+1) begin
                if (grant[ip][op] && in_valid[ip]) begin
                    out_data[op]  = in_data[ip];
                    out_valid[op] = 1'b1;
                end
            end
        end
    end

endmodule
