# 纯 FPGA 工程流程指南（无 PS）

## 适用范围

本指南适用于**无 ARM 处理器的纯 FPGA 工程**，包括但不限于：

- Virtex UltraScale+ / Virtex UltraScale
- Kintex UltraScale+ / Kintex UltraScale
- Artix UltraScale+ / 7 系列纯 FPGA（xc7a*、xc7k*、xc7v*）
- Alveo 加速卡（U50/U200/U250/U280 等，底层是 UltraScale+ FPGA）

> ⚠️ 与 Zynq MPSoC 的根本区别：**没有 ARM 处理器**，没有 `zynq_ultra_ps_e` IP，不需要 Block Design，不导出 XSA。这是一个纯 FPGA 设计流程。

---

## 工程创建

```tcl
# 纯 FPGA 工程创建（纯 PL，无 BD）
set project_name  "my_fpga_design"
set project_dir   "./$project_name"
set part_number   "<your-part-number>"   ;# 如 xcvu9p-flgb2104-2-i、xcku115-flvf1924-2-i 等

create_project $project_name $project_dir -part $part_number -force

# 纯 FPGA 工程通常不需要设置 board_part（除非用 Alveo 等官方板）
# 例如 Alveo 卡：
# set_property board_part <vendor>:<board>:part0:<version> [current_project]
```

---

## 常用 IP 核（纯 FPGA 典型场景）

### PCIe 硬核 + XDMA
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

> PCIe 链路速度/宽度需根据器件支持能力调整（Gen3/Gen4，x1~x16）。

### 100G 以太网（CMAC）
```tcl
# 100G MAC（CMAC UltraScale+ 硬核，部分器件支持）
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

纯 FPGA 工程完全基于 HDL + IP，不需要 Block Design：

```tcl
# ============================================
# 创建纯 FPGA 工程并添加文件
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

## XDC 约束要点

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
# 板卡主时钟（示例：300 MHz 差分）
create_clock -period 3.333 -name clk_300m \
  [get_ports clk_300m_p]
```

### GT Transceiver（高速串口，如 100G 以太网）
```xdc
# GT 参考时钟（示例：156.25 MHz，用于 100G CMAC）
create_clock -period 6.400 -name gt_ref_clk \
  [get_ports gt_ref_clk_p]

# GT 引脚不需要 IOSTANDARD 约束（差分高速引脚由工具自动处理）
```

### HP Bank IO 约束
```xdc
set_property PACKAGE_PIN <pin> [get_ports {led[0]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {led[*]}]
```

### SLR 约束（多 SLR 大型器件）
部分高端器件（如 VU9P、VU13P 等）采用多 SLR 堆叠（Super Logic Region）架构，跨 SLR 路径延迟较大，大型设计需要显式指派：
```xdc
# 将关键模块锁定到特定 SLR（用于时序收敛）
set_property USER_SLR_ASSIGNMENT SLR0 [get_cells my_pcie_logic]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells my_core_logic]
set_property USER_SLR_ASSIGNMENT SLR2 [get_cells my_hbm_logic]
```

---

## 构建流程特殊注意

### SLR 跨越时序（多 SLR 器件的主要时序挑战）
多 SLR 器件跨 SLR 的路径延迟较大（典型 2-3 ns），时序紧张时需要：
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

| 项目 | Zynq UltraScale+ MPSoC | 纯 FPGA（无 PS） |
|------|-----------------------|------------------|
| 处理器 | 有（Cortex-A53）| 无 |
| Block Design | 需要（配置 PS）| 不需要 |
| 顶层生成方式 | `make_wrapper`（BD wrapper）| 直接写 HDL 顶层 |
| 主控制器 | PS（ARM）| 无，或用 MicroBlaze 软核 |
| 导出给软件 | 需要 XSA（Vitis/PetaLinux）| 不需要，直接用 .bit |
| 编程接口 | JTAG / SD / QSPI 启动 | JTAG / PCIe JTAG |
| DDR 控制 | PS 内置 DDR 控制器 | 需要 MIG / DDR4 IP 核 |
| SLR | 通常 1 个 | 视器件而定，大器件可能多个 |

---

## MIG / DDR4 IP —— 纯 FPGA DDR 内存控制器

如果纯 FPGA 设计需要 DDR 内存（无 PS，需要单独 IP）：
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
