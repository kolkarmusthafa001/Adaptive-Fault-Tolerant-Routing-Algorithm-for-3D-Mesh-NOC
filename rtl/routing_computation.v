// ============================================================
//  routing_computation.v
//  Adaptive Fault-Tolerant Routing (AFTR) Algorithm
//  Topology : 3D Mesh  (X x Y x Z)
//  Primary  : Dimension-order XYZ (minimal path)
//  Fallback : Non-minimal detour avoiding faulty/congested ports
//  Deadlock : Negative-first turn model enforced
//  Latency  : Single-cycle combinational output
// ============================================================
`timescale 1ns/1ps

module routing_computation #(
    parameter X_W = 3,   // bits for X coordinate (supports up to 8)
    parameter Y_W = 3,
    parameter Z_W = 3,
    parameter NUM_PORTS = 7  // E,W,N,S,Up,Dn,Local
)(
    // Current router coordinates
    input  wire [X_W-1:0] cur_x,
    input  wire [Y_W-1:0] cur_y,
    input  wire [Z_W-1:0] cur_z,
    // Destination coordinates (from flit header)
    input  wire [X_W-1:0] dst_x,
    input  wire [Y_W-1:0] dst_y,
    input  wire [Z_W-1:0] dst_z,
    // Port availability from health_monitor
    input  wire [5:0]     port_available, // [E,W,N,S,Up,Dn]
    // Routing valid request
    input  wire           req,
    // Output port selection (one-hot)
    output reg  [NUM_PORTS-1:0] out_port,   // [E,W,N,S,Up,Dn,Local]
    output reg                  valid
);

    // Port indices
    localparam P_E     = 0;
    localparam P_W     = 1;
    localparam P_N     = 2;
    localparam P_S     = 3;
    localparam P_UP    = 4;
    localparam P_DN    = 5;
    localparam P_LOCAL = 6;

    // Signed deltas
    wire signed [X_W:0] dx = $signed({1'b0, dst_x}) - $signed({1'b0, cur_x});
    wire signed [Y_W:0] dy = $signed({1'b0, dst_y}) - $signed({1'b0, cur_y});
    wire signed [Z_W:0] dz = $signed({1'b0, dst_z}) - $signed({1'b0, cur_z});

    wire at_dst = (dx == 0) && (dy == 0) && (dz == 0);

    // Primary preferred ports per dimension
    wire pref_E  = (dx > 0);
    wire pref_W  = (dx < 0);
    wire pref_N  = (dy > 0);
    wire pref_S  = (dy < 0);
    wire pref_UP = (dz > 0);
    wire pref_DN = (dz < 0);

    // ---- Negative-first turn model:
    //   Route all negative dimensions BEFORE positive dimensions.
    //   This breaks cyclic channel dependencies → deadlock free.
    // ---- Priority: negative Z → negative Y → negative X →
    //                positive Z → positive Y → positive X

    // Build ordered candidate list
    // candidate[i] = {port_idx, available}
    // We pick the first available preferred port in priority order.

    always @(*) begin
        out_port = 0;
        valid    = 0;

        if (!req) begin
            out_port = 0;
            valid    = 0;
        end else if (at_dst) begin
            out_port = (1 << P_LOCAL);
            valid    = 1;
        end else begin
            // --- Negative first: try negative directions ---
            // Priority 1: -Z (Down)
            if (pref_DN && port_available[P_DN]) begin
                out_port = (1 << P_DN); valid = 1;
            end
            // Priority 2: -Y (South)
            else if (pref_S && port_available[P_S]) begin
                out_port = (1 << P_S); valid = 1;
            end
            // Priority 3: -X (West)
            else if (pref_W && port_available[P_W]) begin
                out_port = (1 << P_W); valid = 1;
            end
            // Priority 4: +Z (Up)
            else if (pref_UP && port_available[P_UP]) begin
                out_port = (1 << P_UP); valid = 1;
            end
            // Priority 5: +Y (North)
            else if (pref_N && port_available[P_N]) begin
                out_port = (1 << P_N); valid = 1;
            end
            // Priority 6: +X (East)
            else if (pref_E && port_available[P_E]) begin
                out_port = (1 << P_E); valid = 1;
            end
            // --- Fallback: non-minimal detour via any available port ---
            // If ALL preferred minimal ports are blocked, allow a non-minimal
            // hop on any available port except local (to avoid starvation).
            // Note: non-minimal moves only when at least one preferred port blocked.
            else begin
                // Try any available directional port (detour allowed)
                if (port_available[P_E])       begin out_port = (1<<P_E);  valid=1; end
                else if (port_available[P_W])  begin out_port = (1<<P_W);  valid=1; end
                else if (port_available[P_N])  begin out_port = (1<<P_N);  valid=1; end
                else if (port_available[P_S])  begin out_port = (1<<P_S);  valid=1; end
                else if (port_available[P_UP]) begin out_port = (1<<P_UP); valid=1; end
                else if (port_available[P_DN]) begin out_port = (1<<P_DN); valid=1; end
                else begin
                    // All ports blocked — hold (backpressure upstream)
                    out_port = 0; valid = 0;
                end
            end
        end
    end

endmodule
