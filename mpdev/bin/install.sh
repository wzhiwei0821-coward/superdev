#!/usr/bin/env bash
#
# mpdev v2.0.0 Plugin 一键安装
# ============================
# Usage:
#   bash install.sh                       # 默认 GitHub 源
#   bash install.sh --target=~/dev/mpdev  # 自定义本地路径
#
# 一键 (curl):
#   bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
#

set -e

REPO_URL="${MPDEV_REPO:-https://github.com/wzhiwei0821-coward/superdev.git}"
SUBDIR="${MPDEV_SUBDIR:-mpdev}"
TARGET="${MPDEV_TARGET:-$HOME/dev/mpdev}"

# ---- 参数 ----
for arg in "$@"; do
  case $arg in
    --target=*) TARGET="${arg#*=}"; shift ;;
    --repo=*)   REPO_URL="${arg#*=}"; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's|^# \?||'
      exit 0
      ;;
    *) echo "未知参数: $arg" ; exit 1 ;;
  esac
done

TARGET="${TARGET/#\~/$HOME}"

# ---- 开场 ----
cat <<EOF

╭──────────────────────────────────────────────────────────╮
│  mpdev v2.0.0 Plugin 安装                                  │
│  多模块 AI 协同开发框架 · Claude Code Plugin              │
╰──────────────────────────────────────────────────────────╯

源:     $REPO_URL (subdir: $SUBDIR)
目标:   $TARGET

EOF

# ---- 前置检查 ----
echo "▶ Step 1/4: 前置检查"

command -v git >/dev/null || { echo "❌ git 未安装"; exit 1; }
echo "  ✅ git: $(git --version | head -1)"

if [ ! -d "$HOME/.claude" ]; then
  echo "⚠️ 未检测到 ~/.claude，请先安装 Claude Code: https://docs.claude.com/en/docs/claude-code"
  read -p "继续？(y/N) " yn
  [[ "$yn" =~ ^[Yy]$ ]] || exit 2
fi

if [ -d "$TARGET" ]; then
  echo "⚠️ 目标已存在: $TARGET"
  read -p "覆盖（git pull 拉新）/取消？(y/N) " yn
  case $yn in
    [Yy]*) cd "$TARGET" && git pull 2>&1 | tail -3 ;;
    *) echo "已取消"; exit 2 ;;
  esac
fi

# ---- 克隆 ----
echo ""
echo "▶ Step 2/4: 克隆 mpdev"

if [ ! -d "$TARGET/.git" ]; then
  TMP=$(mktemp -d)
  trap "rm -rf $TMP" EXIT

  if ! git clone --depth=1 "$REPO_URL" "$TMP/superdev" 2>&1 | tail -3; then
    echo "❌ clone 失败"
    exit 3
  fi

  if [ ! -d "$TMP/superdev/$SUBDIR" ]; then
    echo "❌ 找不到 $SUBDIR 子目录"
    exit 3
  fi

  mkdir -p "$(dirname "$TARGET")"
  cp -r "$TMP/superdev/$SUBDIR" "$TARGET"
fi

# 验证 manifest
[ -f "$TARGET/.claude-plugin/marketplace.json" ] || { echo "❌ marketplace.json 缺失"; exit 3; }
echo "  ✅ $TARGET 就绪"

# ---- 版本 ----
echo ""
echo "▶ Step 3/4: 版本信息"
VERSION=$(cat "$TARGET/VERSION" 2>/dev/null || echo "unknown")
echo "  📦 mpdev v$VERSION"

# ---- 引导 ----
echo ""
echo "▶ Step 4/5: 在 Claude Code 内完成 plugin 注册"
echo ""
cat <<EOF
现在请打开 Claude Code，按顺序输入：

  ╭─────────────────────────────────────────────────────────╮
  │  /plugin marketplace add file://$TARGET
  │  /plugin install mpdev@mpdev                             │
  ╰─────────────────────────────────────────────────────────╯

完成后**完全重启** Claude Code（不仅是 /clear），
输入 /mpdev: 应见 9 个命令自动补全:

  /mpdev:check    /mpdev:commit  /mpdev:contracts
  /mpdev:dev      /mpdev:env     /mpdev:fix
  /mpdev:init     /mpdev:test    /mpdev:understand

文档:
  快速上手:    $TARGET/docs/quickstart.md
  从 v1 升级:  $TARGET/docs/upgrade-guide.md
  故障排查:    $TARGET/docs/troubleshooting.md

EOF

# ---- BOM 自检（v2.0.1+）----
# 修复 T42 audit bug：中文 Windows 上无 BOM 的 .ps1 会被 GBK 解码 → 整个文件挂
echo ""
echo "▶ Step 5/5: 校验 .ps1 文件 BOM"
fixed=0
# 用 find -print0 + while read -d '' 处理路径含空格的情况
while IFS= read -r -d '' f; do
  # 读前 3 字节
  bom=$(head -c 3 "$f" | od -An -tx1 | tr -d ' \n')
  if [ "$bom" != "efbbbf" ]; then
    # 缺 BOM，补上：写 EF BB BF + 原内容
    tmp="$(mktemp)"
    printf '\xef\xbb\xbf' > "$tmp"
    cat "$f" >> "$tmp"
    mv "$tmp" "$f"
    fixed=$((fixed + 1))
  fi
done < <(find "$TARGET" -name '*.ps1' -print0 2>/dev/null)
if [ $fixed -gt 0 ]; then
  echo "  ⚠️  补充了 $fixed 个 .ps1 文件的 UTF-8 BOM（可能源仓未加 BOM）"
else
  echo "  ✅ 所有 .ps1 文件 BOM 完整"
fi

echo "✅ 安装完成"
exit 0
