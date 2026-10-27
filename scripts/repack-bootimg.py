#!/usr/bin/env python3
# repack-bootimg.py —— 把任意 boot.img 的 kernel 换成你给的内核 Image
#
# 支持 header v0/v1/v2（老 qcom）与 v3/v4（AOSP）。
# 默认输出「最小镜像」：header + kernel + ramdisk (+ second/dtb)，丢弃原镜像尾部的
# 分区对齐填充与 AVB footer —— 这正是 `fastboot flash boot` 报
# "Volume Full"（镜像比 boot 分区大）时的修法。
#
# 用法：
#   python repack-bootimg.py --boot boot.img --kernel Image --out boot_ksu.img
#   python repack-bootimg.py --boot boot.img --kernel Image --out x.img --keep-tail
import argparse
import struct
import sys

MAGIC = b"ANDROID!"


def align(n, a):
    return (n + a - 1) // a * a


def parse(buf):
    if buf[:8] != MAGIC:
        sys.exit("不是 Android boot image（magic 不匹配）")
    hv = struct.unpack_from("<I", buf, 40)[0]
    if hv in (3, 4):
        ks, rs, osv = struct.unpack_from("<III", buf, 8)
        return dict(kernel=ks, ramdisk=rs, second=0, dt=0, page=4096, hv=hv, osv=osv)
    ks, ka, rs, ra, ss, sa, tags, pg, _hv, osv = struct.unpack_from("<10I", buf, 8)
    dt = 0
    if hv in (1, 2):
        dt = struct.unpack_from("<I", buf, 1648)[0]  # dt_size (v1/v2)
    if pg not in (2048, 4096, 8192, 16384):
        pg = 4096
    return dict(kernel=ks, ramdisk=rs, second=ss, dt=dt, page=pg, hv=hv, osv=osv)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot", required=True)
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--keep-tail", action="store_true", help="保留原镜像尾部填充/AVB footer（默认丢弃）")
    a = ap.parse_args()

    src = open(a.boot, "rb").read()
    h = parse(src)
    pg = h["page"]
    off = pg
    kernel = src[off:off + h["kernel"]]
    off += align(h["kernel"], pg)
    ramdisk = src[off:off + h["ramdisk"]]
    off += align(h["ramdisk"], pg)
    second = src[off:off + h["second"]] if h["second"] else b""
    off += align(h["second"], pg)
    dt = src[off:off + h["dt"]] if h["dt"] else b""
    off += align(h["dt"], pg)

    new_k = open(a.kernel, "rb").read()
    if len(new_k) < 1024 * 1024:
        sys.exit("内核过小，检查 --kernel")

    header = bytearray(src[:pg])
    struct.pack_into("<I", header, 8, len(new_k))

    out = bytearray(header)
    out += new_k + b"\x00" * (align(len(new_k), pg) - len(new_k))
    out += ramdisk + b"\x00" * (align(len(ramdisk), pg) - len(ramdisk))
    if second:
        out += second + b"\x00" * (align(len(second), pg) - len(second))
    if dt:
        out += dt + b"\x00" * (align(len(dt), pg) - len(dt))
    if a.keep_tail:
        tail_end = len(src)
        if len(out) <= tail_end:
            out += src[len(out):]

    open(a.out, "wb").write(out)
    print(f"header    : v{h['hv']} page={pg}")
    print(f"kernel    : {h['kernel']:,} -> {len(new_k):,} bytes")
    print(f"ramdisk   : {len(ramdisk):,} bytes (原样)")
    print(f"second/dtb: {len(second):,} / {len(dt):,} bytes")
    print(f"原镜像    : {len(src):,} bytes")
    print(f"新镜像    : {len(out):,} bytes  ({'保留尾部' if a.keep_tail else '已丢弃尾部填充/AVB footer'})")


if __name__ == "__main__":
    main()
