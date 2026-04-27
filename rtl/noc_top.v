// ============================================================
//  noc_top.v
//  4 x 4 x 4  3D Mesh NoC — Full System Top Level
//  64 routers, wired with XYZ adjacency
//  Fault injection: fault_map[63:0] × 6 directions
// ============================================================
`timescale 1ns/1ps
`include "flit_pkg.vh"

module noc_top #(
    parameter NX         = 4,
    parameter NY         = 4,
    parameter NZ         = 4,
    parameter FLIT_WIDTH = 32,
    parameter BUF_DEPTH  = 4,
    parameter X_W        = 2,   // log2(NX)
    parameter Y_W        = 2,
    parameter Z_W        = 2,
    parameter NUM_PORTS  = 7
)(
    input  wire clk,
    input  wire rst_n,

    // Injection ports (one per router from local PE)
    input  wire [FLIT_WIDTH-1:0] inject_flit  [0:NX*NY*NZ-1],
    input  wire                  inject_valid  [0:NX*NY*NZ-1],

    // Ejection ports (one per router to local PE)
    output wire [FLIT_WIDTH-1:0] eject_flit   [0:NX*NY*NZ-1],
    output wire                  eject_valid   [0:NX*NY*NZ-1],

    // Fault injection map: [router_id * 6 + dir]
    input  wire [NX*NY*NZ*6-1:0] fault_map     // 0 = inject fault, 1 = healthy
);

    localparam NUM_R = NX * NY * NZ;

    // Helper function: flatten (x,y,z) → router index
    function automatic integer rid;
        input integer x, y, z;
        rid = z * (NX * NY) + y * NX + x;
    endfunction

    // ---- Inter-router wires ----
    // port order: E(0) W(1) N(2) S(3) Up(4) Dn(5) Local(6)
    wire [FLIT_WIDTH-1:0] r_out [0:NUM_R-1][0:NUM_PORTS-1];
    wire                  r_out_v [0:NUM_R-1][0:NUM_PORTS-1];

    // Health wires: [router][port]  (6 directional)
    wire [5:0] h_out [0:NUM_R-1];
    wire [5:0] h_in  [0:NUM_R-1];

    // ---- Connect health signals between neighbours ----
    // E/W: h_out[r][E] drives h_in[r_east][W]
    // N/S: h_out[r][N] drives h_in[r_north][S]
    // Up/Dn: h_out[r][Up] drives h_in[r_up][Dn]
    genvar x, y, z;
    generate
        for (z = 0; z < NZ; z = z+1) begin : hz
            for (y = 0; y < NY; y = y+1) begin : hy
                for (x = 0; x < NX; x = x+1) begin : hx
                    localparam integer R = z*NX*NY + y*NX + x;
                    // E neighbour
                    if (x < NX-1) begin
                        localparam integer RE = z*NX*NY + y*NX + (x+1);
                        assign h_in[R][0]  = h_out[RE][1]; // E←W of east neighbour
                        assign h_in[RE][1] = h_out[R][0];
                    end else begin
                        assign h_in[R][0] = 1'b0; // boundary = faulty
                    end
                    // N neighbour
                    if (y < NY-1) begin
                        localparam integer RN = z*NX*NY + (y+1)*NX + x;
                        assign h_in[R][2]  = h_out[RN][3];
                        assign h_in[RN][3] = h_out[R][2];
                    end else begin
                        assign h_in[R][2] = 1'b0;
                    end
                    // Up neighbour
                    if (z < NZ-1) begin
                        localparam integer RU = (z+1)*NX*NY + y*NX + x;
                        assign h_in[R][4]  = h_out[RU][5];
                        assign h_in[RU][5] = h_out[R][4];
                    end else begin
                        assign h_in[R][4] = 1'b0;
                    end
                    // W boundary
                    if (x == 0) assign h_in[R][1] = 1'b0;
                    // S boundary
                    if (y == 0) assign h_in[R][3] = 1'b0;
                    // Dn boundary
                    if (z == 0) assign h_in[R][5] = 1'b0;
                end
            end
        end
    endgenerate

    // ---- Instantiate all routers ----
    generate
        for (z = 0; z < NZ; z = z+1) begin : rz
            for (y = 0; y < NY; y = y+1) begin : ry
                for (x = 0; x < NX; x = x+1) begin : rx
                    localparam integer R = z*NX*NY + y*NX + x;

                    // Input to each router: flit from neighbour's output
                    wire [FLIT_WIDTH-1:0] p_in [0:NUM_PORTS-1];
                    wire                  p_in_v [0:NUM_PORTS-1];

                    // E input = west output of east neighbour
                    assign p_in[0]   = (x < NX-1) ? r_out[R+1][1]   : 0;
                    assign p_in_v[0] = (x < NX-1) ? r_out_v[R+1][1] : 0;
                    // W input = east output of west neighbour
                    assign p_in[1]   = (x > 0) ? r_out[R-1][0]   : 0;
                    assign p_in_v[1] = (x > 0) ? r_out_v[R-1][0] : 0;
                    // N input = south output of north neighbour
                    assign p_in[2]   = (y < NY-1) ? r_out[R+NX][3]   : 0;
                    assign p_in_v[2] = (y < NY-1) ? r_out_v[R+NX][3] : 0;
                    // S input = north output of south neighbour
                    assign p_in[3]   = (y > 0) ? r_out[R-NX][2]   : 0;
                    assign p_in_v[3] = (y > 0) ? r_out_v[R-NX][2] : 0;
                    // Up input = down output of upper neighbour
                    assign p_in[4]   = (z < NZ-1) ? r_out[R+NX*NY][5]   : 0;
                    assign p_in_v[4] = (z < NZ-1) ? r_out_v[R+NX*NY][5] : 0;
                    // Dn input = up output of lower neighbour
                    assign p_in[5]   = (z > 0) ? r_out[R-NX*NY][4]   : 0;
                    assign p_in_v[5] = (z > 0) ? r_out_v[R-NX*NY][4] : 0;
                    // Local input from PE injection
                    assign p_in[6]   = inject_flit[R];
                    assign p_in_v[6] = inject_valid[R];

                    router_top #(
                        .FLIT_WIDTH(FLIT_WIDTH),
                        .BUF_DEPTH(BUF_DEPTH),
                        .X_W(X_W), .Y_W(Y_W), .Z_W(Z_W),
                        .NUM_PORTS(NUM_PORTS)
                    ) u_router (
                        .clk              (clk),
                        .rst_n            (rst_n),
                        .coord_x          (x[X_W-1:0]),
                        .coord_y          (y[Y_W-1:0]),
                        .coord_z          (z[Z_W-1:0]),
                        .port_in          (p_in),
                        .port_in_valid    (p_in_v),
                        .port_out         (r_out[R]),
                        .port_out_valid   (r_out_v[R]),
                        .neighbor_health_in(h_in[R]),
                        .health_out       (h_out[R]),
                        .local_link_up    (fault_map[R*6 +: 6]),
                        .credit_out       ()
                    );

                    // Eject to local PE
                    assign eject_flit[R]  = r_out[R][6];
                    assign eject_valid[R] = r_out_v[R][6];
                end
            end
        end
    endgenerate

endmodule
