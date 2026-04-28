#!/usr/bin/env bash
# mpdev-suite packer — 生成离线 tar.gz，供内网无 git 拉取的项目使用
#
# Usage:
#   ./scripts/pack.sh                    # 打包当前目录的 .claude/
#   ./scripts/pack.sh --output dist/     # 指定输出目录
#
# Output: mpdev-suite-v{VERSION}.tar.gz

set -euo pipefail

OUT_DIR="${1:-./dist}"
VERSION=$(cat VERSION)

# preflight
[ -d ".claude" ] || { echo "❌ 当前目录无 .claude/，请在 mpdev-suite 仓库根运行" >&2; exit 1; }
[ -n "$VERSION" ] || { echo "❌ VERSION 文件为空" >&2; exit 1; }

mkdir -p "$OUT_DIR"

PACK_NAME="mpdev-suite-v${VERSION}"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# 准备打包目录（只含 .claude/ + 必要脚本，不含 git 元数据）
mkdir -p "$TMP/$PACK_NAME"
cp -r .claude "$TMP/$PACK_NAME/"
cp VERSION "$TMP/$PACK_NAME/"
cp CHANGELOG.md "$TMP/$PACK_NAME/" 2>/dev/null || true
cp scripts/install-offline.sh "$TMP/$PACK_NAME/install.sh" 2>/dev/null || cat > "$TMP/$PACK_NAME/install.sh" <<'EOF'
#!/usr/bin/env bash
# 离线安装：从解压后的目录把 .claude/ 拷贝到目标项目
set -euo pipefail
TARGET="${MPDEV_TARGET:-./.claude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -d "$TARGET" ] && { read -p "$TARGET 已存在，覆盖？(y/N) " ans; [[ "${ans:-N}" =~ ^[Yy]$ ]] || exit 1; rm -rf "$TARGET"; }
mkdir -p "$TARGET"
cp -r "$SCRIPT_DIR/.claude/." "$TARGET/"
mkdir -p "$TARGET/agents"
mkdir -p "$TARGET/mpdev-runs"/{commits,fixes,setup,test-cases,test-exports,test-plans}
echo "$(cat "$SCRIPT_DIR/VERSION")" > "$TARGET/.mpdev-version"
echo "✅ 已安装到 $TARGET"
EOF
chmod +x "$TMP/$PACK_NAME/install.sh"

# 打包
TARBALL="$OUT_DIR/${PACK_NAME}.tar.gz"
tar -czf "$TARBALL" -C "$TMP" "$PACK_NAME"

# sha256 校验文件（便于 release 时 publish）
if command -v sha256sum >/dev/null; then
  (cd "$OUT_DIR" && sha256sum "${PACK_NAME}.tar.gz" > "${PACK_NAME}.tar.gz.sha256")
elif command -v shasum >/dev/null; then
  (cd "$OUT_DIR" && shasum -a 256 "${PACK_NAME}.tar.gz" > "${PACK_NAME}.tar.gz.sha256")
fi

echo "✅ 打包完成: $TARBALL"
ls -lh "$TARBALL"
[ -f "$TARBALL.sha256" ] && cat "$TARBALL.sha256"

cat <<EOF

下游使用方式（上传到 GitHub Releases 后）：
  wget https://github.com/wzhiwei0821-coward/superdev/releases/download/v${VERSION}/${PACK_NAME}.tar.gz
  tar -xzf ${PACK_NAME}.tar.gz
  cd ${PACK_NAME} && ./install.sh
EOF
