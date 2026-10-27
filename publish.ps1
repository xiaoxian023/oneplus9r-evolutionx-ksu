# publish.ps1 —— 把本仓库发布到 GitHub，并创建 Release 上传二进制附件
# 依赖：git、GitHub CLI（gh，已 `gh auth login`）
#
# 用法：
#   .\publish.ps1 -Repo "yourname/oneplus9r-evolutionx-ksu"
#
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [string]$Tag = 'v1.0.0',
    [string]$ArtifactDir = 'F:\TEST\ksu-next-lemonades\pkg\kernel-a16',
    [string]$ManagerApk = 'F:\TEST\ksu-next-lemonades\pkg\modules\KernelSU_Next_v3.4.0_33294-release.apk',
    [string]$StockImg = 'F:\TEST\ksu-next-lemonades\dist\recovery\stock_boot_A16_11.6.2.img',
    [switch]$SkipPush
)
$ErrorActionPreference = 'Stop'
foreach ($t in 'git', 'gh') { if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "缺 $t" } }

function Step($n, $msg) { Write-Host "[$n] $msg" -ForegroundColor Cyan }

Step 1 '初始化仓库'
if (-not (Test-Path '.git')) {
    git init -b main | Out-Null
}
git add -A
git -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" commit -m "OnePlus 9R + Evolution X 16: KernelSU-Next root (v1.0.0)" 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host '  没有新改动可提交，继续' -ForegroundColor DarkGray }

Step 2 "创建/关联远端 $Repo"
$remote = git remote 2>$null
if (-not ($remote -contains 'origin')) {
    gh repo create $Repo --public --source=. --remote=origin --description "KernelSU-Next root for OnePlus 9R on Evolution X 16 (kernel matched to ROM build)" 2>$null
    if ($LASTEXITCODE -ne 0) { git remote add origin "https://github.com/$Repo.git" }
}

if (-not $SkipPush) {
    Step 3 '推送 main'
    git push -u origin main
}

Step 4 "创建 Release $Tag 并上传附件"
$assets = @()
if (Test-Path "$ArtifactDir\boot_ksu_lin.img")   { $assets += "$ArtifactDir\boot_ksu_lin.img" }
if (Test-Path "$ArtifactDir\boot_base_lin.img")  { $assets += "$ArtifactDir\boot_base_lin.img" }
if (Test-Path $StockImg)                          { $assets += $StockImg }
if (Test-Path $ManagerApk)                        { $assets += $ManagerApk }
if ($assets.Count -eq 0) { throw "找不到任何附件，检查 -ArtifactDir / -ManagerApk / -StockImg" }

gh release create $Tag --title "v1.0.0 · OnePlus 9R · Evolution X 16 · KernelSU-Next" `
    --notes-file releases/RELEASE_NOTES_v1.0.0.md @assets

Step 5 '完成'
Write-Host "仓库: https://github.com/$Repo" -ForegroundColor Green
Write-Host "Release: https://github.com/$Repo/releases/tag/$Tag" -ForegroundColor Green
Write-Host '提醒：附件是二进制（img/apk），不要 git add 进仓库；本仓库 .gitignore 已排除 *.img' -ForegroundColor Yellow
