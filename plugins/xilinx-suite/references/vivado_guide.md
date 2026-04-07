# Vivado 工程完整流程指南

## 工程类型判断

| 器件 | 类型 | PS 配置 |
|------|------|---------|
| xczu*（Zynq UltraScale+ MPSoC 全系）| MPSoC | 需配置 PS，参考 `mpsoc_ps_config.md` |
| xcvc*（Versal ACAP）| Versal | 使用 CIPS IP，参考 Versal 文档 |
| xcvu*、xcku*、xc7*（UltraScale+/UltraScale/7 系列）| 纯 FPGA | 无 PS，纯 PL 设计 |

---

## 阶段 1：工程创建

生成 `01_create_project.tcl`：

```tcl
# ============================================================
# Vivado 工程创建脚本
# 用法：vivado -mode batch -source 01_create_project.tcl
# ============================================================
set project_name  "my_design"
set project_dir   "./my_design_proj"
set part_number   "<your-part-number>"       ;# 替换为实际 part

# 创建工程
create_project $project_name $project_dir -part $part_number -force

# 基本属性
set_property simulator_language  Mixed      [current_project]
set_property default_lib         xil_defaultlib [current_project]
set_property target_language     Verilog    [current_project]

# 如有自定义 IP 仓库（例如 HLS 导出的 IP）
# set_property ip_repo_paths {./hls_ip_repo} [current_project]
# update_ip_catalog -rebuild

puts "工程创建完成：$project_dir/$project_name.xpr"
```

**运行方式：**
```bash
# 批处理（推荐自动化）
vivado -mode batch -source 01_create_project.tcl -log create.log -nojournal

# 在 Vivado Tcl Console 中运行
source 01_create_project.tcl
```

---

## 阶段 2：Block Design（MPSoC 工程）

生成 `02_create_bd.tcl`。PS 配置参数请参考 `mpsoc_ps_config.md`。

### 2.1 创建 BD 并配置 PS

```tcl
# ============================================================
# Block Design 创建脚本
# 在已打开的 Vivado 工程中运行（Project Mode）
# ============================================================

# 创建 BD
create_bd_design "design_1"
update_compile_order -fileset sources_1

# ------- Zynq UltraScale+ PS -------
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 zynq_ultra_ps_e_0

# 基本 PS 配置（根据 mpsoc_ps_config.md 调整参数）
set_property -dict [list \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
  CONFIG.PSU__USE__M_AXI_HPM0_FPD           {1}   \
  CONFIG.PSU__USE__M_AXI_HPM1_FPD           {0}   \
  CONFIG.PSU__UART0__PERIPHERAL__ENABLE      {1}   \
  CONFIG.PSU__UART0__PERIPHERAL__IO          {MIO 14 .. 15} \
  CONFIG.PSU__CAN1__PERIPHERAL__ENABLE       {0}   \
] [get_bd_cells zynq_ultra_ps_e_0]

# PS 板卡预设（如有官方板卡支持文件，可用此简化配置）
# apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
#   -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]
```

### 2.2 添加复位 IP

```tcl
# Processor System Reset（处理 PS 复位信号，每个时钟域一个）
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_0_100M

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins rst_ps8_0_100M/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
               [get_bd_pins rst_ps8_0_100M/ext_reset_in]
```

### 2.3 AXI 互联（SmartConnect，推荐 Vivado 2019.1+）

```tcl
# SmartConnect：PS 作为 Master，连接多个 PL Slave IP
set N_SLAVES 2   ;# 根据实际 IP 数量修改

create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property CONFIG.NUM_SI {1} [get_bd_cells axi_smc]
set_property CONFIG.NUM_MI $N_SLAVES [get_bd_cells axi_smc]

# 连接 PS → SmartConnect
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins axi_smc/S00_AXI]

# 连接时钟和复位
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins rst_ps8_0_100M/interconnect_aresetn] \
               [get_bd_pins axi_smc/aresetn]
```

### 2.4 添加 AXI IP 示例（AXI GPIO）

```tcl
# AXI GPIO
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list \
  CONFIG.C_GPIO_WIDTH  {8} \
  CONFIG.C_ALL_OUTPUTS {1} \
] [get_bd_cells axi_gpio_0]

# 连接到 SmartConnect
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
                    [get_bd_intf_pins axi_gpio_0/S_AXI]

# 连接时钟、复位
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_ps8_0_100M/peripheral_aresetn] \
               [get_bd_pins axi_gpio_0/s_axi_aresetn]

# GPIO 外部端口
create_bd_port -dir O -from 7 -to 0 gpio_out
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_ports gpio_out]
```

### 2.5 添加自定义 HLS IP

```tcl
# 前提：在工程属性中添加 HLS IP 仓库路径
# set_property ip_repo_paths {./01_hls/hls_proj/solution1/impl/ip} [current_project]
# update_ip_catalog -rebuild

create_bd_cell -type ip -vlnv xilinx.com:hls:my_function:1.0 my_function_0

connect_bd_intf_net [get_bd_intf_pins axi_smc/M01_AXI] \
                    [get_bd_intf_pins my_function_0/s_axi_control]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins my_function_0/ap_clk]
connect_bd_net [get_bd_pins rst_ps8_0_100M/peripheral_aresetn] \
               [get_bd_pins my_function_0/ap_rst_n]
```

### 2.6 中断连接

```tcl
# 聚合多个中断信号
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property CONFIG.NUM_PORTS {2} [get_bd_cells xlconcat_0]

connect_bd_net [get_bd_pins axi_gpio_0/ip2intc_irpt] \
               [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins my_function_0/interrupt] \
               [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins xlconcat_0/dout] \
               [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
```

### 2.7 地址分配和 BD 完成

```tcl
# 自动分配地址（如需手动指定地址，使用 assign_bd_address）
assign_bd_address

# 可选：手动指定地址
# set_property offset 0xA0000000 [get_bd_addr_segs {my_function_0/s_axi_control/reg0}]
# set_property range  4K         [get_bd_addr_segs {my_function_0/s_axi_control/reg0}]

# 验证 BD
validate_bd_design

# 生成 BD wrapper（Verilog）
make_wrapper -files [get_files design_1.bd] -top
set wrapper_file [glob ./my_design_proj/my_design_proj.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v]
add_files -norecurse $wrapper_file
set_property top design_1_wrapper [current_fileset]

# 生成目标文件（IP 产品指南和 HDL）
generate_target all [get_files design_1.bd]
export_ip_user_files -of_objects [get_files design_1.bd] -no_script -sync -force -quiet

puts "Block Design 创建完成"
```

---

## 阶段 3：添加 HDL 源文件

生成 `03_add_sources.tcl`：

```tcl
# Verilog 源文件
if {[llength [glob -nocomplain ./hdl/*.v]] > 0} {
    add_files -fileset sources_1 [glob ./hdl/*.v]
}
# SystemVerilog
if {[llength [glob -nocomplain ./hdl/*.sv]] > 0} {
    add_files -fileset sources_1 [glob ./hdl/*.sv]
}
# VHDL
if {[llength [glob -nocomplain ./hdl/*.vhd]] > 0} {
    add_files -fileset sources_1 [glob ./hdl/*.vhd]
}
# 仿真文件
if {[llength [glob -nocomplain ./sim/*.v]] > 0} {
    add_files -fileset sim_1 [glob ./sim/*.v]
}

# 纯 PL 工程设置顶层（BD 工程已自动设置 wrapper 为顶层，无需这步）
# set_property top my_top [current_fileset]

update_compile_order -fileset sources_1
```

---

## 阶段 4：XDC 约束

参考 `xdc_constraints.md` 生成详细约束。最简模板：

```xdc
## 时钟约束（必须第一个定义）
# create_clock -period 10.000 -name clk_in [get_ports clk_in]

## PL GPIO 引脚约束（MPSoC）
# set_property PACKAGE_PIN  <引脚>    [get_ports gpio_out[0]]
# set_property IOSTANDARD   LVCMOS18  [get_ports gpio_out[0]]

## 假路径约束（跨时钟域）
# set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
```

添加 XDC 文件：
```tcl
add_files -fileset constrs_1 -norecurse ./constraints/design.xdc
```

---

## 阶段 5：综合与实现

生成 `05_build.tcl`：

```tcl
# ============================================================
# 综合、实现、比特流生成（Project Mode）
# ============================================================

# 打开工程（如从新终端运行）
# open_project ./my_design_proj/my_design_proj.xpr

# ——— 综合 ———
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "综合失败！请检查 synth_1.log"
}
puts "综合完成"

# ——— 实现（含比特流）———
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "实现失败！请检查 impl_1.log"
}
puts "实现完成"

# ——— 导出 XSA ———
open_run impl_1
file mkdir ./output
write_hw_platform -fixed -force -include_bit ./output/design_fixed.xsa
puts "XSA 已导出：./output/design_fixed.xsa"
```

### 综合策略选择

| 场景 | 综合策略 | 实现策略 |
|------|---------|---------|
| 一般设计 | `Vivado Synthesis Defaults` | `Vivado Implementation Defaults` |
| 时序紧张 | `Flow_PerfOptimized_high` | `Performance_ExplorePostRoutePhysOpt` |
| 资源紧张 | `Flow_AreaOptimized_high` | `Area_ExploreSequential` |
| 快速迭代 | `Flow_RuntimeOptimized` | `Flow_RuntimeOptimized` |

---

## 阶段 6：报告分析

生成 `06_reports.tcl`：

```tcl
open_run impl_1

file mkdir ./reports

# 时序摘要（首先看这个）
report_timing_summary -delay_type min_max -report_unconstrained \
    -max_paths 10 -file ./reports/timing_summary.rpt

# 时序违例详情
report_timing -max_paths 50 -slack_lesser_than 0.0 \
    -sort_by slack -file ./reports/timing_violations.rpt

# 资源利用率（分层次）
report_utilization -hierarchical -file ./reports/utilization.rpt

# 功耗
report_power -file ./reports/power.rpt

# 时钟
report_clock_utilization -file ./reports/clocks.rpt
```

### 时序结果解读

| 指标 | 含义 | 通过标准 |
|------|------|---------|
| WNS（最差负裕量）| 最慢路径的余量 | ≥ 0（负值表示违例）|
| TNS（总负裕量）| 所有违例路径总和 | = 0 |
| WHS（最差保持裕量）| 保持时间余量 | ≥ 0 |

**WNS < 0 时的修复策略（按优先级排序）：**
1. 升高综合/实现策略等级（最简单，先试）
2. 添加 `phys_opt_design` 步骤
3. 在 HDL 中插入流水线寄存器拆分关键路径
4. 在 XDC 中添加 `set_multicycle_path` 放松多周期路径
5. 降低时钟频率

---

## 阶段 7：导出 XSA

```tcl
# 综合前 XSA（含 BD，供在 Vitis 中查看 IP 地址映射）
write_hw_platform -force ./output/design_pre.xsa

# 实现后固定 XSA（含比特流，供 Vitis 裸机开发 / PetaLinux 使用）
open_run impl_1
write_hw_platform -fixed -force -include_bit ./output/design_fixed.xsa
```

---

## Non-Project 模式（适合 CI/自动化）

```tcl
# 不创建 .xpr 文件，直接综合实现
read_verilog    [glob ./hdl/*.v]
read_bd         [glob ./bd/*.bd]
read_xdc        ./constraints/design.xdc

synth_design    -top design_1_wrapper -part <your-part-number>
write_checkpoint -force ./checkpoints/post_synth.dcp
report_timing_summary -file ./reports/post_synth_timing.rpt

opt_design
place_design    -directive Explore
phys_opt_design
route_design    -directive AggressiveExplore

write_bitstream -force ./output/design.bit
write_hw_platform -fixed -force -include_bit ./output/design_fixed.xsa
```

---

## 常见问题

**Q：BD 中 IP 找不到怎么办？**
```tcl
# 检查 IP 目录
get_ipdefs -filter {NAME =~ *zynq*}
# 刷新 IP 目录
update_ip_catalog -rebuild
```

**Q：SmartConnect 如何支持多时钟？**
```tcl
# 设置从时钟数量
set_property CONFIG.NUM_CLKS {2} [get_bd_cells axi_smc]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk1] \
               [get_bd_pins axi_smc/aclk1]
```

**Q：如何在批处理模式中打开已有工程？**
```tcl
open_project /path/to/project.xpr
```
