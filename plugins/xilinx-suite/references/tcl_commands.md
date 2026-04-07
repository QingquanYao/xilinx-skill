# Vivado Tcl 命令速查表

## 工程管理

| 命令 | 说明 | 示例 |
|------|------|------|
| `create_project` | 创建新工程 | `create_project my_proj . -part <part_number> -force` |
| `open_project` | 打开工程 | `open_project ./my_proj/my_proj.xpr` |
| `close_project` | 关闭工程 | `close_project` |
| `current_project` | 获取当前工程 | `get_property PART [current_project]` |
| `get_runs` | 列出 runs | `get_runs synth_1` |

## 文件管理

| 命令 | 说明 | 示例 |
|------|------|------|
| `add_files` | 添加文件到工程 | `add_files -fileset sources_1 ./hdl/*.v` |
| `add_files -fileset constrs_1` | 添加约束文件 | `add_files -fileset constrs_1 ./constraints.xdc` |
| `read_verilog` | 读取 Verilog（非工程模式）| `read_verilog ./hdl/top.v` |
| `read_vhdl` | 读取 VHDL | `read_vhdl -library work ./hdl/top.vhd` |
| `read_xdc` | 读取 XDC（非工程模式）| `read_xdc ./constraints.xdc` |
| `get_files` | 获取文件列表 | `get_files *.bd` |
| `remove_files` | 删除文件 | `remove_files ./old_file.v` |

## Block Design

| 命令 | 说明 | 示例 |
|------|------|------|
| `create_bd_design` | 创建 BD | `create_bd_design "design_1"` |
| `open_bd_design` | 打开 BD | `open_bd_design [get_files design_1.bd]` |
| `save_bd_design` | 保存 BD | `save_bd_design` |
| `create_bd_cell` | 添加 IP | `create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0` |
| `delete_bd_objs` | 删除 BD 对象 | `delete_bd_objs [get_bd_cells axi_gpio_0]` |
| `set_property` | 设置 IP 属性 | `set_property CONFIG.C_GPIO_WIDTH 8 [get_bd_cells axi_gpio_0]` |
| `set_property -dict` | 批量设置属性 | `set_property -dict [list CONFIG.A {1} CONFIG.B {2}] [get_bd_cells ...]` |
| `connect_bd_intf_net` | 连接 AXI 接口 | `connect_bd_intf_net [get_bd_intf_pins ip/S_AXI] [get_bd_intf_pins smc/M00_AXI]` |
| `connect_bd_net` | 连接信号线 | `connect_bd_net [get_bd_pins ip/clk] [get_bd_pins ps/pl_clk0]` |
| `disconnect_bd_net` | 断开连接 | `disconnect_bd_net [get_bd_nets clk_net] [get_bd_pins ...]` |
| `create_bd_port` | 创建 BD 顶层端口 | `create_bd_port -dir O -type data led` |
| `make_bd_pins_external` | 引脚连接到顶层 | `make_bd_pins_external [get_bd_pins axi_gpio_0/gpio_io_o]` |
| `apply_bd_automation` | 自动连接 | `apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e ...` |
| `validate_bd_design` | 验证 BD | `validate_bd_design` |
| `assign_bd_address` | 自动地址分配 | `assign_bd_address` |
| `get_bd_cells` | 获取 IP 单元 | `get_bd_cells axi_gpio_0` |
| `get_bd_intf_pins` | 获取 AXI 接口 | `get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD` |
| `get_bd_pins` | 获取信号引脚 | `get_bd_pins zynq_ultra_ps_e_0/pl_clk0` |
| `get_bd_addr_segs` | 获取地址段 | `get_bd_addr_segs {ps/Data/SEG_axi_gpio_0_Reg}` |

## 生成产品和 Wrapper

| 命令 | 说明 | 示例 |
|------|------|------|
| `generate_target` | 生成输出产品 | `generate_target all [get_files design_1.bd]` |
| `make_wrapper` | 创建 HDL Wrapper | `make_wrapper -files [get_files design_1.bd] -top` |
| `export_ip_user_files` | 导出 IP 用户文件 | `export_ip_user_files -of_objects [get_files design_1.bd] -force` |

## 综合与实现（Project 模式）

| 命令 | 说明 | 示例 |
|------|------|------|
| `launch_runs` | 启动 run | `launch_runs synth_1 -jobs 8` |
| `wait_on_run` | 等待 run 完成 | `wait_on_run synth_1` |
| `get_property PROGRESS` | 查看进度 | `get_property PROGRESS [get_runs synth_1]` |
| `get_property STATUS` | 查看状态 | `get_property STATUS [get_runs synth_1]` |
| `open_run` | 打开 run | `open_run impl_1` |
| `set_property STRATEGY` | 设置策略 | `set_property STRATEGY {Vivado Implementation Defaults} [get_runs impl_1]` |
| `reset_run` | 重置 run | `reset_run synth_1` |

## 综合与实现（非工程模式）

| 命令 | 说明 | 示例 |
|------|------|------|
| `synth_design` | 综合 | `synth_design -top design_wrapper -part <part_number>` |
| `opt_design` | 优化网表 | `opt_design` |
| `power_opt_design` | 功耗优化 | `power_opt_design` |
| `place_design` | 布局 | `place_design -directive Explore` |
| `phys_opt_design` | 物理优化（布局后）| `phys_opt_design` |
| `route_design` | 布线 | `route_design -directive Explore` |
| `write_bitstream` | 生成比特流 | `write_bitstream -force ./output/design.bit` |
| `write_checkpoint` | 保存设计检查点 | `write_checkpoint -force synth.dcp` |
| `open_checkpoint` | 读取检查点 | `open_checkpoint synth.dcp` |

## 综合策略选项（`-directive`）

**synth_design：**
- `Default` — 默认
- `RuntimeOptimized` — 快速综合（调试用）
- `AreaOptimized_medium` / `AreaOptimized_high` — 面积优化
- `AlternateRoutability` — 改善可布线性

**place_design：**
- `Default` / `Explore` / `ExtraNetDelay_high` / `AltSpreadLogic_high`

**route_design：**
- `Default` / `Explore` / `MoreGlobalIterations` / `AggressiveExplore`

## 报告生成

| 命令 | 说明 | 关键选项 |
|------|------|---------|
| `report_timing_summary` | 时序摘要 | `-max_paths 10 -file timing.rpt` |
| `report_timing` | 详细时序路径 | `-max_paths 50 -slack_lesser_than 0.0 -sort_by slack` |
| `report_utilization` | 资源利用率 | `-hierarchical -file util.rpt` |
| `report_power` | 功耗 | `-file power.rpt` |
| `report_clock_utilization` | 时钟资源 | `-file clk_util.rpt` |
| `report_clock_interaction` | 时钟域交互 | `-file clk_interaction.rpt` |
| `report_cdc` | 跨时钟域 | `-file cdc.rpt` |
| `report_drc` | 设计规则检查 | `-file drc.rpt` |
| `report_route_status` | 布线状态 | `-file route_status.rpt` |
| `report_io` | IO 配置 | `-file io.rpt` |

## 导出

| 命令 | 说明 | 示例 |
|------|------|------|
| `write_hw_platform` | 导出 XSA | `write_hw_platform -fixed -force -include_bit ./output/design.xsa` |
| `write_device_image` | 生成 PDI（Versal）| — |
| `export_simulation` | 导出仿真文件 | `export_simulation -simulator xsim -of_objects [get_files *.bd]` |

## 调试（ILA / VIO）

| 命令 | 说明 |
|------|------|
| `create_debug_core` | 创建 ILA/VIO 核 |
| `connect_debug_port` | 连接信号到 ILA |
| `implement_debug_core` | 实现 Debug 核 |
| `write_debug_probes` | 生成 `.ltx` 文件 |

## 查询类命令

| 命令 | 说明 |
|------|------|
| `get_cells` | 获取设计单元 |
| `get_nets` | 获取网络 |
| `get_ports` | 获取端口 |
| `get_clocks` | 获取时钟 |
| `get_property` | 获取属性值 |
| `get_ipdefs` | 获取 IP 定义 |
| `report_property` | 显示对象所有属性（调试很有用）|

```tcl
# 查看 IP 的所有可配置参数（非常有用！）
report_property [get_bd_cells axi_gpio_0]

# 查看某个对象的特定属性
get_property CONFIG.C_GPIO_WIDTH [get_bd_cells axi_gpio_0]

# 搜索 IP
get_ipdefs *axi_gpio*
```

## 常用 Tcl 编程技巧

```tcl
# 错误处理
if {[catch {launch_runs synth_1 -jobs 8} err]} {
    puts "ERROR: $err"
    exit 1
}

# 等待并检查
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed"
    puts [get_property STATUS [get_runs synth_1]]
    exit 1
}

# 条件判断
if {[llength [get_bd_cells axi_gpio_0]] > 0} {
    puts "axi_gpio_0 exists"
}

# 循环添加文件
foreach hdl_file [glob ./hdl/*.v] {
    add_files -fileset sources_1 $hdl_file
}

# 设置变量化的工程配置
set part    "<part_number>"
set proj    "my_design"
set jobs    [expr {min(8, [exec nproc])}]
```
