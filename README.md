# OnePlus 9R (lemonades) · Evolution X 16 · KernelSU-Next

给 **OnePlus 9R（lemonades）** 跑 **Evolution X 11.6.2 / Android 16** 的一整套 KernelSU-Next root 方案：
与 ROM 完全同源的内核镜像、可复现的编译脚本、boot.img 重打包工具、隐藏栈与验证脚本。

> 这不是通用一键工具。所有产物都绑定具体 ROM build，跨 build 使用会起不来 —— 下面把"为什么"和"怎么重新生成"都写清楚了。

## 现状

| 项 | 状态 |
|---|---|
| 设备 | OnePlus 9R（`lemonades`，SM8250-AC / kona，kernel 4.19，**非 GKI**） |
| ROM | Evolution X `EvolutionX-16.0-20260404-lemonades-11.6.2-Official`（`post-build-incremental=1775355166`） |
| Root | **KernelSU-Next v3.4.0-legacy**，`CONFIG_KSU=y`，hook 模式 **Kprobes**，非 GKI |
| 内核源码 | `LineageOS/android_kernel_oneplus_sm8250` · `lineage-23.2` · commit **`0970a5d23405`** |
| 内核版本串 | `4.19.325-cip128-st12-perf-g0970a5d23405` —— 与 ROM 自带内核逐字符一致 |
| boot.img | header **v2**、page 4096、ramdisk 2,832,693 B、dtb 1,428,199 B、成品 **55,193,600 B**（分区 96 MiB） |
| SUSFS | **未集成**（见 [docs/HIDING.md](docs/HIDING.md) 第 3 层与「已知限制」） |

## 快速开始

```powershell
# 1. 取镜像（Release 附件）后先临时启动，不写分区
fastboot boot boot_ksu_lin.img

# 2. 确认能进系统、能拿到 root
adb install -r KernelSU_Next_v3.4.0_33294-release.apk
adb shell su -c id                     # uid=0(root)

# 3. 落盘（不要带 _a/_b，让 fastboot 落到活动槽）
fastboot flash boot boot_ksu_lin.img
fastboot reboot
```

回滚：`fastboot flash boot stock_boot_A16_11.6.2.img`（Release 附件，96 MiB，与分区同尺寸）。

## 为什么这么麻烦：三个已经踩过的坑

### 1. 内核源码树选错 → 连无 root 的基线都起不来

| 树 | 版本串 | 结果 |
|---|---|---|
| `Evolution-X-Devices/kernel_oneplus_sm8250` @ `bka` | `4.19.325-perf-g5d1e271a1322` | ✗ 卡 Orange State |
| `LineageOS/android_kernel_oneplus_sm8250` @ `lineage-23.2` + commit `0970a5d` | `4.19.325-cip128-st12-perf-g0970a5d23405` | ✓ 正常启动 |

判据：**内核版本串必须和 ROM 自带内核一致**。`-cip128-st12` 这个后缀就是那条源码线的指纹。

```bash
# 从 ROM 的 boot.img 里读版本串，作为选树依据
python -c "import re;d=open('boot.img','rb').read();print(re.search(rb'Linux version [^\x00]{0,160}',d).group(0).decode())"
```

### 2. 直接把原镜像尾部搬过去 → `Volume Full`

`payload.bin` 里的分区镜像是**整分区大小**（boot = 100,663,296 B = 96 MiB），尾部是填充 + AVB footer。
原样搬运再加一个略大的内核，成品 101,707,776 B > 分区 → `Writing 'boot_a' FAILED (remote: 'Error flashing partition : Volume Full')`。

正确做法（`scripts/repack-bootimg.py` 默认行为）：只写 `header + kernel + ramdisk + dtb`，丢弃尾部填充与 AVB footer，
fastboot 会自己补齐。成品 55,193,600 B。

### 3. Manager 与内核版本不匹配 → `Failed to update App Profile`

内核编进去的是 **33294（v3.4.0）**，装 3.4.2 的 Manager 就会出现 App Profile 保存失败。
Manager 必须与内核版本对齐：**`KernelSU_Next_v3.4.0_33294-release.apk`**。

## 目录

```
scripts/
  build-kernel.sh        从源码编内核 → Image → 校验（Linux/WSL2）
  repack-bootimg.py      纯 Python 重打包 boot.img（v0–v4，默认输出最小镜像）
  flash-bootimg.ps1      fastboot boot 验证 → flash boot → 验证 su
  install-modules.ps1    Manager + Zygisk Next + PIF + LSPosed，列出待 umount 的 App
  verify-hide.ps1        逐项验证隐藏是否真的生效
docs/
  BUILD.md               从零编译（工具链、defconfig、常见报错）
  FLASH.md               刷入与回滚的完整流程
  TROUBLESHOOTING.md     五个实际踩过的故障与判读方法
  HIDING.md              隐藏的三层结构、能力边界、SUSFS 现状
.github/workflows/
  build-kernel.yml       云端构建内核（Actions，手动触发）
```

## 自己重编（换 ROM build 时必做）

```bash
# Linux / WSL2
KERNEL_BRANCH=lineage-23.2 \
KERNEL_COMMIT=0970a5d23405622c10bc4ff60ef0ba30499611e1 \
DEFCONFIG=vendor/kona-perf_defconfig \
./scripts/build-kernel.sh
```

详见 [docs/BUILD.md](docs/BUILD.md)。工具链：AOSP `clang-r487747c`（clang 17.0.2）；
ROM 官方是 clang 21，用 17 编出的 Image 差 2 KB，功能一致。

## 验证与隐藏

```powershell
.\scripts\install-modules.ps1     # 装 Manager + 模块
.\scripts\verify-hide.ps1         # 挂载整洁度 / su 上下文 / 模块清单 / 待 umount 列表
```

隐藏能力与边界见 [docs/HIDING.md](docs/HIDING.md)：内核侧 `kernel_umount` + `selinux_hide`、用户态
Zygisk Next + PIF、逐 App umount。**SUSFS 未集成**（4.19 + KernelSU-Next legacy 缺 supercall 通道，
ReSukiSU 侧还差代码量，详见该文档）。

## 兼容性矩阵

| ROM build | 可直接用本仓库 Release？ |
|---|---|
| EvolutionX 11.6.2 / 20260404（incremental `1775355166`） | ✅ |
| 其他 A16 build | ❌ 需按新 build 重编（版本串必须匹配） |
| Android 15 及更早 | ❌ 内核线不同 |

## 许可与致谢

- 内核改动与补丁：**GPL-2.0**（衍生自 Linux kernel / LineageOS）
- 本仓库脚本：**GPL-2.0**，与内核保持一致，便于二次分发
- 致谢：[KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)、
  [LineageOS kernel](https://github.com/LineageOS/android_kernel_oneplus_sm8250)、
  [Evolution X](https://evolution-x.org/device/lemonades)、
  [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3)（早期 sideload 方案曾使用）、
  [susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)（SUSFS 移植尝试）

## 免责声明

刷机有风险。本仓库所有验证都来自一台真机 + 可复现构建，但**不保证**在其他 9R 上零风险。
先 `fastboot boot` 临时启动验证，确认无问题再 `fastboot flash`；始终保留原版 boot.img。
