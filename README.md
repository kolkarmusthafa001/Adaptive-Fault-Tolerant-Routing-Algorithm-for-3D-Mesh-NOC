# AFTR 3D Mesh NoC — Project README

## Title
Design of a Robust Adaptive Fault-Tolerant Routing Algorithm
for 3D Mesh Network-on-Chip (NoC) Systems

---

## File Structure

```
noc_aftr/
├── rtl/
│   ├── flit_pkg.vh          ← Flit format macros & defines
│   ├── input_buffer.v       ← 4-slot FIFO with credit-based flow control
│   ├── health_monitor.v     ← Look-Ahead 1-bit fault status TX/RX
│   ├── routing_computation.v← AFTR algorithm (XYZ + adaptive fallback)
│   ├── vc_allocator.v       ← 2-VC deadlock-free allocator (round-robin)
│   ├── switch_allocator.v   ← iSLIP-inspired switch arbiter
│   ├── crossbar.v           ← 7×7 non-blocking mux crossbar
│   ├── router_top.v         ← Router integration (all sub-modules)
│   └── noc_top.v            ← 4×4×4 3D Mesh full NoC
├── tb/
│   └── tb_noc_top.v         ← Testbench: 3 traffic tests + fault injection
└── constraints/
    └── constraints.xdc      ← Xilinx VIVADO timing & power constraints
```

---

## VIVADO Setup Steps

### Step 1: Create Project
1. Open Xilinx VIVADO → "Create Project"
2. Name: `noc_aftr`
3. Type: **RTL Project**
4. Part: `xc7a100tcsg324-1` (Artix-7)

### Step 2: Add Sources
- Add ALL files from `rtl/` as **Design Sources**
- Add `tb/tb_noc_top.v` as **Simulation Source**
- Add `constraints/constraints.xdc` as **Constraints**
- Set `flit_pkg.vh` as a header (include file)

### Step 3: Set Top Modules
- Design top: `noc_top`
- Simulation top: `tb_noc_top`

### Step 4: Run Simulation
- Flow → Run Simulation → Run Behavioral Simulation
- Console should print PDR and latency metrics

### Step 5: Synthesis
- Flow → Run Synthesis
- Check Timing Summary: WNS should be ≥ 0 at 250 MHz

### Step 6: Implementation
- Flow → Run Implementation
- Check Power Report: should be < 500 mW on Artix-7

---

## Expected Simulation Results

| Test Case                  | Sent | PDR Target | Avg Latency |
|---------------------------|------|------------|-------------|
| Uniform Random (no fault) | 32   | ~100%      | 5–15 cycles |
| Hotspot (no fault)        | 20   | ~100%      | 10–25 cycles|
| 5 TSV faults injected     | 40   | ≥ 95%      | 15–30 cycles|

---

## Key Design Features

| Feature                     | Detail                              |
|-----------------------------|-------------------------------------|
| Routing                     | Adaptive XYZ + non-minimal fallback |
| Deadlock prevention         | Negative-first turn model + 2 VCs   |
| Fault detection latency     | 1 clock cycle                       |
| Buffer depth per port       | 4 flits (configurable)              |
| Flit width                  | 32 bits                             |
| Target frequency (FPGA)     | 250 MHz (Artix-7)                   |
| Estimated LUT overhead      | +8–12% vs XYZ baseline              |

---

## Parameterisation Guide

To change mesh size, edit `noc_top.v` parameters:
```verilog
parameter NX = 4, NY = 4, NZ = 4   // change to e.g. 8x8x4
parameter X_W = 2, Y_W = 2, Z_W = 2 // = ceil(log2(N))
```

To change buffer depth (throughput vs area):
```verilog
parameter BUF_DEPTH = 4   // increase to 8 for higher load
```

---
*K. MD. MUSTHAFA — R200784 | RGUKT RK Valley*
