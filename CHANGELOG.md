# Changelog

## v1.0.0 — 2026-10-27

首个可用版本：OnePlus 9R + Evolution X 11.6.2（Android 16）上的 KernelSU-Next root。

### 新增

- `boot_ksu_lin.img`：基于 `LineageOS/android_kernel_oneplus_sm8250@lineage-23.2@0970a5d` 编译，
  版本串 `4.19.325-cip128-st12-perf-g0970a5d23405`，与 ROM 自带内核一致
- `boot_base_lin.img`：同一源码的基线内核（无 root），用于排障与二分
- `stock_boot_A16_11.6.2.img`：原版 boot.img（96 MiB，与 boot 分区同尺寸），恢复用
- `scripts/repack-bootimg.py`：boot.img 重打包（header v0–v4，默认输出最小镜像，丢弃尾部填充与 AVB footer）
- `scripts/build-kernel.sh`：一条命令复现内核编译（AOSP clang-r487747c）
- `scripts/install-modules.ps1` / `verify-hide.ps1`：模块安装与隐藏验证

### 修复

- **镜像超分区导致 `Volume Full`**：旧产物 101,707,776 B > boot 分区 100,663,296 B；
  改为最小镜像后 55,193,600 B
- **选错内核源码树导致无法开机**：`Evolution-X-Devices/kernel_oneplus_sm8250@bka`
  （`4.19.325-perf-g5d1e271a1322`）不适用于本 ROM；改用 LineageOS 树并 pin 到 `0970a5d`
- **Manager 与内核版本不匹配**：内核 33294（v3.4.0）需搭配 `KernelSU_Next_v3.4.0_33294-release.apk`

### 已知问题

- SUSFS 未集成（KernelSU-Next legacy 在 4.19 上缺 supercall 通道；ReSukiSU 侧移植不完整），
  详见 `docs/HIDING.md`
- 仅支持 Evolution X 11.6.2 / 20260404（incremental `1775355166`）；其他 build 必须重编
