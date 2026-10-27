#!/usr/bin/env bash
# build-kernel.sh —— 在 Linux / WSL2 上编译 OnePlus 9R (lemonades) 的 KernelSU-Next 内核
#
# 关键点：内核源码必须与 ROM 自带内核的版本串一致。
#   本仓库验证过的组合：
#     repo   = https://github.com/LineageOS/android_kernel_oneplus_sm8250
#     branch = lineage-23.2
#     commit = 0970a5d23405622c10bc4ff60ef0ba30499611e1
#     version= 4.19.325-cip128-st12-perf-g0970a5d23405
#
# 用法：
#   ./build-kernel.sh                 # 用上面的默认值，产物 out-ksu/Image
#   KERNEL_COMMIT=<sha> ./build-kernel.sh
#   WITH_KSU=0 ./build-kernel.sh      # 只编基线内核（排障用）
set -euo pipefail

KERNEL_REPO=${KERNEL_REPO:-https://github.com/LineageOS/android_kernel_oneplus_sm8250}
KERNEL_BRANCH=${KERNEL_BRANCH:-lineage-23.2}
KERNEL_COMMIT=${KERNEL_COMMIT:-0970a5d23405622c10bc4ff60ef0ba30499611e1}
DEFCONFIG=${DEFCONFIG:-vendor/kona-perf_defconfig}
KSU_TAG=${KSU_TAG:-v3.4.0-legacy}
WITH_KSU=${WITH_KSU:-1}
WORK=${WORK:-$PWD/work}
JOBS=${JOBS:-$(nproc)}
OUT=$PWD/out-ksu
CLANG_URL=${CLANG_URL:-https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android14-release/clang-r487747c.tar.gz}

log(){ printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die(){ printf '\n[FAIL] %s\n' "$*" >&2; exit 1; }

for t in git make curl tar file; do command -v "$t" >/dev/null || die "缺 $t"; done
mkdir -p "$WORK" "$OUT"

log "1/7 源码 $KERNEL_REPO @ $KERNEL_BRANCH ($KERNEL_COMMIT)"
if [[ -d "$WORK/kernel/.git" ]]; then
  git -C "$WORK/kernel" fetch --depth=1 origin "$KERNEL_BRANCH"
else
  git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$WORK/kernel"
fi
git -C "$WORK/kernel" fetch --depth=1 origin "$KERNEL_COMMIT" && git -C "$WORK/kernel" checkout -q FETCH_HEAD \
  || die "取不到 $KERNEL_COMMIT（换 KERNEL_COMMIT 或去掉该变量用分支 HEAD）"
git -C "$WORK/kernel" log -1 --oneline

log "2/7 工具链"
CLANG_BIN=${CLANG_DIR:-}
if [[ -z "$CLANG_BIN" ]]; then
  [[ -f "$WORK/clang.tar.gz" ]] || curl -LSs -o "$WORK/clang.tar.gz" "$CLANG_URL"
  [[ -x "$WORK/clang/bin/clang" ]] || { mkdir -p "$WORK/clang" && tar -xzf "$WORK/clang.tar.gz" -C "$WORK/clang"; }
  CLANG_BIN=$WORK/clang/bin
fi
"$CLANG_BIN/clang" --version | head -1

log "3/7 注入 KernelSU-Next ($KSU_TAG)"
cd "$WORK/kernel"
if [[ "$WITH_KSU" == "1" ]]; then
  if [[ ! -d KernelSU-Next ]]; then
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/$KSU_TAG/kernel/setup.sh" | bash -s "$KSU_TAG"
  fi
  [[ -L drivers/kernelsu ]] || die "setup.sh 未生效"
fi

log "4/7 配置（$DEFCONFIG + debugfs/oplus 片段）"
K=("$WORK/kernel")
make -C "$WORK/kernel" O=out ARCH=arm64 "$DEFCONFIG" >/dev/null
ARCH=arm64 "$WORK/kernel/scripts/kconfig/merge_config.sh" -O "$WORK/kernel/out" "$WORK/kernel/out/.config" \
  "$WORK/kernel/arch/arm64/configs/vendor/debugfs.config" \
  "$WORK/kernel/arch/arm64/configs/vendor/oplus.config" >/dev/null
if [[ "$WITH_KSU" == "1" ]]; then
  "$WORK/kernel/scripts/config" --file "$WORK/kernel/out/.config" -e KSU -e KPROBES
fi
make -C "$WORK/kernel" O=out ARCH=arm64 olddefconfig >/dev/null
grep -q '^CONFIG_KSU=y' "$WORK/kernel/out/.config" 2>/dev/null && log "KSU 已启用" || log "未启用 KSU（基线模式）"

log "5/7 编译 (-j$JOBS)"
make -C "$WORK/kernel" O=out ARCH=arm64 -j"$JOBS" \
  CC="$CLANG_BIN/clang" LD=ld.lld AR=llvm-ar NM=llvm-nm \
  OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
  CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu-

log "6/7 产物"
IMG="$WORK/kernel/out/arch/arm64/boot/Image"
[[ -f "$IMG" ]] || die "没有 Image"
cp "$IMG" "$OUT/Image"
ls -l "$OUT/Image"
python3 - <<'PY' "$OUT/Image"
import re,sys
d=open(sys.argv[1],'rb').read()
m=re.search(rb'Linux version [^\x00]{0,200}', d)
print("版本串:", m.group(0).decode("utf-8","replace") if m else "未找到")
PY

log "7/7 说明"
cat <<EOF
产物：$OUT/Image

下一步二选一：
  A. 重打包进你自己的 boot.img（需要与 ROM 同 build 的 boot.img）
     python3 scripts/repack-bootimg.py --boot boot.img --kernel $OUT/Image --out boot_ksu.img
  B. 打包成 AnyKernel3（TWRP sideload）
     git clone --depth=1 https://github.com/osm0sis/AnyKernel3 ak && cp $OUT/Image ak/kernel
     (cd ak && zip -r9 ../KSU-Next-lemonades.zip . -x '*.git*' README.md)

刷入前请先 fastboot boot 临时验证。
EOF
