#!/usr/bin/env bash
# post-subagent-check.sh — mpdev SubagentStop hook
#
# 触发: subagent 跑完
# 输入: stdin JSON; 兼容 3 种可能字段名（.subagent_response/.output/.response）
# 输出: hookSpecificOutput with additionalContext (cross_module_issue 命中) 或 {}

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

check_disabled

# 读 stdin → 提取响应字段
STDIN=$(cat)
RESPONSE=""

# 优先用 jq（如果可用）
if command -v jq >/dev/null 2>&1; then
  RESPONSE=$(echo "$STDIN" | jq -r '.subagent_response // .output // .response // ""' 2>/dev/null || echo "")
fi

# 如果 jq 提取为空，则假设 stdin 本身就是纯文本响应内容
if [ -z "$RESPONSE" ]; then
  RESPONSE="$STDIN"
fi

# 提取 cross_module_issue 字段
ISSUE=$(echo "$RESPONSE" | grep -E 'cross_module_issue:[[:space:]]*[^[:space:]]' | head -1)
[ -z "$ISSUE" ] && { echo "{}"; exit 0; }

# null / "" / 空值 → 跳过
if echo "$ISSUE" | grep -qE 'cross_module_issue:[[:space:]]*(null|""|\s*$)'; then
  echo "{}"
  exit 0
fi

# 解析 value（移除 cross_module_issue 前缀和尾部 JSON 标点）
DESC=$(echo "$ISSUE" | sed -E 's/cross_module_issue:[[:space:]]*//; s/^"//; s/"[,}].*$//; s/^[[:space:]]*//')

# 启发式抽模块名（匹配常见 mpdev 模块命名，优先最后提到的）
TARGET=$(echo "$DESC" | grep -oE '\b(java|vue|dispatch|analytics|algor|h5|pad|web|frontend|backend)\b' | tail -1)

# 构造 additionalContext
if [ -n "$TARGET" ]; then
  suggestion="

建议下一步：\`/mpdev:fix ${TARGET} <bug 描述>\`"
else
  suggestion="

建议检查 cross_module_issue 涉及的模块，跑 \`/mpdev:fix <module> <bug>\`。"
fi

context="## 跨模块影响提示

上一步 impl agent 反馈跨模块影响：
> ${DESC}
${suggestion}"

output_additional_context "SubagentStop" "$context"
