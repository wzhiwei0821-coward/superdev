#!/usr/bin/env bash
#
# mpdev v2.1.168 兼容修复脚本
# ============================
# Claude Code v2.1.168 起不再对 command name: 字段自动拼插件前缀，
# 导致所有 mpdev 短名命令 (name: init) 失效。
# 本脚本直接修 ~/.claude/plugins/cache/ 里的缓存文件，不依赖 /plugin 命令。
#
# 用法:
#   bash fix-v2.1.168.sh
#
# 或一键:
#   bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/scripts/fix-v2.1.168.sh)
#
# 修完完全重启 Claude Code 即可。

set -e

echo ""
echo "╭──────────────────────────────────────────╮"
echo "│  mpdev v2.1.168 兼容修复                    │"
echo "│  修 command name: 字段 + plugin.json     │"
echo "╰──────────────────────────────────────────╯"
echo ""

# ── 1. 找缓存目录 ──
PLUGIN_CACHE="${HOME}/.claude/plugins/cache/mpdev"

if [ ! -d "$PLUGIN_CACHE" ]; then
  echo "❌ 找不到 mpdev plugin 缓存: $PLUGIN_CACHE"
  echo "   请确认 mpdev plugin 已安装。"
  exit 1
fi

# 支持多个版本目录，找最新的
CACHE_DIR=$(find "$PLUGIN_CACHE" -maxdepth 3 -name "plugin.json" -path "*/.claude-plugin/*" 2>/dev/null | head -1 | xargs dirname | xargs dirname)
if [ -z "$CACHE_DIR" ]; then
  echo "❌ 在缓存中找不到 plugin.json"
  exit 1
fi

echo "✔ 缓存目录: $CACHE_DIR"
echo ""

# ── 2. 修 command name: 字段 ──
CMDS_DIR="$CACHE_DIR/commands"
if [ ! -d "$CMDS_DIR" ]; then
  echo "❌ 找不到 commands/ 目录"
  exit 1
fi

echo "▶ 修复 command name: 字段..."
FIXED=0
for f in "$CMDS_DIR"/*.md; do
  [ -f "$f" ] || continue
  fname=$(basename "$f" .md)
  old=$(head -5 "$f" | grep "^name:" | awk '{print $2}')
  
  if [ -z "$old" ]; then
    echo "  ⚠️  $fname.md: 无 name 字段，跳过"
    continue
  fi

  # 已经是 mpdev:xxx 格式就不动
  case "$old" in
    mpdev:*) echo "  ✅ $fname.md: $old (已修复)"; continue ;;
  esac

  sed -i "s/^name: $old$/name: mpdev:$old/" "$f"
  new=$(head -5 "$f" | grep "^name:" | awk '{print $2}')
  echo "  🔧 $fname.md: $old → $new"
  FIXED=$((FIXED + 1))
done
echo "  ✔ 修复了 $FIXED 个文件"
echo ""

# ── 3. 修 plugin.json（加 commands 数组） ──
PJ="$CACHE_DIR/.claude-plugin/plugin.json"
echo "▶ 修复 plugin.json..."

python3 -c "
import json, sys

with open('$PJ', 'r', encoding='utf-8') as f:
    pj = json.load(f)

changed = False

# 补 version
if pj.get('version') != '2.1.1':
    pj['version'] = '2.1.1'
    changed = True
    print('  version: → 2.1.1')

# 补 commands 数组
if 'commands' not in pj:
    pj['commands'] = [
        './commands/check.md',
        './commands/commit.md',
        './commands/contracts.md',
        './commands/dev.md',
        './commands/env.md',
        './commands/fix.md',
        './commands/init.md',
        './commands/test.md',
        './commands/understand.md'
    ]
    changed = True
    print('  commands: 添加了 9 个条目')

if changed:
    with open('$PJ', 'w', encoding='utf-8') as f:
        json.dump(pj, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print('  ✔ plugin.json 已更新')
else:
    print('  ✅ plugin.json 无需更改')
" 2>/dev/null || {
  echo "  ⚠️  python3 不可用，跳过 plugin.json 修复（不影响功能）"
}
echo ""

# ── 4. 完成 ──
echo "✅ 修复完成！"
echo ""
echo "现在请完全退出 Claude Code 再重新打开。"
echo "输入 /mpdev: 应自动补全 9 个命令。"
echo ""
