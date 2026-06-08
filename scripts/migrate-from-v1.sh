#!/usr/bin/env bash
#
# v1.x → v2.0.0 项目迁移脚本
# ===========================
# 在 v1 项目根跑。备份 .claude/ → 删 plugin 接管的文件 → 保留项目数据
#

set -e

# ---- 参数 ----
AUTO_CLEAN=false
for arg in "$@"; do
  case $arg in
    --auto-clean-framework-agents) AUTO_CLEAN=true; shift ;;
    -h|--help)
      cat <<EOF
Usage: migrate-from-v1.sh [--auto-clean-framework-agents]

参数:
  --auto-clean-framework-agents  额外删除 4 个框架 agent（code-reviewer/
                                  integration-checker/acceptance-reviewer/
                                  doc-refresher），让 plugin 接管。
                                  默认不删（保护项目自定义）。
EOF
      exit 0 ;;
    *) echo "❌ 未知参数: $arg"; exit 1 ;;
  esac
done

if [ ! -d .claude ]; then
  echo "❌ 当前目录无 .claude/，不像 v1 项目"; exit 1
fi

if [ ! -f .claude/.mpdev-version ]; then
  echo "⚠️ 未检测到 .mpdev-version。可能已是 v2 或非 mpdev 项目。"
  read -p "继续？(y/N) " yn
  [[ "$yn" =~ ^[Yy]$ ]] || exit 2
fi

TS=$(date +%Y%m%d-%H%M%S)
BACKUP=".claude.v1-backup.$TS"

echo "▶ Step 1/3: 备份 .claude/ → $BACKUP"
cp -r .claude "$BACKUP"
echo "  ✅ 备份完成"

echo ""
echo "▶ Step 2/3: 删除 plugin 接管的文件"

# 删 commands/
if [ -d .claude/commands ]; then
  rm -rf .claude/commands
  echo "  - .claude/commands/ (plugin 接管)"
fi

# 删 templates/
if [ -d .claude/templates ]; then
  rm -rf .claude/templates
  echo "  - .claude/templates/ (plugin 接管)"
fi

# 删顶级 md 文件
for f in MPDev-Scheme.md mpdev-suite-workflow.md README.md .mpdev-version; do
  if [ -f ".claude/$f" ]; then
    rm -f ".claude/$f"
    echo "  - .claude/$f (plugin 接管)"
  fi
done

# 删 4 个框架 agent（仅当 --auto-clean-framework-agents）
if [ "$AUTO_CLEAN" = "true" ]; then
  echo ""
  echo "  --auto-clean-framework-agents: 移除 4 个框架 agent"
  cleaned=0
  for a in code-reviewer integration-checker acceptance-reviewer doc-refresher; do
    if [ -f ".claude/agents/$a.md" ]; then
      rm -f ".claude/agents/$a.md"
      echo "  - .claude/agents/$a.md (让 plugin 接管)"
      cleaned=$((cleaned + 1))
    fi
  done
  echo "  ✅ 已清理 $cleaned 个框架 agent"
fi

echo ""
echo "▶ Step 3/3: 检查保留的项目数据"
echo "  📁 .claude/agents/        $(ls .claude/agents 2>/dev/null | wc -l) 个 agent 文件"
echo "  📁 .claude/mpdev-runs/    $(find .claude/mpdev-runs -type f 2>/dev/null | wc -l) 个运行记录"
[ -f .claude/.mpdev-env-state.yml ] && echo "  📄 .claude/.mpdev-env-state.yml"
[ -f .claude/.mpdev-runtime-creds.yml ] && echo "  📄 .claude/.mpdev-runtime-creds.yml"

echo ""
echo "✅ 迁移完成"
echo ""
if [ "$AUTO_CLEAN" = "true" ]; then
  cat <<'EOF'
后续:
  1. 确认 v2 plugin 已装:
     /plugin list | grep mpdev

  2. ✅ 框架 agent 已被 plugin 接管（已通过 --auto-clean-framework-agents）

  3. 完全重启 Claude Code，验证 /mpdev: 自动补全

  4. 确认无问题后可删备份:
     rm -rf "BACKUP_PATH"

  详见 docs/upgrade-guide.md
EOF
else
  cat <<'EOF'
后续:
  1. 确认 v2 plugin 已装:
     /plugin list | grep mpdev

  2. 推荐删 4 个框架 agent（让 plugin 接管最新版本）:
     rm .claude/agents/code-reviewer.md
     rm .claude/agents/integration-checker.md
     rm .claude/agents/acceptance-reviewer.md
     rm .claude/agents/doc-refresher.md
     （项目特化的 *-impl.md / architect.md / 等不要删）

     💡 或下次跑 migrate 时加 --auto-clean-framework-agents flag 自动清理

  3. 完全重启 Claude Code，验证 /mpdev: 自动补全

  4. 确认无问题后可删备份:
     rm -rf "BACKUP_PATH"

  详见 docs/upgrade-guide.md
EOF
fi
echo ""
echo "  备份位置: $BACKUP（保留至少 7 天后再删）"
