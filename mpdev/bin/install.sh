#!/usr/bin/env bash
#
# mpdev Plugin 一键安装 (v2.0.0)
# ===============================
# 默认从公司 GitLab 内网装 (SSH)；--source=github 切公网。
#
# Usage:
#   bash install.sh                       # 默认 GitLab (SSH)
#   bash install.sh --source=github       # 切公网 GitHub (HTTPS)
#   bash install.sh --target=~/dev/mpdev  # 自定义本地路径
#   bash install.sh --help                # 完整帮助
#
# 一键 (curl):
#   bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
#

set -e

# ---- Source 配置 ----
SOURCE_GITLAB_URL="git@10.173.28.211:robot-ai/mppm/mpdev.git"
SOURCE_GITLAB_BRANCH="master"
SOURCE_GITLAB_SUBDIR=""

SOURCE_GITHUB_URL="https://github.com/wzhiwei0821-coward/superdev.git"
SOURCE_GITHUB_BRANCH="main"
SOURCE_GITHUB_SUBDIR="mpdev"

SOURCE_TYPE="${MPDEV_SOURCE:-gitlab}"
SKIP_SSH_KEYSCAN=false
TARGET="${MPDEV_TARGET:-$HOME/dev/mpdev}"

# ---- 参数 ----
for arg in "$@"; do
  case $arg in
    --source=gitlab)    SOURCE_TYPE="gitlab"; shift ;;
    --source=github)    SOURCE_TYPE="github"; shift ;;
    --target=*)         TARGET="${arg#*=}"; shift ;;
    --repo=*)           REPO_URL_OVERRIDE="${arg#*=}"; shift ;;
    --branch=*)         BRANCH_OVERRIDE="${arg#*=}"; shift ;;
    --subdir=*)         SUBDIR_OVERRIDE="${arg#*=}"; shift ;;
    --skip-ssh-keyscan) SKIP_SSH_KEYSCAN=true; shift ;;
    -h|--help)
      cat <<EOF
Usage: install.sh [OPTIONS]

OPTIONS:
  --source=gitlab     (默认) 从公司 GitLab 装 (SSH)
  --source=github     从 GitHub 公网装 (HTTPS, 无需 SSH)
  --target=PATH       自定义本地 clone 路径（默认 \$HOME/dev/mpdev）
  --repo=URL          覆盖 source 的 clone URL（专家模式）
  --branch=NAME       覆盖 source 的分支
  --subdir=PATH       覆盖 source 的子目录（空字符串表示仓根 = plugin）
  --skip-ssh-keyscan  跳过 SSH 主机指纹自动接受
  -h, --help          显示此帮助

ENVIRONMENT:
  MPDEV_SOURCE=gitlab|github   等价 --source
  MPDEV_TARGET=PATH            等价 --target

EXAMPLES:
  bash install.sh                            # 默认 GitLab (SSH)
  bash install.sh --source=github            # 切公网 GitHub
  MPDEV_SOURCE=github bash install.sh        # env 等价
EOF
      exit 0 ;;
    *) echo "❌ 未知参数: $arg" ; exit 1 ;;
  esac
done

# 根据 SOURCE_TYPE 选 URL/branch/subdir（flag override 优先）
case $SOURCE_TYPE in
  gitlab)
    REPO_URL="${REPO_URL_OVERRIDE:-$SOURCE_GITLAB_URL}"
    BRANCH="${BRANCH_OVERRIDE:-$SOURCE_GITLAB_BRANCH}"
    SUBDIR="${SUBDIR_OVERRIDE-$SOURCE_GITLAB_SUBDIR}"
    ;;
  github)
    REPO_URL="${REPO_URL_OVERRIDE:-$SOURCE_GITHUB_URL}"
    BRANCH="${BRANCH_OVERRIDE:-$SOURCE_GITHUB_BRANCH}"
    SUBDIR="${SUBDIR_OVERRIDE-$SOURCE_GITHUB_SUBDIR}"
    ;;
  *) echo "❌ 未知 source: $SOURCE_TYPE (合法: gitlab / github)"; exit 1 ;;
esac

TARGET="${TARGET/#\~/$HOME}"

# ---- 开场 ----
cat <<EOF

╭──────────────────────────────────────────────────────────╮
│  mpdev v2.0.0 Plugin 安装                                  │
│  多模块 AI 协同开发框架 · Claude Code Plugin              │
╰──────────────────────────────────────────────────────────╯

源:     [$SOURCE_TYPE] $REPO_URL
分支:   $BRANCH
子目录: ${SUBDIR:-（仓根）}
目标:   $TARGET

EOF

# ---- Step 1/6: 前置检查 ----
echo "▶ Step 1/6: 前置检查"
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
    [Yy]*) cd "$TARGET" && git pull 2>&1 | tail -3 || true; cd - >/dev/null ;;
    *) echo "已取消"; exit 2 ;;
  esac
fi

# ---- Step 2/6: SSH 主机指纹（仅 gitlab）----
if [ "$SOURCE_TYPE" = "gitlab" ] && [ "$SKIP_SSH_KEYSCAN" = false ]; then
  echo ""
  echo "▶ Step 2/6: SSH 主机指纹（gitlab 源需要）"
  SSH_HOST=$(echo "$REPO_URL" | sed -E 's|^git@([^:]+):.*|\1|')

  if ssh-keygen -F "$SSH_HOST" >/dev/null 2>&1; then
    echo "  ✅ $SSH_HOST 主机指纹已在 known_hosts"
  else
    echo "  ⚠️  $SSH_HOST 主机指纹未在 known_hosts"
    echo "      推荐：先手动 ssh -T git@$SSH_HOST 查看并接受指纹"
    read -p "      或自动 ssh-keyscan 添加？(y/N) " yn
    case $yn in
      [Yy]*) ssh-keyscan -H "$SSH_HOST" >> ~/.ssh/known_hosts 2>/dev/null && echo "  ✅ 已加入" ;;
      *) echo "  → 请手动 ssh -T git@$SSH_HOST 后重跑本脚本"; exit 4 ;;
    esac
  fi

  if ! ssh -T -o BatchMode=yes -o ConnectTimeout=5 "git@$SSH_HOST" 2>&1 | grep -qE "Welcome|successfully|GitLab"; then
    echo "  ❌ SSH 鉴权失败。可能原因："
    echo "      ① GitLab User Settings → SSH Keys 添加你的公钥（~/.ssh/id_*.pub）"
    echo "      ② SSH key 不存在 → ssh-keygen -t ed25519 -C \"your_email\""
    echo "      ③ 网络不通（VPN / 防火墙）→ ping $SSH_HOST"
    exit 4
  fi
  echo "  ✅ SSH 鉴权通过"
else
  echo ""
  echo "▶ Step 2/6: 跳过（GitHub 走 HTTPS，无需 SSH）"
fi

# ---- Step 3/6: 克隆 ----
echo ""
echo "▶ Step 3/6: 克隆 mpdev (source=$SOURCE_TYPE, branch=$BRANCH)"

if [ ! -d "$TARGET/.git" ]; then
  TMP=$(mktemp -d)
  trap "rm -rf $TMP" EXIT

  if ! git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$TMP/repo" 2>&1 | tail -3; then
    echo "❌ git clone 失败"
    exit 3
  fi

  if [ -n "$SUBDIR" ]; then
    SUITE_ROOT="$TMP/repo/$SUBDIR"
    [ -d "$SUITE_ROOT" ] || { echo "❌ 找不到 $SUBDIR 子目录"; exit 3; }
  else
    SUITE_ROOT="$TMP/repo"
  fi

  mkdir -p "$(dirname "$TARGET")"
  cp -r "$SUITE_ROOT" "$TARGET"
fi

[ -f "$TARGET/.claude-plugin/marketplace.json" ] || { echo "❌ marketplace.json 缺失"; exit 3; }
echo "  ✅ $TARGET 就绪"

# ---- Step 4/6: 版本信息 ----
echo ""
echo "▶ Step 4/6: 版本信息"
VERSION=$(cat "$TARGET/VERSION" 2>/dev/null || echo "unknown")
echo "  📦 mpdev v$VERSION"

# ---- Step 5/6: 在 Claude Code 内完成 plugin 注册 ----
echo ""
echo "▶ Step 5/6: 在 Claude Code 内完成 plugin 注册"
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

# ---- Step 6/6: hooks 可执行 + BOM 自检 ----
echo "▶ Step 6/6: hooks 可执行 + .ps1 文件 BOM 校验"

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
  echo "  ⚠️  补充了 $fixed 个 .ps1 文件的 UTF-8 BOM（可能源仓未加 BOM）"
else
  echo "  ✅ 所有 .ps1 文件 BOM 完整"
fi

echo ""
echo "✅ 安装完成"
exit 0
