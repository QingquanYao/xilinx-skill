# PetaLinux + gRPC 端到端部署指南

> **适用版本：** PetaLinux 2024.2, Vivado 2024.2, gRPC 1.60.1, Protobuf 25.3, Yocto meta-oe (scarthgap branch)
> **适用器件：** Zynq UltraScale+ MPSoC（EG/EV 全系，包括官方 ZCU10x 开发板和各类第三方自制板）
> - 不适用：Versal（ACAP 架构不同，PetaLinux 流程差异较大）
> **主机环境：** Windows 10/11 + VMware Workstation 17 + Ubuntu 22.04 LTS (Jammy) 虚拟机
> **典型场景：**
> - 把原本跑在 PYNQ + ZMQ 的 FPGA 控制程序迁移到纯 PetaLinux，用 gRPC 作为 PC ↔ 板卡 RPC 层
> - 在任何 ZynqMP 板卡上从零搭建能跑 gRPC C++ 服务端 + Python 客户端的最小闭环
> - 需要在嵌入式 Linux 上对接 AXI GPIO / AXI DMA / udmabuf 并通过 gRPC 暴露给上位机

---

## 目录

- [0. TL;DR（30 秒速览）](#0-tldr30-秒速览)
- [1. 总览：端到端数据流 + 节点拓扑](#1-总览端到端数据流--节点拓扑)
- [2. 前置准备](#2-前置准备)
- [3. 阶段 A：Vivado 硬件工程](#3-阶段-avivado-硬件工程)
- [4. 阶段 B：PetaLinux 工程创建 + 导入硬件](#4-阶段-bpetalinux-工程创建--导入硬件)
- [5. 阶段 C：rootfs 软件包配置](#5-阶段-crootfs-软件包配置)
- [6. 阶段 D：设备树 system-user.dtsi（udmabuf 预留）](#6-阶段-d设备树-system-userdtsiudmabuf-预留)
- [7. 阶段 E：PetaLinux 构建 + 打包 BOOT.BIN](#7-阶段-epetalinux-构建--打包-bootbin)
- [8. 阶段 F：SD 卡烧录 + 板卡首次上电](#8-阶段-fsd-卡烧录--板卡首次上电)
- [9. 阶段 G：板卡网络配置 + SSH 连通](#9-阶段-g板卡网络配置--ssh-连通)
- [10. 阶段 H：demo_server 编译（方案 A：VM 预生成 + 板上 g++）](#10-阶段-hdemo_server-编译方案-avm-预生成--板上-g)
- [11. 阶段 I：运行服务端 + Python 客户端测试](#11-阶段-i运行服务端--python-客户端测试)
- [12. 阶段 J：每次重刷 rootfs 后的必做清单](#12-阶段-j每次重刷-rootfs-后的必做清单)
- [13. 常见问题速查（10 项）](#13-常见问题速查10-项)
- [14. 关键文件清单](#14-关键文件清单)
- [15. 版本差异](#15-版本差异)
- [16. 参考文档](#16-参考文档)

---

## 0. TL;DR（30 秒速览）

**目标**：让板卡跑起来一个 gRPC C++ 服务端，暴露 `WriteGpio/ReadGpio/StreamDmaData` 三个 RPC，上位机用 Python 客户端能验证 GPIO 环回 + DMA 数据连续性。

**四条黄金规则**：

1. **[VM]** `petalinux-package --boot` 必须带 `--fpga images/linux/system.bit`，否则 BOOT.BIN 只有 1.8 MB，板卡启动会卡死在 `deferred_probe_work_func`（RCU stall，永远不 login）
2. **[板卡]** rootfs 是 tmpfs，`/home/petalinux` 重启会清空；`libutf8_range.so` 被 Yocto 改名为 `libutf8_range_lib.so`，链接时要手动软链
3. **流程**：走 **VM → hgfs 共享 → Windows → scp → 板卡** 的 V 字路径，**不要折腾 VM 直连板卡**
4. **C++ protoc 别装板卡上**，走"VM 预生成 `.pb.cc/.pb.h` + 板卡只跑 g++"方案

**最小成功判据**：板卡串口输出 `Demo gRPC server listening on 0.0.0.0:50051`，上位机 Python 客户端两个 GPIO 测试 + DMA stream 全 PASS。

---

## 1. 总览：端到端数据流 + 节点拓扑

### 1.1 节点拓扑

```
┌─────────────────┐                                     ┌──────────────────┐
│   VM (Ubuntu)   │                                     │   Windows Host   │
│  22.04 LTS      │        VMware hgfs 共享              │  Vivado 2024.2   │
│                 │<═══════════════════════════════════>│  Python 3.11     │
│ PetaLinux 2024.2│  /mnt/hgfs/<name> ↔ D:\<path>        │                  │
│ protoc / proto  │                                     │  以太网卡         │
│  预生成 stub    │                                     │  192.168.2.100/24│
└─────────────────┘                                     └────────┬─────────┘
                                                                 │
                                                                 │ 直连网线
                                                                 │ 或普通交换机
                                                                 │
                                                        ┌────────▼─────────┐
                                                        │   ZynqMP Board   │
                                                        │  PetaLinux rootfs│
                                                        │  end0 192.168.2.10│
                                                        │                  │
                                                        │  demo_server     │
                                                        │    ↓ /dev/mem    │
                                                        │   AXI GPIO       │
                                                        │   AXI DMA        │
                                                        │   udmabuf0       │
                                                        │    ↓             │
                                                        │   PL (bitstream) │
                                                        └──────────────────┘
```

**为什么是 V 字路径**：
- VM 默认 NAT，`ens33` 拿 `192.168.44.x`，和板卡 `192.168.2.x` 不在同一 L2，直连要改桥接且容易踩 WLAN 自动桥接的坑
- Windows 直连板卡是最稳的物理链路
- VM ↔ Windows 用 VMware hgfs 共享文件夹零配置就能跑
- 上位机 Python 客户端本来就应该在 Windows 上（避开 VM/板卡网络问题）

### 1.2 数据流（一个 RPC 请求的完整路径）

```
Python 客户端 (Windows)
   │
   │  grpc.insecure_channel("192.168.2.10:50051")
   │  stub.WriteGpio(GpioWriteRequest(channel=1, value=0xDEADBEEF))
   ▼
TCP/IP (192.168.2.100 → 192.168.2.10)
   │
   │  HTTP/2 over TCP, gRPC framing
   ▼
demo_server (PetaLinux, aarch64, sudo)
   │
   │  DemoServiceImpl::WriteGpio(ctx, req, resp)
   │  *(volatile uint32_t*)(gpio_mmap + 0x0) = req.value()
   ▼
/dev/mem mmap → AXI GP0 (0xA000_0000)
   │
   │  AXI4-Lite write transaction
   ▼
PL 侧 AXI GPIO IP → 驱动 PL LED/寄存器
```

### 1.3 编译产出流

```
[VM] proto/demo.proto
   │
   │  protoc --cpp_out --grpc_out
   ▼
[VM] server/demo.pb.{h,cc}, server/demo.grpc.pb.{h,cc}
   │
   │  cp -r ~/grpc_demo_src/server /mnt/hgfs/.../server_built
   ▼
[Windows] D:\...\grpc_demo\server_built\
   │
   │  scp -r ... petalinux@192.168.2.10:~/server
   ▼
[板卡] ~/server/{*.cpp, *.pb.cc, *.pb.h, build.sh}
   │
   │  chmod +x build.sh && ./build.sh
   │  → g++ -std=c++17 -O2 ... pkg-config --libs grpc++ protobuf
   ▼
[板卡] ~/server/demo_server  (~321 KB ELF, 动态链接 grpc++/protobuf)
   │
   │  sudo ./demo_server --port 50051
   ▼
   Demo gRPC server listening on 0.0.0.0:50051  ✓
```

---

## 2. 前置准备

### 2.1 主机硬件要求

| 项 | 最低 | 推荐 |
|---|---|---|
| 主机 CPU | 4 核 | 8 核+ |
| 内存 | 16 GB | 32 GB+（PetaLinux build 期间 VM 建议分 16 GB） |
| 主机磁盘 | 150 GB 可用 | 300 GB（PetaLinux build cache 能到 ~100 GB） |
| 网卡 | 1 个以太网卡直连板卡 | 1 以太网 + 1 WLAN（两者不能同网段） |

### 2.2 软件环境清单

**Windows 主机：**
- [ ] VMware Workstation 16/17（或 VirtualBox 6.1+）
- [ ] Vivado 2024.2（用于硬件设计、bitstream 生成）
- [ ] Vitis Unified 2024.2（可选，裸机预验证 AXI GPIO/DMA）
- [ ] Xshell / PuTTY / TeraTerm（串口终端）
- [ ] OpenSSH 客户端（Windows 10/11 内置）
- [ ] Anaconda/Miniconda（Python 客户端虚拟环境）
- [ ] 读卡器（烧 SD 卡）

**VM (Ubuntu 22.04 LTS)：**
- [ ] Ubuntu 22.04.5 LTS（**不要用 24.04**，PetaLinux 2024.2 官方只支持 22.04 和 20.04）
- [ ] PetaLinux 2024.2 安装在 `/tools/Xilinx/PetaLinux/2024.2`
- [ ] 依赖包：`sudo apt install -y tftpd-hpa gawk wget git diffstat unzip texinfo gcc build-essential chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev python3-subunit mesa-common-dev zstd liblz4-tool file locales libtinfo5 libacl1`
- [ ] VMware Tools（共享文件夹必须）
- [ ] 至少 100 GB VM 磁盘

**板卡：**
- [ ] 任意 ZynqMP 开发板（官方 ZCU10x 或第三方自制板均可）
- [ ] 2 根 USB 线（串口 + JTAG）
- [ ] 1 根以太网线（RJ45 直连 PC 或接交换机）
- [ ] 1 张 SD 卡（8 GB+，Class 10）
- [ ] 板卡供电适配器

### 2.3 VMware 网络与共享文件夹

**[Windows]** 共享文件夹设置：

1. VMware → 虚拟机 → 设置 (Settings) → 选项 (Options) → 共享文件夹 (Shared Folders)
2. 启用 (Enabled) → 添加 (Add)
3. 主机路径 (Host path) 选 `D:\your_project_root`
4. 共享名 (Name) 填个简短易记的，比如 `grpc_demo`
5. 勾选 "启用此共享 (Enable this share)"

**[VM]** 挂载验证：

```bash
ls /mnt/hgfs/
# 应该看到 grpc_demo
ls /mnt/hgfs/grpc_demo
# 能看到 Windows 端的文件
```

**如果 `/mnt/hgfs/` 为空**：

```bash
# [VM]
sudo vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other
# 或写进 /etc/fstab 持久化
echo ".host:/ /mnt/hgfs fuse.vmhgfs-fuse allow_other,defaults 0 0" | sudo tee -a /etc/fstab
```

### 2.4 串口终端（观察板卡启动日志）

**[Windows]** 用 Xshell/PuTTY/TeraTerm：
- 串口号：板卡 USB 转 UART 连接后在设备管理器看（通常是 `COMx`）
- 波特率：**115200**
- 数据位 8、停止位 1、无校验、无流控
- 终端类型：xterm

---

## 3. 阶段 A：Vivado 硬件工程

> **本节只讲 gRPC demo 需要的最小硬件**。如果你已经有自己的 Vivado 工程（含 AXI GPIO + AXI DMA + udmabuf 预留内存），直接跳到阶段 B。

### 3.1 Block Design 必备 IP

| IP | 地址 | 作用 |
|---|---|---|
| `zynq_ultra_ps_e_0` (PS8) | — | MPSoC 处理系统；必须使能 M_AXI_HPM0_FPD（给 PL 外设用）和 S_AXI_HP0_FPD（DMA 回写 DDR） |
| `axi_gpio_0` | `0xA000_0000` | 两个 32-bit 通道，一个输出驱动 LED / ila_probe，一个回环用于测试 |
| `axi_dma_0` | `0xA001_0000` | S2MM（Stream → Memory）通道，把 PL 的递增计数器数据搬进 DDR |
| 测试数据源（任选） | — | 可以用 `util_counter_binary` + AXI4-Stream Data Generator，或者自己写 Verilog 产生 92 word burst + TLAST |
| `proc_sys_reset_0` | — | PL 复位管理 |
| `clk_wiz_0` / PS PL Clock | 100~200 MHz | PL 时钟 |

**地址固化**：demo_server.cpp 会用 mmap 硬编码 `0xA0000000` 和 `0xA0010000`，**如果你改了地址必须同步改 demo_server.cpp 顶部的 `#define GPIO_BASE` 和 `#define DMA_BASE`**。

### 3.2 关键 Vivado Tcl 片段

**[Windows]** 在 Vivado Tcl Console 里跑（或写进 `grpc_demo/vivado/scripts/setup_bd.tcl`）：

```tcl
# 设置 AXI GPIO 地址
set_property offset 0xA0000000 [get_bd_addr_segs \
    {zynq_ultra_ps_e_0/Data/SEG_axi_gpio_0_Reg}]
set_property range 64K [get_bd_addr_segs \
    {zynq_ultra_ps_e_0/Data/SEG_axi_gpio_0_Reg}]

# 设置 AXI DMA 寄存器地址
set_property offset 0xA0010000 [get_bd_addr_segs \
    {zynq_ultra_ps_e_0/Data/SEG_axi_dma_0_Reg}]
set_property range 64K [get_bd_addr_segs \
    {zynq_ultra_ps_e_0/Data/SEG_axi_dma_0_Reg}]

# AXI DMA 的 S2MM 通道把 HP0 映射到整个 DDR
# （udmabuf 需要从这个地址空间里能看到自己的 phys_addr）
```

### 3.3 AXI DMA 参数

双击 `axi_dma_0`：

- [ ] Enable Scatter Gather Engine：**取消勾选**（Direct Register Mode 最简单，demo_server 用 Direct Mode）
- [ ] Enable Micro DMA：取消
- [ ] Width of Buffer Length Register：23（支持最大 8 MB 一次传输）
- [ ] Enable Read Channel（MM2S）：取消（demo 只用 S2MM）
- [ ] Enable Write Channel（S2MM）：**勾选**
- [ ] Memory Map Data Width：64 位
- [ ] Stream Data Width：32 位
- [ ] Max Burst Size：16

### 3.4 PS8 必备配置

参考本目录 `mpsoc_ps_config.md`，重点：

- [ ] **QSPI FBCLK** 必须绑定到 MIO6（否则 QSPI 启动模式下系统上不来）
- [ ] **MIO Bank 0/1/2/3 电压** 按板卡实际电平配置（很多板卡 MIO 实际是 1.8V，Vivado 默认 `LVCMOS33` 会打错 IOSTANDARD，需改为 `LVCMOS18`）
- [ ] **TTC0~3** 全部使能（systemd 需要）
- [ ] **IRQ0** 使能，`axi_dma_0/s2mm_introut` 连到 PS8 的 `pl_ps_irq0[0]`
- [ ] **Display Port**（如果板卡有 DP 口）必须 **GUI 手动配**，Tcl 配不了（Vivado IP 内部 DRC 会回滚）

### 3.5 综合 + 实现 + 导出 XSA

```tcl
# [Windows] Vivado Tcl Console
generate_target all [get_files design_1.bd]
launch_runs synth_1 -jobs 8
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# 导出硬件描述给 PetaLinux
write_hw_platform -fixed -include_bit -force -file \
    D:/path/to/design_1_wrapper.xsa
```

**预期产出**：
- `design_1_wrapper.xsa`（~30 MB，含 bitstream）

---

## 4. 阶段 B：PetaLinux 工程创建 + 导入硬件

### 4.1 source 环境 + 建工程

```bash
# [VM]
source /tools/Xilinx/PetaLinux/2024.2/settings.sh
petalinux-util --webtalk off    # 关闭 webtalk（避免上报遥测）

cd ~/grpc_demo
petalinux-create --type project \
    --template zynqMP \
    --name grpc_demo_proj
cd grpc_demo_proj
```

### 4.2 导入硬件（把 XSA 从 Windows 拷进 VM）

```bash
# [VM]
# 通过 hgfs 共享拷
cp /mnt/hgfs/grpc_demo/vivado/design_1_wrapper.xsa .

petalinux-config --get-hw-description=./design_1_wrapper.xsa
# 弹出菜单 → 一般直接 Exit 保存即可
```

**常见坑**：`libtinfo.so.5: cannot open shared object file`

```bash
# [VM] Ubuntu 22.04 没有 libtinfo5，要么装兼容包，要么软链
sudo apt install -y libtinfo5 || \
    sudo ln -s /lib/x86_64-linux-gnu/libtinfo.so.6 /lib/x86_64-linux-gnu/libtinfo.so.5
```

### 4.3 确认 meta-oe layer 已启用（gRPC/protobuf 来自这里）

```bash
# [VM]
grep -r "meta-openembedded" build/conf/bblayers.conf
# 至少要看到：
# /path/to/components/yocto/layers/meta-openembedded/meta-oe
```

**未启用**的话：
```bash
# [VM]
petalinux-config
# → Yocto Settings → User Layers → 新加一行：
#   ${PROOT}/components/yocto/layers/meta-openembedded/meta-oe
```

---

## 5. 阶段 C：rootfs 软件包配置

### 5.1 编辑 petalinuxbsp.conf（**唯一可靠的追加包方式**）

`project-spec/configs/rootfs_config` 是 Kconfig 自动生成的，手动追加无效。`petalinux-config -c rootfs` 菜单里也搜不到 grpc/protobuf 这些包。**必须用 `petalinuxbsp.conf` 的 `IMAGE_INSTALL:append`**：

```bash
# [VM]
nano project-spec/meta-user/conf/petalinuxbsp.conf
```

追加下面这些行（**每行包名前必须有一个空格**，否则会粘到前一个字符串里）：

```bitbake
# ============================================================
# demo_server 板上本地编译 + 运行所需的全套包
# ============================================================

# 基础工具链（gcc/g++/make/binutils/libc-dev/libstdc++-dev）
IMAGE_INSTALL:append = " packagegroup-core-buildessential"
IMAGE_INSTALL:append = " cmake pkgconfig git"

# 硬件调试工具
IMAGE_INSTALL:append = " devmem2 u-dma-buf"

# protobuf 运行时 + 头文件 + pkg-config 描述
IMAGE_INSTALL:append = " protobuf protobuf-c"
IMAGE_INSTALL:append = " protobuf-dev protobuf-c-dev"

# gRPC 运行时 + 头文件 + pkg-config 描述
IMAGE_INSTALL:append = " grpc grpc-dev"

# 注意事项：
# 1. protobuf-compiler（C++ protoc）属于 build-time-only，即使加进
#    IMAGE_INSTALL 也不会装到 target rootfs，必须走"VM 预生成"方案
# 2. grpc-compiler 同上，但 grpc_cpp_plugin 的 target 变体会被打进
#    grpc 包，板卡上能找到 /usr/bin/grpc_cpp_plugin（但用不到，因为
#    没有 protoc 就没法用）
# 3. 如果只装 protobuf 不装 protobuf-dev，pkg-config 会找不到
#    protobuf.pc，build.sh 会失败
```

### 5.2 gitsm fetch 失败预处理（国内网络）

gRPC 用 `gitsm://github.com/grpc/grpc.git` 拉十几个子模块（boringssl, abseil, protobuf, re2, c-ares, upb, xds, googleapis 等），国内 VM 大概率失败。**提前配好 GitHub 镜像**：

```bash
# [VM]
git config --global url."https://gh-proxy.com/https://github.com/".insteadOf "https://github.com/"

# 清已有的失败 state（如果之前 build 过）
rm -rf build/tmp/work/cortexa72-cortexa53-xilinx-linux/grpc/
```

**备选镜像**（按稳定性排序）：
- `https://gh-proxy.com/`
- `https://ghfast.top/`
- `https://hub.gitmirror.com/`
- `https://mirror.ghproxy.com/`

**或配 http 代理**（如果有 clash/v2ray）：
```bash
git config --global https.proxy http://127.0.0.1:7890
```

---

## 6. 阶段 D：设备树 system-user.dtsi（udmabuf 预留）

DMA buffer 必须是 **物理连续** 的内存，而 Linux 默认不给用户态这种内存。解法是用 `u-dma-buf` 内核模块，它创建 `/dev/udmabuf0` 字符设备，mmap 它就能拿到一块物理连续的 buffer，并通过 sysfs 读出 `phys_addr`。

### 6.1 编辑 system-user.dtsi

```bash
# [VM]
nano project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
```

```dts
/include/ "system-conf.dtsi"
/ {
    /* 从 DDR 顶部预留 1 MB 给 udmabuf
     * 注意地址要避开 kernel/reserved-memory，这里选 0x6530_0000
     * （4GB DDR 的话 0x0 ~ 0x7FFF_FFFF 是 DDR low，再往上是 PL 外设）
     */
    reserved-memory {
        #address-cells = <2>;
        #size-cells = <2>;
        ranges;

        udmabuf_reserved: buffer@65300000 {
            compatible = "shared-dma-pool";
            reusable;
            size = <0x0 0x00100000>;    /* 1 MB */
            alignment = <0x0 0x00001000>;
            linux,cma-default;
        };
    };

    udmabuf@0 {
        compatible = "ikwzm,u-dma-buf";
        device-name = "udmabuf0";
        size = <0x00100000>;    /* 1 MB */
        memory-region = <&udmabuf_reserved>;
    };
};
```

**调地址注意事项**：
- 必须落在 DDR 物理地址空间内（ZynqMP 通常是 `0x0` 起的 DDR 空间，具体大小视板卡而定）
- 必须避开 kernel 自己用的区域（一般 kernel 在 `0x0 ~ 0x3FFF_FFFF` 附近）
- 本例 `0x6530_0000` 是经验值，板上启动后会看到 `udmabuf phys_addr=0x5d100000`（内核自动重映射了，以实际为准）

### 6.2 配置 u-dma-buf 内核模块

```bash
# [VM]
petalinux-config -c rootfs
# 进入 "Filesystem Packages" → "misc" → 搜索 u-dma-buf，确认勾上
# 或直接确认 petalinuxbsp.conf 里已经追加了（见 5.1）
```

**验证模块是否会加载**（启动后）：

```bash
# [板卡]
ls /dev/udmabuf0                          # 应该存在
cat /sys/class/u-dma-buf/udmabuf0/size     # 应该 = 1048576
cat /sys/class/u-dma-buf/udmabuf0/phys_addr  # 应该是个 DDR 地址
```

---

## 7. 阶段 E：PetaLinux 构建 + 打包 BOOT.BIN

### 7.1 主构建

```bash
# [VM]
cd ~/grpc_demo/grpc_demo_proj

# 首次 build 耗时 1~3 小时（取决于 CPU 和网络）
petalinux-build 2>&1 | tee build.log
```

**成功输出末尾**：
```
[INFO] Successfully built project
```

**中途失败 do_fetch**：参考 5.2 节配镜像，然后：
```bash
# [VM]
petalinux-build -c grpc -c cleansstate
petalinux-build -c linux-xlnx -c cleansstate   # 如果是 kernel 仓库失败
petalinux-build
```

### 7.2 打包 BOOT.BIN（**关键！必须带 --fpga**）

```bash
# [VM]
petalinux-package --boot \
    --u-boot \
    --fpga images/linux/system.bit \
    --force

# 自检大小
ls -lh images/linux/BOOT.BIN
```

**预期输出**：
```
[INFO] File in BOOT BIN: ".../zynqmp_fsbl.elf"
[INFO] File in BOOT BIN: ".../pmufw.elf"
[INFO] File in BOOT BIN: ".../system.bit"          ← 这一行必须出现
[INFO] File in BOOT BIN: ".../bl31.elf"
[INFO] File in BOOT BIN: ".../system.dtb"
[INFO] File in BOOT BIN: ".../u-boot.elf"
[INFO] Generating zynqmp binary package BOOT.BIN...
[INFO]   : Bootimage generated successfully
```

```bash
$ ls -lh images/linux/BOOT.BIN
-rw-rw-r-- 1 yqq yqq 30M Apr 6 18:38 images/linux/BOOT.BIN  ← ~30 MB ✓
```

**⚠️ 如果看到 1.8 MB，立刻停下来检查 `--fpga` 参数**，强刷上板会卡死启动。

### 7.3 [可选] 生成 WIC image（一体化 SD 卡镜像）

```bash
# [VM]
petalinux-package --wic
ls -lh images/linux/*.wic
# 用 balenaEtcher 或 dd 直接写到 SD 卡，能跳过手动拷 3 个文件的步骤
```

---

## 8. 阶段 F：SD 卡烧录 + 板卡首次上电

### 8.1 SD 卡分区布局

PetaLinux 默认生成的 SD 卡要两个分区：

| 分区 | 类型 | 大小 | 挂载点 | 内容 |
|---|---|---|---|---|
| `/dev/sdXN1` | FAT32 | 512 MB | `/boot` | `BOOT.BIN`, `image.ub`, `boot.scr` |
| `/dev/sdXN2` | ext4 | 剩余 | `/` | rootfs（可选，默认用 initramfs） |

**最简单的方式**：买新卡，用 Windows 资源管理器看见的 FAT32 卷直接拖文件进去（VM 识别到 SD 卡分区后直接 cp 也行）。

### 8.2 拷文件到 FAT32 分区

```bash
# [VM] 假设 SD 卡自动挂在 /media/yqq/<UUID>/
ls /media/yqq/
# 例如：3B16-47E0  1cdb7e8f-8d30-45eb-ac79-6f71c426214e
# 前者是 FAT32（UUID 短），后者是 ext4

cp images/linux/BOOT.BIN   /media/yqq/3B16-47E0/
cp images/linux/image.ub   /media/yqq/3B16-47E0/
cp images/linux/boot.scr   /media/yqq/3B16-47E0/
sync

ls -lh /media/yqq/3B16-47E0/
# BOOT.BIN   30M   ← 必须含 bitstream
# image.ub   180M  ← kernel + dtb + initramfs
# boot.scr   4K    ← U-Boot distro boot 脚本
```

**⚠️ 缺 `boot.scr` 会导致 U-Boot 依次尝试 JTAG/QSPI/NAND/USB/PXE 全部超时**，板卡永远进不了 login。

### 8.3 弹出 + 插回 + 上电

```bash
# [VM]
sudo umount /media/yqq/3B16-47E0/
# 或在文件管理器点"安全弹出"
```

插回板卡 → 上电 → 观察串口：

**预期启动日志**：
```
U-Boot SPL 2024.01 (...)
BL31: v2.10
...
Starting kernel ...

[    0.000000] Linux version 6.6.10-xilinx-v2024.2 ...
[    0.xxxxxx] ... (一堆内核打印) ...
[    x.xxxxxx] systemd[1]: Starting systemd-...
[   xx.xxxxxx] random: crng init done

PetaLinux 2024.2 zynqmp-grpc ttyPS0

zynqmp-grpc login: petalinux
Password:
You are required to change your password immediately ...
New password: (输新密码)
Retype new password:
zynqmp-grpc:~$
```

**启动失败的典型症状**：

| 症状 | 原因 | 查哪里 |
|---|---|---|
| `Retrying PXE... SYSLINUX not found` 反复 | SD 卡 FAT32 里缺 `boot.scr` | 8.2 节重拷 |
| 卡在 `rcu: INFO: rcu_sched detected stalls ... deferred_probe_work_func` | BOOT.BIN 漏了 `--fpga`，PL 黑屏 → AXI 挂死 | 7.2 节 |
| 永远停在 `Starting kernel...` | image.ub 损坏或与 dtb 不匹配 | 重新 petalinux-build |
| `synquacer-uart: probe failed` 之类的 serial probe 错 | FSBL/bitstream 与 dtb 不匹配 | 确认 XSA 和 petalinux 是同一次 build |

---

## 9. 阶段 G：板卡网络配置 + SSH 连通

### 9.1 配板卡 IP

**[板卡]** 临时方案（重启会丢）：

```bash
sudo ifconfig end0 192.168.2.10 netmask 255.255.255.0 up
ip a show end0
```

**预期**：
```
3: end0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP ...
    link/ether c6:40:d2:bb:bd:a2 brd ff:ff:ff:ff:ff:ff
    inet 192.168.2.10/24 brd 192.168.2.255 scope global end0
       valid_lft forever preferred_lft forever
```

**[板卡]** 持久化方案（systemd-networkd）：

```bash
sudo tee /etc/systemd/network/10-end0.network > /dev/null <<'EOF'
[Match]
Name=end0

[Network]
Address=192.168.2.10/24
EOF

sudo systemctl restart systemd-networkd
```

### 9.2 配 Windows 以太网卡

**[Windows]** 控制面板 → 网络和共享中心 → 更改适配器设置 → 你直连板卡的那块以太网卡 → 右键属性 → Internet 协议版本 4 (TCP/IPv4) → 手动配：
- IP 地址：**192.168.2.100**
- 子网掩码：**255.255.255.0**
- 默认网关：**留空**
- DNS：**留空**

**确认 WLAN 不能也在同网段**（IP 冲突是 problem #11 的根因）：
```powershell
# [Windows]
ipconfig /all | Select-String "IPv4"
# 检查所有网卡 IP，确保只有以太网卡是 192.168.2.100
```

### 9.3 测试连通性

```powershell
# [Windows]
ping 192.168.2.10

# 正常：
# 来自 192.168.2.10 的回复: 字节=32 时间<1ms TTL=64    ← TTL=64 是 Linux
#
# 异常：
# 来自 192.168.2.10 的回复: ... TTL=128                ← TTL=128 是 Windows
#   → 说明 ping 的是自己，有 IP 冲突，检查 WLAN
```

**深度排查**：
```powershell
# [Windows]
Test-NetConnection 192.168.2.10 -Port 22
# 应显示：
#   ComputerName: 192.168.2.10
#   RemoteAddress: 192.168.2.10
#   RemotePort: 22
#   TcpTestSucceeded: True
#   SourceAddress: 192.168.2.100           ← 必须是以太网卡的 IP
#   InterfaceAlias: 以太网                   ← 必须是以太网卡，不是 WLAN
```

### 9.4 SSH 登录

```powershell
# [Windows]
# 如果之前 scp/ssh 过旧 rootfs（host key 会变），先清 known_hosts
ssh-keygen -R 192.168.2.10

ssh petalinux@192.168.2.10
# 第一次会问 yes/no，输 yes
# 然后输板卡密码（首次启动时改的那个）
```

---

## 10. 阶段 H：demo_server 编译（方案 A：VM 预生成 + 板上 g++）

### 10.1 为什么选方案 A

| 方案 | 说明 | 优点 | 缺点 |
|---|---|---|---|
| **A. VM 预生成 + 板上 g++**（**采用**） | VM 端用 native protoc 生成 `.pb.cc/.pb.h`，scp 到板子只跑 g++ | 不需要板卡装 protoc；改源码后重 build 只需要板卡 g++ | 每次改 `.proto` 要重新在 VM 跑 protoc 再传 |
| B. 纯板卡编译 | rootfs 装 protobuf-compiler | 一体化流程 | meta-oe 的 protobuf-compiler 只做 native，target 不装，实际跑不通 |
| C. VM 交叉编译 | 用 PetaLinux SDK aarch64 sysroot 直接出 ELF | 板卡不用装任何编译器 | 要 `petalinux-build --sdk`，多一步，且 SDK 很大 |

### 10.2 VM 端：安装系统 protoc + 找 native sysroot

```bash
# [VM]
# PetaLinux 2024.2 默认 rm_work，native 的 protoc 可执行文件被清理，
# 只剩 include/lib。装系统 protoc：
sudo apt install -y protobuf-compiler
protoc --version

# 如果 PetaLinux settings.sh 已 source，PATH 会优先命中 sysroot 残留的
# protoc 25.3 而不是 apt 装的 3.12，恰好和板卡的 libprotobuf 25.3 对齐
# 如果命中的是 3.12，也能用（gRPC 的 .pb.cc 大多数情况向后兼容）

# 找 native sysroot 路径
source /tools/Xilinx/PetaLinux/2024.2/settings.sh
cd ~/grpc_demo/grpc_demo_proj
SYSROOT=$PWD/build/tmp/sysroots-components/x86_64

# 验证三个 native 组件都在
find $SYSROOT -name "grpc_cpp_plugin" -type f
# → $SYSROOT/grpc-native/usr/bin/grpc_cpp_plugin

find $SYSROOT -name "libprotoc.so*"
# → $SYSROOT/protobuf-native/usr/lib/libprotoc.so.25.3.0
# → $SYSROOT/protobuf-native/usr/lib/libprotoc.so

find $SYSROOT -name "libabsl_log_internal_check_op*"
# → $SYSROOT/abseil-cpp-native/usr/lib/libabsl_log_internal_check_op.so*
```

### 10.3 VM 端：准备源码目录

```bash
# [VM]
# 从共享文件夹拷一份到 home，避免在 hgfs 上直接写（hgfs 有时权限诡异）
cp -r /mnt/hgfs/grpc_demo ~/grpc_demo_src
cd ~/grpc_demo_src

# 目录结构应该是：
# ~/grpc_demo_src/
# ├── proto/
# │   └── demo.proto
# ├── server/
# │   ├── demo_server.cpp
# │   └── build.sh   (原始版本，会调 protoc，我们要改掉)
# └── client/
#     └── demo_client.py
```

### 10.4 VM 端：生成 C++ stub（含 LD_LIBRARY_PATH 修复）

```bash
# [VM]
export LD_LIBRARY_PATH=$SYSROOT/abseil-cpp-native/usr/lib:$SYSROOT/protobuf-native/usr/lib:$SYSROOT/grpc-native/usr/lib:$LD_LIBRARY_PATH

PLUGIN=$SYSROOT/grpc-native/usr/bin/grpc_cpp_plugin

# 第一步：生成 message class
protoc -I proto --cpp_out=server proto/demo.proto

# 第二步：生成 gRPC service stub
protoc -I proto \
    --grpc_out=server \
    --plugin=protoc-gen-grpc=$PLUGIN \
    proto/demo.proto

ls server/
# build.sh  demo.grpc.pb.cc  demo.grpc.pb.h  demo.pb.cc  demo.pb.h  demo_server.cpp
```

**常见缺库连环错**（按报错依次解决）：

| 报错 | 缺失库 | 解决 |
|---|---|---|
| `libprotoc.so.25.3.0: cannot open shared object file` | protobuf-native | 加 `$SYSROOT/protobuf-native/usr/lib` 到 LD_LIBRARY_PATH |
| `libabsl_log_internal_check_op.so.2401.0.0: ...` | abseil-cpp-native | 加 `$SYSROOT/abseil-cpp-native/usr/lib` |
| `libabsl_synchronization.so...` 或 `libabsl_time.so...` | abseil-cpp-native（同上） | 一般加上整个 abseil-cpp-native/usr/lib 即可解决 |
| `libre2.so...` | re2-native | 加 `$SYSROOT/re2-native/usr/lib` |

### 10.5 VM 端：写板卡端精简 build.sh

```bash
# [VM]
cat > ~/grpc_demo_src/server/build.sh << 'EOF'
#!/bin/bash
# Board-side build: protoc pre-generated on VM, board only runs g++
set -e
echo "=== Compiling demo_server ==="

# Yocto 打包时 libutf8_range.so 被改名为 libutf8_range_lib.so
# libutf8_validity.so 根本不在 target（符号已嵌入 libprotobuf.so.25.3.0）
# 但 protobuf.pc 还按上游原名写 Libs.private
#   → 过滤掉 -lutf8_validity
#   → 配合软链 libutf8_range.so → libutf8_range_lib.so
LIBS=$(pkg-config --libs grpc++ protobuf | sed 's/-lutf8_validity//g')
CFLAGS=$(pkg-config --cflags grpc++ protobuf)

g++ -std=c++17 -O2 \
    -o demo_server \
    demo_server.cpp \
    demo.pb.cc \
    demo.grpc.pb.cc \
    $CFLAGS $LIBS \
    -lpthread

echo "=== Build complete ==="
echo "Run with: sudo ./demo_server --port 50051"
echo "(sudo required for /dev/mem access)"
EOF
chmod +x ~/grpc_demo_src/server/build.sh
```

### 10.6 VM 端：把 server 目录拷回共享文件夹

```bash
# [VM]
cp -r ~/grpc_demo_src/server /mnt/hgfs/grpc_demo/server_built
ls /mnt/hgfs/grpc_demo/server_built
# build.sh  demo.grpc.pb.cc  demo.grpc.pb.h  demo.pb.cc  demo.pb.h  demo_server.cpp
```

Windows 资源管理器里立刻可见 `D:\...\grpc_demo\server_built\`。

### 10.7 Windows 端：scp 到板卡

```powershell
# [Windows]
# 每次重刷 rootfs 后 host key 变化，先清
ssh-keygen -R 192.168.2.10

scp -r D:\grpc_demo\server_built `
    petalinux@192.168.2.10:/home/petalinux/server
```

**预期输出**：
```
petalinux@192.168.2.10's password:
build.sh              100%  374   182.6KB/s   00:00
demo.grpc.pb.cc       100% 9541     3.0MB/s   00:00
demo.grpc.pb.h        100%   33KB   6.4MB/s   00:00
demo.pb.cc            100%   51KB   9.9MB/s   00:00
demo.pb.h             100%   51KB  12.5MB/s   00:00
demo_server.cpp       100% 9233     8.8MB/s   00:00
```

### 10.8 板卡端：建软链接 + 编译

```bash
# [板卡]
# 修 protobuf pkg-config 里的 -lutf8_range 找不到的问题（每次重启都要做，tmpfs 不持久化）
sudo ln -sf /usr/lib/libutf8_range_lib.so /usr/lib/libutf8_range.so
ls -la /usr/lib/libutf8_range*
# 应该看到：
# lrwxrwxrwx 1 root root    29 ... /usr/lib/libutf8_range.so -> /usr/lib/libutf8_range_lib.so
# lrwxrwxrwx 1 root root    23 ... /usr/lib/libutf8_range_lib.so -> libutf8_range_lib.so.37
# lrwxrwxrwx 1 root root    27 ... /usr/lib/libutf8_range_lib.so.37 -> libutf8_range_lib.so.37.0.0
# -rwxr-xr-x 1 root root 67264 ... /usr/lib/libutf8_range_lib.so.37.0.0

# scp 过来会丢 exec 位
cd ~/server
chmod +x build.sh
./build.sh
```

**预期输出**：
```
=== Compiling demo_server ===
=== Build complete ===
Run with: sudo ./demo_server --port 50051
(sudo required for /dev/mem access)
```

**编译耗时**：板卡 4 核 A53 编译 `.grpc.pb.cc`（40KB）+ `.pb.cc`（50KB）+ `demo_server.cpp`（9KB）大约 **1~5 分钟**（模板展开 + 优化吃 CPU）。期间串口没输出是正常的，只要不出 error 就继续等。

**产出验证**：
```bash
# [板卡]
ls -lh demo_server
# -rwxr-xr-x 1 petalinux petalinux 321K ... demo_server

file demo_server
# demo_server: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV),
#   dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, ...

ldd demo_server
# 确认依赖的 libgrpc++ / libprotobuf / libabsl_* 都能 resolve
```

**编译失败的典型症状**：

| 报错 | 原因 | 解决 |
|---|---|---|
| `ld: cannot find -lutf8_validity` | `protobuf.pc` 里写了但 target 没这个 lib | build.sh 里 `sed 's/-lutf8_validity//g'` 过滤 |
| `ld: cannot find -lutf8_range` | Yocto 把文件名改成了 `libutf8_range_lib.so` | `sudo ln -sf libutf8_range_lib.so /usr/lib/libutf8_range.so` |
| `fatal error: grpcpp/grpcpp.h: No such file or directory` | `grpc-dev` 包没装 | rebuild rootfs，确认 `IMAGE_INSTALL:append = " grpc-dev"` |
| `fatal error: google/protobuf/...: No such file or directory` | `protobuf-dev` 没装 | 同上 |
| `undefined reference to protobuf::...` | libprotobuf 版本不匹配 | VM 端的 protoc 版本和板卡 libprotobuf 版本要一致（都是 25.3） |

---

## 11. 阶段 I：运行服务端 + Python 客户端测试

### 11.1 启动 demo_server（板卡前台运行）

```bash
# [板卡]
cd ~/server
sudo ./demo_server --port 50051
```

**成功输出**（保持这个终端运行，不要关）：
```
GPIO mapped at 0xa0000000
DMA  mapped at 0xa0010000
udmabuf phys_addr=0x5d100000 size=1048576
Demo gRPC server listening on 0.0.0.0:50051
```

**各行含义**：
- `GPIO mapped at 0xa0000000`：demo_server 成功 mmap 了 `/dev/mem` 的 AXI GPIO 地址空间
- `DMA mapped at 0xa0010000`：同上，AXI DMA 寄存器
- `udmabuf phys_addr=0x5d100000 size=1048576`：打开 `/dev/udmabuf0` 并读到了 sysfs 里的物理地址（1 MB = 1048576 bytes）
- `Demo gRPC server listening on 0.0.0.0:50051`：gRPC Server::BuildAndStart 成功，0.0.0.0 表示监听所有网卡

**启动失败的典型症状**：

| 报错 | 原因 | 解决 |
|---|---|---|
| `Failed to open /dev/mem` | 没用 sudo | `sudo ./demo_server ...` |
| `Failed to open /dev/udmabuf0: No such file or directory` | `u-dma-buf` 内核模块没加载 或 设备树没配 | 阶段 D 检查 system-user.dtsi + `lsmod \| grep udma` |
| `mmap: Invalid argument` | udmabuf size mismatch | 确认 `cat /sys/class/u-dma-buf/udmabuf0/size` 和 demo_server 里 `#define UDMABUF_SIZE` 一致 |
| `grpc_server: error while loading shared libraries: libgrpc++.so.1.60: cannot open shared object file` | `grpc` 运行时包没装到 target | rebuild rootfs |

### 11.2 上位机 Python 客户端准备

```powershell
# [Windows] 另开一个 PowerShell 窗口（**不要关 demo_server 那个串口**）
conda create -n grpc_client python=3.11 -y
conda activate grpc_client
pip install grpcio grpcio-tools

cd D:\grpc_demo\client

# 生成 Python 版的 proto stub
python -m grpc_tools.protoc `
    -I..\proto `
    --python_out=. `
    --grpc_python_out=. `
    ..\proto\demo.proto

dir
# demo_client.py
# demo_pb2.py           ← 新生成
# demo_pb2_grpc.py      ← 新生成
# gen_proto.sh
```

### 11.3 跑测试

```powershell
# [Windows]
python demo_client.py --host 192.168.2.10 --port 50051 --words 92
```

**⚠️ `--words` 必须用 92 不能用默认 100**！原因在 11.5 节解释。

**预期输出**：
```
Connecting to 192.168.2.10:50051...
==================================================
Test 1: GPIO Channel 1 - Write 0xDEADBEEF, Read back
==================================================
  Write: success=True, msg=OK
  Read:  value=0xDEADBEEF
  PASS: Value matches!

==================================================
Test 2: GPIO Channel 2 - Write 0x12345678, Read back
==================================================
  Write: success=True, msg=OK
  Read:  value=0x12345678
  PASS: Value matches!

==================================================
Test 3: DMA Stream - 10 frames, 92 words each
==================================================
  Frame   0: first=0x000003EC, last=0x00000447, len=92
  Frame   1: first=0x000003EC, last=0x00000447, len=92
    WARN: Gap between frames: prev_last=0x00000447, first=0x000003EC
  ...
  Frame   9: first=0x000003EC, last=0x00000447, len=92
    WARN: Gap between frames: prev_last=0x00000447, first=0x000003EC
  PASS: All frames have sequential data!

==================================================
Summary:
  GPIO: PASS
  DMA Stream: PASS
```

### 11.4 各测试点含义

**Test 1/2 GPIO RW**：
- `WriteGpio(channel=1, value=0xDEADBEEF)`：gRPC 调板卡 demo_server → `*(uint32_t*)(gpio_mmap + 0) = 0xDEADBEEF` → AXI4-Lite 写事务 → AXI GPIO Ch1 寄存器
- `ReadGpio(channel=1)`：读回来，两个通道各测一次
- 能 RW 说明：Linux 驱动、`/dev/mem` mmap、AXI GP0 总线、PL bitstream（AXI GPIO IP）全链路都活着

**Test 3 DMA Streaming**：
- `StreamDmaData(count=10, words_per_frame=92)`：板卡收到请求后
  1. 清 udmabuf
  2. 把 DMA 寄存器配成 S2MM mode，destination = udmabuf phys_addr
  3. 启动 PL counter IP 产生数据
  4. DMA 收到 TLAST → 中断（或 polling 完成）
  5. 从 udmabuf 读数据 → 封进 `DmaStreamChunk` 消息 → 流式返回
- 数据必须连续递增（`0x3EC, 0x3ED, ..., 0x447`），len=92
- 能跑说明：S2MM DMA + udmabuf + PL 数据源 + gRPC streaming 全链路都活着

### 11.5 为什么是 92 words 不是 100

板卡的 PL counter IP 每次 DMA transaction 会：
1. 从某个初始值（本例 `0x3EC`）开始计数
2. 每 clock 输出一个递增 word
3. 输出 **92 个 word** 后 assert `TLAST`
4. DMA S2MM 收到 TLAST 就 stop

所以：
- `words_per_frame=92` → 刚好匹配 → 92 个连续值 PASS
- `words_per_frame=100` → 前 92 word 是数据，后 8 word 是 udmabuf 初始化的零（demo_server 不清零） → "Non-sequential at word 92: 0x63 → 0x00" 报错

**`first=0x3EC` 而非 `0x0` 的原因**：counter IP 启动到 DMA 开始捕获之间有固定几百拍的流水线延迟（FIFO 填充 + AXI-Stream 握手 + AXI interconnect 延时），这是硬件设计特性。

**帧之间 WARN Gap**：每次 `StreamDmaData` 的每一帧都重新启动 DMA + counter，counter 从同一个起始值（0x3EC）开始，所以帧与帧之间的 last_word → first_word 不连续。这是预期行为，不是 bug。

### 11.6 到这里就通了

**PC ↔ 板卡 gRPC 端到端全链路验证完成**：

```
Python客户端 → TCP/IP → grpc++ server → /dev/mem mmap →
AXI GP0 → PL bitstream (AXI GPIO / AXI DMA) → udmabuf → DDR → 回送
```

---

## 12. 阶段 J：每次重刷 rootfs 后的必做清单

按顺序执行，**缺任何一步下一步都会失败**：

| # | 节点 | 命令/动作 | 防止哪个坑 |
|---|---|---|---|
| 1 | **[VM]** | `petalinux-package --boot --u-boot --fpga images/linux/system.bit --force` | 漏 `--fpga` → 板卡启动死锁 |
| 2 | **[VM]** | `ls -lh images/linux/BOOT.BIN` 自检 ~30 MB | 验证是否漏 fpga |
| 3 | **[VM]** | `cp images/linux/{BOOT.BIN,image.ub,boot.scr} /media/.../BOOT/ && sync` | 必须三件套，少 boot.scr → 找不到内核 |
| 4 | **[VM]** | `sudo umount /media/.../BOOT` 或文件管理器弹出 | 数据没 flush 下板会损坏 |
| 5 | 板卡上电 | 串口 115200-8-N-1 观察启动日志 | — |
| 6 | **[板卡]** | 首次登录改密码 | — |
| 7 | **[板卡]** | `sudo ifconfig end0 192.168.2.10 netmask 255.255.255.0 up` | tmpfs rootfs 不持久化 |
| 8 | **[板卡]** | `sudo ln -sf /usr/lib/libutf8_range_lib.so /usr/lib/libutf8_range.so` | Yocto protobuf 重命名坑 |
| 9 | **[板卡]** | `ls /dev/udmabuf0 && cat /sys/class/u-dma-buf/udmabuf0/size` | 验证 u-dma-buf 模块加载 |
| 10 | **[Windows]** | `ssh-keygen -R 192.168.2.10` | 新 rootfs host key 变化 |
| 11 | **[Windows]** | `ping 192.168.2.10`（TTL 必须 =64） | 排查 IP 冲突 |
| 12 | **[VM]** | 重新跑 protoc 生成 pb stub 到共享文件夹 | 板卡无 C++ protoc |
| 13 | **[Windows]** | `scp -r ...\server_built petalinux@192.168.2.10:~/server` | — |
| 14 | **[板卡]** | `cd ~/server && chmod +x build.sh && ./build.sh` | scp 丢 exec 位 |
| 15 | **[板卡]** | `sudo ./demo_server --port 50051` | 必须 sudo |
| 16 | **[Windows]** | `python demo_client.py --host 192.168.2.10 --port 50051 --words 92` | words 必须按 PL burst 配 |

---

## 13. 常见问题速查（10 项）

### Q1：`protoc: command not found`（板卡）

**原因：** meta-oe 的 `protobuf-compiler` 只做 native 变体，C++ protoc 不会装到 target。

**解决：** 不要试图在板卡装 protoc，采用阶段 H 的方案 A（VM 预生成 + 板上 g++）。

---

### Q2：`ld: cannot find -lutf8_validity` / `-lutf8_range`

**原因：** Yocto 把 `libutf8_range.so` 改名为 `libutf8_range_lib.so`；`libutf8_validity.so` 根本没进 target 包（符号已静态嵌入 libprotobuf）。但 `/usr/lib/pkgconfig/protobuf.pc` 还按上游原名写 `Libs.private`。

**解决：**

```bash
# [板卡]
sudo ln -sf /usr/lib/libutf8_range_lib.so /usr/lib/libutf8_range.so
```

build.sh 里过滤掉 `-lutf8_validity`：

```bash
LIBS=$(pkg-config --libs grpc++ protobuf | sed 's/-lutf8_validity//g')
```

---

### Q3：板卡启动卡在 `rcu: INFO: rcu_sched detected stalls ... deferred_probe_work_func`

**原因：** BOOT.BIN 没打包 bitstream（打包时漏了 `--fpga`），PL 是黑的，内核 probe PL 外设时对无响应 AXI 总线读写 → CPU busy loop → RCU stall。

**定位**：U-Boot 里 `setenv bootargs "... initcall_debug ignore_loglevel"` 启动后会看到两个 PS UART probe 完，下一个 PL 外设 probe 就挂。

**解决：**

```bash
# [VM]
petalinux-package --boot --u-boot --fpga images/linux/system.bit --force
ls -lh images/linux/BOOT.BIN  # 应该 ~30 MB，不是 1.8 MB
```

---

### Q4：`demo_server: Failed to open /dev/mem`

**原因：** 没用 sudo。`/dev/mem` mmap 需要 root 权限。

**解决：** `sudo ./demo_server --port 50051`

或者给 demo_server 加 `CAP_SYS_RAWIO` capability：
```bash
sudo setcap cap_sys_rawio+ep ./demo_server
./demo_server --port 50051  # 不需要 sudo 了
```

---

### Q5：Python client `DMA Stream FAIL: Non-sequential at word N`

**原因：** `--words` 参数和 PL counter IP 的 burst 长度不匹配。

**解决：**
```powershell
# [Windows]
python demo_client.py --words 92    # 按 PL 实际 burst 长度
```

如何知道 PL burst 长度？看 Vivado 里 counter IP 的 TLAST 逻辑，或者跑一次默认 100 看在第几个 word 跳变。

---

### Q6：`grpc_1.60.1.bb do_fetch failed: gitsm://github.com/grpc/grpc.git`

**原因：** 国内 VM 拉 GitHub 子模块超时。gRPC 有 boringssl/abseil/protobuf/re2/c-ares/upb/xds/googleapis 等十几个 submodule，任何一个失败整个 fetch 就挂。

**解决：**

```bash
# [VM]
git config --global url."https://gh-proxy.com/https://github.com/".insteadOf "https://github.com/"
petalinux-build -c grpc -c cleansstate
petalinux-build
```

可选镜像：`gh-proxy.com` / `ghfast.top` / `hub.gitmirror.com` / `mirror.ghproxy.com`

---

### Q7：VM ping 板卡 `TTL=128` 或 `Destination Host Unreachable`

**原因：** 两种可能：
- (a) Windows 某个网卡（通常 WLAN）IP 和板卡冲突，ping 的是自己（Windows TTL=128，Linux TTL=64）
- (b) VM 在 NAT 模式下 `ens33` 拿的是 `192.168.44.x`，和板卡 `192.168.2.x` 不在同一 L2

**解决（推荐）：** 不折腾 VM 网络，走 **"VM → hgfs 共享 → Windows → scp → 板卡"** V 字路径。

**解决（备选）：** VMware → Virtual Network Editor → VMnet0 Bridged → **明确选以太网卡**（不要 Automatic，不要 WLAN），VM 内手动配 `192.168.2.50/24`。

---

### Q8：rebuild rootfs 重启后 `/home/petalinux` 全空，上传的源码丢了

**原因：** PetaLinux 默认 rootfs 是只读 initramfs/tmpfs，家目录不持久化，重启即失。

**解决（临时）：** 每次重启后重新 scp。

**解决（长期）：** `petalinux-config` → `Image Packaging Configuration` → `Root filesystem type = SD card` 启用 ext4 rootfs；或单独分一个 SD 卡分区挂到 `/opt`。

---

### Q9：SSH 连板卡报 `REMOTE HOST IDENTIFICATION HAS CHANGED!`

**原因：** 新 rootfs 第一次启动时 sshd 重新生成 host key，和 Windows `known_hosts` 里记的旧 key 不匹配。

**解决：**

```powershell
# [Windows]
ssh-keygen -R 192.168.2.10
# 然后重新 ssh，第一次会问 yes/no，输 yes 重建信任
```

---

### Q10：U-Boot 报 `Retrying... No SYSLINUX found`

**原因：** SD 卡 FAT32 分区缺 `boot.scr`（U-Boot distro boot 脚本）。

**解决：**

```bash
# [VM]
cp images/linux/boot.scr /media/yqq/<BOOT-UUID>/
sync
```

SD 卡 FAT32 分区必须同时有：`BOOT.BIN` + `image.ub` + `boot.scr`，三个缺一不可。

---

## 14. 关键文件清单

### 14.1 VM 端（PetaLinux 工程）

| 路径 | 作用 | 必须存在？ |
|---|---|---|
| `project-spec/configs/config` | 主 Kconfig | 是 |
| `project-spec/configs/rootfs_config` | rootfs Kconfig（自动生成，**不要手动改**） | 是 |
| `project-spec/meta-user/conf/petalinuxbsp.conf` | **追加包的唯一可靠入口** | 是 |
| `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi` | 用户设备树（udmabuf 预留） | 是 |
| `build/tmp/sysroots-components/x86_64/grpc-native/usr/bin/grpc_cpp_plugin` | native gRPC plugin | 是（VM 侧生成 stub 用） |
| `build/tmp/sysroots-components/x86_64/protobuf-native/usr/lib/libprotoc.so.25.3.0` | native libprotoc | 是 |
| `build/tmp/sysroots-components/x86_64/abseil-cpp-native/usr/lib/libabsl_*.so` | abseil 依赖 | 是 |
| `images/linux/BOOT.BIN` | **最终启动镜像（~30 MB，必须含 bitstream）** | 是 |
| `images/linux/image.ub` | FIT kernel + dtb + initramfs（~180 MB） | 是 |
| `images/linux/boot.scr` | U-Boot distro boot 脚本 | 是 |
| `images/linux/system.bit` | PL bitstream（打包 BOOT.BIN 必传） | 是 |
| `images/linux/zynqmp_fsbl.elf` | First Stage Boot Loader | 自动打进 BOOT.BIN |
| `images/linux/bl31.elf` | ARM Trusted Firmware BL31 | 自动打进 BOOT.BIN |
| `images/linux/pmufw.elf` | PMU firmware | 自动打进 BOOT.BIN |

### 14.2 Windows 端（Vivado/源码工程）

| 路径 | 作用 |
|---|---|
| `D:\...\grpc_demo\vivado\` | Vivado 工程 |
| `D:\...\grpc_demo\vivado\design_1_wrapper.xsa` | 硬件描述，导给 PetaLinux |
| `D:\...\grpc_demo\proto\demo.proto` | gRPC 服务定义 |
| `D:\...\grpc_demo\server\demo_server.cpp` | 服务端 C++ 实现 |
| `D:\...\grpc_demo\server\build.sh` | 板卡端编译脚本（精简版） |
| `D:\...\grpc_demo\client\demo_client.py` | Python 客户端 |
| `D:\...\grpc_demo\server_built\` | **VM 生成后写回共享文件夹的中转目录**（含 .pb.cc/.pb.h） |

### 14.3 板卡 rootfs

| 路径 | 作用 |
|---|---|
| `/usr/bin/gcc` / `g++` | `packagegroup-core-buildessential` 提供 |
| `/usr/bin/grpc_cpp_plugin` | 存在但一般用不到（走方案 A 时） |
| `/usr/lib/libutf8_range_lib.so*` | ⚠️ 需要软链接到 `libutf8_range.so` |
| `/usr/lib/libprotobuf.so.25.3.0` | protobuf C++ 运行时 |
| `/usr/lib/libgrpc++.so.1.60` | gRPC C++ 运行时 |
| `/usr/lib/pkgconfig/grpc++.pc` | pkg-config 元数据 |
| `/usr/lib/pkgconfig/protobuf.pc` | pkg-config 元数据（含要过滤的 -lutf8_validity） |
| `/dev/udmabuf0` | u-dma-buf 字符设备 |
| `/sys/class/u-dma-buf/udmabuf0/phys_addr` | udmabuf 物理地址（demo_server 读这个） |
| `/sys/class/u-dma-buf/udmabuf0/size` | udmabuf 大小 |
| `/dev/mem` | 物理内存访问（AXI 寄存器 mmap，需要 sudo） |
| `/home/petalinux/server/` | ⚠️ tmpfs，重启清空，源码和 ELF 都会丢 |

---

## 15. 版本差异

| 版本 | 说明 |
|---|---|
| **PetaLinux 2022.x 及之前** | rootfs 配置可能还能通过 `petalinux-config -c rootfs` 菜单添加 grpc/protobuf，无需改 `petalinuxbsp.conf`；libprotobuf 3.21.x，无 utf8_range/utf8_validity 拆分坑 |
| **PetaLinux 2023.1~2023.2** | libprotobuf 仍是 3.21.x；meta-oe `grpc` 配方已经从 `git://` 切到 `gitsm://`，开始出现 submodule fetch 坑 |
| **PetaLinux 2024.1** | libprotobuf 升级到 25.x，**本文所有 utf8_range 命名坑开始出现**；`rm_work` 默认启用 |
| **PetaLinux 2024.2**（本文） | libprotobuf 25.3.0，libgrpc 1.60.1；`IMAGE_INSTALL:append` 语法已不再接受 `append_IMAGE_INSTALL` 旧风格；系统网络名改为 `end0`（之前可能是 `eth0` 或 `enp0s1`） |
| **Yocto scarthgap** | meta-oe protobuf recipe 把 `libutf8_range.so` 改名为 `libutf8_range_lib.so`（上游避免命名冲突） |

---

## 16. 参考文档

### Xilinx 官方
- **UG1144** – PetaLinux Tools Documentation Reference Guide
- **UG1137** – Zynq UltraScale+ MPSoC Software Developer Guide
- **UG1085** – Zynq UltraScale+ MPSoC Technical Reference Manual
- **PG021** – AXI DMA v7.1 LogiCORE IP Product Guide
- **PG144** – AXI GPIO v2.0 LogiCORE IP Product Guide
- **XAPP1305** – Accelerating OpenCV Applications with Zynq UltraScale+ MPSoC（Yocto 流程参考）

### 开源项目
- **gRPC C++ Reference**：https://grpc.io/docs/languages/cpp/
- **Protobuf C++ Reference**：https://protobuf.dev/reference/cpp/
- **u-dma-buf (ikwzm)**：https://github.com/ikwzm/udmabuf
- **meta-openembedded**：https://git.openembedded.org/meta-openembedded
- **Yocto protobuf recipe**：`meta-openembedded/meta-oe/recipes-devtools/protobuf/`
- **Yocto grpc recipe**：`meta-openembedded/meta-oe/recipes-devtools/grpc/`

### 本项目
- `migration_guide.md` – 从官方评估板（如 ZCU104）迁移到自制 ZynqMP 板的完整指南，含常见问题踩坑记录
- `grpc_demo/vivado/scripts/setup_bd.tcl` – Vivado 工程自动化脚本
- `grpc_demo/vivado/scripts/fix_ps8.tcl` – PS8 MIO/TTC/IRQ 修复脚本

### 相邻 reference（本目录）
- `petalinux_guide.md` – PetaLinux 基础流程
- `mpsoc_ps_config.md` – PS8 配置（QSPI/MIO/DP）
- `mpsoc_bd_guide.md` – Block Design 常见拓扑
- `vivado_guide.md` – Vivado 工程流程
