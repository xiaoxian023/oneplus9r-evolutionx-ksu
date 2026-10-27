# 故障排查（全部来自真机实测）

## 1. 卡在 "Orange State ... will boot in 5 seconds" 不动

这是 bootloader 的画面，说明**内核在真正接管显示之前就挂了**。按顺序排除：

```powershell
# a) 先用原版 boot.img 恢复
fastboot flash boot stock_boot_A16_11.6.2.img

# b) 用无 root 的基线内核验证源码树是否正确
fastboot boot boot_base_lin.img
```

| 基线内核结果 | 结论 |
|---|---|
| 能进系统 | 源码树正确，问题在 root 注入 → 换 KernelSU-Next `v3.4.0-legacy` 重编 |
| 也卡住 | 源码树错误 → 对照 `docs/BUILD.md` 的"选源码树的判据"（版本串必须一致） |

实测：`Evolution-X-Devices/kernel_oneplus_sm8250@bka` 编出来的内核对 11.6.2 起不来，
`LineageOS/android_kernel_oneplus_sm8250@lineage-23.2@0970a5d` 才行。

## 2. `fastboot flash` 报 `Volume Full`

```
boot_a partition size: 100663296
boot_a image size:     101707776      ← 超了 1 MB
Writing 'boot_a' FAILED (remote: 'Error flashing partition : Volume Full')
```

原因：`payload.bin` 里的 boot 是**整分区镜像**（96 MiB），尾部是填充 + AVB footer；
原样搬运再加一个略大的内核就越界。

修法：

```powershell
python .\scripts\repack-bootimg.py --boot boot.img --kernel Image --out boot_ksu.img
```

默认只写 `header + kernel + ramdisk + dtb`，成品约 55 MB。

## 3. Manager 报 `Failed to update App Profile`

内核里编的是 **33294（v3.4.0）**，Manager 却是 3.4.2 → supercall 命令集不一致。
换用 **`KernelSU_Next_v3.4.0_33294-release.apk`** 即可。

## 4. `su` 拿到 root 但模块装不上

```powershell
adb shell su -c 'ksud module list'
adb shell su -c 'ls -l /data/adb/ksu'
adb logcat -d | findstr /i "ksu profile"
```

- `/data/adb/ksu` 无 `ksu.db`：ksud 首次没跑起来，重装 Manager 并允许一次 root
- logcat 出现 `avc: denied`：SELinux 策略问题，需要在内核补 rules

## 5. 绿色竖线出现在开机第一屏

那是 bootloader 阶段（内核还没接管显示），与镜像无关。刷回原版仍在 ⇒ 屏幕/排线问题。

## 6. 刷完能开机但 WiFi / 指纹 / 摄像头失效

内核与 ROM build 不匹配的典型症状（源码树对、commit 不对也会这样）。
核对版本串，必要时用 ROM 对应 commit 重编。

## 7. `fastboot devices` 看不到手机

- 换主板后置 USB 口、换线（数据线不是充电线）
- `adb kill-server` 后重试
- Windows 设备管理器里看是否有未知设备 → 装 Google USB Driver
- 仍不行：进入 EDL（音量上下 + 电源长按），用 MSM 工具恢复
