# Zynq UltraScale+ MPSoC Block Design 配置指南
## 适用器件：Zynq UltraScale+ MPSoC 全系（CG/EG/EV 各子型号）

## 器件系列概览

Zynq UltraScale+ MPSoC 分为三大子系列：

| 子系列 | 主要特征 | 典型用途 |
|--------|----------|----------|
| CG | 双核 A53 + 双核 R5F，无 GPU | 低成本嵌入式控制 |
| EG | 四核 A53 + 双核 R5F + Mali-400 GPU | 通用嵌入式 + 图形 |
| EV | EG 全部特性 + VCU（H.264/H.265 硬核编解码） | 视频处理 |

**所有子系列的 PS 配置方法完全相同**，只需根据实际 part number 切换。官方评估板（ZCU10x 系列）有 Xilinx 提供的 Board Support Package，支持 `apply_bd_automation` 一键预设；自制板必须手动配置每个 PS 参数。

---

## Zynq PS IP 核名称

| Vivado 版本 | IP VLNV |
|-------------|---------|
| 2018.x–2024.x | `xilinx.com:ip:zynq_ultra_ps_e:3.3`（或更新的 3.4/3.5） |

获取最新版本：
```tcl
set ps_vlnv [lindex [get_ipdefs *zynq_ultra_ps_e*] end]
create_bd_cell -type ip -vlnv $ps_vlnv zynq_ultra_ps_e_0
```

---

## PS 关键配置参数

### DDR4 内存接口
```tcl
# 常见 DDR4 配置（需根据实际硬件原理图调整！）
CONFIG.PSU__DDRC__ENABLE           {1}
CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {0}
CONFIG.PSU__DDRC__BUS_WIDTH        {64}       ;# 64-bit 数据总线（带 ECC 则 72）
CONFIG.PSU__DDRC__ECC              {Disabled} ;# 或 Enabled
CONFIG.PSU__DDRC__SPEED_BIN        {DDR4_2400T}
CONFIG.PSU__DDRC__T_RCD            {11}
CONFIG.PSU__DDRC__T_RP             {11}
CONFIG.PSU__DDRC__T_RC             {39}

# 内存地址范围（2GB 示例）
CONFIG.PSU__DDR__MEMORY__BASEADDR  {0x0000000000000000}
CONFIG.PSU__DDR__MEMORY__HIGHADDR  {0x000000007FFFFFFF}
```

> ⚠️ DDR4 时序参数（T_RCD、T_RP 等）**必须**对照内存颗粒手册填写，否则系统可能不稳定。建议从板卡厂商参考设计复制。

### MIO 外设配置
```tcl
# UART0（PS 控制台，常用于调试）
CONFIG.PSU__UART0__PERIPHERAL__ENABLE {1}
CONFIG.PSU__UART0__PERIPHERAL__IO    {MIO 14..15}
CONFIG.PSU__UART0__BAUD_RATE         {115200}

# UART1（可选的第二串口）
CONFIG.PSU__UART1__PERIPHERAL__ENABLE {0}

# Ethernet 0（千兆以太网）
CONFIG.PSU__ETHERNET0__PERIPHERAL__ENABLE  {1}
CONFIG.PSU__ETHERNET0__PERIPHERAL__IO      {MIO 26..31}
CONFIG.PSU__ETHERNET0__GRP_MDIO__ENABLE    {1}
CONFIG.PSU__ETHERNET0__GRP_MDIO__IO        {MIO 32..33}

# USB 0（USB 3.0 需要 GT Transceiver）
CONFIG.PSU__USB0__PERIPHERAL__ENABLE  {1}
CONFIG.PSU__USB0__PERIPHERAL__IO      {MIO 52..63}
CONFIG.PSU__USB0__REF_CLK_SEL         {Ref Clk0}

# SD / eMMC
CONFIG.PSU__SDIO1__PERIPHERAL__ENABLE  {1}
CONFIG.PSU__SDIO1__PERIPHERAL__IO      {MIO 46..51}
CONFIG.PSU__SDIO1__GRP_CD__ENABLE      {1}
CONFIG.PSU__SDIO1__GRP_CD__IO         {MIO 45}

# QSPI（启动 Flash）
CONFIG.PSU__QSPI__PERIPHERAL__ENABLE  {1}
CONFIG.PSU__QSPI__PERIPHERAL__IO      {MIO 0..12}
CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE   {1}
CONFIG.PSU__QSPI__GRP_FBCLK__IO      {MIO 6}

# I2C 0
CONFIG.PSU__I2C0__PERIPHERAL__ENABLE  {1}
CONFIG.PSU__I2C0__PERIPHERAL__IO      {MIO 18..19}

# GPIO（MIO 扩展）
CONFIG.PSU__GPIO0__PERIPHERAL__ENABLE {1}
CONFIG.PSU__GPIO0__PERIPHERAL__IO    {MIO 0..25}
CONFIG.PSU__GPIO1__PERIPHERAL__ENABLE {1}
CONFIG.PSU__GPIO1__PERIPHERAL__IO    {MIO 26..51}
```

### PL 时钟配置
```tcl
# PL 时钟 0（通常是主时钟，AXI 总线常用 100/150 MHz）
CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ  {100}
CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {100}

# PL 时钟 1（可选，高速逻辑用 200/300 MHz）
CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ  {200}

# PL 时钟 2/3（可选，特殊需求）
CONFIG.PSU__CRL_APB__PL2_REF_CTRL__FREQMHZ  {0}  ;# 0=禁用
CONFIG.PSU__CRL_APB__PL3_REF_CTRL__FREQMHZ  {0}
```

### PS-PL AXI 接口配置
```tcl
# === PS 作为 AXI Master（控制 PL 外设）===
# HPM0_FPD：32-bit，高性能主接口（最常用）
CONFIG.PSU__USE__M_AXI_HPM0_FPD          {1}
CONFIG.PSU__MAXIGP0__DATA_WIDTH          {32}
# HPM1_FPD（第二主接口）
CONFIG.PSU__USE__M_AXI_HPM1_FPD          {0}
# HPM0_LPD（低功耗域）
CONFIG.PSU__USE__M_AXI_HPM0_LPD          {0}

# === PL 作为 AXI Master（DMA 访问 PS DDR）===
# HPC0/HPC1（高性能带缓存）
CONFIG.PSU__USE__S_AXI_HPC0_FPD          {0}
# HP0-HP3（高性能，无缓存，DMA 数据路径首选）
CONFIG.PSU__USE__S_AXI_HP0_FPD           {1}
CONFIG.PSU__SAXIGP2__DATA_WIDTH          {128}  ;# HP0 数据宽度
CONFIG.PSU__USE__S_AXI_HP1_FPD           {0}
CONFIG.PSU__USE__S_AXI_HP2_FPD           {0}
CONFIG.PSU__USE__S_AXI_HP3_FPD           {0}
# ACP（加速一致性端口）
CONFIG.PSU__USE__S_AXI_ACP               {0}
```

### 中断配置
```tcl
# PL 到 PS 中断（最多支持 8+8 = 16 个 PL 中断）
CONFIG.PSU__USE__IRQ0  {1}   ;# pl_ps_irq0（8 位，连 xlconcat 输出）
CONFIG.PSU__USE__IRQ1  {0}   ;# pl_ps_irq1（可选）
```

---

## 完整 BD 脚本框架（Zynq UltraScale+ MPSoC 通用）

```tcl
# ============================================
# Block Design 创建脚本（Zynq UltraScale+ MPSoC 通用基础配置）
# ============================================

# 创建 BD
create_bd_design "design_1"

# --------------------------------------------
# 1. Zynq UltraScale+ PS
# --------------------------------------------
set ps_vlnv [lindex [get_ipdefs *zynq_ultra_ps_e*] end]
create_bd_cell -type ip -vlnv $ps_vlnv zynq_ultra_ps_e_0

set_property -dict [list \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ   {100} \
  CONFIG.PSU__USE__M_AXI_HPM0_FPD               {1} \
  CONFIG.PSU__MAXIGP0__DATA_WIDTH               {32} \
  CONFIG.PSU__USE__IRQ0                          {1} \
  CONFIG.PSU__UART0__PERIPHERAL__ENABLE          {1} \
  CONFIG.PSU__UART0__PERIPHERAL__IO              {MIO 14..15} \
  CONFIG.PSU__ETHERNET0__PERIPHERAL__ENABLE      {1} \
  CONFIG.PSU__ETHERNET0__PERIPHERAL__IO          {MIO 26..31} \
  CONFIG.PSU__ETHERNET0__GRP_MDIO__ENABLE        {1} \
  CONFIG.PSU__ETHERNET0__GRP_MDIO__IO            {MIO 32..33} \
  CONFIG.PSU__QSPI__PERIPHERAL__ENABLE           {1} \
  CONFIG.PSU__QSPI__PERIPHERAL__IO               {MIO 0..12} \
] [get_bd_cells zynq_ultra_ps_e_0]

# --------------------------------------------
# 2. Processor System Reset
# --------------------------------------------
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pl_clk0

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins rst_pl_clk0/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
               [get_bd_pins rst_pl_clk0/ext_reset_in]

# --------------------------------------------
# 3. AXI SmartConnect（主互连）
# --------------------------------------------
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property CONFIG.NUM_SI {1} [get_bd_cells axi_smc]
set_property CONFIG.NUM_MI {2} [get_bd_cells axi_smc]  ;# 按实际外设数修改

connect_bd_intf_net \
  [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
  [get_bd_intf_pins axi_smc/S00_AXI]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins rst_pl_clk0/interconnect_aresetn] \
               [get_bd_pins axi_smc/aresetn]

# --------------------------------------------
# 4. AXI GPIO（示例外设）
# --------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list \
  CONFIG.C_GPIO_WIDTH    {8} \
  CONFIG.C_ALL_OUTPUTS   {1} \
] [get_bd_cells axi_gpio_0]

connect_bd_intf_net \
  [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins axi_gpio_0/S_AXI]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_pl_clk0/peripheral_aresetn] \
               [get_bd_pins axi_gpio_0/s_axi_aresetn]

# --------------------------------------------
# 5. 中断（如有外设产生中断）
# --------------------------------------------
# create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_irq
# set_property CONFIG.NUM_PORTS {1} [get_bd_cells xlconcat_irq]
# connect_bd_net [get_bd_pins axi_gpio_0/ip2intc_irpt] \
#                [get_bd_pins xlconcat_irq/In0]
# connect_bd_net [get_bd_pins xlconcat_irq/dout] \
#                [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

# --------------------------------------------
# 6. 设置外部端口（PL 引脚）
# --------------------------------------------
# 将 GPIO 输出连接到顶层端口示例：
# make_bd_pins_external [get_bd_pins axi_gpio_0/gpio_io_o]
# set_property name led [get_bd_ports gpio_io_o_0]

# --------------------------------------------
# 7. 地址分配
# --------------------------------------------
assign_bd_address

# 可手动设置地址（可选）
# set_property offset 0xA0000000 [get_bd_addr_segs \
#   {zynq_ultra_ps_e_0/Data/SEG_axi_gpio_0_Reg}]

# --------------------------------------------
# 8. 验证和生成
# --------------------------------------------
validate_bd_design
save_bd_design

# 生成输出产品
generate_target all [get_files design_1.bd]

# 创建顶层 HDL Wrapper
make_wrapper -files [get_files design_1.bd] -top
add_files -norecurse [glob ./*/*/sources_1/bd/design_1/hdl/*wrapper*]
set_property top design_1_wrapper [current_fileset]
```

---

## 常见问题

**Q：apply_bd_automation 有什么用？**
A：可以自动完成 PS 的 DDR 和 MIO 配置（使用板卡预设），省去手动配置参数。但需要 Vivado 已安装对应的 Board Files。若没有预设，建议手动配置。

**Q：SmartConnect vs AXI Interconnect，选哪个？**
A：Vivado 2019.1+ 推荐 SmartConnect（自动优化，更简单）。老版本项目保留 AXI Interconnect 即可。

**Q：HPM0_FPD 和 HP0_FPD 的区别？**
A：HPM（High Performance Master）是 PS 作为主控访问 PL；HP（High Performance Slave）是 PL（如 DMA）作为主控访问 PS 内存（DDR）。

**Q：为什么 XSA 要用 fixed？**
A：`-fixed` 表示含比特流的固定硬件平台，PetaLinux 和 Vitis 都需要这个来知道具体的硬件配置和地址映射。没有 `-fixed` 的 XSA 只含 BD，不含比特流。

---

## 官方评估板快速上手（Board Preset 方式）

Xilinx 官方评估板（如 ZCU10x 系列）有 Board Support Package，可大幅简化 PS 配置：

```tcl
# 方法一：在创建工程时指定板卡
create_project my_proj ./my_proj -part <your-part-number>
set_property board_part <vendor>:<board>:part0:<version> [current_project]

# 方法二：创建 BD 后应用板卡预设（自动配置 DDR4、MIO、时钟）
create_bd_design "design_1"
set ps_vlnv [lindex [get_ipdefs *zynq_ultra_ps_e*] end]
create_bd_cell -type ip -vlnv $ps_vlnv zynq_ultra_ps_e_0

# 应用板卡预设（会自动填充 DDR4 时序、MIO 引脚分配等）
apply_bd_automation \
  -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
  -config {apply_board_preset "1"} \
  [get_bd_cells zynq_ultra_ps_e_0]
```

> 使用 Board Preset 后，DDR4、UART、Ethernet、USB、SD 等常用外设的 MIO 引脚会自动按官方原理图配置，无需手动查引脚表。

**官方评估板与自定义板的主要区别：**
- 官方评估板有 Board Files，支持 `apply_bd_automation` 一键预设
- 自制板（无论哪个子型号）没有 Board Files，必须手动配置每个 PS 参数
- EV 系列器件包含 VCU（Video Codec Unit）硬核，如需使用需额外配置 `v_proc_ss` 等 IP
