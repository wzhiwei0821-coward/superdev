# mpdev-suite updater (PowerShell native)
#
# Usage (推荐 — 强制 UTF-8 解码避免 ??? 乱码):
#   $wc=New-Object Net.WebClient; $wc.Encoding=[Text.Encoding]::UTF8
#   $s=$wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/update.ps1')
#   if($s[0]-eq[char]0xFEFF){$s=$s.Substring(1)}; iex $s
#
# 简化版 (可能乱码): iwr -useb .../scripts/update.ps1 | iex

$ErrorActionPreference = 'Stop'

# 强制 UTF-8 输出，避免 cp437/cp936 控制台把中文显示为 ???
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

$RepoUrl = if ($env:MPDEV_REPO) { $env:MPDEV_REPO } else { 'https://github.com/wzhiwei0821-coward/superdev.git' }
$Version = if ($env:MPDEV_VERSION) { $env:MPDEV_VERSION } else { 'latest' }
$Target  = if ($env:MPDEV_TARGET)  { $env:MPDEV_TARGET }  else { './.claude' }
$Subdir  = if (Test-Path Env:MPDEV_SUBDIR) { $env:MPDEV_SUBDIR } else { 'mpdev-suite' }   # monorepo 子目录；$env:MPDEV_SUBDIR='' 可禁用

function Die  ($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }
function Info ($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Ok   ($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }

function FilesSame($a, $b) {
    if (-not ((Test-Path $a) -and (Test-Path $b))) { return $false }
    return (Get-FileHash $a).Hash -eq (Get-FileHash $b).Hash
}

# --- preflight ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die 'git 未安装' }
if (-not (Test-Path $Target)) { Die "$Target 不存在 — 请先用 install.ps1 安装" }

$verFile = Join-Path $Target '.mpdev-version'
$CurVersion = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { 'unknown' }
Info "当前版本: $CurVersion -> 目标版本: $Version"

# --- backup ---
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = "$Target.bak.$ts"
Copy-Item -Path $Target -Destination $Backup -Recurse -Force
Ok "已备份到 $Backup"

# --- download new version ---
$tmpName = "mpdev-" + [guid]::NewGuid().ToString('N').Substring(0,8)
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) $tmpName
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    Info "拉取新版本"
    $cloneArgs = @('clone', '--depth=1')
    if ($Version -ne 'latest') { $cloneArgs += @('--branch', "v$Version") }
    $cloneArgs += @($RepoUrl, (Join-Path $Tmp 'suite'))

    & git $cloneArgs
    if ($LASTEXITCODE -ne 0) { Die "git clone 失败（version=$Version）" }

    # 解析套件根（支持 monorepo 子目录）
    $SuiteRoot = if ($Subdir) { Join-Path $Tmp "suite/$Subdir" } else { Join-Path $Tmp 'suite' }
    $ClaudeRoot = Join-Path $SuiteRoot '.claude'
    if (-not (Test-Path $ClaudeRoot)) { Die "$ClaudeRoot 不存在（检查 MPDEV_SUBDIR='$Subdir'）" }

    $newVerFile = Join-Path $SuiteRoot 'VERSION'
    $NewVersion = if (Test-Path $newVerFile) { (Get-Content $newVerFile -Raw).Trim() } else { $Version }

    # --- 覆盖框架文件（项目无关） ---
    Info "更新框架文件"
    Copy-Item -Path (Join-Path $ClaudeRoot 'commands/*') -Destination (Join-Path $Target 'commands') -Recurse -Force
    Copy-Item -Path (Join-Path $ClaudeRoot 'templates/*.tmpl') -Destination (Join-Path $Target 'templates') -Force
    Copy-Item -Path (Join-Path $ClaudeRoot 'templates/understand/*') -Destination (Join-Path $Target 'templates/understand') -Recurse -Force
    Copy-Item -Path (Join-Path $ClaudeRoot 'MPDev-Scheme.md') -Destination $Target -Force
    Copy-Item -Path (Join-Path $ClaudeRoot 'mpdev-suite-workflow.md') -Destination $Target -Force
    Copy-Item -Path (Join-Path $ClaudeRoot 'README.md') -Destination $Target -Force

    # --- dialects / test-flavors：三方合并 ---
    # 规则: new == bak (框架没改) → 保留用户版
    #       new != bak, user == bak (用户没改) → 覆盖
    #       new != bak, user != bak (双方都改) → 用户版保留 + 新版存 .new
    Info "合并 dialects/ 和 test-flavors/（自定义文件保留）"
    foreach ($d in @('dialects','test-flavors')) {
        $newDir = Join-Path $ClaudeRoot "templates/$d"
        $tgtDir = Join-Path $Target "templates/$d"
        $bakDir = Join-Path $Backup "templates/$d"
        if (-not (Test-Path $newDir)) { continue }

        Get-ChildItem -Path $newDir -Filter '*.md' | ForEach-Object {
            $name = $_.Name
            $newF = $_.FullName
            $tgtF = Join-Path $tgtDir $name
            $bakF = Join-Path $bakDir $name

            if (-not (Test-Path $tgtF)) {
                Copy-Item -Path $newF -Destination $tgtF -Force
                Info "  + 新增 $d/$name"
                return
            }

            $frameworkChanged = -not (FilesSame $newF $bakF)
            if (-not $frameworkChanged) { return }   # 框架没动这个文件，跳过

            $userChanged = -not (FilesSame $tgtF $bakF)
            if ($userChanged) {
                Info "  $d/$name 用户已改 — 新版保存为 $name.new（手工合并）"
                Copy-Item -Path $newF -Destination "$tgtF.new" -Force
            } else {
                Copy-Item -Path $newF -Destination $tgtF -Force
            }
        }
    }

    # --- 保留项不动：agents/ 和 mpdev-runs/ ---
    Set-Content -Path $verFile -Value $NewVersion -Encoding utf8 -NoNewline

    Ok "升级完成: $CurVersion -> $NewVersion"
} finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '后续：'
Write-Host "  Get-ChildItem $Target -Recurse -Filter '*.new'   # 查看待手工合并的文件"
Write-Host "  Remove-Item -Recurse -Force $Backup              # 确认无误后删除备份"
Write-Host ''
Write-Host '回滚：'
Write-Host "  Remove-Item -Recurse -Force $Target; Move-Item $Backup $Target"
