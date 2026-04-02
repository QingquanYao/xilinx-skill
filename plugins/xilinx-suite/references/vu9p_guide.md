# VU9P 纯 FPGA 工程流程指南

## 器件信息

| 项目 | 值 |
|------|-----|
| 系列 | Virtex UltraScale+ |
| 典型 Part | xcvu9p-flgb2104-2-i（或 -3-e / -2L-e 等速度档）|
| 特点 | **纯 PL，无 PS**，无 Zynq 处理器，无 Block Design PS IP |
| PL 资源 | ~2.6M LUT、6840 DSP、2160 BRAM、120 UltraRAM |
| 高速接口 | PCIe Gen4 ×16（硬核）、100G 以太网、GTY Transceiver |

> ⚠️ VU9P 与 Zynq MPSoC 的根本区别：**没有 ARM 处理器**，没有 `zynq_ultra_ps_e` IP，不需要 Block Design，不导出 XSA。这是一个纯 FPGA 设计流程。

---

## 工程创建

```tcl
# VU9P 工程创建（纯 PL，无 BD）
set project_name  "my_vu9p_design"
set project_dir   "./$project_name"
set part_number   "xcvu9p-flgb2104-2-i"

create_project $project_name $project_dir -part $part_number -force

# VU9P 通常不需要设置 board_part（除非用 Alveo U250/U280 等官方板）
# 如果是 Alveo U250：
# set_property board_part xilinx.com:au250:part0:1.3 [current_project]
```

---

## 常用 IP 核（VU9P 典型场景）

### PCIe Gen4 硬核
```tcl
# XDMA（PCIe DMA，最常用的 PCIe IP）
create_ip -name xdma -vendor xilinx.com -library ip -version 4.1 -module_name xdma_0

set_property -dict [list \
  CONFIG.mode_selection           {Advanced} \
  CONFIG.pl_link_cap_max_link_speed {16.0_GT/s} \
  CONFIG.pl_link_cap_max_link_width {X16} \
  CONFIG.axisten_if_enable_client_tag {true} \
  CONFIG.pf0_device_id            {7038} \
  CONFIG.pf0_bar0_scale           {Megabytes} \
  CONFIG.pf0_bar0_size            {256} \
] [get_ips xdma_0]

generate_target all [get_ips xdma_0]
```

### 100G 以太网（CMAC）
```tcl
# 100G MAC（CMAC UltraScale+ 硬核）
create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 \
  -module_name cmac_usplus_0

set_property -dict [list \
  CONFIG.CMAC_CAUI4_MODE {1} \
  CONFIG.NUM_LANES        {4x25} \
  CONFIG.GT_REF_CLK_FREQ {156.25} \
  CONFIG.USER_INTERFACE   {AXIS} \
  CONFIG.TX_FLOW_CONTROL  {0} \
  CONFIG.RX_FLOW_CONTROL  {0} \
] [get_ips cmac_usplus_0]
```

### BRAM / UltraRAM
```tcl
# Block Memory Generator（BRAM）
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 \
  -module_name bram_64kx32

set_property -dict [list \
  CONFIG.Memory_Type          {Simple_Dual_Port_RAM} \
  CONFIG.Write_Width_A        {32} \
  CONFIG.Write_Depth_A        {65536} \
  CONFIG.Read_Width_A         {32} \
  CONFIG.Write_Width_B        {32} \
  CONFIG.Read_Width_B         {32} \
  CONFIG.Enable_32bit_Address {false} \
] [get_ips bram_64kx32]
```

### Clock Wizard（MMCM/PLL）
```tcl
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
  -module_name clk_wiz_0

set_property -dict [list \
  CONFIG.PRIMITIVE              {MMCM} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100.000} \
  CONFIG.USE_LOCKED              {true} \
  CONFIG.USE_RESET               {false} \
] [get_ips clk_wiz_0]
```

---

## 典型工程结构（无 BD）

VU9P 工程完全基于 HDL + IP，不需要 Block Design：

```tcl
# ============================================
# 创建 VU9P 工程并添加文件
# ============================================

create_project $project_name $project_dir -part $part_number -force

# 添加 HDL 源文件
add_files -fileset sources_1 [glob ./hdl/*.v]
add_files -fileset sources_1 [glob ./hdl/*.sv]

# 生成 IP 核（见上面 IP 创建命令）
# 每个 IP 创建后执行：
# generate_target all [get_ips ip_name]

# 添加约束
add_files -fileset constrs_1 ./constraints/top.xdc

# 设置顶层
set_property top my_top [current_fileset]

# 综合
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# 实现 + 比特流
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
```

---

## VU9P XDC 约束要点

### PCIe 时钟（硬核引脚固定，无需手动约束位置）
```xdc
# PCIe 参考时钟（100 MHz，差分）
# 注意：PCIe 硬核时钟引脚由 XDMA IP 自动约束，通常不用手写
# 如果需要手动：
create_clock -period 10.000 -name pcie_refclk \
  [get_ports pcie_refclk_p]
```

### 用户时钟（板卡晶振输入）
```xdc
# 板卡主时钟（300 MHz，差分，以 Alveo U250 为例）
create_clock -period 3.333 -name clk_300m \
  [get_ports clk_300m_p]
```

### GTY Transceiver（高速串口，如 100G 以太网）
```xdc
# GT 参考时钟（156.25 MHz，用于 100G CMAC）
create_clock -period 6.400 -name gt_ref_clk \
  [get_ports gt_ref_clk_p]

# GT 引脚不需要 IOSTANDARD 约束（差分高速引脚由工具自动处理）
```

### HP Bank IO（VU9P 无 HD Bank，全部是 HP）
```xdc
set_property PACKAGE_PIN AW27 [get_ports {led[0]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {led[*]}]
```

### SLR 约束（VU9P 有 3 个 SLR，大型设计需要关注）
```xdc
# 将关键模块锁定到特定 SLR（可选，用于时序收敛）
set_property USER_SLR_ASSIGNMENT SLR0 [get_cells my_pcie_logic]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells my_core_logic]
set_property USER_SLR_ASSIGNMENT SLR2 [get_cells my_hbm_logic]
```

---

## 构建流程（VU9P 特殊注意）

### SLR 跨越时序（VU9P 的主要时序挑战）
VU9P 有 3 个 SLR（Super Logic Region），跨 SLR 的路径延迟较大（约 2-3 ns），时序紧张时需要：
```tcl
# 1. 在跨 SLR 路径上加寄存器（推荐在 RTL 层解决）
# 2. 使用 Pipelining 指令
set_property PIPELINE_STYLE Auto [get_cells crossing_logic]

# 3. 实现时用更激进的策略
set_property STRATEGY {Performance_ExplorePostRoutePhysOpt} [get_runs impl_1]
```

### 推荐实现策略
```tcl
# 对于有 SLR 跨越的大型设计
set_property STRATEGY {Performance_ExplorePostRoutePhysOpt} [get_runs impl_1]

# 或在 Non-Project 模式
place_design   -directive AltSpreadLogic_high
phys_opt_design -directive AggressiveExplore
route_design   -directive AggressiveExplore
phys_opt_design -directive AggressiveExplore
```

---

## 与 MPSoC 流程的关键区别对比

| 项目 | ZU15/19EG（MPSoC）| VU9P（纯 FPGA）|
|------|-----------------|--------------|
| 处理器 | 有（Cortex-A53）| 无 |
| Block Design | 需要（配置 PS）| 不需要 |
| 顶层生成方式 | `make_wrapper`（BD wrapper）| 直接写 HDL 顶层 |
| 主控制器 | PS（ARM）| 无，或用 MicroBlaze 软核 |
| 导出给软件 | 需要 XSA（Vitis/PetaLinux）| 不需要，直接用 .bit |
| 编程接口 | JTAG / SD / QSPI 启动 | JTAG / PCIe JTAG |
| DDR 控制 | PS 内置 DDR 控制器 | 需要 MIG IP 核 |
| SLR | 1 个 | 3 个（需注意跨 SLR 时序）|

---

## MIG（Memory Interface Generator）——VU9P DDR4

如果 VU9P 设计需要 DDR4 内存（无 PS，需要单独 IP）：
```tcl
create_ip -name ddr4 -vendor xilinx.com -library ip -version 2.2 \
  -module_name ddr4_0

set_property -dict [list \
  CONFIG.C0_CLOCK_BOARD_INTERFACE  {default_300mhz_clk0} \
  CONFIG.C0_DDR4_BOARD_INTERFACE   {ddr4_sdram_c1} \
  CONFIG.C0.DDR4_TimePeriod        {833} \
  CONFIG.C0.DDR4_InputClockPeriod  {3332} \
  CONFIG.C0.DDR4_DataWidth         {72} \
  CONFIG.C0.DDR4_DataMask          {NONE} \
  CONFIG.C0.DDR4_Ecc               {true} \
] [get_ips ddr4_0]
```
