# XDC 约束文件完整指南

XDC 文件用于告知 Vivado 物理和时序约束。约束顺序很重要：**时钟定义 → IO 约束 → 时序例外**。

---

## 一、时钟约束（最关键，必须首先定义）

### 主时钟输入
```xdc
# 单端时钟（100 MHz，10 ns 周期）
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} \
  [get_ports sys_clk]

# 差分时钟对（只约束正端）
create_clock -period 10.000 -name sys_clk_p \
  [get_ports sys_clk_p]
# 注意：sys_clk_n 无需单独约束
```

### 生成时钟（MMCM/PLL 输出）
```xdc
# MMCM 生成的 200 MHz 时钟
create_generated_clock -name clk_200m \
  -source [get_pins mmcm_inst/CLKIN1] \
  -multiply_by 2 \
  [get_pins mmcm_inst/CLKOUT0]

# MMCM 生成的 50 MHz 时钟
create_generated_clock -name clk_50m \
  -source [get_pins mmcm_inst/CLKIN1] \
  -divide_by 2 \
  [get_pins mmcm_inst/CLKOUT1]
```

> ⚠️ 对于使用 Clock Wizard IP 的设计，Vivado 通常会自动生成这些约束。检查综合后报告，避免重复定义。

---

## 二、IO 引脚约束

### 基本格式
```xdc
# 引脚位置
set_property PACKAGE_PIN <引脚号> [get_ports <端口名>]
# IO 电平标准
set_property IOSTANDARD  <标准>   [get_ports <端口名>]
```

### PL IO Bank 电平参考（通用原则）

| Bank 类型 | 典型 VCCIO | 推荐 IOSTANDARD |
|-----------|-----------|----------------|
| HP（High-Performance） | 1.8V 及以下 | LVCMOS18、LVDS、HSTL/SSTL 等 |
| HD（High-Density） | 1.8V / 3.3V | LVCMOS18 / LVCMOS33 |

> ⚠️ **同一 Bank 内所有 IO 必须使用相同电平组**（VCCIO 统一），混用会导致错误。具体 Bank 编号请查阅目标器件的 Package/Pinout 手册。

### 常用 IO 标准
```xdc
# 单端低电压
set_property IOSTANDARD LVCMOS33 [get_ports led[*]]    ;# 3.3V
set_property IOSTANDARD LVCMOS18 [get_ports data_in]   ;# 1.8V

# 差分对（高速接口）
set_property PACKAGE_PIN AA1 [get_ports clk_p]
set_property PACKAGE_PIN AA2 [get_ports clk_n]
set_property IOSTANDARD LVDS [get_ports clk_p]
set_property IOSTANDARD LVDS [get_ports clk_n]

# 驱动强度和边沿速率（单端 IO 有效）
set_property DRIVE 8       [get_ports led[*]]  ;# 8/12/16 mA
set_property SLEW  SLOW    [get_ports led[*]]  ;# SLOW / FAST
```

### 批量约束写法（推荐）
```xdc
# 同类端口批量设置
set_property IOSTANDARD LVCMOS18 [get_ports {led[*] btn[*]}]

# 使用 foreach 处理复杂分配
# （在 Tcl Console 中也可以这样写）
foreach {port pin} {
  led_0   H7
  led_1   J7
  led_2   K7
  btn_0   G6
} {
  set_property PACKAGE_PIN $pin [get_ports $port]
  set_property IOSTANDARD LVCMOS18 [get_ports $port]
}
```

---

## 三、IO 时序约束

仅用于有时序要求的外部接口（与外部芯片通信时需要）：

```xdc
# 输入延迟（从外部芯片到 FPGA，最大/最小）
set_input_delay -clock sys_clk -max  2.000 [get_ports data_in[*]]
set_input_delay -clock sys_clk -min  0.500 [get_ports data_in[*]]

# 输出延迟（从 FPGA 到外部芯片）
set_output_delay -clock sys_clk -max  1.500 [get_ports data_out[*]]
set_output_delay -clock sys_clk -min -1.000 [get_ports data_out[*]]
```

---

## 四、时序例外约束

### False Path（完全异步信号）
```xdc
# 跨时钟域的异步信号，无时序关系
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
set_false_path -from [get_clocks clk_b] -to [get_clocks clk_a]

# 具体信号的 false path（如慢速控制信号）
set_false_path -from [get_ports reset_ext]

# 从特定寄存器输出的路径
set_false_path -from [get_cells config_reg[*]]
```

### 异步时钟组（推荐方式，比 false path 更清晰）
```xdc
# 声明两组时钟完全异步
set_clock_groups -asynchronous \
  -group [get_clocks clk_100m] \
  -group [get_clocks clk_200m_async]
```

### Multicycle Path（多周期路径，放松时序要求）
```xdc
# 数据每 2 个周期采样一次（Setup 放松 1 个周期）
set_multicycle_path -setup 2 \
  -from [get_cells data_src_reg[*]] \
  -to   [get_cells data_dst_reg[*]]

# 对应的 Hold 约束（必须配对，否则 Hold 会过于严格）
set_multicycle_path -hold  1 \
  -from [get_cells data_src_reg[*]] \
  -to   [get_cells data_dst_reg[*]]
```

### Max Delay（精确控制路径延迟，常用于 CDC 同步器）
```xdc
# 跨时钟域同步器（2FF 同步链）推荐写法
# 限制发送端寄存器到同步器第一级的路径延迟不超过目标时钟周期
set_max_delay -datapath_only 5.0 \
  -from [get_cells src_cdc_reg] \
  -to   [get_cells sync_stage1_reg]
```

---

## 五、Vivado 调试约束（ILA）

```xdc
# ILA debug hub 的时钟约束
# （通常 Vivado 自动处理，但遇到问题时手动添加）
create_debug_hub
set_property C_CLK_INPUT_FREQ_HZ  100000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false      [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN    1          [get_debug_cores dbg_hub]
```

---

## 六、完整 XDC 文件结构示例

```xdc
##############################################################
# 文件名: design.xdc
# 工程:   ZynqMP 演示工程
# 说明:   PL 端 IO 约束（PS 端引脚由 Vivado 自动处理）
##############################################################

# ==== 1. 主时钟（来自板卡晶振） ====
create_clock -period 10.000 -name pl_clk_in [get_ports pl_clk_in_p]

# ==== 2. 异步时钟域声明 ====
# 注意：ps8 内部时钟由 Vivado 自动处理，不需要手动定义
# 如有多个独立时钟域，在此声明
# set_clock_groups -asynchronous ...

# ==== 3. PL IO 引脚 ====
# LED（HD Bank，LVCMOS33）
set_property PACKAGE_PIN H3  [get_ports {led[0]}]
set_property PACKAGE_PIN H4  [get_ports {led[1]}]
set_property PACKAGE_PIN H5  [get_ports {led[2]}]
set_property PACKAGE_PIN H6  [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
set_property SLEW SLOW  [get_ports {led[*]}]
set_property DRIVE 4    [get_ports {led[*]}]

# 按键（HP Bank，LVCMOS18）
set_property PACKAGE_PIN G7  [get_ports {btn[0]}]
set_property PACKAGE_PIN G8  [get_ports {btn[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {btn[*]}]

# ==== 4. 时序例外 ====
# 按键去抖逻辑（异步采样，不需要时序分析）
set_false_path -from [get_ports {btn[*]}]
```

---

## 七、常见错误和注意事项

1. **`[get_ports xxx]` 返回空**：检查 HDL 顶层端口名是否与 XDC 中一致（大小写敏感）
2. **`IOSTANDARD` 和 `PACKAGE_PIN` 必须同时设置**，缺一不可
3. **同 Bank 混用不同 IOSTANDARD**：Vivado 会报错 DRC，检查 VCCIO 设计
4. **差分时钟只约束正端**（`_p`），负端自动关联
5. **PS 端引脚不需要在 XDC 中约束**，由 Zynq PS IP 的配置自动管理
6. **综合后运行 `report_clock_interaction`** 检查所有跨时钟域路径是否都有约束
