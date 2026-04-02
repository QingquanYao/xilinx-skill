# Vitis Unified IDE 工程流程指南（2022.x+）

## 概述

Vitis Unified IDE（2022.x+）是全新统一的开发环境，支持：
- **裸机（Standalone）**：直接运行在处理器上，无操作系统
- **FreeRTOS**：轻量实时操作系统
- **Linux 用户空间**：运行在 PetaLinux 上的用户态应用程序

**主要概念：**
```
XSA 文件（Vivado 导出）
    ↓
Platform（平台）：定义硬件，包含 BSP 驱动库
    ↓
Domain（域）：处理器核 + 操作系统（standalone/freertos/linux）
    ↓
Application（应用程序）：用户代码，链接到 Platform 和 Domain
```

**命令行工具：**
- `xsct`：Xilinx System Configuration Tool，Tcl 解释器，是 Vitis Unified 的主要脚本接口
- `vitis`：Vitis IDE 启动器（可用 `-s script.tcl` 运行脚本）

---

## 阶段 1：创建平台和应用工程（XSCT 脚本）

生成 `03_vitis_create.tcl`：

```tcl
# ============================================================
# Vitis Unified IDE 工程创建脚本（2022.x+ XSCT API）
# 用法：xsct 03_vitis_create.tcl
# ============================================================

# ——— 配置变量 ———
set xsa_file      "../02_vivado/output/design_fixed.xsa"   ;# XSA 路径
set workspace_dir "./03_vitis/workspace"                    ;# Vitis 工作区
set platform_name "my_platform"                             ;# 平台名称
set domain_name   "standalone_ps_a53"                       ;# 域名称
set proc_core     "psu_cortexa53_0"                        ;# 处理器核（见下方列表）
set os_type       "standalone"                              ;# standalone/freertos/linux
set app_name      "my_app"                                  ;# 应用名称
set app_template  "Hello World"                             ;# 模板（见下方列表）

# ——— 处理器核选项（MPSoC ZU*）———
# psu_cortexa53_0 / psu_cortexa53_1  ← ARM A53 核（64位）
# psu_cortexr5_0  / psu_cortexr5_1   ← ARM R5 核（实时，32位）
# psu_pmu_0                           ← PMU 固件
# psu_csudma_0                        ← CSU DMA

# ——— 设置工作区 ———
setws $workspace_dir

# ——— 创建平台 ———
puts "=== 创建平台 ==="
platform create -name $platform_name \
    -hw $xsa_file \
    -proc $proc_core \
    -os $os_type \
    -out $workspace_dir

# 如需同时添加 Linux 域（双域平台）
# domain create -name {linux_domain} -os {linux} -proc {psu_cortexa53_0}

# 构建平台（生成 BSP 库）
platform generate

puts "=== 平台构建完成 ==="

# ——— 创建应用工程 ———
puts "=== 创建应用 ==="
app create -name $app_name \
    -platform $platform_name \
    -domain $domain_name \
    -template $app_template

# 构建应用
app build -name $app_name

puts "=== 应用构建完成 ==="
puts "ELF 文件位置：$workspace_dir/$app_name/Debug/${app_name}.elf"
```

**运行命令：**
```bash
xsct 03_vitis_create.tcl 2>&1 | tee vitis_build.log
```

---

## 应用模板列表

```
Hello World              ← 基础 Hello World（推荐入门）
Empty Application        ← 空工程
Memory Tests             ← DDR 内存测试
Zynq FSBL                ← 第一阶段引导程序（FSBL）
FreeRTOS Hello World     ← FreeRTOS 基础示例
lwIP Echo Server         ← 网络 Echo 服务器（含 lwIP）
OpenAMP echo-test        ← 多核通信（A53 + R5 协同）
```

查询可用模板：
```tcl
# 在 xsct 中运行
repo -scan
app list -templates
```

---

## 阶段 2：添加自定义源文件

```tcl
# 添加源文件到工程
importsources -name $app_name -path ./src

# 或手动添加单个文件
file copy ./src/my_driver.c $workspace_dir/$app_name/src/
file copy ./src/my_driver.h $workspace_dir/$app_name/src/

# 重新构建
app build -name $app_name
```

---

## 阶段 3：BSP 配置（外设驱动）

```tcl
# 查看可用 BSP 参数
bsp listparams

# 修改 BSP 配置（例如设置 UART 波特率）
bsp setparam stdin  psu_uart_0
bsp setparam stdout psu_uart_0

# 添加 BSP 库（如 lwIP、xilffs）
bsp setlib -name xilffs      ;# FatFS 文件系统
bsp setlib -name xilsecure   ;# 安全库（加密）
bsp setlib -name openamp     ;# 多核通信

# 重新生成 BSP
bsp regenerate
platform generate
```

---

## 阶段 4：Hello World 到完整裸机程序

### 典型裸机程序框架（main.c）

```c
#include "xparameters.h"     // 自动生成，包含所有 IP 的地址和参数
#include "xil_printf.h"      // Xilinx printf（输出到 UART）
#include "xil_io.h"          // 内存映射 IO 读写
#include "sleep.h"           // 延迟函数

// 读写 AXI IP 寄存器的辅助宏
#define MY_IP_BASEADDR   XPAR_MY_FUNCTION_0_S_AXI_CONTROL_BASEADDR
#define MY_IP_REG_CTRL   0x00   // 控制寄存器偏移
#define MY_IP_REG_STATUS 0x04   // 状态寄存器偏移
#define MY_IP_REG_DATA   0x10   // 数据寄存器偏移

// 启动 HLS IP
void start_hls_ip(u32 param) {
    Xil_Out32(MY_IP_BASEADDR + MY_IP_REG_DATA, param);  // 写参数
    Xil_Out32(MY_IP_BASEADDR + MY_IP_REG_CTRL, 0x01);   // 写 ap_start
}

// 等待 HLS IP 完成
void wait_hls_ip(void) {
    u32 status;
    do {
        status = Xil_In32(MY_IP_BASEADDR + MY_IP_REG_STATUS);
    } while (!(status & 0x02));  // 等待 ap_done
}

int main(void) {
    xil_printf("=== 系统启动 ===\r\n");

    // 启动 HLS IP 并等待完成
    start_hls_ip(42);
    wait_hls_ip();
    xil_printf("HLS IP 执行完毕\r\n");

    while (1) {
        // 主循环
        usleep(1000000);  // 1秒
        xil_printf("运行中...\r\n");
    }
    return 0;
}
```

### xparameters.h 中的关键宏

`xparameters.h` 由 BSP 自动生成，包含所有 IP 的地址：

```c
// AXI GPIO
#define XPAR_AXI_GPIO_0_BASEADDR        0xA0000000UL
#define XPAR_AXI_GPIO_0_HIGHADDR        0xA0000FFFUL

// HLS IP（s_axi_control 接口基地址）
#define XPAR_MY_FUNCTION_0_S_AXI_CONTROL_BASEADDR  0xA0010000UL

// UART
#define XPAR_PSU_UART_0_BASEADDR        0xFF000000UL
```

---

## 阶段 5：生成 BOOT.BIN

裸机程序需要打包成 BOOT.BIN 才能从 SD 卡或 QSPI Flash 启动。

### 方法 1：使用 XSCT 生成 BIF 并打包

```tcl
# 生成 BIF 文件（Boot Image Format）
set bif_content {
    // arch = zynqmp; split = false; format = BIN
    the_ROM_image:
    {
        [fsbl_config] a53_x64
        [bootloader, destination_cpu = a53-0] ./fsbl/fsbl.elf
        [pmufw_image] ./pmufw/pmufw.elf
        [destination_device = pl] ./vivado/design.bit
        [destination_cpu = a53-0, exception_level = el-3, trustzone] ./bl31.elf
        [destination_cpu = a53-0, exception_level = el-2] ./my_app/my_app.elf
    }
}

set bif_file "./output/boot.bif"
set fp [open $bif_file w]
puts $fp $bif_content
close $fp

# 打包 BOOT.BIN
exec bootgen -image $bif_file -arch zynqmp -o ./output/BOOT.BIN -w on
puts "BOOT.BIN 已生成：./output/BOOT.BIN"
```

### 方法 2：仅裸机程序（无 Linux，简化 BIF）

```
the_ROM_image:
{
    [fsbl_config] a53_x64
    [bootloader, destination_cpu = a53-0] fsbl.elf
    [pmufw_image] pmufw.elf
    [destination_device = pl] design.bit
    [destination_cpu = a53-0] my_app.elf
}
```

---

## 阶段 6：调试（JTAG 连接）

```tcl
# 连接硬件（通过 JTAG）
connect

# 查看目标
targets

# 选择 A53 核 0（通常 target 2 或 3，取决于板卡）
targets -set -filter {name =~ "Cortex-A53 #0"}

# 下载比特流到 PL
fpga ./output/design.bit

# 初始化 PS（配置 DDR 等）
source ./03_vitis/workspace/my_platform/hw/psu_init.tcl
psu_init

# 下载并运行 ELF
dow ./03_vitis/workspace/my_app/Debug/my_app.elf
run

# 设置断点
bpadd -addr &main

# 停止、继续
stop
con
```

**命令行方式（非交互式）：**
```bash
xsct -eval "connect; targets; fpga design.bit; \
    source psu_init.tcl; psu_init; \
    dow my_app.elf; run"
```

---

## FreeRTOS 应用要点

```c
#include "FreeRTOS.h"
#include "task.h"

// 任务函数
void vTaskA(void *pvParam) {
    while (1) {
        xil_printf("Task A running\r\n");
        vTaskDelay(pdMS_TO_TICKS(500));  // 延迟 500ms
    }
}

int main(void) {
    // 创建任务
    xTaskCreate(vTaskA, "TaskA", configMINIMAL_STACK_SIZE * 4,
                NULL, tskIDLE_PRIORITY + 1, NULL);

    // 启动调度器（不会返回）
    vTaskStartScheduler();
    return 0;
}
```

---

## 常见问题

**Q：`xparameters.h` 中找不到我的 IP 地址**
```
原因：XSA 没有正确导出，或 BD 中该 IP 没有连接到 PS 的 AXI Master 接口
解决：检查 Vivado 的 Address Editor，确认 IP 已分配地址；重新导出 XSA 并重新创建平台
```

**Q：裸机程序运行后没有 UART 输出**
```
解决步骤：
1. 检查 BSP 的 stdin/stdout 是否设置为正确的 UART（xsct: bsp setparam stdout psu_uart_0）
2. 确认 XDC 中 UART MIO 引脚配置与硬件一致
3. 串口工具波特率设置（默认 115200 8N1）
```

**Q：如何访问 AXI GPIO 控制 LED？**
```c
#include "xgpio.h"

XGpio gpio;
XGpio_Initialize(&gpio, XPAR_AXI_GPIO_0_DEVICE_ID);
XGpio_SetDataDirection(&gpio, 1, 0x00);  // 通道1全部输出
XGpio_DiscreteWrite(&gpio, 1, 0xFF);     // 全部置高（LED 亮）
```
