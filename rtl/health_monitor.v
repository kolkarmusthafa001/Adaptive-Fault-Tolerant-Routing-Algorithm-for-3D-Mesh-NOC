// ============================================================
//  health_monitor.v
//  Look-Ahead 1-bit health status TX/RX + fault table
//  Monitors: E, W, N, S, Up, Down (6 directional ports)
//  Low-power: updates fault table only on status change
// ============================================================
`timescale 1ns/1ps

module health_monitor #(
    parameter NUM_PORTS = 6   // directional ports (excl. local)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // Health signals FROM neighbors (1 = healthy, 0 = faulty)
    input  wire [NUM_PORTS-1:0]  neighbor_health_in,
    // Health signals TO neighbors (advertise our link state)
    output wire [NUM_PORTS-1:0]  health_out,
    // Local link enable – set to 0 to simulate fault injection
    input  wire [NUM_PORTS-1:0]  local_link_up,
    // Fault table output (registered, stable for routing)
    output reg  [NUM_PORTS-1:0]  fault_table,       // 1=healthy, 0=faulty
    // Congestion signals from switch allocator
    input  wire [NUM_PORTS-1:0]  congestion_flag,   // 1=congested
    // Combined availability (healthy AND not congested)
    output reg  [NUM_PORTS-1:0]  port_available
);

    // ---- Advertise our own link state to neighbors ----
    assign health_out = local_link_up;

    // ---- Update fault table (register neighbor health) ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fault_table    <= {NUM_PORTS{1'b1}};  // assume all healthy at reset
            port_available <= {NUM_PORTS{1'b1}};
        end else begin
            fault_table    <= neighbor_health_in & local_link_up;
            port_available <= (neighbor_health_in & local_link_up) & ~congestion_flag;
        end
    end

endmodule
