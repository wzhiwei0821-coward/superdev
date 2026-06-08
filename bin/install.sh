#!/usr/bin/env bash
#
# mpdev Plugin 一键安装 (v2.2.0)
# ===============================
# 从 GitHub 拉取 superdev 仓库的 mpdev/ 子目录。
#
# Usage:
#   bash install.sh                       # 默认 ~/dev/mpdev
#   bash install.sh --target=~/dev/mpdev  # 自定义路径
#   bash install.sh --help
#
# 一键 (curl):
#   bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
#

set -e

REPO_URL="https://github.com/wzhiwei0821-coward/superdev.git"
BRANCH="main"
SUBDIR="mpdev"
TARGET="${MPDEV_TARGET:-$HOME/dev/mpdev}"

# ---- 参数 ----
for arg in "$@"; do
  case $arg in
    --target=*)   TARGET="${arg#*=}"; shift ;;
    --repo=*)     REPO_URL="${arg#*=}"; shift ;;
    --branch=*)   BRANCH="${arg#*=}"; shift ;;
    -h|--help)
      cat <<EOF
Usage: install.sh [OPTIONS]

OPTIONS:
  --target=PATH   自定义安装路径（默认 \$HOME/dev/mpdev）
  --repo=URL      覆盖 GitHub 仓库 URL
  --branch=NAME   覆盖分支（默认 main）
  -h, --help      显示此帮助

ENVIRONMENT:
  MPDEV_TARGET=PATH  等价 --target

EXAMPLE:
  bash install.sh
  bash install.sh --target=~/my-tools/mpdev
EOF
      exit 0 ;;
    *) echo "❌ 未知参数: $arg" ; exit 1 ;;
  esac
done

TARGET="${TARGET/#\~/$HOME}"

# ---- 开场 ----
cat <<EOF

╭──────────────────────────────────────────────────────────╮
│  mpdev v2.2.0 Plugin 安装                                  │
│  多模块 AI 协同开发框架 · Claude Code Plugin              │
╰──────────────────────────────────────────────────────────╯

源:     $REPO_URL
分支:   $BRANCH
目标:   $TARGET

EOF

# ---- Step 1/5: 前置检查 ----
echo "▶ Step 1/5: 前置检查"
command -v git >/dev/null || { echo "❌ git 未安装"; exit 1; }
echo "  ✅ git: $(git --version | head -1)"

if [ ! -d "$HOME/.claude" ]; then
  echo "⚠️ 未检测到 ~/.claude，请先安装 Claude Code"
  read -p "继续？(y/N) " yn
  [[ "$yn" =~ ^[Yy]$ ]] || exit 2
fi

if [ -d "$TARGET/.git" ]; then
  echo "  📦 已存在，git pull 拉新..."
  cd "$TARGET" && git pull 2>&1 | tail -3 || true; cd - >/dev/null
fi

# ---- Step 2/5: 克隆 ----
echo ""
echo "▶ Step 2/5: 克隆 mpdev"

if [ ! -d "$TARGET/.git" ]; then
  git clone --depth=1 --branch "$BRANCH" --no-checkout "$REPO_URL" "$TARGET" 2>&1 | tail -3 || { echo "❌ git clone 失败"; exit 3; }
  cd "$TARGET"
  git sparse-checkout init --cone 2>/dev/null || true
  git sparse-checkout set "$SUBDIR" 2>/dev/null || { echo "❌ sparse checkout 失败"; exit 3; }
  shopt -s dotglob
  cp -r "$SUBDIR"/* . 2>/dev/null || true
  rm -rf "$SUBDIR"
  cd - >/dev/null
fi

[ -f "$TARGET/.claude-plugin/plugin.json" ] || { echo "❌ plugin.json 缺失"; exit 3; }
echo "  ✅ $TARGET 就绪"

# ---- Step 3/5: 版本信息 ----
echo ""
echo "▶ Step 3/5: 版本信息"
VERSION=$(cat "$TARGET/VERSION" 2>/dev/null || echo "unknown")
echo "  📦 mpdev v$VERSION"

# ---- Step 4/5: plugin 注册提示 ----
echo ""
echo "▶ Step 4/5: 在 Claude Code 内注册 plugin"
echo ""
cat <<EOF
现在请打开 Claude Code，执行：

  ╭─────────────────────────────────────────────────────────╮
  │  /plugin marketplace add https://github.com/wzhiwei0821-coward/superdev
  │  /plugin install mpdev@superdev                          │
  ╰─────────────────────────────────────────────────────────╯

完成后**完全重启** Claude Code（不仅是 /clear），
输入 /mpdev: 应见 9 个命令自动补全:

  /mpdev:check    /mpdev:commit  /mpdev:contracts
  /mpdev:dev      /mpdev:env     /mpdev:fix
  /mpdev:init     /mpdev:test    /mpdev:understand

文档:
  快速上手:    $TARGET/docs/quickstart.md
  故障排查:    $TARGET/docs/troubleshooting.md

EOF

# ---- Step 5/5: hooks 可执行 + BOM 自检 ----
echo "▶ Step 5/5: hooks 可执行 + .ps1 BOM 校验"

if [ -d "$TARGET/hooks" ]; then
  chmod +x "$TARGET/hooks/"*.sh 2>/dev/null || true
fi

fixed=0
while IFS= read -r -d '' f; do
  bom=$(head -c 3 "$f" | od -An -tx1 | tr -d ' \n')
  if [ "$bom" != "efbbbf" ]; then
    tmp="$(mktemp)"
    printf '\xef\xbb\xbf' > "$tmp"
    cat "$f" >> "$tmp"
    mv "$tmp" "$f"
    fixed=$((fixed + 1))
  fi
done < <(find "$TARGET" -name '*.ps1' -print0 2>/dev/null)
if [ $fixed -gt 0 ]; then
  echo "  ⚠️  补充了 $fixed 个 .ps1 文件的 UTF-8 BOM"
else
  echo "  ✅ 所有 .ps1 文件 BOM 完整"
fi

echo ""
echo "✅ 安装完成"
exit 0
