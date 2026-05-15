#!/usr/bin/env bash
# mpdev-suite installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/install.sh | bash
#   curl -fsSL .../install.sh | MPDEV_VERSION=1.0.0 bash
#   curl -fsSL .../install.sh | MPDEV_TARGET=./custom-claude bash

set -euo pipefail

# --- config (override via env) ---
REPO_URL="${MPDEV_REPO:-https://github.com/wzhiwei0821-coward/superdev.git}"
VERSION="${MPDEV_VERSION:-latest}"
TARGET="${MPDEV_TARGET:-./.claude}"
SUBDIR="${MPDEV_SUBDIR-mpdev-suite}"   # monorepo 子目录；显式 export MPDEV_SUBDIR= 可禁用

# --- helpers ---
die() { echo "❌ $*" >&2; exit 1; }
info() { echo "▶ $*"; }
ok() { echo "✅ $*"; }

# --- preflight ---
command -v git >/dev/null || die "git 未安装"

if [ -e "$TARGET" ]; then
  if [ -f "$TARGET/.mpdev-version" ]; then
    cur=$(cat "$TARGET/.mpdev-version")
    info "$TARGET 已存在 mpdev-suite v$cur — 升级请用 update.sh"
  fi
  read -p "$TARGET 已存在，覆盖？(y/N) " ans
  [[ "${ans:-N}" =~ ^[Yy]$ ]] || die "已取消"
  rm -rf "$TARGET"
fi

# --- download ---
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

info "拉取 mpdev-suite (version=$VERSION)"
if [ "$VERSION" = "latest" ]; then
  git clone --depth=1 "$REPO_URL" "$TMP/suite" 2>&1 | tail -3
else
  git clone --depth=1 --branch "v$VERSION" "$REPO_URL" "$TMP/suite" 2>&1 | tail -3 \
    || die "找不到版本 v$VERSION（可用 git ls-remote --tags $REPO_URL 列出）"
fi

# 解析套件根（支持 monorepo 子目录）
SUITE_ROOT="$TMP/suite${SUBDIR:+/$SUBDIR}"
[ -d "$SUITE_ROOT/.claude" ] || die "$SUITE_ROOT/.claude 不存在（检查 MPDEV_SUBDIR='$SUBDIR' 是否正确）"

# 解析实际版本号（latest 模式从 VERSION 文件读）
ACTUAL_VERSION=$(cat "$SUITE_ROOT/VERSION" 2>/dev/null || echo "$VERSION")

# --- install ---
mkdir -p "$TARGET"
cp -r "$SUITE_ROOT/.claude/." "$TARGET/"

# 二次保险：清掉项目实例残留（仓库中本应已清空）
rm -rf "$TARGET/agents/"*.md 2>/dev/null || true
find "$TARGET/mpdev-runs" -mindepth 1 -maxdepth 1 -type d -not -name 'commits' -not -name 'fixes' -not -name 'setup' -not -name 'test-cases' -not -name 'test-exports' -not -name 'test-plans' -exec rm -rf {} + 2>/dev/null || true

# 确保空目录骨架就位（git 不保留空目录，命令运行时直接写入）
mkdir -p "$TARGET/agents"
mkdir -p "$TARGET/mpdev-runs"/{commits,fixes,setup,test-cases,test-exports,test-plans}

# 打版本标
echo "$ACTUAL_VERSION" > "$TARGET/.mpdev-version"

# .gitignore 注入（v1.3.0+ 引入 runtime-probe 凭据 + 笔记目录）
GITIGNORE_PATH="$(dirname "$TARGET")/.gitignore"
GITIGNORE_ENTRIES=(
  ".claude/.mpdev-runtime-creds.yml"
  ".claude/.mpdev-env-state.yml"
  ".claude-notes/"
)
if [ -f "$GITIGNORE_PATH" ]; then
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qxF "$entry" "$GITIGNORE_PATH"; then
      echo "$entry" >> "$GITIGNORE_PATH"
      info "已追加到 .gitignore: $entry"
    fi
  done
else
  printf '%s\n' "${GITIGNORE_ENTRIES[@]}" > "$GITIGNORE_PATH"
  info "已新建 .gitignore（含运行时文件忽略规则）"
fi

ok "mpdev-suite v$ACTUAL_VERSION 已安装到 $TARGET"

# --- next steps ---
cat <<EOF

下一步：
  /mpdev-understand                # 阶段 0a：生成各模块 CLAUDE.md
  /mpdev-contracts                 # 阶段 0b：跨模块项目才需要，单模块跳过
  /mpdev-init                      # 阶段 1：生成 12 个 agent
  /mpdev "需求描述"                 # 阶段 2：开始日常开发

文档：
  $TARGET/README.md                顶层入口（5 步激活流 + FAQ）
  $TARGET/mpdev-suite-workflow.md  详细使用手册
  $TARGET/MPDev-Scheme.md          架构与角色设计

升级：
  curl -fsSL .../scripts/update.sh | bash
EOF
