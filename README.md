# 🔗 Adaptive Fault-Tolerant Routing (AFTR) for 3D Mesh Network-on-Chip

> **B.Tech Final Year Project** — Electronics & Communication Engineering  
> Rajiv Gandhi University of Knowledge Technologies (RGUKT), RK Valley, Kadapa  
> **Author:** K. Md. Musthafa (R200784) | **Guide:** Mr. B. Madhan Mohan

---

## 📌 Overview

As VLSI scaling continues, 3D Network-on-Chip (NoC) has emerged as a promising interconnect solution — stacking silicon dies using **Through-Silicon Vias (TSVs)** to reduce latency and footprint. However, the high thermal density in 3D stacks causes frequent TSV link failures that cripple traditional deterministic routing.

This project proposes a **low-latency Adaptive Fault-Tolerant Routing (AFTR)** algorithm for 3D Mesh NoCs, implemented end-to-end in **Verilog HDL** and verified on **Xilinx VIVADO**.

---

## ✨ Key Features

| Feature | Detail |
|---|---|
| **Fault Detection** | 1-bit Look-Ahead health signal — detects faults in **1 clock cycle** |
| **Routing** | Negative-First Turn Model with non-minimal fallback |
| **Deadlock Freedom** | Mathematically proven via acyclic Channel Dependency Graph |
| **Virtual Channels** | 2-VC separation for routing class isolation |
| **Hardware Overhead** | Only **+8–10% LUTs** over baseline XYZ routing |
| **Topology** | 4×4×4 3D Mesh — 64 routers, fully parameterizable |
| **Target Platform** | Xilinx Artix-7 `xc7a100tcsg324-1` @ **250 MHz** |

---

## 📊 Simulation Results

### Test Scenarios (Xilinx VIVADO Behavioral Simulation @ 100 MHz)

| Test Scenario | Packets Sent | Packets Received | PDR | Avg Latency |
|---|---|---|---|---|
| TEST 1: Uniform Random — No Faults | 20 | 20 | **100.0%** | 125.0 ns (12.5 cyc) |
| TEST 2: Hotspot Traffic — No Faults | 16 | 16 | **100.0%** | 121.5 ns (12.2 cyc) |
| TEST 3: 5 TSV Fault Injection | 24 | 22 | **91.7%** | 368.1 ns (36.8 cyc) |

### AFTR vs XYZ Routing — Fault Sensitivity

| Fault Count | AFTR PDR | XYZ PDR | Improvement | Avg Latency |
|---|---|---|---|---|
| 0 faults | 100% | 100% | +0% | ~125 ns |
| 2 faults | ~97% | ~88% | +9% | ~190 ns |
| **5 faults** | **91.7%** | **~65%** | **+27%** | **~368 ns** |
| 8 faults | ~82% | ~48% | +34% | ~480 ns |
| 10 faults | ~75% | ~35% | +40% | ~590 ns |
| 12 faults | ~67% | ~27% | +40% | ~700 ns |
| 15 faults | ~55% | ~18% | +37% | >800 ns |

> **At 5 simultaneous TSV faults, AFTR delivers 91.7% PDR vs ~65% for XYZ routing — a 27% improvement.**

---

## 🏗️ System Architecture

### Network Topology

```
4×4×4 3D Mesh — 64 Routers
├── NX = 4, NY = 4, NZ = 4
├── 7 ports per router: East, West, North, South, Up, Down, Local
├── Diameter: 9 hops (corner-to-corner)
├── Average hop count: ~4.5 hops
├── Total TSV links: 48 (16 per layer boundary × 3 boundaries)
└── Total bidirectional links: 192 (144 in-plane + 48 TSV)
```

### Router Pipeline (5 Stages)

```
BW → RC → VA → SA → ST
│     │    │    │    └─ Switch Traversal (crossbar)
│     │    │    └─ Switch Allocation (iSLIP round-robin)
│     │    └─ Virtual Channel Allocation (round-robin)
│     └─ Route Computation (AFTR algorithm)
└─ Buffer Write (credit-based FIFO)
```

### AFTR Routing Priority (Negative-First)

```
1. Down  (−Z)   ← highest priority
2. South (−Y)
3. West  (−X)
4. Up    (+Z)
5. North (+Y)
6. East  (+X)   ← lowest priority
7. Detour       ← non-minimal fallback
8. IDLE         ← wait if no port available
```

---

## 🗂️ Repository Structure

```
.
├── rtl/
│   ├── flit_pkg.vh              # Flit format constants and macros
│   ├── input_buffer.v           # Credit-based 4-slot FIFO buffer
│   ├── health_monitor.v         # Look-Ahead 1-cycle fault detector
│   ├── routing_computation.v    # AFTR core algorithm (combinational)
│   ├── vc_allocator.v           # 2-VC round-robin allocator
│   ├── switch_allocator.v       # iSLIP-inspired per-output arbiter
│   ├── crossbar.v               # 7×7 non-blocking switch fabric
│   ├── router_top.v             # Complete 7-port router integration
│   └── noc_top.v                # 4×4×4 mesh of 64 router instances
├── tb/
│   └── tb_noc_top.v             # Testbench (3 simulation scenarios)
├── constraints/
│   └── constraints.xdc          # Timing and false-path constraints
├── docs/
│   └── project_report.pdf       # Full project report
└── README.md
```

---

## 🔬 Verilog Modules

| Module | File | Description |
|---|---|---|
| `flit_pkg` | `flit_pkg.vh` | Flit type constants, bit-field macros |
| `input_buffer` | `input_buffer.v` | Credit-based FIFO, 4 slots × 32-bit |
| `health_monitor` | `health_monitor.v` | 1-cycle Look-Ahead fault detector |
| `routing_computation` | `routing_computation.v` | AFTR negative-first priority logic |
| `vc_allocator` | `vc_allocator.v` | 2-VC round-robin allocator |
| `switch_allocator` | `switch_allocator.v` | iSLIP-inspired per-port arbiter |
| `crossbar` | `crossbar.v` | 7×7 fully combinational switch |
| `router_top` | `router_top.v` | Integrated 7-port AFTR router |
| `noc_top` | `noc_top.v` | Top-level 4×4×4 mesh system |

---

## ⚙️ Technology Specifications

| Parameter | Value |
|---|---|
| HDL Standard | Verilog-2001 (IEEE 1364-2001) |
| EDA Tool | Xilinx VIVADO Design Suite 2024.x |
| Simulator | VIVADO Behavioral Simulator (xsim) |
| Target FPGA | Artix-7 `xc7a100tcsg324-1` (speed grade -1) |
| Target Frequency | 250 MHz (FPGA) / 500 MHz+ (ASIC 28 nm) |
| Flit Width | 32 bits |
| Buffer Depth | 4 flits per port |
| Virtual Channels | 2 per port |
| Flow Control | Credit-based |
| Fault Model | Permanent TSV open-circuit failure |

---

## 🚀 Getting Started

### Prerequisites

- Xilinx VIVADO Design Suite 2024.x (or compatible version)
- Artix-7 device support installed

### Running Simulation

1. **Clone the repository**
   ```bash
   git clone https://github.com/<your-username>/aftr-3d-noc.git
   cd aftr-3d-noc
   ```

2. **Open VIVADO and create a new project**
   - Add all files from `rtl/` as design sources
   - Add `tb/tb_noc_top.v` as simulation source
   - Add `constraints/constraints.xdc`
   - Set top module to `noc_top` (or `tb_noc_top` for simulation)

3. **Run Behavioral Simulation**
   ```
   Simulation → Run Behavioral Simulation → Run All
   ```
   Expected output in Tcl Console:
   ```
   TEST 1 | PDR: 100.0% | Avg Latency: 125.0 ns  → PASS
   TEST 2 | PDR: 100.0% | Avg Latency: 121.5 ns  → PASS
   TEST 3 | PDR:  91.7% | Avg Latency: 368.1 ns  → PASS (AFTR rerouted around faults)
   ```

4. **Run Synthesis**
   - Flow → Run Synthesis
   - Target: `xc7a100tcsg324-1`, Clock: 4 ns (250 MHz)

---

## 📐 32-bit Flit Format

```
 [31:30]      [29:27]   [26:24]   [23:21]   [20:18]   [17:15]   [14:12]   [11:0]
┌──────────┬──────────┬─────────┬─────────┬─────────┬─────────┬─────────┬──────────┐
│ Flit Type│  Dst X   │  Dst Y  │  Dst Z  │  Src X  │  Src Y  │  Src Z  │ Payload  │
│ (2 bits) │ (3 bits) │(3 bits) │(3 bits) │(3 bits) │(3 bits) │(3 bits) │(12 bits) │
└──────────┴──────────┴─────────┴─────────┴─────────┴─────────┴─────────┴──────────┘

Flit Types:  00=HEAD  |  01=BODY  |  10=TAIL  |  11=HEAD+TAIL (single-flit packet)
```

---

## ✅ Advantages & Limitations

| Aspect | Advantage | Limitation |
|---|---|---|
| Fault Detection | 1 clock cycle (Look-Ahead) | Only adjacent (1-hop) links visible |
| PDR (5 faults) | 91.7% vs ~65% (XYZ) | 2 packets unrecoverable at extreme paths |
| Fault-free Latency | 12.5 cycles | +2.9× increase under 5 faults |
| Hardware | +8–10% LUT overhead only | 2× buffer per port (2 VCs) |
| Deadlock | Mathematically proven free | Fixed priority ordering |
| Scalability | Parameter change only (NX/NY/NZ) | Local info limits multi-hop awareness |
| Portability | Verilog-2001 — any EDA tool | No physical FPGA test performed |

---

## 🔮 Future Work

- **Thermal-aware routing** — integrate on-chip thermal sensors for predictive rerouting before TSV faults occur
- **2-hop Look-Ahead** — extend health monitoring to two hops for better fault-path awareness
- **ML-enhanced priority** — learn traffic patterns to dynamically optimize port priority weights
- **Physical FPGA testing** — validate on Artix-7 hardware with integrated logic analyzer
- **Formal verification** — use Cadence JasperGold / Synopsys VC Formal to formally prove deadlock-freedom on RTL

---

## 📚 References

Key references used in this project:

1. Dally & Towles — *Route Packets, Not Wires*, DAC 2001
2. Benini & De Micheli — *Networks on Chips: A New SoC Paradigm*, IEEE Computer 2002
3. Glass & Ni — *The Turn Model for Adaptive Routing*, JACM 1994
4. Pavlidis & Friedman — *3-D Topologies for Networks-on-Chip*, IEEE TVLSI 2007
5. McKeown — *The iSLIP Scheduling Algorithm*, IEEE/ACM Trans. Networking 1999



---

## 👤 Author

**K. Md. Musthafa** — R200784  
B.Tech, Electronics & Communication Engineering  
RGUKT RK Valley, Kadapa, Andhra Pradesh  

**Project Guide:** Mr. B. Madhan Mohan, Assistant Professor, ECE  
 

---

## 📄 License

This project is submitted as an academic B.Tech project to RGUKT RK Valley (2025–2026).  
For academic reference and educational use only.
