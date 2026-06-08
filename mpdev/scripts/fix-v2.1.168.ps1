# mpdev v2.1.168 兼容修复 (PowerShell)
# ======================================
# 直接修 ~\.claude\plugins\cache\mpdev 缓存，不依赖 /plugin 命令。
# 修完完全重启 Claude Code 即可。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File fix-v2.1.168.ps1
#
# 或一键：
#   powershell -ExecutionPolicy Bypass -Command "iex (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/scripts/fix-v2.1.168.ps1')"

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false

Write-Host ""
Write-Host "╭──────────────────────────────────────────╮"
Write-Host "│  mpdev v2.1.168 兼容修复 (PowerShell)      │"
Write-Host "│  修 command name: 字段 + plugin.json     │"
Write-Host "╰──────────────────────────────────────────╯"
Write-Host ""

# ── 1. 找缓存目录 ──
$cacheRoot = "$env:USERPROFILE\.claude\plugins\cache\mpdev"
if (-not (Test-Path $cacheRoot)) {
    Write-Host "❌ 找不到 mpdev plugin 缓存: $cacheRoot"
    Write-Host "   请确认 mpdev plugin 已安装。"
    exit 1
}

# 找包含 plugin.json 的缓存目录
$pjList = Get-ChildItem -Path $cacheRoot -Recurse -Depth 4 -Filter "plugin.json" |
    Where-Object { $_.FullName -match '\.claude-plugin\\plugin\.json$' }
if (-not $pjList) {
    Write-Host "❌ 在缓存中找不到 plugin.json"
    exit 1
}
$cacheDir = Split-Path -Parent (Split-Path -Parent $pjList[0].FullName)
Write-Host "✔ 缓存目录: $cacheDir"
Write-Host ""

# ── 2. 修 command name: 字段 ──
$cmdsDir = Join-Path $cacheDir "commands"
if (-not (Test-Path $cmdsDir)) {
    Write-Host "❌ 找不到 commands/ 目录"
    exit 1
}

Write-Host "▶ 修复 command name: 字段..."
$fixed = 0
Get-ChildItem -Path $cmdsDir -Filter "*.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -Encoding UTF8
    $fname = $_.BaseName

    # 提取 name: 字段
    if ($content -match "name:\s*(\S+)") {
        $old = $Matches[1]
    } else {
        Write-Host "  ⚠️  $($_.Name): 无 name 字段，跳过"
        return
    }

    # 已经是 mpdev:xxx 就不动
    if ($old -match "^mpdev:") {
        Write-Host "  ✅ $($_.Name): $old (已修复)"
        return
    }

    $new = "mpdev:$old"
    $content = $content -replace "name:\s*$old", "name: $new"
    [System.IO.File]::WriteAllText($_.FullName, $content, $utf8)
    Write-Host "  🔧 $($_.Name): $old → $new"
    $fixed++
}
Write-Host "  ✔ 修复了 $fixed 个文件"
Write-Host ""

# ── 3. 修 plugin.json ──
$pjPath = Join-Path $cacheDir ".claude-plugin\plugin.json"
Write-Host "▶ 修复 plugin.json..."
$pj = Get-Content $pjPath -Raw -Encoding UTF8 | ConvertFrom-Json
$changed = $false

if ($pj.version -ne "2.1.1") {
    $pj.version = "2.1.1"
    $changed = $true
    Write-Host "  version: → 2.1.1"
}

$cmdNames = @(
    "./commands/check.md", "./commands/commit.md", "./commands/contracts.md",
    "./commands/dev.md", "./commands/env.md", "./commands/fix.md",
    "./commands/init.md", "./commands/test.md", "./commands/understand.md"
)
if (-not $pj.commands) {
    $pj | Add-Member -MemberType NoteProperty -Name "commands" -Value $cmdNames
    $changed = $true
    Write-Host "  commands: 添加了 $($cmdNames.Count) 个条目"
}

if ($changed) {
    $pj | ConvertTo-Json -Depth 3 | ForEach-Object {
        [System.IO.File]::WriteAllText($pjPath, $_ + "`n", $utf8)
    }
    Write-Host "  ✔ plugin.json 已更新"
} else {
    Write-Host "  ✅ plugin.json 无需更改"
}
Write-Host ""

# ── 4. 完成 ──
Write-Host "✅ 修复完成！"
Write-Host ""
Write-Host "现在请完全退出 Claude Code 再重新打开。"
Write-Host "输入 /mpdev: 应自动补全 9 个命令。"
Write-Host ""
