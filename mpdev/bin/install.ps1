# mpdev v2.0.0 Plugin 一键安装 (PowerShell)
#
# Usage:
#   $wc=New-Object Net.WebClient; $wc.Encoding=[Text.Encoding]::UTF8
#   $s=$wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.ps1')
#   if($s[0]-eq[char]0xFEFF){$s=$s.Substring(1)}; iex $s

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$RepoUrl = if ($env:MPDEV_REPO) { $env:MPDEV_REPO } else { 'https://github.com/wzhiwei0821-coward/superdev.git' }
$Subdir  = if ($env:MPDEV_SUBDIR) { $env:MPDEV_SUBDIR } else { 'mpdev' }
$Target  = if ($env:MPDEV_TARGET) { $env:MPDEV_TARGET } else { Join-Path $HOME 'dev/mpdev' }

function Die  ($m) { Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }
function Info ($m) { Write-Host "[INFO]  $m" -ForegroundColor Cyan }
function Ok   ($m) { Write-Host "[OK]    $m" -ForegroundColor Green }

# preflight
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die 'git 未安装' }

if (-not (Test-Path "$HOME/.claude")) {
    Info "未检测到 ~/.claude，请先装 Claude Code"
    $ans = Read-Host "继续？(y/N)"
    if ($ans -notmatch '^[Yy]$') { Die '已取消' }
}

if (Test-Path $Target) {
    Info "$Target 已存在"
    $ans = Read-Host "覆盖（git pull）/取消？(y/N)"
    if ($ans -match '^[Yy]$') { Push-Location $Target; & git pull; Pop-Location }
    else { Die '已取消' }
}

# clone
Info '克隆 superdev 仓库'
$tmpName = 'mpdev-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) $tmpName
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    & git clone --depth=1 $RepoUrl (Join-Path $Tmp 'superdev')
    if ($LASTEXITCODE -ne 0) { Die 'git clone 失败' }

    $SuiteRoot = Join-Path $Tmp "superdev/$Subdir"
    if (-not (Test-Path $SuiteRoot)) { Die "$SuiteRoot 不存在" }

    New-Item -ItemType Directory -Force -Path (Split-Path $Target -Parent) | Out-Null
    Copy-Item -Path $SuiteRoot -Destination $Target -Recurse -Force

    $manifest = Join-Path $Target '.claude-plugin/marketplace.json'
    if (-not (Test-Path $manifest)) { Die 'marketplace.json 缺失' }
    Ok "$Target 就绪"

    $verFile = Join-Path $Target 'VERSION'
    $Version = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { 'unknown' }
    Info "mpdev v$Version"
} finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

# 引导
Write-Host ''
Write-Host '现在请打开 Claude Code，按顺序输入：'
Write-Host ''
Write-Host "  /plugin marketplace add file://$Target" -ForegroundColor Yellow
Write-Host '  /plugin install mpdev@mpdev' -ForegroundColor Yellow
Write-Host ''
Write-Host '完成后完全重启 Claude Code，/mpdev: 应见 9 个命令补全。'
Write-Host ''
Write-Host "文档:    $Target/docs/quickstart.md"
Write-Host "升级:    $Target/docs/upgrade-guide.md"
Write-Host "排错:    $Target/docs/troubleshooting.md"
