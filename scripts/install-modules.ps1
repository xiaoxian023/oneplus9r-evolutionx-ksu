# install-modules.ps1 —— KernelSU-Next root 已生效后，装齐 Manager + 模块 + 隐藏配置
# 用法： .\install-modules.ps1
#        .\install-modules.ps1 -HideApps com.tencent.mm,com.eg.android.AlipayGphone
[CmdletBinding()]
param(
    [string[]]$HideApps = @('com.tencent.mm', 'com.eg.android.AlipayGphone', 'com.unionpay'),
    [switch]$SkipInstall
)
$ErrorActionPreference = 'Stop'
$pkgRoot = Split-Path $PSScriptRoot -Parent
$modDir = Join-Path $pkgRoot 'modules'
$adb = 'adb'

function Sh([string]$cmd) { (& $adb shell $cmd) 2>&1 }

Write-Host "[0/5] 前置检查" -ForegroundColor Cyan
$id = (Sh 'su -c id').Trim()
if ($id -notmatch 'uid=0') {
    Write-Host "  su 未就绪：先确认内核已带 KernelSU-Next，并手动装一次 Manager 授权" -ForegroundColor Yellow
}
Write-Host "  su → $id"

if (-not $SkipInstall) {
    Write-Host "[1/5] 安装 Manager" -ForegroundColor Cyan
    $apk = Get-ChildItem $modDir -Filter 'KernelSU_Next_*.apk' | Select-Object -First 1
    if ($apk) { & $adb install -r $apk.FullName; } else { Write-Host "  包里没有 Manager apk" -ForegroundColor Yellow }

    Write-Host "[2/5] 推送模块" -ForegroundColor Cyan
    & $adb shell mkdir -p /sdcard/Download/ksu-modules | Out-Null
    Get-ChildItem $modDir -Filter '*.zip' | ForEach-Object {
        & $adb push $_.FullName "/sdcard/Download/ksu-modules/$($_.Name)" | Out-Null
        Write-Host "  pushed $($_.Name)"
    }

    Write-Host "[3/5] ksud 安装模块（KernelSU-Next 的模块安装接口）" -ForegroundColor Cyan
    foreach ($z in (Get-ChildItem $modDir -Filter '*.zip')) {
        $remote = "/sdcard/Download/ksu-modules/$($z.Name)"
        $out = (Sh "su -c 'ksud module install $remote'").Trim()
        Write-Host "  $($z.Name) → $out"
    }
}

Write-Host "[4/5] 隐藏配置（umount）" -ForegroundColor Cyan
Write-Host "  KernelSU-Next 没有 Magisk DenyList，隐藏靠逐 App 的 umount（mount namespace 隔离）：" -ForegroundColor Gray
Write-Host "   Manager → 底部『应用』→ 找到目标 App → 打开『卸载模块 / umount』" -ForegroundColor Gray
Write-Host "  建议先开这几类：银行、支付、企业 MDM、反作弊、政府类 App" -ForegroundColor Gray
foreach ($p in $HideApps) {
    $installed = (Sh "pm list packages $p").Trim()
    if ($installed) { Write-Host "   需要开 umount: $p" } else { Write-Host "   未安装: $p" -ForegroundColor DarkGray }
}
Write-Host "  也可在 su shell 里确认内核状态：ksud -V / cat /proc/version"

Write-Host "[5/5] 验证 Play Integrity" -ForegroundColor Cyan
Write-Host "  装 Play Integrity API Checker，看 MEETS_DEVICE_INTEGRITY；"
Write-Host "  若只有 BASIC 通过：确认 Zygisk Next 已启用、PIF 模块已装并在 ksud module list 里可见"
Write-Host ""
Write-Host "  当前模块列表：" -ForegroundColor Cyan
Sh "su -c 'ksud module list'"
