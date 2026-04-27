// ============================================================
//  router_top.v
//  AFTR Router — Top-Level Integration
//  Ports: E(0), W(1), N(2), S(3), Up(4), Down(5), Local(6)
//  Pipeline: Input Buffer → VC Alloc → Route Compute →
//            Switch Alloc → Crossbar → Output
// ============================================================
`timescale 1ns/1ps
`include "flit_pkg.vh"

module router_top #(
    parameter FLIT_WIDTH = 32,
    parameter BUF_DEPTH  = 4,
    parameter NUM_VC     = 2,
    parameter X_W        = 3,
    parameter Y_W        = 3,
    parameter Z_W        = 3,
    parameter NUM_PORTS  = 7   // 6 directional + 1 local
)(
    input  wire clk,
    input  wire rst_n,

    // Coordinates of this router
    input  wire [X_W-1:0] coord_x,
    input  wire [Y_W-1:0] coord_y,
    input  wire [Z_W-1:0] coord_z,

    // Physical link: input flits from 7 ports
    input  wire [FLIT_WIDTH-1:0] port_in  [0:NUM_PORTS-1],
    input  wire                  port_in_valid [0:NUM_PORTS-1],

    // Physical link: output flits to 7 ports
    output wire [FLIT_WIDTH-1:0] port_out [0:NUM_PORTS-1],
    output wire                  port_out_valid [0:NUM_PORTS-1],

    // Health signals: from neighbors (6 directional only)
    input  wire [5:0] neighbor_health_in,
    output wire [5:0] health_out,

    // Fault injection (test only) — 0 = fault that link
    input  wire [5:0] local_link_up,

    // Back-pressure credits to upstream
    output wire [2:0] credit_out [0:NUM_PORTS-1]
);

    // ---- Internal signals ----
    wire [FLIT_WIDTH-1:0] buf_dout  [0:NUM_PORTS-1];
    wire                  buf_empty [0:NUM_PORTS-1];
    wire                  buf_full  [0:NUM_PORTS-1];
    reg                   buf_rd_en [0:NUM_PORTS-1];
    wire [2:0]            buf_credits [0:NUM_PORTS-1];

    wire [5:0] fault_table;
    wire [5:0] port_available_6;  // 6 directional ports

    wire [NUM_PORTS-1:0] rc_out_port [0:NUM_PORTS-1];
    wire                 rc_valid    [0:NUM_PORTS-1];

    wire [NUM_PORTS*NUM_VC-1:0] vc_req, vc_grant, vc_occupied;
    wire [NUM_PORTS-1:0] sw_grant   [0:NUM_PORTS-1];
    wire [NUM_PORTS-1:0] sw_req     [0:NUM_PORTS-1];
    wire [NUM_PORTS-1:0] congestion_flag_full;

    wire [FLIT_WIDTH-1:0] xbar_out  [0:NUM_PORTS-1];
    wire                  xbar_valid [0:NUM_PORTS-1];

    genvar i;

    // ---- Input Buffers ----
    generate
        for (i = 0; i < NUM_PORTS; i = i+1) begin : gen_buf
            input_buffer #(
                .FLIT_WIDTH(FLIT_WIDTH),
                .DEPTH(BUF_DEPTH),
                .PTR_W($clog2(BUF_DEPTH))
            ) u_buf (
                .clk    (clk),
                .rst_n  (rst_n),
                .wr_en  (port_in_valid[i]),
                .din    (port_in[i]),
                .full   (buf_full[i]),
                .rd_en  (buf_rd_en[i]),
                .dout   (buf_dout[i]),
                .empty  (buf_empty[i]),
                .credits(buf_credits[i])
            );
            assign credit_out[i] = buf_credits[i];
        end
    endgenerate

    // ---- Health Monitor ----
    wire [5:0] congestion_6 = congestion_flag_full[5:0];

    health_monitor #(.NUM_PORTS(6)) u_health (
        .clk               (clk),
        .rst_n             (rst_n),
        .neighbor_health_in(neighbor_health_in),
        .health_out        (health_out),
        .local_link_up     (local_link_up),
        .fault_table       (fault_table),
        .congestion_flag   (congestion_6),
        .port_available    (port_available_6)
    );

    // Extend port_available to full 7 ports (local always available for routing to local)
    wire [NUM_PORTS-1:0] port_available = {1'b1, port_available_6};

    // ---- Routing Computation (one unit per input port) ----
    generate
        for (i = 0; i < NUM_PORTS; i = i+1) begin : gen_rc
            routing_computation #(
                .X_W(X_W), .Y_W(Y_W), .Z_W(Z_W),
                .NUM_PORTS(NUM_PORTS)
            ) u_rc (
                .cur_x         (coord_x),
                .cur_y         (coord_y),
                .cur_z         (coord_z),
                .dst_x         (`GET_DST_X(buf_dout[i])),
                .dst_y         (`GET_DST_Y(buf_dout[i])),
                .dst_z         (`GET_DST_Z(buf_dout[i])),
                .port_available(port_available[5:0]),
                .req           (!buf_empty[i] && `IS_HEAD(buf_dout[i])),
                .out_port      (rc_out_port[i]),
                .valid         (rc_valid[i])
            );
        end
    endgenerate

    // ---- Switch Request: map routing result to SW request ----
    generate
        for (i = 0; i < NUM_PORTS; i = i+1) begin : gen_sw_req
            assign sw_req[i] = (rc_valid[i] && !buf_empty[i]) ? rc_out_port[i] : 0;
        end
    endgenerate

    // ---- Switch Allocator ----
    switch_allocator #(.NUM_PORTS(NUM_PORTS)) u_sw_alloc (
        .clk            (clk),
        .rst_n          (rst_n),
        .req            (sw_req),
        .grant          (sw_grant),
        .congestion_flag(congestion_flag_full)
    );

    // ---- Read enable: pop buffer when grant received ----
    generate
        for (i = 0; i < NUM_PORTS; i = i+1) begin : gen_rd
            always @(*) begin
                buf_rd_en[i] = (|sw_grant[i]) && !buf_empty[i];
            end
        end
    endgenerate

    // ---- Crossbar ----
    crossbar #(.FLIT_WIDTH(FLIT_WIDTH), .NUM_PORTS(NUM_PORTS)) u_xbar (
        .in_data (buf_dout),
        .in_valid(sw_grant[0]),   // placeholder; driven per port below
        .grant   (sw_grant),
        .out_data (xbar_out),
        .out_valid(xbar_valid)
    );

    // ---- Drive output ports ----
    generate
        for (i = 0; i < NUM_PORTS; i = i+1) begin : gen_out
            assign port_out[i]       = xbar_out[i];
            assign port_out_valid[i] = xbar_valid[i];
        end
    endgenerate

endmodule
