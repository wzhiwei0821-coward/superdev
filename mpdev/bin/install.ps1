# mpdev Plugin 一键安装 (PowerShell, v2.1.1+)
#
# 默认从公司 GitLab 内网装 (SSH)；--source=github 切公网。
# Windows 用户跑 GitLab 源前先 ssh -T git@10.173.28.211 接受指纹。
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

# ---- Source 配置 ----
$SourceGitlabUrl    = 'git@10.173.28.211:robot-ai/mppm/mpdev.git'
$SourceGitlabBranch = 'master'
$SourceGitlabSubdir = ''

$SourceGithubUrl    = 'https://github.com/wzhiwei0821-coward/superdev.git'
$SourceGithubBranch = 'main'
$SourceGithubSubdir = 'mpdev'

$SourceType = if ($env:MPDEV_SOURCE) { $env:MPDEV_SOURCE } else { 'gitlab' }
$Target     = if ($env:MPDEV_TARGET) { $env:MPDEV_TARGET } else { Join-Path $HOME 'dev/mpdev' }
$RepoOverride = $null
$BranchOverride = $null
$SubdirOverride = $null

# ---- 参数 ----
foreach ($a in $args) {
    switch -Regex ($a) {
        '^--source=gitlab$' { $SourceType = 'gitlab' }
        '^--source=github$' { $SourceType = 'github' }
        '^--target=(.+)$'   { $Target = $matches[1] }
        '^--repo=(.+)$'     { $RepoOverride = $matches[1] }
        '^--branch=(.+)$'   { $BranchOverride = $matches[1] }
        '^--subdir=(.+)$'   { $SubdirOverride = $matches[1] }
        '^(-h|--help)$' {
            Write-Host @"
Usage: install.ps1 [OPTIONS]

OPTIONS:
  --source=gitlab     (默认) 从公司 GitLab 装 (SSH，Windows 走 Git Bash)
  --source=github     从 GitHub 公网装 (HTTPS)
  --target=PATH       自定义本地 clone 路径
  --repo=URL          覆盖 clone URL
  --branch=NAME       覆盖分支
  --subdir=PATH       覆盖子目录

ENVIRONMENT:
  MPDEV_SOURCE=gitlab|github
  MPDEV_TARGET=PATH
"@
            exit 0
        }
        default { Write-Host "❌ 未知参数: $a" -ForegroundColor Red; exit 1 }
    }
}

# 选 URL/branch/subdir
switch ($SourceType) {
    'gitlab' {
        $RepoUrl = if ($RepoOverride) { $RepoOverride } else { $SourceGitlabUrl }
        $Branch  = if ($BranchOverride) { $BranchOverride } else { $SourceGitlabBranch }
        $Subdir  = if ($null -ne $SubdirOverride) { $SubdirOverride } else { $SourceGitlabSubdir }
    }
    'github' {
        $RepoUrl = if ($RepoOverride) { $RepoOverride } else { $SourceGithubUrl }
        $Branch  = if ($BranchOverride) { $BranchOverride } else { $SourceGithubBranch }
        $Subdir  = if ($null -ne $SubdirOverride) { $SubdirOverride } else { $SourceGithubSubdir }
    }
    default {
        Write-Host "❌ 未知 source: $SourceType (合法: gitlab / github)" -ForegroundColor Red
        exit 1
    }
}

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

# 提示 GitLab 用户先接受 SSH 主机指纹
if ($SourceType -eq 'gitlab') {
    Info "GitLab 源需要 SSH 鉴权。Windows 请先在 Git Bash 跑: ssh -T git@10.173.28.211"
    Info "若 SSH 未配，安装会失败。"
}

# clone
Info "克隆 source=$SourceType branch=$Branch"
$tmpName = 'mpdev-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) $tmpName
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    & git clone --depth=1 --branch $Branch $RepoUrl (Join-Path $Tmp 'repo')
    if ($LASTEXITCODE -ne 0) { Die 'git clone 失败' }

    $SuiteRoot = if ($Subdir) { Join-Path $Tmp "repo/$Subdir" } else { Join-Path $Tmp 'repo' }
    if (-not (Test-Path $SuiteRoot)) { Die "$SuiteRoot 不存在" }

    New-Item -ItemType Directory -Force -Path (Split-Path $Target -Parent) | Out-Null
    if ($Subdir) {
        Copy-Item -Path $SuiteRoot -Destination $Target -Recurse -Force
    } else {
        # 仓根即 plugin：拷内容
        New-Item -ItemType Directory -Force -Path $Target | Out-Null
        Copy-Item -Path (Join-Path $SuiteRoot '*') -Destination $Target -Recurse -Force
    }

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

# hooks .sh 文件 LF 行尾保护（v2.1.0+）
if (Test-Path (Join-Path $Target 'hooks')) {
    foreach ($f in (Get-ChildItem -Path (Join-Path $Target 'hooks') -Filter '*.sh').FullName) {
        $content = [System.IO.File]::ReadAllText($f) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($f, $content, (New-Object System.Text.UTF8Encoding $false))
    }
}

# BOM 自检（v2.0.1+）
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
    Write-Host "⚠️ 补充了 $fixed 个 .ps1 文件的 UTF-8 BOM（可能源仓未加 BOM）" -ForegroundColor Yellow
} else {
    Write-Host '✅ 所有 .ps1 文件 BOM 完整' -ForegroundColor Green
}
