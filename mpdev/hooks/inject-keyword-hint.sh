#!/usr/bin/env bash
# inject-keyword-hint.sh — mpdev UserPromptSubmit hook
#
# 触发: 用户提交 prompt
# 输入: stdin JSON with .prompt
# 输出: hookSpecificOutput with systemMessage (命中时) 或 {} (未命中)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

check_disabled

# 读 stdin → .prompt
if command -v jq >/dev/null 2>&1; then
  PROMPT=$(cat | jq -r '.prompt // ""')
else
  PROMPT=$(cat | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# 已在用 /mpdev:* 命令 → 跳过自我推荐
if echo "$PROMPT" | grep -q '^/mpdev:'; then
  echo "{}"
  exit 0
fi

# Helper 函数: 检查是否匹配任意关键词并返回
check_and_output() {
  local cmd="$1"
  shift
  # 检查 prompt 是否包含任意传入的关键词
  for keyword in "$@"; do
    if echo "$PROMPT" | grep -q "$keyword"; then
      msg="💡 检测到与 \`/mpdev:${cmd}\` 相关的关键词。如果想用 mpdev 工作流处理，可以试试：

\`\`\`
/mpdev:${cmd} <补充信息>
\`\`\`

（继续当前对话不受影响）"
      output_system_message "UserPromptSubmit" "$msg"
      exit 0
    fi
  done
}

# 按顺序检查关键词 → 命令映射
check_and_output "fix" "修.*bug" "fix.*bug" "NPE" "空指针" "异常" "报错" "stacktrace"
check_and_output "dev" "新.*需求" "新功能" "增加.*字段" "加.*接口" "加.*表" "新.*API"
check_and_output "understand" "理解.*项目" "新项目" "没有 CLAUDE" "代码不熟" "看不懂"
check_and_output "env" "启动.*服务" "起.*环境" "环境.*状态" "重启.*服务"
check_and_output "test" "写.*测试" "加.*测试" "测试覆盖" "test case"
check_and_output "check" "检查.*契约" "跨模块.*一致" "联调" "契约.*漂移"
check_and_output "commit" "生成 commit" "提交.*说明" "改了什么" "commit message"

echo "{}"
