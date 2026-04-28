#!/usr/bin/env bash
# mpdev-suite updater — 升级已安装的 .claude/ 套件
# 策略：备份 → 拉新版 → 覆盖框架文件 → 保留项目实例
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/update.sh | bash
#   curl -fsSL .../update.sh | MPDEV_VERSION=1.1.0 bash

set -euo pipefail

REPO_URL="${MPDEV_REPO:-https://github.com/wzhiwei0821-coward/superdev.git}"
VERSION="${MPDEV_VERSION:-latest}"
TARGET="${MPDEV_TARGET:-./.claude}"
SUBDIR="${MPDEV_SUBDIR-mpdev-suite}"   # monorepo 子目录；显式 export MPDEV_SUBDIR= 可禁用

die() { echo "❌ $*" >&2; exit 1; }
info() { echo "▶ $*"; }
ok() { echo "✅ $*"; }

# --- preflight ---
command -v git >/dev/null || die "git 未安装"
[ -d "$TARGET" ] || die "$TARGET 不存在 — 请先用 install.sh 安装"

CUR_VERSION=$(cat "$TARGET/.mpdev-version" 2>/dev/null || echo "unknown")
info "当前版本: $CUR_VERSION → 目标版本: $VERSION"

# --- backup ---
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="${TARGET}.bak.${TS}"
cp -r "$TARGET" "$BACKUP"
ok "已备份到 $BACKUP"

# --- download new version ---
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

info "拉取新版本"
if [ "$VERSION" = "latest" ]; then
  git clone --depth=1 "$REPO_URL" "$TMP/suite" 2>&1 | tail -3
else
  git clone --depth=1 --branch "v$VERSION" "$REPO_URL" "$TMP/suite" 2>&1 | tail -3 \
    || die "找不到版本 v$VERSION"
fi
# 解析套件根（支持 monorepo 子目录）
SUITE_ROOT="$TMP/suite${SUBDIR:+/$SUBDIR}"
[ -d "$SUITE_ROOT/.claude" ] || die "$SUITE_ROOT/.claude 不存在（检查 MPDEV_SUBDIR='$SUBDIR'）"

NEW_VERSION=$(cat "$SUITE_ROOT/VERSION" 2>/dev/null || echo "$VERSION")

# --- 覆盖框架文件（项目无关）---
info "更新框架文件"
cp -r "$SUITE_ROOT/.claude/commands/." "$TARGET/commands/"
cp "$SUITE_ROOT/.claude/templates/"*.tmpl "$TARGET/templates/"
cp -r "$SUITE_ROOT/.claude/templates/understand/." "$TARGET/templates/understand/"
cp "$SUITE_ROOT/.claude/MPDev-Scheme.md" "$TARGET/"
cp "$SUITE_ROOT/.claude/mpdev-suite-workflow.md" "$TARGET/"
cp "$SUITE_ROOT/.claude/README.md" "$TARGET/"

# --- dialects / test-flavors：三方合并（用户可能加过自定义）---
info "合并 dialects/ 和 test-flavors/（自定义文件保留）"
for d in dialects test-flavors; do
  for f in "$SUITE_ROOT/.claude/templates/$d/"*.md; do
    name=$(basename "$f")
    target_f="$TARGET/templates/$d/$name"
    if [ -f "$target_f" ]; then
      # 同名文件：如果用户改过（与备份不同），则保留并提示
      if ! diff -q "$BACKUP/templates/$d/$name" "$f" >/dev/null 2>&1; then
        # 框架升级了，但用户也可能改过 → 保留用户版，新版另存为 .new
        if ! diff -q "$BACKUP/templates/$d/$name" "$target_f" >/dev/null 2>&1; then
          info "  $d/$name 用户已改 — 新版保存为 $name.new（手工合并）"
          cp "$f" "$target_f.new"
        else
          # 用户没改，直接更新
          cp "$f" "$target_f"
        fi
      fi
    else
      # 新增文件，直接拷
      cp "$f" "$target_f"
      info "  + 新增 $d/$name"
    fi
  done
done

# --- 保留项不动 ---
# agents/ ✓（项目实例）
# mpdev-runs/ ✓（运行历史）
# .mpdev-version 更新

echo "$NEW_VERSION" > "$TARGET/.mpdev-version"

ok "升级完成: $CUR_VERSION → $NEW_VERSION"

cat <<EOF

后续：
  diff -ur $BACKUP $TARGET    # 对比变更
  ls $TARGET/templates/{dialects,test-flavors}/*.new 2>/dev/null  # 查看待手工合并的文件
  rm -rf $BACKUP              # 确认无误后删除备份

如发现问题回滚：
  rm -rf $TARGET && mv $BACKUP $TARGET
EOF
