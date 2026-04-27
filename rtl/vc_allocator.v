// ============================================================
//  vc_allocator.v
//  2-VC Virtual Channel Allocator
//  VC0 = positive-dimension packets (deadlock-safe class 0)
//  VC1 = negative-dimension packets (deadlock-safe class 1)
//  Separation enforces negative-first and prevents deadlock cycles.
//  Uses round-robin arbitration for fairness.
// ============================================================
`timescale 1ns/1ps

module vc_allocator #(
    parameter NUM_PORTS = 7,
    parameter NUM_VC    = 2
)(
    input  wire                           clk,
    input  wire                           rst_n,
    // VC request: req[port][vc]
    input  wire [NUM_PORTS*NUM_VC-1:0]    vc_req,
    // Granted VC: grant[port][vc] (one-hot per port)
    output reg  [NUM_PORTS*NUM_VC-1:0]    vc_grant,
    // VC occupancy (from input buffers)
    input  wire [NUM_PORTS*NUM_VC-1:0]    vc_occupied
);

    integer p, v;
    reg [NUM_VC-1:0] rr_ptr [0:NUM_PORTS-1];  // round-robin pointer per port

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vc_grant <= 0;
            for (p = 0; p < NUM_PORTS; p = p+1)
                rr_ptr[p] <= 0;
        end else begin
            vc_grant <= 0;
            for (p = 0; p < NUM_PORTS; p = p+1) begin
                // Round-robin among VCs for this port
                begin : vc_arb
                    integer i;
                    reg found;
                    found = 0;
                    for (i = 0; i < NUM_VC && !found; i = i+1) begin
                        v = (rr_ptr[p] + i) % NUM_VC;
                        if (vc_req[p*NUM_VC + v] && !vc_occupied[p*NUM_VC + v]) begin
                            vc_grant[p*NUM_VC + v] <= 1'b1;
                            rr_ptr[p] <= (v + 1) % NUM_VC;
                            found = 1;
                        end
                    end
                end
            end
        end
    end

endmodule
