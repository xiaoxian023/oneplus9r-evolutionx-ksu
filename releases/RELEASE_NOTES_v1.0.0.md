# v1.0.0 — OnePlus 9R · Evolution X 16 · KernelSU-Next

## 适用对象

| 项 | 要求 |
|---|---|
| 机型 | OnePlus 9R（`lemonades`，kona / SM8250-AC，kernel 4.19 非 GKI） |
| ROM | Evolution X `11.6.2` / `20260404`（`ro.build.version.incremental` = `1775355166`） |
| 前提 | bootloader 已解锁 |

其他 build 请勿直刷，按 `docs/BUILD.md` 用对应 commit 重编。

## 附件

| 文件 | 用途 | sha256 |
|---|---|---|
| `boot_ksu_lin.img` | KernelSU-Next 内核（55,193,600 B） | `c83668f10be9f1b81485dc8fa124d7520b0bb3b2fc0f0b53f437d0d6dc2ad0ab` |
| `boot_base_lin.img` | 同源基线内核，无 root，排障用 | `526164d80fd0f7e773f257a612929039ccd9142511696c3fae93e99bc7007a38` |
| `stock_boot_A16_11.6.2.img` | 原版 boot.img（96 MiB，恢复用） | `eb0ebb74df35085ae6d497272e5df5ccab5a4956ac3bd626bfb05ae2f4597271` |
| `KernelSU_Next_v3.4.0_33294-release.apk` | 与内核版本对齐的 Manager | `50339a93c0f812b8a72c1a387a1b441891e3df0f20b2d9daf80fd798d04b3de8` |

## 安装

```powershell
fastboot boot boot_ksu_lin.img                 # 先临时启动验证
adb install -r KernelSU_Next_v3.4.0_33294-release.apk
adb shell su -c id                             # uid=0(root)

fastboot flash boot boot_ksu_lin.img           # 不带 _a/_b
fastboot reboot
```

回滚：`fastboot flash boot stock_boot_A16_11.6.2.img`

## 内核信息

- 源码：`LineageOS/android_kernel_oneplus_sm8250` · `lineage-23.2` · `0970a5d23405622c10bc4ff60ef0ba30499611e1`
- 版本串：`4.19.325-cip128-st12-perf-g0970a5d23405`（与 ROM 自带内核一致）
- KernelSU-Next：`v3.4.0-legacy`，`CONFIG_KSU=y`，hook = Kprobes，非 GKI
- 工具链：AOSP clang-r487747c（clang 17.0.2）
- defconfig：`vendor/kona-perf_defconfig` + `debugfs.config` + `oplus.config`

## 已知限制

- **SUSFS 未集成**：4.19 + KernelSU-Next legacy 缺少 SUSFS supercall 通道；
  ReSukiSU 侧的移植尚不完整。当前隐藏能力见 `docs/HIDING.md`。
- 版本强绑定：换 ROM build 必须重编内核（版本串要对齐）。
- Manager 必须 33294 版本，否则 App Profile 会保存失败。

## 校验建议

```powershell
adb shell uname -a                     # 应含 4.19.325-cip128-st12-perf-g0970a5d23405
adb shell su -c id                     # uid=0(root)
adb shell /data/adb/ksud -V
```
