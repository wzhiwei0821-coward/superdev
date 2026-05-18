#!/usr/bin/env bash
# sync-to-gitlab.sh — 把 superdev/mpdev/ 同步到 GitLab 独立 mpdev 仓
#
# Usage: 在 superdev/ 根跑
#   bash mpdev/scripts/sync-to-gitlab.sh
#   bash mpdev/scripts/sync-to-gitlab.sh --dry-run
#
# Environment:
#   MPDEV_GITLAB_REPO    覆盖 GitLab clone URL
#   MPDEV_GITLAB_BRANCH  覆盖 GitLab 分支（默认 master）
#   MPDEV_SOURCE_DIR     覆盖本地 mpdev 子目录（默认 mpdev）

set -e

GITLAB_REPO="${MPDEV_GITLAB_REPO:-git@10.173.28.211:robot-ai/mppm/mpdev.git}"
GITLAB_BRANCH="${MPDEV_GITLAB_BRANCH:-master}"
SOURCE_DIR="${MPDEV_SOURCE_DIR:-mpdev}"
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    *) echo "❌ 未知参数: $arg"; exit 1 ;;
  esac
done

# Preflight
[ -d "$SOURCE_DIR" ] || { echo "❌ $SOURCE_DIR/ 不存在 (是否在 superdev/ 根?)"; exit 1; }
[ -f "$SOURCE_DIR/VERSION" ] || { echo "❌ $SOURCE_DIR/VERSION 缺失"; exit 1; }
command -v rsync >/dev/null || { echo "❌ rsync 未安装（Mac/Linux 自带；Git Bash 需 pacman -S rsync）"; exit 1; }

VERSION=$(cat "$SOURCE_DIR/VERSION")
SUPERDEV_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "▶ 同步 mpdev v$VERSION (superdev@$SUPERDEV_SHA)"
echo "  目标: $GITLAB_REPO ($GITLAB_BRANCH)"
$DRY_RUN && echo "  [DRY-RUN 模式，不会真 push]"
echo ""

# Clone GitLab 仓
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
echo "▶ Step 1/4: Clone GitLab 仓到临时目录"
git clone --depth=1 --branch "$GITLAB_BRANCH" "$GITLAB_REPO" "$TMP/gitlab" 2>&1 | tail -2

# 检查版本冲突
if (cd "$TMP/gitlab" && git tag -l "v$VERSION" | grep -q .); then
  echo "⚠️  GitLab 仓已存在 v$VERSION tag"
  read -p "覆盖（不推荐 — 删 tag + force push）/ 取消？(y/N) " yn
  case $yn in
    [Yy]*) (cd "$TMP/gitlab" && git tag -d "v$VERSION" && git push origin ":refs/tags/v$VERSION" 2>/dev/null || true) ;;
    *) echo "取消"; exit 2 ;;
  esac
fi

# rsync 同步
echo ""
echo "▶ Step 2/4: rsync $SOURCE_DIR/ → GitLab 临时副本"
rsync -av --delete --exclude='.git' "$SOURCE_DIR/" "$TMP/gitlab/"

# 提交 + tag
echo ""
echo "▶ Step 3/4: commit + tag"
cd "$TMP/gitlab"
git add -A
if git diff --cached --quiet; then
  echo "  ℹ️ GitLab 已是最新，无需提交"
  exit 0
fi
git -c user.email='mpdev-sync@local' -c user.name='mpdev-sync' commit -m "release: v$VERSION

Synced from superdev@$SUPERDEV_SHA via sync-to-gitlab.sh"
git tag "v$VERSION"

# Push
echo ""
if $DRY_RUN; then
  echo "▶ Step 4/4: [DRY-RUN] 跳过 push。下次去掉 --dry-run 即可推送。"
  echo "  将推送的内容:"
  git log -1 --stat
else
  echo "▶ Step 4/4: Push 到 GitLab"
  git push origin "$GITLAB_BRANCH"
  git push origin "v$VERSION"
fi

echo ""
echo "✅ 同步完成: v$VERSION"
echo "   GitLab: http://10.173.28.211/robot-ai/mppm/mpdev/-/tree/$GITLAB_BRANCH"
