# flash-bootimg.ps1 —— 已编好 boot_ksu.img 时使用（fastboot 路线）
# 用法： .\flash-bootimg.ps1 -BootKsu .\boot_ksu.img -StockBoot .\boot.img
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BootKsu,
    [string]$StockBoot = '',
    [switch]$TempBootOnly
)
$ErrorActionPreference = 'Stop'
foreach ($t in 'adb', 'fastboot') {
    if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "缺 $t，用 tools\platform-tools 里的 adb/fastboot（已随包）" }
}
if (-not (Test-Path $BootKsu)) { throw "找不到 $BootKsu" }
$BootKsu = (Resolve-Path $BootKsu).Path

Write-Host "[1/5] 设备检查" -ForegroundColor Cyan
$dev = adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' }
if (-not $dev) { throw "adb 看不到设备" }
Write-Host ("  {0}" -f (adb shell getprop ro.product.device).Trim())
Write-Host ("  {0}" -f (adb shell getprop ro.build.fingerprint).Trim())

Write-Host "[2/5] bootloader" -ForegroundColor Cyan
adb reboot bootloader | Out-Null
fastboot wait-for-device | Out-Null
Start-Sleep 2
fastboot getvar current-slot 2>&1 | Select-String 'current-slot' | ForEach-Object { Write-Host "  $($_.Line.Trim())" }

Write-Host "[3/5] 临时启动（不写分区）" -ForegroundColor Cyan
fastboot boot $BootKsu
$deadline = (Get-Date).AddSeconds(180)
do { Start-Sleep 3; $s = (adb get-state 2>$null) } while ($s -ne 'device' -and (Get-Date) -lt $deadline)
if ($s -ne 'device') { throw "临时启动失败：boot.img 与 ROM build 不匹配。fastboot reboot 后重编。" }
Start-Sleep 8

if ($TempBootOnly) { Write-Host "仅临时启动，未落盘" -ForegroundColor Yellow; return }

Write-Host "[4/5] 落盘" -ForegroundColor Cyan
adb reboot bootloader | Out-Null
fastboot wait-for-device | Out-Null
Start-Sleep 2
fastboot flash boot $BootKsu
fastboot reboot | Out-Null

Write-Host "[5/5] 验证" -ForegroundColor Cyan
Start-Sleep 20
$deadline = (Get-Date).AddSeconds(240)
do { Start-Sleep 3; $s = (adb get-state 2>$null) } while ($s -ne 'device' -and (Get-Date) -lt $deadline)
if ($s -ne 'device') { throw "起不来 → fastboot flash boot <原版 boot.img>" }
Start-Sleep 8
Write-Host "  su: $((adb shell 'su -c id' 2>&1).Trim())"
if ($StockBoot) { Write-Host "  救砖：fastboot flash boot `"$((Resolve-Path $StockBoot).Path)`"" -ForegroundColor Yellow }
