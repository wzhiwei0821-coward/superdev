# mpdev Plugin 一键安装 (PowerShell, v2.2.0)
#
# 从 GitHub 拉取 superdev 仓库的 mpdev/ 子目录。
#
# Usage (推荐 — 强制 UTF-8 解码避免 ??? 乱码):
#   $wc=New-Object Net.WebClient; $wc.Encoding=[Text.Encoding]::UTF8
#   $s=$wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.ps1')
#   if($s[0]-eq[char]0xFEFF){$s=$s.Substring(1)}; iex $s

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

# ---- 配置 ----
$RepoUrl = 'https://github.com/wzhiwei0821-coward/superdev.git'
$Branch  = 'main'
$Subdir  = 'mpdev'
$Target  = if ($env:MPDEV_TARGET) { $env:MPDEV_TARGET } else { Join-Path $HOME 'dev/mpdev' }

# ---- 参数 ----
foreach ($a in $args) {
    switch -Regex ($a) {
        '^--target=(.+)$' { $Target = $matches[1] }
        '^--repo=(.+)$'   { $RepoUrl = $matches[1] }
        '^--branch=(.+)$' { $Branch = $matches[1] }
        '^(-h|--help)$' {
            Write-Host @"
Usage: install.ps1 [OPTIONS]

OPTIONS:
  --target=PATH   自定义安装路径（默认 ~/dev/mpdev）
  --repo=URL      覆盖 GitHub 仓库 URL
  --branch=NAME   覆盖分支（默认 main）
  -h, --help      显示此帮助

ENVIRONMENT:
  MPDEV_TARGET=PATH  等价 --target
"@
            exit 0
        }
        default { Write-Host "❌ 未知参数: $a" -ForegroundColor Red; exit 1 }
    }
}

function Die  ($m) { Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }
function Info ($m) { Write-Host "[INFO]  $m" -ForegroundColor Cyan }
function Ok   ($m) { Write-Host "[OK]    $m" -ForegroundColor Green }

# ---- 前置检查 ----
Info "前置检查"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die 'git 未安装' }

if (-not (Test-Path "$HOME/.claude")) {
    Info "未检测到 ~/.claude，请先装 Claude Code"
    $ans = Read-Host "继续？(y/N)"
    if ($ans -notmatch '^[Yy]$') { Die '已取消' }
}

$targetHasGit = (Test-Path (Join-Path $Target '.git'))
if ($targetHasGit) {
    Info "$Target 已是 git 仓，git pull 拉新..."
    Push-Location $Target
    try { & git pull --ff-only 2>&1 | Select-Object -Last 3 } finally { Pop-Location }
} elseif (Test-Path $Target) {
    Info "$Target 已存在（非 git 仓）"
    $ans = Read-Host "覆盖（清空后重 clone）/取消？(y/N)"
    if ($ans -notmatch '^[Yy]$') { Die '已取消' }
    Remove-Item -Recurse -Force $Target
}

# ---- 克隆 ----
if (-not $targetHasGit) {
    Info "克隆 $RepoUrl (branch=$Branch)"
    & git clone --depth=1 --branch $Branch --no-checkout $RepoUrl $Target
    if ($LASTEXITCODE -ne 0) { Die 'git clone 失败' }

    Push-Location $Target
    try {
        & git sparse-checkout init --cone 2>$null
        & git sparse-checkout set $Subdir
        if ($LASTEXITCODE -ne 0) { Die 'sparse checkout 失败' }
        Copy-Item -Path "$Subdir/*" -Destination . -Recurse -Force
        Remove-Item -Recurse -Force $Subdir
    } finally { Pop-Location }
}

$manifest = Join-Path $Target '.claude-plugin/plugin.json'
if (-not (Test-Path $manifest)) { Die 'plugin.json 缺失' }
Ok "$Target 就绪"

# ---- 版本 ----
$verFile = Join-Path $Target 'VERSION'
$Version = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { 'unknown' }
Info "mpdev v$Version"

# ---- 引导 ----
Write-Host ''
Write-Host '现在请打开 Claude Code，执行：'
Write-Host ''
Write-Host '  /plugin marketplace add https://github.com/wzhiwei0821-coward/superdev' -ForegroundColor Yellow
Write-Host '  /plugin install mpdev@superdev' -ForegroundColor Yellow
Write-Host ''
Write-Host '完成后完全重启 Claude Code，/mpdev: 应见 9 个命令补全。'
Write-Host ''
Write-Host "文档:    $Target/docs/quickstart.md"
Write-Host "排错:    $Target/docs/troubleshooting.md"

# ---- hooks LF 行尾保护 ----
if (Test-Path (Join-Path $Target 'hooks')) {
    foreach ($f in (Get-ChildItem -Path (Join-Path $Target 'hooks') -Filter '*.sh').FullName) {
        $content = [System.IO.File]::ReadAllText($f) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($f, $content, (New-Object System.Text.UTF8Encoding $false))
    }
}

# ---- BOM 自检 ----
Write-Host ''
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$fixed = 0
foreach ($f in (Get-ChildItem -Path $Target -Recurse -Filter '*.ps1').FullName) {
    $bytes = [System.IO.File]::ReadAllBytes($f) | Select-Object -First 3
    $hasBom = ($bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if (-not $hasBom) {
        $content = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($f, $content, $utf8Bom)
        $fixed++
    }
}
if ($fixed -gt 0) {
    Write-Host "⚠️ 补充了 $fixed 个 .ps1 文件的 UTF-8 BOM" -ForegroundColor Yellow
} else {
    Write-Host '✅ 所有 .ps1 文件 BOM 完整' -ForegroundColor Green
}
