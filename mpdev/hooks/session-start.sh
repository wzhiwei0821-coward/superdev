#!/usr/bin/env bash
# session-start.sh — mpdev SessionStart hook
#
# 触发: Claude Code 启动 / 新会话
# 输入: stdin {} (SessionStart 事件无 payload)
# 输出: hookSpecificOutput JSON with additionalContext
# 失败策略: 任何错误都退回 {}，绝不阻塞会话

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

check_disabled

PROJECT_DIR=$(get_project_dir)

# Glob CLAUDE.md 排除明显非业务目录
mapfile -t CLAUDE_FILES < <(find "$PROJECT_DIR" \
  -name CLAUDE.md \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/.claude/plugins/*' \
  -not -path '*/target/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  2>/dev/null)

# 0 个 → 静默退出
[ ${#CLAUDE_FILES[@]} -eq 0 ] && { echo "{}"; exit 0; }

# 超过 5 个 → 取前 5
COUNT_TOTAL=${#CLAUDE_FILES[@]}
if [ $COUNT_TOTAL -gt 5 ]; then
  CLAUDE_FILES=("${CLAUDE_FILES[@]:0:5}")
fi
COUNT_INCLUDED=${#CLAUDE_FILES[@]}

# 拼接摘要
summary=""
for f in "${CLAUDE_FILES[@]}"; do
  rel="${f#$PROJECT_DIR/}"
  module=$(basename "$(dirname "$f")")
  # 提取 "## 技术栈" 节（限 10 行）
  tech=$(awk '/^## 技术栈/{f=1;next} /^## /{f=0} f' "$f" | head -10)
  if [ -n "$tech" ]; then
    summary+="### ${module} (${rel}):
${tech}

"
  else
    summary+="### ${module} (${rel}): (无 '技术栈' 节)

"
  fi
done

# 构造 additionalContext
omitted=""
if [ $COUNT_TOTAL -gt $COUNT_INCLUDED ]; then
  omitted="（还有 $((COUNT_TOTAL - COUNT_INCLUDED)) 个 CLAUDE.md 未注入，按需用 /mpdev:understand 重新理解）"
fi

context="## mpdev: 检测到 ${COUNT_INCLUDED} 个模块 CLAUDE.md ${omitted}

${summary}
（可调 /mpdev:understand 重新生成或更新；/mpdev:dev 启动跨模块开发主流程。）"

output_additional_context "SessionStart" "$context"
