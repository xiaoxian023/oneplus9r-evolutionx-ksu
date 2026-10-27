# 从源码编译

## 前置

- Linux 或 WSL2 Ubuntu 22.04+，磁盘 ≥ 60 GB，内存 ≥ 8 GB
- 无需 Docker；脚本会自己下 AOSP clang（`clang-r487747c`，clang 17.0.2）
- 网络能到 `github.com`、`android.googlesource.com`

```bash
sudo apt install -y build-essential bc flex bison libssl-dev libelf-dev \
  python3 zip unzip curl git liblz4-tool device-tree-compiler gcc-aarch64-linux-gnu
```

## 一条命令

```bash
./scripts/build-kernel.sh
```

默认参数（就是本仓库验证过的组合）：

| 变量 | 默认值 |
|---|---|
| `KERNEL_REPO` | `https://github.com/LineageOS/android_kernel_oneplus_sm8250` |
| `KERNEL_BRANCH` | `lineage-23.2` |
| `KERNEL_COMMIT` | `0970a5d23405622c10bc4ff60ef0ba30499611e1` |
| `DEFCONFIG` | `vendor/kona-perf_defconfig`（+ `debugfs.config`、`oplus.config` 片段） |
| `KSU_TAG` | `v3.4.0-legacy` |
| `WITH_KSU` | `1`（设 `0` 只编基线内核，用于排障） |

产物 `out-ksu/Image`，同时打印版本串。

## 选源码树的判据（最重要的一步）

**内核版本串必须与手机 ROM 自带内核一致。**

```bash
# 从 ROM 的 boot.img（payload_dumper 抽出来的）读版本串
python3 - <<'PY'
import re
d=open('boot.img','rb').read()
print(re.search(rb'Linux version [^\x00]{0,200}', d).group(0).decode())
PY
```

手机侧对照：

```bash
adb shell uname -a
```

本机实测：

| 源码树 | 版本串 | 能否启动 |
|---|---|---|
| `Evolution-X-Devices/kernel_oneplus_sm8250` @ `bka` | `4.19.325-perf-g5d1e271a1322` | ✗ 卡 Orange State（连无 root 基线也不行） |
| `LineageOS/android_kernel_oneplus_sm8250` @ `lineage-23.2` + `0970a5d` | `4.19.325-cip128-st12-perf-g0970a5d23405` | ✓ |

`-cip128-st12` 是那条源码线的指纹，缺了它就不是同一棵树。

## 常见编译错误

| 报错 | 原因 / 处理 |
|---|---|
| `undefined reference to ksu_*` | 用了 `next` 分支的 KernelSU-Next（5.x API）；4.19 必须 `v3.4.0-legacy` |
| `linux/pgtable.h: No such file` | 同上，legacy 版本不会引用该头 |
| `-Werror` 打断 | `KCFLAGS=-Wno-error` 或换回默认工具链 |
| `kheaders_data.tar.xz Error 127` | 缺 `xz-utils` / `cpio` |
| `No hooks were defined` | 没选 hook 模式；legacy 在 4.19 上应自动选 Kprobes（`CONFIG_KSU_KPROBES_HOOK=y`） |

## 云端构建

`.github/workflows/build-kernel.yml` 支持手动触发，产物是 `Image` 与版本串日志，方便在无本地 Linux 时复现。
