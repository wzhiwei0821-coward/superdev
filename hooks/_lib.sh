#!/usr/bin/env bash
# hooks/_lib.sh — 共享工具，被 3 个 hook source
# 设计原则：fail-silent，绝不阻塞会话；只读不写

# 用户禁用 → 立即返回 {} 并 exit 0
check_disabled() {
  if [ -n "$MPDEV_NO_HOOKS" ]; then
    echo "{}"
    exit 0
  fi
}

# 找项目根（Claude Code 注入 CLAUDE_PROJECT_DIR；fallback 到 PWD）
get_project_dir() {
  echo "${CLAUDE_PROJECT_DIR:-$PWD}"
}

# 从文件提取 YAML frontmatter 块（首个 --- ~ --- 之间）
extract_frontmatter() {
  awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$1"
}

# 从 frontmatter / markdown 抽取指定 key 的值
get_yaml_field() {
  local content="$1"
  local key="$2"
  echo "$content" | grep -E "^${key}:" | head -1 | sed -E "s/^${key}:[[:space:]]*//; s/^['\"]//; s/['\"]$//"
}

# 输出 hookSpecificOutput JSON（用 jq 优先；jq 不可用退化）
output_additional_context() {
  local event_name="$1"
  local ctx="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg event "$event_name" --arg ctx "$ctx" '{
      hookSpecificOutput: {
        hookEventName: $event,
        additionalContext: $ctx
      }
    }'
  else
    local esc_ctx
    esc_ctx=$(echo "$ctx" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}')
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"${event_name}\",\"additionalContext\":\"${esc_ctx}\"}}"
  fi
}

# 输出 hookSpecificOutput JSON with systemMessage（同上但 message 显式给用户）
output_system_message() {
  local event_name="$1"
  local msg="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg event "$event_name" --arg msg "$msg" '{
      hookSpecificOutput: {
        hookEventName: $event,
        systemMessage: $msg
      }
    }'
  else
    local esc_msg
    esc_msg=$(echo "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}')
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"${event_name}\",\"systemMessage\":\"${esc_msg}\"}}"
  fi
}
