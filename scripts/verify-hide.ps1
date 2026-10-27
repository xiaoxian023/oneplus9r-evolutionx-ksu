# verify-hide.ps1 —— 刷完 boot_ksu_A16.img 后，逐项检查隐藏是否真的生效
# 用法： .\hide\verify-hide.ps1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Continue'
function Sh([string]$c) { (& adb shell $c) 2>&1 }

Write-Host "[1] 设备与内核" -ForegroundColor Cyan
Write-Host ("  device: " + (Sh 'getprop ro.product.device').Trim())
Write-Host ("  uname : " + (Sh 'uname -a').Trim())
Write-Host ("  build : " + (Sh 'getprop ro.build.display.id').Trim())

Write-Host "[2] root 是否生效" -ForegroundColor Cyan
Write-Host ("  su -c id : " + (Sh 'su -c id').Trim())
Write-Host ("  ksud -V  : " + (Sh '/data/adb/ksud -V').Trim())

Write-Host "[3] 内核侧隐藏：非 root 上下文不应看到 ksu 挂载" -ForegroundColor Cyan
$m1 = Sh 'cat /proc/mounts | grep -i -E "ksu|susfs|KSU"'
if ($m1.Trim()) { Write-Warning ("  普通 shell 看到挂载（异常）: " + ($m1 -join ' ')) } else { Write-Host "  /proc/mounts 干净 ✓" -ForegroundColor Green }
$m2 = Sh 'su -c "cat /proc/mounts | grep -i -E \"ksu|susfs|overlay\""'
Write-Host ("  root 上下文（对照，正常应能看到）: " + (($m2 | Select-Object -First 3) -join ' | '))

Write-Host "[4] SELinux 与调试状态" -ForegroundColor Cyan
Write-Host ("  getenforce      : " + (Sh 'getenforce').Trim())
Write-Host ("  ro.debuggable   : " + (Sh 'getprop ro.debuggable').Trim())
Write-Host ("  ro.secure       : " + (Sh 'getprop ro.secure').Trim())
Write-Host ("  init.svc.adbd   : " + (Sh 'getprop init.svc.adbd').Trim())

Write-Host "[5] 模块栈" -ForegroundColor Cyan
$mods = Sh 'su -c "ksud module list"'
$mods | ForEach-Object { Write-Host "  $_" }
foreach ($need in 'zygisksu', 'playintegrityfix', 'lsposed') {
    $hit = ($mods -join "`n") -match [regex]::Escape($need)
    if ($hit) { Write-Host "  $need ✓" -ForegroundColor Green } else { Write-Warning "  $need 未安装或未启用" }
}

Write-Host "[6] Zygisk 与 PIF 生效判断" -ForegroundColor Cyan
$z = Sh 'su -c "ls /data/adb/modules/zygisksu 2>/dev/null"'
if ($z.Trim()) { Write-Host "  Zygisk Next 目录存在 ✓" } else { Write-Warning "  Zygisk Next 目录缺失" }
Write-Host "  下一步：装 Play Integrity API Checker 看 MEETS_DEVICE_INTEGRITY" -ForegroundColor Gray

Write-Host "[7] 待隐藏清单（Manager → 应用 → 打开『卸载模块(umount)』）" -ForegroundColor Cyan
$pkgs = @('com.tencent.mm', 'com.eg.android.AlipayGphone', 'com.unionpay', 'com.icbc', 'com.chase.sig.android')
foreach ($p in $pkgs) {
    $inst = (Sh "pm list packages $p").Trim()
    if ($inst) { Write-Host "  需 umount: $p" }
}

Write-Host ""
Write-Host "结论口径：挂载列表干净 + su 只在 root 上下文可见 + 三个模块在列 = 第 1、2 层到位；" -ForegroundColor Yellow
Write-Host "        深层检测（/data/adb 目录项、kallsyms 枚举）需要 SUSFS，见 HIDING.md。" -ForegroundColor Yellow
