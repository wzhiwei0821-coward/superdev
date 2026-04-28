# mpdev-suite installer (PowerShell native)
# Usage:
#   iwr -useb https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/install.ps1 | iex
#   $env:MPDEV_VERSION='1.0.0'; iwr -useb .../install.ps1 | iex
#   $env:MPDEV_TARGET='./custom-claude'; iwr -useb .../install.ps1 | iex

$ErrorActionPreference = 'Stop'

# 强制 UTF-8 输出，避免 cp437/cp936 控制台把中文显示为 ???
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

# --- config (override via $env:MPDEV_*) ---
$RepoUrl = if ($env:MPDEV_REPO) { $env:MPDEV_REPO } else { 'https://github.com/wzhiwei0821-coward/superdev.git' }
$Version = if ($env:MPDEV_VERSION) { $env:MPDEV_VERSION } else { 'latest' }
$Target  = if ($env:MPDEV_TARGET)  { $env:MPDEV_TARGET }  else { './.claude' }
$Subdir  = if (Test-Path Env:MPDEV_SUBDIR) { $env:MPDEV_SUBDIR } else { 'mpdev-suite' }   # monorepo 子目录；$env:MPDEV_SUBDIR='' 可禁用

function Die  ($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }
function Info ($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Ok   ($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }

# --- preflight ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die 'git 未安装' }

if (Test-Path $Target) {
    if (Test-Path (Join-Path $Target '.mpdev-version')) {
        $cur = (Get-Content (Join-Path $Target '.mpdev-version') -Raw).Trim()
        Info "$Target 已存在 mpdev-suite v$cur — 升级请用 update.ps1"
    }
    $ans = Read-Host "$Target 已存在，覆盖？(y/N)"
    if ($ans -notmatch '^[Yy]$') { Die '已取消' }
    Remove-Item -Recurse -Force $Target
}

# --- download ---
$tmpName = "mpdev-" + [guid]::NewGuid().ToString('N').Substring(0,8)
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) $tmpName
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    Info "拉取 mpdev-suite (version=$Version)"
    $cloneArgs = @('clone', '--depth=1')
    if ($Version -ne 'latest') { $cloneArgs += @('--branch', "v$Version") }
    $cloneArgs += @($RepoUrl, (Join-Path $Tmp 'suite'))

    & git $cloneArgs
    if ($LASTEXITCODE -ne 0) {
        Die "git clone 失败（version=$Version）。可用 git ls-remote --tags $RepoUrl 列出可用版本"
    }

    # 解析套件根（支持 monorepo 子目录）
    $SuiteRoot = if ($Subdir) { Join-Path $Tmp "suite/$Subdir" } else { Join-Path $Tmp 'suite' }
    if (-not (Test-Path (Join-Path $SuiteRoot '.claude'))) {
        Die "$SuiteRoot/.claude 不存在（检查 MPDEV_SUBDIR='$Subdir'）"
    }

    $verFile = Join-Path $SuiteRoot 'VERSION'
    $ActualVersion = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { $Version }

    # --- install ---
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    Copy-Item -Path (Join-Path $SuiteRoot '.claude/*') -Destination $Target -Recurse -Force

    # 二次保险：清掉项目实例残留（仓库中本应已清空）
    $agentsDir = Join-Path $Target 'agents'
    if (Test-Path $agentsDir) {
        Get-ChildItem $agentsDir -Filter '*.md' -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    # 空目录骨架（git 不保留空目录）
    New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
    foreach ($d in @('commits','fixes','setup','test-cases','test-exports','test-plans')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Target "mpdev-runs/$d") | Out-Null
    }

    # 版本标
    Set-Content -Path (Join-Path $Target '.mpdev-version') -Value $ActualVersion -Encoding utf8 -NoNewline

    Ok "mpdev-suite v$ActualVersion 已安装到 $Target"
} finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '下一步：'
Write-Host '  /mpdev-understand                # 阶段 0a：生成各模块 CLAUDE.md'
Write-Host '  /mpdev-contracts                 # 阶段 0b：跨模块项目才需要，单模块跳过'
Write-Host '  /mpdev-init                      # 阶段 1：生成 12 个 agent'
Write-Host '  /mpdev "需求描述"                 # 阶段 2：开始日常开发'
Write-Host ''
Write-Host '文档：'
Write-Host "  $Target/README.md                顶层入口"
Write-Host "  $Target/mpdev-suite-workflow.md  详细使用手册"
Write-Host ''
Write-Host '升级：'
Write-Host '  iwr -useb .../scripts/update.ps1 | iex'
