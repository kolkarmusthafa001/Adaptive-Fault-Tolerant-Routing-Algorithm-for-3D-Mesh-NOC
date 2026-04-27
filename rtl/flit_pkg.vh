// ============================================================
//  flit_pkg.vh
//  Flit format definitions for the AFTR 3D Mesh NoC
//
//  Flit format (32-bit):
//  [31:30] flit_type  : 2'b00=HEAD, 2'b01=BODY, 2'b10=TAIL, 2'b11=HEAD+TAIL
//  [29:27] dst_x      : 3-bit X destination
//  [26:24] dst_y      : 3-bit Y destination
//  [23:21] dst_z      : 3-bit Z destination
//  [20:18] src_x      : 3-bit X source
//  [17:15] src_y      : 3-bit Y source
//  [14:12] src_z      : 3-bit Z source
//  [11:0]  payload    : 12-bit data (body/tail flits use [31:0] as full payload)
// ============================================================

`ifndef FLIT_PKG_VH
`define FLIT_PKG_VH

// Flit type encoding
`define FLIT_HEAD     2'b00
`define FLIT_BODY     2'b01
`define FLIT_TAIL     2'b10
`define FLIT_HEADTAIL 2'b11

// Field bit positions
`define FLIT_TYPE_HI  31
`define FLIT_TYPE_LO  30
`define FLIT_DSTX_HI  29
`define FLIT_DSTX_LO  27
`define FLIT_DSTY_HI  26
`define FLIT_DSTY_LO  24
`define FLIT_DSTZ_HI  23
`define FLIT_DSTZ_LO  21
`define FLIT_SRCX_HI  20
`define FLIT_SRCX_LO  18
`define FLIT_SRCY_HI  17
`define FLIT_SRCY_LO  15
`define FLIT_SRCZ_HI  14
`define FLIT_SRCZ_LO  12
`define FLIT_PAY_HI   11
`define FLIT_PAY_LO    0

// Helper macros
`define GET_DST_X(f) f[`FLIT_DSTX_HI:`FLIT_DSTX_LO]
`define GET_DST_Y(f) f[`FLIT_DSTY_HI:`FLIT_DSTY_LO]
`define GET_DST_Z(f) f[`FLIT_DSTZ_HI:`FLIT_DSTZ_LO]
`define GET_TYPE(f)  f[`FLIT_TYPE_HI:`FLIT_TYPE_LO]
`define IS_HEAD(f)   (f[`FLIT_TYPE_HI:`FLIT_TYPE_LO] == `FLIT_HEAD || \
                      f[`FLIT_TYPE_HI:`FLIT_TYPE_LO] == `FLIT_HEADTAIL)
`define IS_TAIL(f)   (f[`FLIT_TYPE_HI:`FLIT_TYPE_LO] == `FLIT_TAIL || \
                      f[`FLIT_TYPE_HI:`FLIT_TYPE_LO] == `FLIT_HEADTAIL)

`endif
