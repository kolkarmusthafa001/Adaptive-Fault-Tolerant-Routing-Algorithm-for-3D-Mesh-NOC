// ============================================================
//  switch_allocator.v
//  Round-Robin Switch Allocator
//  - Arbitrates N input ports competing for N output ports
//  - Separable allocator: iSLIP-inspired 1-round RR
//  - Generates congestion flags for health_monitor
//  - Low latency: 1-cycle grant
// ============================================================
`timescale 1ns/1ps

module switch_allocator #(
    parameter NUM_PORTS = 7   // E,W,N,S,Up,Dn,Local
)(
    input  wire                        clk,
    input  wire                        rst_n,
    // Request matrix: req[in_port] = one-hot out_port
    input  wire [NUM_PORTS-1:0]        req [0:NUM_PORTS-1],
    // Grant: grant[in_port] = one-hot out_port granted
    output reg  [NUM_PORTS-1:0]        grant [0:NUM_PORTS-1],
    // Congestion: an output port is congested if ≥2 inputs want it
    output reg  [NUM_PORTS-1:0]        congestion_flag
);

    // Round-robin pointers per output port
    reg [$clog2(NUM_PORTS)-1:0] rr_ptr [0:NUM_PORTS-1];

    integer op, ip, i;
    reg [NUM_PORTS-1:0] out_granted;  // track which outputs already granted
    reg [$clog2(NUM_PORTS)-1:0] cand;
    reg [NUM_PORTS-1:0] contention; // count requesters per output

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (op = 0; op < NUM_PORTS; op = op+1) begin
                grant[op]  <= 0;
                rr_ptr[op] <= op; // stagger initial pointers
            end
            congestion_flag <= 0;
        end else begin
            // Reset grants
            for (ip = 0; ip < NUM_PORTS; ip = ip+1)
                grant[ip] <= 0;

            out_granted = 0;

            // Phase 1: compute contention per output port
            for (op = 0; op < NUM_PORTS; op = op+1) begin
                contention[op] = 0;
                for (ip = 0; ip < NUM_PORTS; ip = ip+1)
                    if (req[ip][op]) contention[op] = contention[op] + 1;
            end
            congestion_flag <= (contention > 1) ? {NUM_PORTS{1'b1}} & contention : 0;

            // Phase 2: round-robin arbitration per output port
            for (op = 0; op < NUM_PORTS; op = op+1) begin
                if (!out_granted[op]) begin
                    for (i = 0; i < NUM_PORTS; i = i+1) begin
                        cand = (rr_ptr[op] + i) % NUM_PORTS;
                        if (req[cand][op] && !out_granted[op]) begin
                            grant[cand][op] <= 1'b1;
                            out_granted[op]  = 1'b1;
                            rr_ptr[op]      <= (cand + 1) % NUM_PORTS;
                        end
                    end
                end
            end
        end
    end

endmodule
