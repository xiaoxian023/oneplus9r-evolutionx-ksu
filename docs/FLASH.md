# 刷入与回滚

## 先决条件

- bootloader 已解锁（`fastboot getvar unlocked` → `yes`），显示 Orange State 警告属正常
- 手机里装着 **同一个 build** 的 Evolution X（`adb shell getprop ro.build.version.incremental` 必须与镜像来源一致）
- 手里有原版 `boot.img`（本仓库 Release 的 `stock_boot_A16_11.6.2.img`，或自己从 ROM 包抽）

## 标准流程：先临时启动，再落盘

```powershell
adb reboot bootloader
fastboot devices              # 必须能看到设备
fastboot getvar current-slot  # 记下 a 还是 b

# 1) 临时启动（不写任何分区；失败长按电源 15s 即可恢复）
fastboot boot boot_ksu_lin.img

# 2) 起来后确认 root
adb install -r KernelSU_Next_v3.4.0_33294-release.apk
adb shell su -c id            # uid=0(root)

# 3) 落盘
adb reboot bootloader
fastboot flash boot boot_ksu_lin.img     # 不带 _a/_b，自动落到活动槽
fastboot reboot
```

> 为什么强调"不带 `_a/_b`"：如果活动槽是 `b`，而命令写成 `flash boot_a`，刷完等于没变化，表现就是"刷了没反应 / 还是老系统"。

## 校验

```powershell
adb shell uname -a
# 期望包含：4.19.325-cip128-st12-perf-g0970a5d23405

adb shell su -c id
adb shell /data/adb/ksud -V
```

Manager 首页应显示 **版本 33294**、工作模式 **KernelSU（非 GKI）**。

## 回滚

```powershell
adb reboot bootloader
fastboot flash boot stock_boot_A16_11.6.2.img
fastboot reboot
```

数据不受影响。若连 fastboot 都进不去（极少数），用 MSM Download Tool / OPlus flash tool 以 EDL 模式恢复整机固件。

## 常见刷入错误

| fastboot 输出 | 含义 | 处理 |
|---|---|---|
| `Volume Full` | 镜像大于 boot 分区（96 MiB = 100,663,296 B） | 用 `scripts/repack-bootimg.py` 重新打包（默认丢弃尾部填充与 AVB footer） |
| `skip copying boot_a image avb footer` | fastboot 会按分区补齐，属正常提示 | 无需处理 |
| `FAILED (remote: 'Flashing is not allowed')` | bootloader 未解锁 | 先解锁（会清数据） |
| 卡在 Orange State 不动 | 内核与 ROM 不匹配（源码树错）或 boot.img 结构错 | 先 `fastboot boot stock_boot_A16_11.6.2.img` 恢复，再按 `docs/BUILD.md` 选对源码树 |
