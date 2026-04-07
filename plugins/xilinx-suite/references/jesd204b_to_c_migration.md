# JESD204B to JESD204C IP Migration Guide

## Background

Vivado 2024.1+ removes the old `jesd204` IP (v7.2). All new designs must use `jesd204c` IP (v4.3+).
JESD204C IP supports **8B10B encoding mode** for full backward compatibility with JESD204B converters (AD9144, AD9250, AD9680, DAC38J84 etc.).

This guide covers the complete migration procedure for Zynq UltraScale+ / UltraScale+ devices with typical JESD204B converters such as AD9144 DAC and AD9250 ADC.

---

## Step 1: Create New JESD204C IPs

### TX IP (replacing old jesd204 TX)

```tcl
create_ip -name jesd204c -vendor xilinx.com -library ip -module_name jesd204c_tx
set_property -dict [list \
    CONFIG.C_NODE_IS_TRANSMIT {1} \
    CONFIG.C_LANES {8} \
    CONFIG.C_ENCODING {0} \
    CONFIG.GT_Line_Rate {10} \
    CONFIG.GT_REFCLK_FREQ {200} \
    CONFIG.DRPCLK_FREQ {100.0} \
    CONFIG.Transceiver {GTHE4} \
    CONFIG.AXICLK_FREQ {100.0} \
] [get_ips jesd204c_tx]
```

### RX IP (replacing old jesd204 RX)

```tcl
create_ip -name jesd204c -vendor xilinx.com -library ip -module_name jesd204c_rx
set_property -dict [list \
    CONFIG.C_NODE_IS_TRANSMIT {0} \
    CONFIG.C_LANES {2} \
    CONFIG.C_ENCODING {0} \
    CONFIG.GT_Line_Rate {5} \
    CONFIG.GT_REFCLK_FREQ {200} \
    CONFIG.DRPCLK_FREQ {100.0} \
    CONFIG.Transceiver {GTHE4} \
    CONFIG.AXICLK_FREQ {100.0} \
] [get_ips jesd204c_rx]
```

**Key setting: `C_ENCODING {0}`** = 8B10B mode, which makes JESD204C backward compatible with all JESD204B converters.

### PHY IP (usually unchanged)

```tcl
create_ip -name jesd204_phy -vendor xilinx.com -library ip -module_name jesd204_phy_0
set_property -dict [list \
    CONFIG.C_LANES {8} \
    CONFIG.GT_Line_Rate {10} \
    CONFIG.RX_GT_Line_Rate {5} \
    CONFIG.Tx_use_64b {0} \
    CONFIG.Rx_use_64b {0} \
    CONFIG.Transceiver {GTHE4} \
] [get_ips jesd204_phy_0]
```

---

## Step 2: Port Name Changes

### 2.1 Reset Signals

| Old (v7.2) | New (v4.3) | Notes |
|------------|------------|-------|
| `.tx_reset(signal)` | `.tx_core_reset(signal)` | TX core reset |
| `.rx_reset(signal)` | `.rx_core_reset(signal)` | RX core reset |

### 2.2 Frame Indicator Signals

| Old (v7.2) | New (v4.3) | Notes |
|------------|------------|-------|
| `.tx_start_of_frame()` | `.tx_sof()` | TX start of frame |
| `.tx_start_of_multiframe()` | `.tx_somf()` | TX start of multiframe |
| `.rx_start_of_frame()` | `.rx_sof()` | RX start of frame |
| `.rx_start_of_multiframe()` | `.rx_somf()` | RX start of multiframe |
| `.rx_frame_error()` | `.rx_frm_err()` | RX frame error |
| `.rxencommaalign_out()` | `.encommaalign()` | Comma align output |

### 2.3 Removed Ports (no direct replacement)

| Old Port | Notes |
|----------|-------|
| `rx_end_of_frame[3:0]` | Removed, derive from rx_sof if needed |
| `rx_end_of_multiframe[3:0]` | Removed, derive from rx_somf if needed |
| `gt_prbssel_out[3:0]` | PRBS removed, use GT DRP if needed |

### 2.4 New Ports (must be connected)

| New Port | Direction | Width | Per-Lane | Purpose |
|----------|-----------|-------|----------|---------|
| `gtX_txheader` | TX IP output | 2 | Yes | 64-bit alignment header |
| `gtX_rxheader` | RX IP input | 2 | Yes | 64-bit alignment header |
| `gtX_rxmisalign` | RX IP input | 1 | Yes | Lane misalignment detect |
| `gtX_rxblock_sync` | RX IP input | 1 | Yes | Block sync status |
| `irq` | Both TX/RX output | 1 | No | Interrupt (can leave unconnected) |

---

## Step 3: Data Width Change (32-bit to 64-bit)

This is the most critical change. All GT lane data paths expand from 32-bit to 64-bit.

### Old Code Pattern (v7.2)

```verilog
// Old: TX IP outputs 32-bit, need zero-padding to 64-bit for PHY
wire [31:0] gt0_txdata_old;
jesd204_tx old_tx_inst (
    .gt0_txdata(gt0_txdata_old),  // 32-bit output
    ...
);
jesd204_phy_0 phy_inst (
    .gt0_txdata({32'b0, gt0_txdata_old}),  // zero-padded to 64-bit
    ...
);

// Old: PHY outputs 64-bit, need slicing to 32-bit for RX IP
wire [63:0] gt0_rxdata_phy;
jesd204_phy_0 phy_inst (
    .gt0_rxdata(gt0_rxdata_phy),  // 64-bit output
    ...
);
jesd204_rx old_rx_inst (
    .gt0_rxdata(gt0_rxdata_phy[31:0]),  // sliced to 32-bit
    ...
);
```

### New Code Pattern (v4.3)

```verilog
// New: Direct 64-bit connections, NO padding/slicing needed
wire [63:0] gt0_txdata, gt0_rxdata;
wire [1:0]  gt0_txheader, gt0_rxheader;     // NEW header signals
wire        gt0_rxmisalign, gt0_rxblock_sync; // NEW alignment signals

// TX IP -> PHY (direct 64-bit)
jesd204c_tx new_tx_inst (
    .gt0_txdata(gt0_txdata),        // 64-bit output
    .gt0_txheader(gt0_txheader),    // NEW: 2-bit header
    ...
);
jesd204_phy_0 phy_inst (
    .gt0_txdata(gt0_txdata),        // 64-bit input (direct!)
    .gt0_txheader(gt0_txheader),    // NEW: 2-bit header
    ...
);

// PHY -> RX IP (direct 64-bit)
jesd204_phy_0 phy_inst (
    .gt0_rxdata(gt0_rxdata),        // 64-bit output
    .gt0_rxheader(gt0_rxheader),    // NEW
    .gt0_rxmisalign(gt0_rxmisalign),      // NEW
    .gt0_rxblock_sync(gt0_rxblock_sync),  // NEW
    ...
);
jesd204c_rx new_rx_inst (
    .gt0_rxdata(gt0_rxdata),        // 64-bit input (direct!)
    .gt0_rxheader(gt0_rxheader),    // NEW
    .gt0_rxmisalign(gt0_rxmisalign),      // NEW
    .gt0_rxblock_sync(gt0_rxblock_sync),  // NEW
    ...
);
```

### Wire Declarations Template

```verilog
// TX lane data (per lane, repeat for all lanes)
wire [63:0] gt0_txdata, gt1_txdata, gt2_txdata /* ... */;
wire [3:0]  gt0_txcharisk, gt1_txcharisk /* ... */;
wire [1:0]  gt0_txheader, gt1_txheader /* ... */;  // NEW

// RX lane data (per lane, repeat for active RX lanes)
wire [63:0] gt0_rxdata, gt1_rxdata;
wire [3:0]  gt0_rxcharisk, gt1_rxcharisk;
wire [3:0]  gt0_rxdisperr, gt1_rxdisperr;
wire [3:0]  gt0_rxnotintable, gt1_rxnotintable;
wire [1:0]  gt0_rxheader, gt1_rxheader;         // NEW
wire        gt0_rxmisalign, gt1_rxmisalign;     // NEW
wire        gt0_rxblock_sync, gt1_rxblock_sync; // NEW
```

---

## Step 4: Complete TX Instance Template

```verilog
jesd204c_tx jesd204c_tx_inst (
    // GT data: 64-bit per lane (direct to PHY)
    .gt0_txdata(gt0_txdata),       .gt0_txcharisk(gt0_txcharisk),  .gt0_txheader(gt0_txheader),
    .gt1_txdata(gt1_txdata),       .gt1_txcharisk(gt1_txcharisk),  .gt1_txheader(gt1_txheader),
    .gt2_txdata(gt2_txdata),       .gt2_txcharisk(gt2_txcharisk),  .gt2_txheader(gt2_txheader),
    .gt3_txdata(gt3_txdata),       .gt3_txcharisk(gt3_txcharisk),  .gt3_txheader(gt3_txheader),
    .gt4_txdata(gt4_txdata),       .gt4_txcharisk(gt4_txcharisk),  .gt4_txheader(gt4_txheader),
    .gt5_txdata(gt5_txdata),       .gt5_txcharisk(gt5_txcharisk),  .gt5_txheader(gt5_txheader),
    .gt6_txdata(gt6_txdata),       .gt6_txcharisk(gt6_txcharisk),  .gt6_txheader(gt6_txheader),
    .gt7_txdata(gt7_txdata),       .gt7_txcharisk(gt7_txcharisk),  .gt7_txheader(gt7_txheader),
    // Control
    .tx_reset_done(w_tx_reset_done),
    .tx_reset_gt(w_tx_reset_gt),
    .tx_core_clk(w_tx_core_clk),
    .tx_core_reset(w_tx_sys_reset),    // WAS: tx_reset
    .irq(),                             // NEW: leave unconnected
    // AXI-Lite
    .s_axi_aclk(clk_axi_100m),
    .s_axi_aresetn(w_rst_n),
    .s_axi_awaddr(w_tx_s_axi_awaddr),   // 12-bit
    .s_axi_awvalid(w_tx_s_axi_awvalid),
    .s_axi_awready(w_tx_s_axi_awready),
    .s_axi_wdata(w_tx_s_axi_wdata),     // 32-bit
    .s_axi_wstrb(4'b1111),
    .s_axi_wvalid(w_tx_s_axi_wvalid),
    .s_axi_wready(w_tx_s_axi_wready),
    .s_axi_bresp(w_tx_s_axi_bresp),
    .s_axi_bvalid(w_tx_s_axi_bvalid),
    .s_axi_bready(w_tx_s_axi_bready),
    .s_axi_araddr(w_s_axi_araddr),
    .s_axi_arvalid(w_s_axi_arvalid),
    .s_axi_arready(w_s_axi_arready),
    .s_axi_rdata(w_s_axi_rdata),
    .s_axi_rresp(w_s_axi_rresp),
    .s_axi_rvalid(w_s_axi_rvalid),
    .s_axi_rready(w_s_axi_rready),
    // JESD204 data
    .tx_sysref(w_sysref),
    .tx_sof(w_tx_sof),                  // WAS: tx_start_of_frame
    .tx_somf(w_tx_somf),                // WAS: tx_start_of_multiframe
    .tx_aresetn(w_tx_aresetn),
    .tx_tdata(w_tx_tdata),              // 256-bit user data
    .tx_tready(w_tx_tready),
    .tx_sync(w_tx_sync)
);
```

---

## Step 5: Complete RX Instance Template

```verilog
jesd204c_rx jesd204c_rx_inst (
    // GT data: 64-bit per lane (direct from PHY)
    .gt0_rxdata(gt0_rxdata),
    .gt0_rxcharisk(gt0_rxcharisk),
    .gt0_rxdisperr(gt0_rxdisperr),
    .gt0_rxnotintable(gt0_rxnotintable),
    .gt0_rxheader(gt0_rxheader),          // NEW
    .gt0_rxmisalign(gt0_rxmisalign),      // NEW
    .gt0_rxblock_sync(gt0_rxblock_sync),  // NEW
    .gt1_rxdata(gt1_rxdata),
    .gt1_rxcharisk(gt1_rxcharisk),
    .gt1_rxdisperr(gt1_rxdisperr),
    .gt1_rxnotintable(gt1_rxnotintable),
    .gt1_rxheader(gt1_rxheader),          // NEW
    .gt1_rxmisalign(gt1_rxmisalign),      // NEW
    .gt1_rxblock_sync(gt1_rxblock_sync),  // NEW
    // Control
    .rx_reset_done(w_rx_reset_done),
    .encommaalign(w_rxencommaalign_out),   // WAS: rxencommaalign_out
    .rx_reset_gt(w_rx_reset_gt),
    .rx_core_clk(w_rx_core_clk),
    .rx_core_reset(w_rx_sys_reset),        // WAS: rx_reset
    .irq(),                                 // NEW: leave unconnected
    // AXI-Lite (can tie off if not used)
    .s_axi_aclk(clk_axi_100m),
    .s_axi_aresetn(w_rst_n),
    .s_axi_awaddr(12'b0),  .s_axi_awvalid(1'b0),  .s_axi_awready(),
    .s_axi_wdata(32'b0),   .s_axi_wstrb(4'b0),    .s_axi_wvalid(1'b0),  .s_axi_wready(),
    .s_axi_bresp(),        .s_axi_bvalid(),        .s_axi_bready(1'b0),
    .s_axi_araddr(12'b0),  .s_axi_arvalid(1'b0),  .s_axi_arready(),
    .s_axi_rdata(),        .s_axi_rresp(),         .s_axi_rvalid(),      .s_axi_rready(1'b0),
    // JESD204 data
    .rx_aresetn(),
    .rx_tdata(w_rx_tdata),               // 64-bit user data
    .rx_tvalid(w_rx_tvalid),
    .rx_sof(w_rx_sof),                   // WAS: rx_start_of_frame
    .rx_somf(w_rx_somf),                 // WAS: rx_start_of_multiframe
    .rx_frm_err(w_rx_frm_err),           // WAS: rx_frame_error
    .rx_sysref(w_sysref),
    .rx_sync(w_rx_sync)
);
```

---

## Step 6: AXI Register Configuration (TX)

JESD204C in 8B10B mode maintains register compatibility with v7.2. Use a 13-step AXI write sequence:

```verilog
// jesd_axi_write.v - Register write sequence
// Address map for jesd204c v4.3 (8B10B mode)

localparam ADDR_RESET          = 12'h020;
localparam ADDR_8B10B_CFG      = 12'h03C;
localparam ADDR_SUB_CLASS      = 12'h034;
localparam ADDR_LANE_ENA       = 12'h040;
localparam ADDR_TEST_MODE      = 12'h048;
localparam ADDR_SYSREF         = 12'h050;
localparam ADDR_TX_ILA_CFG0    = 12'h070;
localparam ADDR_TX_ILA_CFG1    = 12'h074;
localparam ADDR_TX_ILA_CFG2    = 12'h078;
localparam ADDR_TX_ILA_CFG4    = 12'h080;

// Sequence:
//  0: Write RESET=1 (assert reset)
//  1: Write RESET=0 (release)
//  2: Write 8B10B_CFG (F, K, SCR, ILA)
//  3: Write SUB_CLASS=1
//  4: Write LANE_ENA (e.g. 0xFF for 8 lanes)
//  5: Write TEST_MODE=0
//  6: Write SYSREF=0
//  7: Write TX_ILA_CFG0 (DID, BID)
//  8: Write TX_ILA_CFG1 (M, N, N', CS)
//  9: Write TX_ILA_CFG2 (S, HD, CF)
// 10: Write TX_ILA_CFG4 (RES1, RES2)
// 11: Write RESET=1 (apply config)
// 12: Write RESET=0 (link starts)
```

### 8B10B_CFG Register (0x03C) Encoding

```
Bits [31:24]: ILA multiframes count - 1 (typically 3 = 4 multiframes)
Bit  [17]:    ILA Required (1 = enable)
Bit  [16]:    SCR (1 = scrambling enabled)
Bits [12:8]:  K-1 (frames per multiframe minus 1)
Bits [4:0]:   F-1 (octets per frame minus 1)
```

### TX_ILA_CFG1 Register (0x074) Encoding

```
Bits [25:24]: CS (control bits per sample)
Bits [20:16]: N'-1 (total bits per sample minus 1)
Bits [12:8]:  N-1 (converter resolution minus 1)
Bits [7:0]:   M-1 (number of converters minus 1)
```

### Common Converter Parameters

| Converter | L | M | F | K | N | N' | S | SCR | Line Rate |
|-----------|---|---|---|---|---|----|---|-----|-----------|
| AD9144 (DAC) | 8 | 4 | 1 | 32 | 16 | 16 | 1 | 1 | 10 Gbps |
| AD9250 (ADC) | 2 | 2 | 2 | 32 | 14 | 16 | 1 | 1 | 5 Gbps |
| AD9680 (ADC) | 4 | 2 | 1 | 32 | 14 | 16 | 1 | 1 | 10 Gbps |

---

## Step 7: PHY Instance (Connections to Both TX and RX)

```verilog
jesd204_phy_0 jesd204_phy_inst (
    .qpll0_refclk(w_qpll_refclk),
    .qpll1_refclk(w_qpll_refclk),
    .drpclk(clk_axi_100m),
    .tx_reset_gt(w_tx_reset_gt),
    .rx_reset_gt(w_rx_reset_gt),
    .tx_sys_reset(w_tx_sys_reset),
    .rx_sys_reset(w_rx_sys_reset),
    .txp_out(txp_out),    .txn_out(txn_out),
    .rxp_in(rxp_in),      .rxn_in(rxn_in),
    .tx_core_clk(w_tx_core_clk),
    .rx_core_clk(w_rx_core_clk),
    .txoutclk(),           .rxoutclk(),
    .gt_powergood(),

    // TX lanes: direct 64-bit from jesd204c_tx
    .gt0_txdata(gt0_txdata),      .gt0_txcharisk(gt0_txcharisk),  .gt0_txheader(gt0_txheader),
    .gt1_txdata(gt1_txdata),      .gt1_txcharisk(gt1_txcharisk),  .gt1_txheader(gt1_txheader),
    // ... repeat for all TX lanes ...

    .tx_reset_done(w_tx_reset_done),

    // RX lanes: direct 64-bit to jesd204c_rx
    .gt0_rxdata(gt0_rxdata),      .gt0_rxcharisk(gt0_rxcharisk),
    .gt0_rxdisperr(gt0_rxdisperr),.gt0_rxnotintable(gt0_rxnotintable),
    .gt0_rxheader(gt0_rxheader),         // NEW: to RX IP
    .gt0_rxmisalign(gt0_rxmisalign),     // NEW: to RX IP
    .gt0_rxblock_sync(gt0_rxblock_sync), // NEW: to RX IP
    // ... repeat for all RX lanes ...
    // Unused RX lanes: leave outputs unconnected
    .gt2_rxdata(),  .gt2_rxcharisk(),  .gt2_rxheader(),  .gt2_rxmisalign(),  .gt2_rxblock_sync(),

    .rx_reset_done(w_rx_reset_done),
    .rxencommaalign(w_rxencommaalign_out),

    // PLL lock outputs
    .common0_qpll0_lock_out(w_common0_pll0_lock_out),
    .common1_qpll0_lock_out(w_common1_pll0_lock_out),
    .common0_qpll1_lock_out(w_common0_pll1_lock_out),
    .common1_qpll1_lock_out(w_common1_pll1_lock_out)
);
```

---

## Step 8: ILA Debug Signal Updates

Update ILA probes for renamed/removed signals:

```verilog
// Old ILA connections (v7.2):
//   .probe5(w_tx_start_of_frame),
//   .probe6(w_tx_end_of_frame),           // REMOVED
//   .probe7(w_tx_start_of_multiframe),
//   .probe8(w_tx_end_of_multiframe),      // REMOVED
//   .probe9(w_rx_frame_error),

// New ILA connections (v4.3):
    .probe5(w_tx_sof),
    .probe6(4'b0),                          // end_of_frame removed
    .probe7(w_tx_somf),
    .probe8(4'b0),                          // end_of_multiframe removed
    .probe9(w_rx_frm_err),
```

---

## Migration Checklist

- [ ] Create jesd204c_tx IP (set C_ENCODING=0 for 8B10B mode)
- [ ] Create jesd204c_rx IP (set C_ENCODING=0 for 8B10B mode)
- [ ] Update/verify jesd204_phy IP version
- [ ] Update wire declarations: 32-bit -> 64-bit for all GT lane data
- [ ] Add new wire declarations: txheader, rxheader, rxmisalign, rxblock_sync
- [ ] Update TX instance: rename reset, sof/somf, remove PRBS, add headers
- [ ] Update RX instance: rename reset, sof/somf/frm_err, remove eof/eomf, add headers+alignment
- [ ] Remove TX data zero-padding logic (was `{32'b0, data[31:0]}`)
- [ ] Remove RX data slicing logic (was `data[31:0]`)
- [ ] Connect all header signals between JESD204C IPs and PHY
- [ ] Connect rxmisalign and rxblock_sync from PHY to RX IP
- [ ] Update AXI register configuration module (verify addresses unchanged)
- [ ] Update ILA debug cores for new signal names
- [ ] Verify tx_tdata width matches JESD204C expectation (M*N'*frames_per_clk)
- [ ] Run synthesis, check for port mismatch errors
- [ ] Run implementation, verify timing closure
- [ ] Program device, check PLL lock + sync status via ILA/VIO
- [ ] Verify data integrity on TX and RX paths

---

## Common Pitfalls

1. **Forgetting header connections**: txheader/rxheader MUST be connected or link won't sync
2. **Old zero-padding left in code**: Remove `{32'b0, gt_txdata}` patterns, use direct 64-bit
3. **rx_end_of_frame used in user logic**: This signal is gone, redesign logic to use rx_sof
4. **AXI register timing**: Wait for AXI config to complete before releasing TX core reset
5. **tx_tdata byte ordering**: JESD204C uses same byte-interleaved format as v7.2 in 8B10B mode
6. **PRBS testing**: No longer available from JESD IP, must use GT DRP for PRBS
7. **ILA probe names**: Old signal names cause "not found" warnings, update probe connections
