# v1.x → v2.0.0 项目迁移脚本 (PowerShell)
#
# 在 v1 项目根跑。备份 .claude/ → 删 plugin 接管的文件 → 保留项目数据

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

# ---- 参数 ----
$AutoClean = $false
foreach ($a in $args) {
    switch ($a) {
        '--auto-clean-framework-agents' { $AutoClean = $true }
        '-h' { Write-Host "Usage: migrate-from-v1.ps1 [--auto-clean-framework-agents]`n`n参数:`n  --auto-clean-framework-agents  额外删除 4 个框架 agent，让 plugin 接管。`n                                  默认不删（保护项目自定义）。"; exit 0 }
        '--help' { Write-Host "Usage: migrate-from-v1.ps1 [--auto-clean-framework-agents]`n`n参数:`n  --auto-clean-framework-agents  额外删除 4 个框架 agent，让 plugin 接管。`n                                  默认不删（保护项目自定义）。"; exit 0 }
        default { Write-Host "❌ 未知参数: $a" -ForegroundColor Red; exit 1 }
    }
}

if (-not (Test-Path '.claude')) {
    Write-Host "[ERROR] 当前目录无 .claude/，不像 v1 项目" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path '.claude/.mpdev-version')) {
    Write-Host "[WARN] 未检测到 .mpdev-version。可能已是 v2 或非 mpdev 项目。" -ForegroundColor Yellow
    $ans = Read-Host "继续？(y/N)"
    if ($ans -notmatch '^[Yy]$') { exit 2 }
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = ".claude.v1-backup.$ts"

Write-Host "▶ Step 1/3: 备份 .claude/ → $Backup" -ForegroundColor Cyan
Copy-Item -Path '.claude' -Destination $Backup -Recurse -Force
Write-Host "  ✅ 备份完成" -ForegroundColor Green

Write-Host ''
Write-Host '▶ Step 2/3: 删除 plugin 接管的文件' -ForegroundColor Cyan

if (Test-Path '.claude/commands') {
    Remove-Item -Recurse -Force '.claude/commands'
    Write-Host '  - .claude/commands/ (plugin 接管)'
}
if (Test-Path '.claude/templates') {
    Remove-Item -Recurse -Force '.claude/templates'
    Write-Host '  - .claude/templates/ (plugin 接管)'
}
foreach ($f in @('MPDev-Scheme.md','mpdev-suite-workflow.md','README.md','.mpdev-version')) {
    $p = Join-Path '.claude' $f
    if (Test-Path $p) {
        Remove-Item -Force $p
        Write-Host "  - .claude/$f (plugin 接管)"
    }
}

# 删 4 个框架 agent（仅当 --auto-clean-framework-agents）
if ($AutoClean) {
    Write-Host ''
    Write-Host '  --auto-clean-framework-agents: 移除 4 个框架 agent' -ForegroundColor Cyan
    $cleaned = 0
    foreach ($a in 'code-reviewer','integration-checker','acceptance-reviewer','doc-refresher') {
        $p = ".claude/agents/$a.md"
        if (Test-Path $p) {
            Remove-Item -Force $p
            Write-Host "  - $p (让 plugin 接管)"
            $cleaned++
        }
    }
    Write-Host "  ✅ 已清理 $cleaned 个框架 agent" -ForegroundColor Green
}

Write-Host ''
Write-Host '▶ Step 3/3: 检查保留的项目数据' -ForegroundColor Cyan
$agentCount = if (Test-Path '.claude/agents') { (Get-ChildItem '.claude/agents' -File).Count } else { 0 }
$runCount = if (Test-Path '.claude/mpdev-runs') { (Get-ChildItem '.claude/mpdev-runs' -Recurse -File).Count } else { 0 }
Write-Host "  📁 .claude/agents/        $agentCount 个 agent 文件"
Write-Host "  📁 .claude/mpdev-runs/    $runCount 个运行记录"
if (Test-Path '.claude/.mpdev-env-state.yml') { Write-Host '  📄 .claude/.mpdev-env-state.yml' }
if (Test-Path '.claude/.mpdev-runtime-creds.yml') { Write-Host '  📄 .claude/.mpdev-runtime-creds.yml' }

Write-Host ''
Write-Host '✅ 迁移完成' -ForegroundColor Green
Write-Host ''
if ($AutoClean) {
    Write-Host @"
后续:
  1. 确认 v2 plugin 已装:
     /plugin list | grep mpdev

  2. ✅ 框架 agent 已被 plugin 接管（已通过 --auto-clean-framework-agents）

  3. 完全重启 Claude Code，验证 /mpdev: 自动补全

  4. 确认无问题后可删备份:
     Remove-Item -Recurse -Force $Backup
"@
} else {
    Write-Host @"
后续:
  1. 确认 v2 plugin 已装:
     /plugin list | grep mpdev

  2. 推荐删 4 个框架 agent（让 plugin 接管最新版本）:
     Remove-Item .claude/agents/code-reviewer.md, .claude/agents/integration-checker.md, .claude/agents/acceptance-reviewer.md, .claude/agents/doc-refresher.md
     （项目特化的 *-impl.md / architect.md / 等不要删）

     💡 或下次跑 migrate 时加 --auto-clean-framework-agents flag 自动清理

  3. 完全重启 Claude Code，验证 /mpdev: 自动补全

  4. 确认无问题后可删备份:
     Remove-Item -Recurse -Force $Backup
"@
}
