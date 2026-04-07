# Vitis HLS 工程完整流程指南（2022.x+）

## 概述

Vitis HLS 将 C/C++ 函数综合为 RTL（Verilog/VHDL），并导出为可在 Vivado 中使用的 IP 核。

**完整流程：**
```
编写 C++ 函数（含 pragma）→ C 仿真验证 → HLS 综合 → RTL 协同仿真 → 导出 IP → Vivado 集成
```

---

## 接口类型选择

在开始之前，根据函数的用途选择接口类型：

| 接口类型 | 适用场景 | 典型 pragma |
|---------|---------|------------|
| `s_axilite` | 标量参数、控制寄存器、状态读取 | `#pragma HLS INTERFACE s_axilite port=return` |
| `axis`（AXI4-Stream）| 流式数据处理（图像、信号流）| `#pragma HLS INTERFACE axis port=data_in` |
| `m_axi`（AXI4 Master）| 访问 DDR 内存（大数据量）| `#pragma HLS INTERFACE m_axi port=buf offset=slave` |
| `ap_none` / `ap_vld` | 简单无总线接口 | `#pragma HLS INTERFACE ap_none port=x` |

**最常见的组合（AXI4-Lite 控制 + AXI4-Stream 数据）：**
```cpp
void my_func(hls::stream<int> &in_stream,
             hls::stream<int> &out_stream,
             int param) {
#pragma HLS INTERFACE axis      port=in_stream
#pragma HLS INTERFACE axis      port=out_stream
#pragma HLS INTERFACE s_axilite port=param
#pragma HLS INTERFACE s_axilite port=return
    // 函数体
}
```

---

## 阶段 1：C++ 源文件编写

### 典型项目结构
```
01_hls/
├── src/
│   ├── my_func.cpp      ← 核心函数（将被综合）
│   └── my_func.h        ← 头文件（定义接口）
└── tb/
    └── my_func_tb.cpp   ← C 测试台（仿真用，不会综合）
```

### 头文件示例（my_func.h）

```cpp
#pragma once
#include "ap_int.h"
#include "hls_stream.h"
#include "ap_axi_sdata.h"

// 自定义 AXI-Stream 数据类型（含 TLAST/TKEEP/TSTRB/TUSER）
typedef ap_axiu<32, 1, 1, 1> axis_pkt_t;

// 主函数声明
void my_func(hls::stream<axis_pkt_t> &in_stream,
             hls::stream<axis_pkt_t> &out_stream,
             ap_uint<8> scale_factor);
```

### 核心函数示例（my_func.cpp）

```cpp
#include "my_func.h"

void my_func(hls::stream<axis_pkt_t> &in_stream,
             hls::stream<axis_pkt_t> &out_stream,
             ap_uint<8> scale_factor) {
// 接口声明
#pragma HLS INTERFACE axis      port=in_stream  name=S_AXIS
#pragma HLS INTERFACE axis      port=out_stream name=M_AXIS
#pragma HLS INTERFACE s_axilite port=scale_factor bundle=ctrl
#pragma HLS INTERFACE s_axilite port=return       bundle=ctrl

    axis_pkt_t pkt;
    do {
        in_stream.read(pkt);
        pkt.data = pkt.data * scale_factor;  // 核心计算
        out_stream.write(pkt);
    } while (!pkt.last);  // 处理直到流末尾
}
```

### 常用 Pragma 速查

```cpp
// 流水线（提高吞吐量，减小 II）
#pragma HLS PIPELINE II=1

// 展开循环（增大并行度，消耗更多资源）
#pragma HLS UNROLL factor=4

// 数组分区（避免读写冲突）
#pragma HLS ARRAY_PARTITION variable=my_array type=cyclic factor=4

// 数组映射到 BRAM/LUTRAM
#pragma HLS BIND_STORAGE variable=my_array type=RAM_2P impl=BRAM

// 数据流（并发执行多个子函数）
#pragma HLS DATAFLOW
```

---

## 阶段 2：创建 HLS 工程（Tcl 脚本）

生成 `01_hls_create.tcl`：

```tcl
# ============================================================
# Vitis HLS 工程创建脚本（2022.x+ Tcl API）
# 用法：vitis_hls -f 01_hls_create.tcl
# ============================================================

# ——— 工程配置 ———
set proj_name    "my_func_proj"
set proj_dir     "./01_hls"
set top_function "my_func"
set part_number  "<your-part-number>"      ;# 替换为目标器件，例如 xczuXXeg-ffvcXXXX-X-i
set clk_period   "10"                       ;# 目标时钟周期（ns），10ns = 100MHz

# ——— 创建工程 ———
open_project -reset $proj_name
cd $proj_dir

# ——— 添加源文件 ———
add_files ./src/my_func.cpp
add_files -tb ./tb/my_func_tb.cpp -csimflags "-std=c++14"

# ——— 设置顶层函数 ———
set_top $top_function

# ——— 创建 Solution ———
open_solution -reset "solution1" -flow_target vitis
set_part $part_number
create_clock -period $clk_period -name default

# ——— 可选：添加优化指令文件 ———
# set_directive_pipeline -II 1 "${top_function}/main_loop"

# ——— C 仿真 ———
puts "=== C 仿真 ==="
csim_design -clean

# ——— 高层次综合 ———
puts "=== HLS 综合 ==="
csynth_design

# ——— RTL 协同仿真（可选，耗时较长）———
# puts "=== RTL 协同仿真 ==="
# cosim_design -trace_level all

# ——— 导出 IP ———
puts "=== 导出 IP ==="
export_design -flow impl -format ip_catalog \
    -output ./output/ip_export \
    -description "My HLS IP" \
    -vendor "mycompany" \
    -version "1.0"

puts "=== HLS 流程完成 ==="
puts "IP 位置：./output/ip_export"
close_project
```

**运行命令：**
```bash
cd 01_hls
vitis_hls -f 01_hls_create.tcl 2>&1 | tee hls_run.log
```

---

## 阶段 3：查看综合报告

综合完成后，关键报告在 `solution1/syn/report/` 目录中。

### 重要指标解读

```
Performance Estimates（性能估计）：
  Timing
    * Clock Target:   10.00 ns         ← 目标时钟
    * Estimated:       8.20 ns         ← 估计最差路径，要 < Target
  Latency（延迟）
    * Latency(cycles): min=128 max=128 ← 函数延迟（时钟周期数）
    * Interval(cycles): min=1 max=1    ← 启动间隔（II=1 表示全流水）

Resource Utilization（资源使用）：
  |   FF  |  LUT  | DSP | BRAM | URAM |
  | 2048  |  1536 |   8 |   4  |   0  |
```

**性能调优指导：**

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| II > 1 | 循环存在依赖或内存访问冲突 | 使用 `ARRAY_PARTITION`，重构数据依赖 |
| Latency 过大 | 循环未展开/未流水 | 添加 `PIPELINE`、`UNROLL` pragma |
| DSP 使用过多 | 乘法运算多 | 考虑查找表替代（`BIND_OP`）|
| BRAM 使用过多 | 大数组 | 使用 `ARRAY_RESHAPE` 或改为片上 URAM |
| 时序未满足 | 关键路径过长 | 插入寄存器，增大时钟周期，或拆分函数 |

---

## 阶段 4：导出 IP 并集成到 Vivado

### 导出方式比较

| 导出格式 | 用途 | 命令参数 |
|---------|------|---------|
| IP Catalog | 标准 IP 集成到 Block Design | `-format ip_catalog` |
| Vivado IP | 含 XDC，可直接在 Vivado 中使用 | `-format vivado_ip` |
| 导出评估（包含比特流）| 验证 IP 在实际器件上的性能 | `-flow impl` |

### 在 Vivado 中集成 HLS IP

1. 在 Vivado 工程设置中添加 IP 仓库路径：
```tcl
set_property ip_repo_paths {./01_hls/my_func_proj/solution1/impl/ip} [current_project]
update_ip_catalog -rebuild
```

2. 在 BD 中添加 HLS IP：
```tcl
# IP 的 VLNV 格式：vendor:library:name:version
# 查找 VLNV：get_ipdefs -filter {NAME =~ *my_func*}
create_bd_cell -type ip -vlnv xilinx.com:hls:my_func:1.0 my_func_0
```

---

## 常见错误

**错误：`II` 无法达到目标（II violation）**
```
原因：循环体内有依赖（read-after-write）或多端口内存冲突
解决：
  1. 将数组声明为 hls::stream（天然 II=1）
  2. 添加 #pragma HLS ARRAY_PARTITION 消除 BRAM 访问冲突
  3. 重写循环，消除循环携带依赖（loop-carried dependency）
```

**错误：`ap_int` 溢出**
```cpp
// 谨慎：ap_uint<8> 加法可能溢出，使用更宽类型
ap_uint<9> sum = (ap_uint<9>)a + b;  // 显式扩展一位
```

**m_axi 接口的 burst 效率低**
```cpp
// 确保连续内存访问才能触发 burst
// 不要在循环中用条件语句跳过地址
#pragma HLS INTERFACE m_axi port=buf max_read_burst_length=256 \
                            max_write_burst_length=256
```

---

## 完整 Makefile（自动化 HLS 流程）

```makefile
PROJ_DIR = ./01_hls
TCL_SCRIPT = 01_hls_create.tcl
LOG = hls_run.log

.PHONY: hls clean

hls:
	cd $(PROJ_DIR) && vitis_hls -f ../$(TCL_SCRIPT) 2>&1 | tee $(LOG)
	@echo "HLS IP 位置：$(PROJ_DIR)/output/ip_export"

clean:
	rm -rf $(PROJ_DIR)/my_func_proj $(PROJ_DIR)/output $(PROJ_DIR)/$(LOG)
```
