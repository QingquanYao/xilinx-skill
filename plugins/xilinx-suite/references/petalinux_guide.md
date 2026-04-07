# PetaLinux 工程完整流程指南

## 概述

PetaLinux 是 Xilinx 提供的嵌入式 Linux 开发工具集，基于 Yocto Project，专用于 Zynq/MPSoC/Versal 平台。

**完整流程：**
```
XSA（来自 Vivado）→ 创建工程 → 配置 → 构建 → 打包 → 部署到 SD 卡 / QSPI
```

**版本要求：**
- PetaLinux 版本必须与 Vivado 版本完全一致（如都用 2023.2）
- 需要 Linux 构建主机（Ubuntu 20.04/22.04 推荐）

---

## 前置要求

```bash
# 安装 PetaLinux 依赖（Ubuntu 20.04/22.04）
sudo apt-get install -y \
    gawk python3 python3-pexpect python3-git python3-jinja2 \
    gcc-multilib build-essential socat cpio unzip rsync \
    diffstat texinfo chrpath autoconf automake \
    libsdl1.2-dev libglib2.0-dev libssl-dev

# 设置 PetaLinux 环境（每次新终端都需要）
source /opt/petalinux/2023.2/settings.sh
```

---

## 阶段 1：创建 PetaLinux 工程

```bash
# ——— 方式 1：从 XSA 创建（最常用）———
petalinux-create --type project --template zynqMP \
    --name my_petalinux_proj
cd my_petalinux_proj

# 导入 Vivado 导出的 XSA
petalinux-config --get-hw-description=../02_vivado/output/design_fixed.xsa

# ——— 方式 2：从板卡 BSP 创建（有官方 BSP 时推荐）———
# petalinux-create --type project -s /path/to/xilinx-zcu104-v2023.2-final.bsp
# cd xilinx-zcu104-2023.2

# ——— 方式 3：更新已有工程的硬件 ———
# petalinux-config --get-hw-description=/path/to/new.xsa
```

---

## 阶段 2：系统配置

### 2.1 系统级配置（内核/引导方式/rootfs 类型）

```bash
# 打开顶层配置菜单
petalinux-config
```

**常用配置项（menuconfig 路径）：**

```
Subsystem AUTO Hardware Settings
  → u-boot Configuration
      → u-boot config target: xilinx_zynqmp_virt_defconfig
  → DTG Settings
      → MACHINE_NAME: zcu102-rev1.0（或自定义板卡名）
      → (SUBSYSTEM_MACHINE_NAME)

Image Packaging Configuration
  → Root filesystem type: (EXT4 / INITRD / NFS)
      INITRD  ← 适合快速启动，rootfs 在 ramdisk
      EXT4    ← 推荐生产用，rootfs 在 SD 卡第2分区

Firmware Version Configuration
  → u-boot Version: (保持默认，与 PetaLinux 版本匹配)
```

### 2.2 内核配置

```bash
# 打开 Linux 内核配置（基于 Kconfig）
petalinux-config -c kernel

# 常用内核配置项：
# Device Drivers → Network device support → 以太网驱动
# Device Drivers → USB support
# File systems → Ext4 journalling file system support
# General setup → Preemption Model → Fully Preemptible (RT)
```

### 2.3 rootfs 配置（添加软件包）

```bash
# 打开 rootfs 配置
petalinux-config -c rootfs

# 常用软件包路径：
# Filesystem Packages → base → busybox
# Filesystem Packages → misc → gdb (调试器)
# Filesystem Packages → libs → libstdc++ (C++ 支持)
# PetaLinux Package Groups → packagegroup-petalinux-self-hosted (含 gcc)
# PetaLinux Package Groups → packagegroup-petalinux-opencv
# user packages → <自定义应用>
```

---

## 阶段 3：设备树定制

### 自定义设备树覆盖（推荐方式）

不直接修改自动生成的设备树，而是使用覆盖文件：

```bash
# 编辑用户自定义 DTS 文件
nano ./project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
```

**`system-user.dtsi` 示例：**

```dts
/include/ "system-conf.dtsi"
/ {
    /* 自定义根节点属性 */
    model = "My Custom ZynqMP Board";
    compatible = "my-company,my-board", "xlnx,zynqmp";

    /* 自定义 GPIO */
    gpio-leds {
        compatible = "gpio-leds";
        status = "okay";
        led0 {
            label = "user-led0";
            gpios = <&gpio 78 0>;  /* MIO 78 */
            default-state = "on";
        };
    };
};

/* 启用/配置已有节点 */
&uart0 {
    status = "okay";
};

&gem3 {
    status = "okay";
    phy-mode = "rgmii-id";
    phy-handle = <&phy0>;
    mdio {
        #address-cells = <1>;
        #size-cells = <0>;
        phy0: ethernet-phy@c {
            reg = <0xc>;
        };
    };
};

/* 自定义 PL IP 节点（AXI GPIO 示例）*/
&axi_gpio_0 {
    status = "okay";
    xlnx,all-outputs = <0x1>;
    xlnx,gpio-width = <0x8>;
};
```

### 查看自动生成的设备树

```bash
# 自动生成的设备树（不要直接修改）
cat ./components/plnx_workspace/device-tree/device-tree/pl.dtsi
cat ./components/plnx_workspace/device-tree/device-tree/system-top.dts
```

---

## 阶段 4：添加自定义应用程序

```bash
# 创建自定义应用程序 recipe
petalinux-create --type apps --name my-app --enable

# 编辑源文件
nano ./project-spec/meta-user/recipes-apps/my-app/files/my-app.c
```

**简单应用示例（my-app.c）：**
```c
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <stdint.h>

#define MY_IP_BASE  0xA0010000  // 与 Vivado Address Editor 一致

int main(void) {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }

    volatile uint32_t *ip = mmap(NULL, 0x10000,
        PROT_READ | PROT_WRITE, MAP_SHARED, fd, MY_IP_BASE);

    // 写控制寄存器（ap_start）
    ip[0] = 1;
    // 等待完成（ap_done）
    while (!(ip[1] & 0x2));
    printf("HLS IP 完成，结果：%u\n", ip[4]);

    munmap((void*)ip, 0x10000);
    close(fd);
    return 0;
}
```

**修改 recipe（my-app.bb）：**
```bitbake
SUMMARY = "My PL control application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://my-app.c"
S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} my-app.c -o my-app
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 my-app ${D}${bindir}
}
```

---

## 阶段 5：构建

```bash
# ——— 完整构建（第一次，耗时 30-90 分钟）———
petalinux-build

# ——— 仅构建特定组件（增量构建，速度快）———
petalinux-build -c kernel          # 仅内核
petalinux-build -c u-boot          # 仅 U-Boot
petalinux-build -c rootfs          # 仅 rootfs
petalinux-build -c my-app          # 仅自定义应用
petalinux-build -c device-tree     # 仅设备树

# 强制重新构建某组件（清除缓存）
petalinux-build -c kernel -x distclean && petalinux-build -c kernel
```

构建完成后的输出文件在 `./images/linux/`：
```
images/linux/
├── BOOT.BIN          ← 启动镜像（含 FSBL + PMU + ATF + U-Boot + 比特流）
├── boot.scr          ← U-Boot 启动脚本
├── image.ub          ← FIT 镜像（含内核 + 设备树）
│   或
├── Image             ← Linux 内核镜像（直接）
├── system.dtb        ← 设备树二进制
└── rootfs.ext4       ← ext4 根文件系统镜像（SD 卡方式用）
    rootfs.cpio.gz    ← INITRD 方式用
```

---

## 阶段 6：打包启动镜像

```bash
# ——— 标准打包（含比特流）———
petalinux-package --boot \
    --fsbl   ./images/linux/zynqmp_fsbl.elf \
    --pmufw  ./images/linux/pmufw.elf \
    --atf    ./images/linux/bl31.elf \
    --fpga   ./images/linux/system.bit \
    --u-boot ./images/linux/u-boot.elf \
    --force

# ——— 不含比特流（比特流由 Linux 驱动动态加载）———
petalinux-package --boot \
    --fsbl ./images/linux/zynqmp_fsbl.elf \
    --pmufw ./images/linux/pmufw.elf \
    --atf ./images/linux/bl31.elf \
    --u-boot ./images/linux/u-boot.elf \
    --force

# ——— 生成 WIC 镜像（可直接 dd 到 SD 卡）———
petalinux-package --wic --wic-extra-args "-c gzip"
# 生成：./images/linux/petalinux-sdimage.wic.gz
```

---

## 阶段 7：部署到 SD 卡

### 方法 1：使用 WIC 镜像（最简单）
```bash
# 解压并写入 SD 卡（注意 /dev/sdX 替换为实际设备）
gunzip ./images/linux/petalinux-sdimage.wic.gz
sudo dd if=./images/linux/petalinux-sdimage.wic of=/dev/sdX bs=4M status=progress
sync
```

### 方法 2：手动分区（两分区方式）
```bash
# 分区布局：
# FAT32 分区（256MB+）：BOOT.BIN, boot.scr, image.ub
# EXT4 分区（剩余）：rootfs 内容

# 写入 FAT32 分区（挂载后复制）
cp images/linux/BOOT.BIN  /mnt/boot/
cp images/linux/boot.scr  /mnt/boot/
cp images/linux/image.ub  /mnt/boot/    # FIT 镜像（内核+设备树）

# 写入 EXT4 分区（rootfs）
sudo tar -xf images/linux/rootfs.tar.gz -C /mnt/rootfs/
```

---

## 阶段 8：动态加载比特流（Linux 运行时）

```bash
# 在目标板 Linux 上：

# 将比特流文件复制到 /lib/firmware/
cp design.bit /lib/firmware/

# 通过 sysfs 加载比特流到 PL
echo 0 > /sys/class/fpga_manager/fpga0/flags
echo design.bit > /sys/class/fpga_manager/fpga0/firmware
cat /sys/class/fpga_manager/fpga0/state  # 应显示 "operating"
```

---

## 常用 PetaLinux 命令速查

```bash
# 打包 SDK（用于应用交叉编译）
petalinux-package --sysroot

# QEMU 仿真（无需实际硬件）
petalinux-boot --qemu --kernel

# 通过 JTAG 下载启动（连接到板卡）
petalinux-boot --jtag --kernel --fpga images/linux/system.bit

# 查看构建日志
bitbake -e my-app | grep ^SRC_URI
cat build/tmp/work/*/my-app/*/temp/log.do_compile

# 清理工程
petalinux-build -x distclean  # 清理所有构建缓存（不删除配置）

# 查看 Linux 内核版本
cat build/tmp/work-shared/*/kernel-source/.config | grep CONFIG_LOCALVERSION
```

---

## 常见问题

**Q：`petalinux-config` 报 XSA 版本不匹配**
```
原因：Vivado 和 PetaLinux 版本不一致
解决：确保两者版本完全一致（如均用 2023.2）
```

**Q：构建时 `do_compile` 报错找不到头文件**
```bash
# 检查 rootfs 中是否缺少依赖包
petalinux-config -c rootfs
# 搜索并启用所需库（如 libssl-dev）
```

**Q：U-Boot 无法找到 `image.ub`**
```
原因：FAT 分区文件名或 boot.scr 中的文件名不匹配
解决：检查 boot.scr 内容（执行 strings boot.scr），确认文件名一致
```

**Q：如何在 Linux 中访问自定义 PL IP？**
```
方法 1：/dev/mem + mmap（见上方应用示例）
方法 2：编写 UIO 驱动（在 DTS 中添加 compatible = "generic-uio" 节点）
方法 3：编写完整内核驱动模块
```
