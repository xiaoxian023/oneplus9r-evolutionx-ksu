# KernelSU-Next 在 OnePlus 9R（Android 16）上的隐藏分层说明

## 一句话结论

**能内置，但要分清"哪一层"**。内核里已经带了 KSU-Next 自己的隐藏机制；SUSFS 那种
"内核级文件系统伪装"在 4.19 + KSU-Next legacy 这套组合上不是开关，而是移植工程。
真正决定你过不过得了检测的，绝大部分在用户态。

## 三层结构

### 第 1 层：内核里已经有的（本 img 自带，无需额外操作）

| 机制 | 在内核哪里 | 作用 |
|---|---|---|
| `kernel_umount` | `feature/kernel_umount.c` | 非 root 进程看不到 KSU 模块的 overlay 挂载点，`/proc/mounts`、`/proc/self/mountinfo` 干净 |
| `selinux_hide` | `feature/selinux_hide.c` | 对 su 相关路径的 SELinux 查询伪装，避免 `u:r:magisk:s0` 一类上下文暴露 |
| `module_blacklist` | `feature/module_blacklist.c` | 拦截特定模块加载请求（部分检测会尝试加载自家 .ko 做探针） |
| `sulog` | `sulog/` | 记录 su 调用（审计用，不影响隐藏） |
| hook mode = Kprobes | `CONFIG_KSU_KPROBES_HOOK=y` | 不修改 syscall table，`/proc/kallsyms` 里没有 sys_call_table 改写痕迹 |

验证（刷完后在设备上跑）：

```bash
adb shell su -c 'cat /proc/mounts | grep -i -E "ksu|susfs|overlay"'   # 非 root 上下文应为空
adb shell 'cat /proc/mounts | grep -i ksu'                            # 普通 shell 必须为空
adb shell 'ls -l /proc/self/ns/mnt'                                   # 命名空间正常
```

### 第 2 层：用户态栈（必须装，决定 Play Integrity / 银行 App）

```
Zygisk Next 1.5.2      → KSU 没有内建 Zygisk
PlayIntegrityFix 4.9   → MEETS_DEVICE_INTEGRITY
Tricky Store           → 只有需要 STRONG_INTEGRITY 时
LSPosed                → 按需
Manager 逐 App 的「卸载模块(umount)」→ 对银行/支付/反作弊逐个开
```

顺序：Zygisk Next → PIF →（其余）。`ksud module list` 能看到三个即生效。

### 第 3 层：SUSFS（内核级伪装，当前 img 未含）

SUSFS 能做而上面两层做不到的：

- 按路径把文件/目录从 `readdir`、`stat`、`open` 层面"擦掉"（不只是挂载点）
- `stat` 结果伪造（大小/时间/inode）
- 隐藏 su 二进制本体、`/data/adb/ksu` 目录项
- kallsyms 符号隐藏、uname/props 级别的补丁
- unicode 混淆路径（防扫描器枚举）

为什么没烤进这个 img：

1. SUSFS 的 4.19 内核补丁（`susfs4ksu` 的 `kernel-4.19` 分支）能打上，缺 1 个 hunk 需要手工对；
2. 更关键的是 **KSU-Next legacy 没有 SUSFS 的 supercall 通道**（`drivers/kernelsu/susfs/` 只存在于 `next` 分支，
   而 `next` 在 4.19 上编不过：`linux/pgtable.h`、`strncpy_from_user_nofault`、`f_op->iopoll/remap_file_range` 全是 5.x API）；
3. 所以要么把 KSU-Next 的 susfs 支持移植进 legacy（改 supercall dispatch + ioctl），要么换回 tiann/KernelSU +
   `10_enable_susfs_for_ksu.patch`。两条都不是"钩个选项重编"的量级。

要做的话，路线是：

```
susfs kernel-4.19 patch（修 1 个 hunk） → 拷 fs/susfs.c、fs/sus_su.c、include/linux/susfs*.h
→ 手工接 KSU-Next legacy 的 supercall（新增 SUSFS_CMD 分支）→ 重编 → repack boot.img
→ 装 sidex15/susfs4ksu-module（提供 ksu_susfs 用户态工具）
```

## 现在这套配置能过什么

| 检测类型 | 结果 |
|---|---|
| Play Integrity BASIC / DEVICE | PIF + Zygisk Next 后通过 |
| Play Integrity STRONG | 需要 Tricky Store + 有效 keybox |
| 普通 root 检测（检查 su 路径、mount、build tags） | umount + selinux_hide 后多数通过 |
| 深度检测（扫描 `/data/adb` 目录项、inode 比对、kallsyms 枚举） | 只有 SUSFS 能扛，当前 img 不保证 |
| 反作弊内核态检测（内存扫描、hook 检测） | 与 root 隐藏无关，属另一维度 |

## 注意

- 内置隐藏不等于"检测不到"：检测方永远在更新，用户态栈（PIF/Tricky Store）需要跟版本走。
- 解锁 bootloader 这件事本身不可隐藏（设备状态在 bootloader 层），部分金融 App 就卡这一条。
