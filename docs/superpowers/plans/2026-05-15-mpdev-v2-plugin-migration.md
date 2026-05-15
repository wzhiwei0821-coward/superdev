# mpdev v2.0.0 Plugin Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 mpdev 从 v1.x「项目级 `.claude/` 复制」模式迁到 v2.0.0「Claude Code Plugin」模式，drop `mpdev-` 命令前缀，4 个框架 agent 进 plugin，templates 路径用 `${CLAUDE_PLUGIN_ROOT}`。

**Architecture:** 新建 `superdev/mpdev/` 顶级目录，平铺 `commands/ templates/ agents/ docs/`，加 `.claude-plugin/{plugin,marketplace}.json` 标准 manifest。旧仓 `mpdev-suite/` 保留半年作为 v1.x 维护模式。

**Tech Stack:** Claude Code Plugin manifest schema; Bash + PowerShell installers; Markdown skill files; sed/grep 批量替换。

**Spec:** [`docs/superpowers/specs/2026-05-15-mpdev-v2-plugin-migration.md`](../specs/2026-05-15-mpdev-v2-plugin-migration.md)

---

## File Structure

### 新增（v2 plugin payload，位于 `superdev/mpdev/`）

| 路径 | 责任 | 来源 |
|------|------|------|
| `.claude-plugin/plugin.json` | Plugin manifest（name/version/keywords） | 新写 |
| `.claude-plugin/marketplace.json` | Marketplace manifest（self-hosted） | 新写 |
| `commands/{dev,fix,understand,init,env,test,check,commit,contracts}.md` | 9 个 slash 命令 | 从 v1 `mpdev-suite/.claude/commands/mpdev-*.md` 平移 + 重命名 + 路径改写 |
| `templates/` 整树 | 模板（dialects/test-flavors/understand/runtime-probe + 7 .tmpl） | 从 v1 `mpdev-suite/.claude/templates/` 整体拷贝 |
| `agents/{code-reviewer,integration-checker,acceptance-reviewer,doc-refresher}.md` | 4 个框架级 shared agent | 新写（v1 中无实体文件） |
| `docs/{MPDev-Scheme,workflow,quickstart,upgrade-guide,troubleshooting}.md` | 5 个用户文档 | 2 个平移 + 3 个新写 |
| `bin/install.sh` + `install.ps1` | plugin 一键安装脚本 | 新写（参考 mppm bin/install.sh） |
| `scripts/migrate-from-v1.sh` + `migrate-from-v1.ps1` | v1.x 项目迁 v2 辅助脚本 | 新写 |
| `VERSION` | `2.0.0` | 新写 |
| `CHANGELOG.md` | 含 `[2.0.0]` 段 | 新写 |
| `README.md` | plugin 风格 README | 新写（参考 mppm README） |
| `LICENSE` | MIT | 新写 |

### 修改（v1 仓库 `superdev/mpdev-suite/`）

| 路径 | 修改内容 |
|------|----------|
| `mpdev-suite/README.md` | 顶部加 deprecation 提示 + 指向 v2 |
| `mpdev-suite/CHANGELOG.md` | 加 `[1.3.1] 维护模式公告` 段 |

---

## Task 1: 建 mpdev/ 顶级目录 + plugin.json

**Files:**
- Create: `mpdev/.claude-plugin/plugin.json`

- [ ] **Step 1: 建顶级目录**

```bash
cd F:/claude/superdev && mkdir -p mpdev/.claude-plugin
```

- [ ] **Step 2: 写 plugin.json**

写入 `mpdev/.claude-plugin/plugin.json`：

```json
{
  "$schema": "https://json.schemastore.org/claude-code-plugin-manifest.json",
  "name": "mpdev",
  "version": "2.0.0",
  "description": "多模块 AI 协同开发框架 — 9 个 /mpdev:* 命令 + 13 个 AI agent 覆盖『理解项目 → 提取契约 → 框架初始化 → 开发 → 测试 → 修复 → 提交』全生命周期",
  "author": {
    "name": "wzhiwei0821-coward"
  },
  "license": "MIT",
  "keywords": [
    "multi-module",
    "ai-coding",
    "code-review",
    "contract-driven",
    "chinese",
    "workflow"
  ]
}
```

- [ ] **Step 3: 验证 JSON 合法**

```bash
cd F:/claude/superdev && python -c "import json; json.load(open('mpdev/.claude-plugin/plugin.json'))" && echo "json ok"
```

Expected: `json ok`

- [ ] **Step 4: 提交**

```bash
cd F:/claude/superdev && git add mpdev/.claude-plugin/plugin.json && git commit -m "feat(v2): add plugin.json manifest

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: marketplace.json

**Files:**
- Create: `mpdev/.claude-plugin/marketplace.json`

- [ ] **Step 1: 写 marketplace.json**

写入 `mpdev/.claude-plugin/marketplace.json`：

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "mpdev",
  "owner": {
    "name": "wzhiwei0821-coward"
  },
  "metadata": {
    "description": "多模块 AI 协同开发框架 plugin — Claude Code 标准化分发",
    "version": "2.0.0"
  },
  "plugins": [
    {
      "name": "mpdev",
      "source": "./",
      "description": "9 个 /mpdev:* 命令 + 4 个框架 agent + 5 个 runtime probe + 13 个 AI agent 模板",
      "category": "dev-tools",
      "tags": ["multi-module", "ai-coding", "code-review", "contract-driven", "chinese"],
      "strict": false
    }
  ]
}
```

- [ ] **Step 2: 验证 JSON**

```bash
cd F:/claude/superdev && python -c "import json; json.load(open('mpdev/.claude-plugin/marketplace.json'))" && echo "json ok"
```

Expected: `json ok`

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev/.claude-plugin/marketplace.json && git commit -m "feat(v2): add marketplace.json manifest

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 平移 templates/ 整树

**Files:**
- Create: `mpdev/templates/**` (从 `mpdev-suite/.claude/templates/` 拷贝)

- [ ] **Step 1: 递归拷贝**

```bash
cd F:/claude/superdev && cp -r mpdev-suite/.claude/templates mpdev/templates
```

- [ ] **Step 2: 验证拷贝完整**

```bash
cd F:/claude/superdev && \
  echo "v1 count:" && find mpdev-suite/.claude/templates -type f | wc -l && \
  echo "v2 count:" && find mpdev/templates -type f | wc -l
```

Expected: 两个数字相等（应是 27：7 .tmpl + 4 dialects + 7 test-flavors + 6 understand/references + 5 runtime-probe + 2 README ≈ 27）

- [ ] **Step 3: 验证 5 个探针文件存在**

```bash
cd F:/claude/superdev && ls mpdev/templates/runtime-probe/
```

Expected: README.md / probe-browser.md / probe-db.md / probe-http.md / probe-ws.md

- [ ] **Step 4: 提交**

```bash
cd F:/claude/superdev && git add mpdev/templates && git commit -m "feat(v2): copy templates/ from v1.3.0

整个 templates/ 树（dialects/test-flavors/understand/runtime-probe + 7 .tmpl）从 v1 平移到 v2。内容不动，仅位置上移一层（去掉 .claude/ 包裹）。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: VERSION + LICENSE

**Files:**
- Create: `mpdev/VERSION`
- Create: `mpdev/LICENSE`

- [ ] **Step 1: VERSION**

写入 `mpdev/VERSION`（单行，无尾换行）：

```
2.0.0
```

- [ ] **Step 2: LICENSE (MIT)**

写入 `mpdev/LICENSE`：

```
MIT License

Copyright (c) 2026 wzhiwei0821-coward

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev/VERSION mpdev/LICENSE && git commit -m "feat(v2): VERSION 2.0.0 + LICENSE MIT

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 验证 plugin 骨架

**Files:** 无修改

- [ ] **Step 1: 目录树检查**

```bash
cd F:/claude/superdev && find mpdev -maxdepth 2 -type d | sort
```

Expected:
```
mpdev
mpdev/.claude-plugin
mpdev/templates
mpdev/templates/dialects
mpdev/templates/runtime-probe
mpdev/templates/test-flavors
mpdev/templates/understand
```

- [ ] **Step 2: 顶级文件**

```bash
cd F:/claude/superdev && ls mpdev/
```

Expected: 含 `.claude-plugin/` `templates/` `VERSION` `LICENSE`（4 项，其他后续 task 加）

- [ ] **Step 3: git log 检查**

```bash
cd F:/claude/superdev && git log --oneline | head -5
```

Expected: 最近 4 个 commit 都是 `feat(v2):` 前缀

---

## Task 6: commands/dev.md (从 mpdev.md 平移 — 主流程)

**Files:**
- Create: `mpdev/commands/dev.md`
- Source: `mpdev-suite/.claude/commands/mpdev.md`

- [ ] **Step 1: 创建 commands 目录 + 拷贝源文件**

```bash
cd F:/claude/superdev && mkdir -p mpdev/commands && cp mpdev-suite/.claude/commands/mpdev.md mpdev/commands/dev.md
```

- [ ] **Step 2: 改 frontmatter `name` 字段**

Edit `mpdev/commands/dev.md`：
- old_string: `name: mpdev`
- new_string: `name: dev`

如果 frontmatter 的 `name` 字段不是 `name: mpdev`（可能写法不同），先 `grep -n "^name:" mpdev/commands/dev.md` 查看实际内容，再相应替换。

- [ ] **Step 3: 替换 `/mpdev-<verb>` 引用为 `/mpdev:<verb>`**

```bash
cd F:/claude/superdev && sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/commands/dev.md
```

- [ ] **Step 4: 替换裸 `/mpdev`（主流程引用）为 `/mpdev:dev`**

用 perl 因为需要负向 lookahead 防止已替换的被改两次：

```bash
cd F:/claude/superdev && perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/commands/dev.md
```

- [ ] **Step 5: 替换 templates 路径**

```bash
cd F:/claude/superdev && sed -i 's|\.claude/templates/|${CLAUDE_PLUGIN_ROOT}/templates/|g' mpdev/commands/dev.md
```

- [ ] **Step 6: 验证替换正确**

```bash
cd F:/claude/superdev && \
  echo "remaining /mpdev- refs (should be 0):" && \
  grep -c "/mpdev-" mpdev/commands/dev.md && \
  echo "new /mpdev: refs (should be > 0):" && \
  grep -c "/mpdev:" mpdev/commands/dev.md && \
  echo "templates refs (should be 0 .claude/templates/):" && \
  grep -c "\.claude/templates/" mpdev/commands/dev.md && \
  echo "name frontmatter:" && \
  grep "^name:" mpdev/commands/dev.md
```

Expected:
- `/mpdev-` count = 0
- `/mpdev:` count > 0 (likely 30+)
- `.claude/templates/` count = 0
- `name: dev`

- [ ] **Step 7: 提交**

```bash
cd F:/claude/superdev && git add mpdev/commands/dev.md && git commit -m "feat(v2): commands/dev.md (was mpdev.md main workflow)

主流程命令重命名 mpdev → dev。drop mpdev- 前缀，所有交叉引用替换。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: commands/fix.md

**Files:**
- Create: `mpdev/commands/fix.md`
- Source: `mpdev-suite/.claude/commands/mpdev-fix.md`

- [ ] **Step 1: 拷贝 + 重命名**

```bash
cd F:/claude/superdev && cp mpdev-suite/.claude/commands/mpdev-fix.md mpdev/commands/fix.md
```

- [ ] **Step 2: 改 frontmatter name**

```bash
cd F:/claude/superdev && sed -i 's|^name: mpdev-fix$|name: fix|' mpdev/commands/fix.md
```

- [ ] **Step 3: 批量替换 4 类**

```bash
cd F:/claude/superdev && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/commands/fix.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/commands/fix.md && \
  sed -i 's|\.claude/templates/|${CLAUDE_PLUGIN_ROOT}/templates/|g' mpdev/commands/fix.md
```

- [ ] **Step 4: 验证**

```bash
cd F:/claude/superdev && \
  echo "/mpdev- count (0?):" && grep -c "/mpdev-" mpdev/commands/fix.md && \
  echo "/mpdev: count (>0?):" && grep -c "/mpdev:" mpdev/commands/fix.md && \
  echo ".claude/templates/ count (0?):" && grep -c "\.claude/templates/" mpdev/commands/fix.md && \
  grep "^name:" mpdev/commands/fix.md
```

Expected: `/mpdev-` = 0, `/mpdev:` > 0, `.claude/templates/` = 0, name = fix

- [ ] **Step 5: 提交**

```bash
cd F:/claude/superdev && git add mpdev/commands/fix.md && git commit -m "feat(v2): commands/fix.md (was mpdev-fix.md)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: commands/understand.md

**Files:**
- Create: `mpdev/commands/understand.md`
- Source: `mpdev-suite/.claude/commands/mpdev-understand.md`

- [ ] **Step 1: 拷贝 + 重命名**

```bash
cd F:/claude/superdev && cp mpdev-suite/.claude/commands/mpdev-understand.md mpdev/commands/understand.md
```

- [ ] **Step 2: 改 frontmatter name**

```bash
cd F:/claude/superdev && sed -i 's|^name: mpdev-understand$|name: understand|' mpdev/commands/understand.md
```

- [ ] **Step 3: 批量替换**

```bash
cd F:/claude/superdev && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/commands/understand.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/commands/understand.md && \
  sed -i 's|\.claude/templates/|${CLAUDE_PLUGIN_ROOT}/templates/|g' mpdev/commands/understand.md
```

- [ ] **Step 4: 验证**

```bash
cd F:/claude/superdev && \
  grep -c "/mpdev-" mpdev/commands/understand.md && \
  grep -c "\.claude/templates/" mpdev/commands/understand.md && \
  grep "^name:" mpdev/commands/understand.md
```

Expected: 0 / 0 / `name: understand`

- [ ] **Step 5: 提交**

```bash
cd F:/claude/superdev && git add mpdev/commands/understand.md && git commit -m "feat(v2): commands/understand.md (was mpdev-understand.md)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: commands/init.md

**Files:**
- Create: `mpdev/commands/init.md`
- Source: `mpdev-suite/.claude/commands/mpdev-init.md`

- [ ] **Step 1: 拷贝 + 重命名**

```bash
cd F:/claude/superdev && cp mpdev-suite/.claude/commands/mpdev-init.md mpdev/commands/init.md
```

- [ ] **Step 2: 改 frontmatter name + 批量替换**

```bash
cd F:/claude/superdev && \
  sed -i 's|^name: mpdev-init$|name: init|' mpdev/commands/init.md && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/commands/init.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/commands/init.md && \
  sed -i 's|\.claude/templates/|${CLAUDE_PLUGIN_ROOT}/templates/|g' mpdev/commands/init.md
```

- [ ] **Step 3: 改 Step 10 — 4 个框架 agent 不再生成（plugin 自带）**

`/mpdev:init` 旧 Step 10 写「复制/保留通用 Agent」生成 4 个框架 agent。v2 改为「plugin 已自带，跳过」。

Use Edit tool on `mpdev/commands/init.md`:

old_string:
```
### Step 10：复制/保留通用 Agent

以下 4 个 agent 直接保留或从模板复制（几乎完全通用）：
- `.claude/agents/code-reviewer.md`
- `.claude/agents/integration-checker.md`
- `.claude/agents/acceptance-reviewer.md`
- `.claude/agents/doc-refresher.md`（**v1.1.0 新增**，用于 `/mpdev:dev` Step 12.5 文档增量刷新）

如果这些文件已存在，保留不覆盖。
如果不存在，从当前项目的已有版本复制（它们是通用的）。
```

new_string:
```
### Step 10：通用 Agent 由 plugin 自带（v2.0.0 起）

以下 4 个框架级 agent 由 mpdev plugin 自带（位于 `${CLAUDE_PLUGIN_ROOT}/agents/`），**本步骤不生成、不复制**：

- `code-reviewer`（plugin 自带）
- `integration-checker`（plugin 自带）
- `acceptance-reviewer`（plugin 自带）
- `doc-refresher`（plugin 自带）

调用方式不变：仍是 `Agent(subagent_type="code-reviewer", ...)`。Claude Code 会先查项目 `.claude/agents/<name>.md`，再回退到 plugin `agents/<name>.md`。

**项目级 override**：用户在 `.claude/agents/code-reviewer.md` 等位置写自定义内容会优先于 plugin 自带版本。

**v1 项目迁移注意**：v1 在 `.claude/agents/` 下生成过这 4 个 agent。可手动删除让 plugin 接管（推荐），或保留用项目自定义版本。
```

- [ ] **Step 4: 同步改 Step 12 输出汇总里的"生成的文件"列表**

old_string:
```
- .claude/agents/code-reviewer.md ← 通用（保留/复制）
- .claude/agents/integration-checker.md ← 通用（保留/复制）
- .claude/agents/acceptance-reviewer.md ← 通用（保留/复制）
- .claude/agents/doc-refresher.md ← 通用（保留/复制；v1.1.0 新增）
```

new_string:
```
- (code-reviewer / integration-checker / acceptance-reviewer / doc-refresher 由 plugin 自带，本命令不生成)
```

- [ ] **Step 5: 验证**

```bash
cd F:/claude/superdev && \
  grep -c "/mpdev-" mpdev/commands/init.md && \
  grep -c "\.claude/templates/" mpdev/commands/init.md && \
  echo "framework agents removed from generation list:" && \
  grep -c "← 通用（保留/复制）" mpdev/commands/init.md
```

Expected: 0 / 0 / 0（最后一条说明已删完）

- [ ] **Step 6: 提交**

```bash
cd F:/claude/superdev && git add mpdev/commands/init.md && git commit -m "feat(v2): commands/init.md — drop 4 framework agent generation

Step 10 改为说明 4 个框架 agent 由 plugin 自带（${CLAUDE_PLUGIN_ROOT}/agents/）；/mpdev:init 仅生成项目特化的 9 个 impl agent。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: commands/env.md

**Files:**
- Create: `mpdev/commands/env.md`

- [ ] **Step 1: 拷贝 + 批量替换**

```bash
cd F:/claude/superdev && \
  cp mpdev-suite/.claude/commands/mpdev-env.md mpdev/commands/env.md && \
  sed -i 's|^name: mpdev-env$|name: env|' mpdev/commands/env.md && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/commands/env.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/commands/env.md && \
  sed -i 's|\.claude/templates/|${CLAUDE_PLUGIN_ROOT}/templates/|g' mpdev/commands/env.md
```

- [ ] **Step 2: 验证**

```bash
cd F:/claude/superdev && \
  grep -c "/mpdev-" mpdev/commands/env.md && \
  grep "^name:" mpdev/commands/env.md
```

Expected: 0 / `name: env`

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev/commands/env.md && git commit -m "feat(v2): commands/env.md (was mpdev-env.md)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: commands/test.md

**Files:**
- Create: `mpdev/commands/test.md`

- [ ] **Step 1: 拷贝 + 替换**

```bash
cd F:/claude/superdev && \
  cp mpdev-suite/.claude/commands/mpdev-test.md mpdev/commands/test.md && \
  sed -i 's|^name: mpdev-test$|name: test|' mpdev/commands/test.md && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/commands/test.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/commands/test.md && \
  sed -i 's|\.claude/templates/|${CLAUDE_PLUGIN_ROOT}/templates/|g' mpdev/commands/test.md
```

- [ ] **Step 2: 验证**

```bash
cd F:/claude/superdev && grep -c "/mpdev-" mpdev/commands/test.md && grep "^name:" mpdev/commands/test.md
```

Expected: 0 / `name: test`

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev/commands/test.md && git commit -m "feat(v2): commands/test.md (was mpdev-test.md)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: commands/check.md

**Files:**
- Create: `mpdev/commands/check.md`

- [ ] **Step 1: 拷贝 + 替换**

```bash
cd F:/claude/superdev && \
  cp mpdev-suite/.claude/commands/mpdev-check.md mpdev/commands/check.md && \
  sed -i 's|^name: mpdev-check$|name: check|' mpdev/commands/check.md && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/commands/check.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/commands/check.md && \
  sed -i 's|\.claude/templates/|${CLAUDE_PLUGIN_ROOT}/templates/|g' mpdev/commands/check.md
```

- [ ] **Step 2: 验证**

```bash
cd F:/claude/superdev && grep -c "/mpdev-" mpdev/commands/check.md && grep "^name:" mpdev/commands/check.md
```

Expected: 0 / `name: check`

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev/commands/check.md && git commit -m "feat(v2): commands/check.md (was mpdev-check.md)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: commands/commit.md

**Files:**
- Create: `mpdev/commands/commit.md`

- [ ] **Step 1: 拷贝 + 替换**

```bash
cd F:/claude/superdev && \
  cp mpdev-suite/.claude/commands/mpdev-commit.md mpdev/commands/commit.md && \
  sed -i 's|^name: mpdev-commit$|name: commit|' mpdev/commands/commit.md && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/commands/commit.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/commands/commit.md && \
  sed -i 's|\.claude/templates/|${CLAUDE_PLUGIN_ROOT}/templates/|g' mpdev/commands/commit.md
```

- [ ] **Step 2: 验证 + 提交**

```bash
cd F:/claude/superdev && \
  grep -c "/mpdev-" mpdev/commands/commit.md && \
  grep "^name:" mpdev/commands/commit.md && \
  git add mpdev/commands/commit.md && \
  git commit -m "feat(v2): commands/commit.md (was mpdev-commit.md)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

Expected: 0 / `name: commit`

---

## Task 14: commands/contracts.md

**Files:**
- Create: `mpdev/commands/contracts.md`

- [ ] **Step 1: 拷贝 + 替换**

```bash
cd F:/claude/superdev && \
  cp mpdev-suite/.claude/commands/mpdev-contracts.md mpdev/commands/contracts.md && \
  sed -i 's|^name: mpdev-contracts$|name: contracts|' mpdev/commands/contracts.md && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/commands/contracts.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/commands/contracts.md && \
  sed -i 's|\.claude/templates/|${CLAUDE_PLUGIN_ROOT}/templates/|g' mpdev/commands/contracts.md
```

- [ ] **Step 2: 验证 + 提交**

```bash
cd F:/claude/superdev && \
  grep -c "/mpdev-" mpdev/commands/contracts.md && \
  grep "^name:" mpdev/commands/contracts.md && \
  git add mpdev/commands/contracts.md && \
  git commit -m "feat(v2): commands/contracts.md (was mpdev-contracts.md)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

Expected: 0 / `name: contracts`

---

## Task 15: 9 个命令文件交叉验证

**Files:** 无修改

- [ ] **Step 1: 全部命令文件确认无残留**

```bash
cd F:/claude/superdev && \
  echo "=== /mpdev- (should all be 0) ===" && \
  for f in mpdev/commands/*.md; do echo "$(basename $f): $(grep -c '/mpdev-' $f)"; done && \
  echo "=== .claude/templates/ (should all be 0) ===" && \
  for f in mpdev/commands/*.md; do echo "$(basename $f): $(grep -c '.claude/templates/' $f)"; done
```

Expected: 所有 18 行（9 文件 × 2 检查）右边都是 `0`

- [ ] **Step 2: 9 个命令文件 name 确认**

```bash
cd F:/claude/superdev && grep -h "^name:" mpdev/commands/*.md | sort
```

Expected:
```
name: check
name: commit
name: contracts
name: dev
name: env
name: fix
name: init
name: test
name: understand
```

- [ ] **Step 3: ${CLAUDE_PLUGIN_ROOT}/templates/ 引用数**

```bash
cd F:/claude/superdev && grep -rc "\${CLAUDE_PLUGIN_ROOT}/templates/" mpdev/commands/
```

Expected: 至少 fix.md / understand.md 有 ≥ 1（其他命令引用模板的话也算）

- [ ] **Step 4: /mpdev: 类引用统计**

```bash
cd F:/claude/superdev && grep -rc "/mpdev:" mpdev/commands/ | grep -v ":0$"
```

Expected: 大部分命令文件有 ≥ 1 引用（特别是 dev.md 应该 ≥ 20 个，因为主流程引用各个子命令）

---

## Task 16: agents/code-reviewer.md

**Files:**
- Create: `mpdev/agents/code-reviewer.md`

- [ ] **Step 1: 建 agents 目录 + 写文件**

```bash
cd F:/claude/superdev && mkdir -p mpdev/agents
```

写入 `mpdev/agents/code-reviewer.md`：

```markdown
---
name: code-reviewer
description: 通用代码审查 agent。在 /mpdev:fix 修复完成后、/mpdev:dev 主流程 Step 12 触发，对照修复前后 diff 做质量审查，输出 Strengths / Issues / Assessment。
allowed-tools: Read, Grep, Glob, Bash
---

# code-reviewer — 通用代码审查

## 职责

对一组改动（commit 或 diff range）做代码质量审查。**不修复，只评估**。

## 何时被调用

- `/mpdev:fix` Step 5 — 修复完成后、生成报告前
- `/mpdev:dev` Step 12 — impl agent 出代码后、commit 前
- 用户手动 `Agent(subagent_type="code-reviewer", ...)`

## 输入（调用方提供）

| 字段 | 必填 | 含义 |
|------|------|------|
| `description` | 是 | 一句话描述本次改动目标（如 "修 TaskService NPE"）|
| `requirements` | 否 | 原始需求 / 修复 bug 描述 / spec 引用 |
| `base_sha` | 否 | 改动前的 commit SHA（默认 HEAD~1）|
| `head_sha` | 否 | 改动后的 commit SHA（默认 HEAD）|
| `scope` | 否 | 重点审查范围（如"仅 Java 模块"），缺省审全部 diff |

## 步骤

### 1. 拉 diff

```
若 base_sha + head_sha 都给了 → Bash("git diff {base_sha}..{head_sha}")
否则 → Bash("git diff HEAD~1..HEAD")
若 diff 为空 → 返回 status=no-changes
```

### 2. 加载上下文

- Read 受影响模块的 `CLAUDE.md`（编码规范 / 字段约束 / 接口字段）
- 若 `description` 提到契约相关字段 → Read 契约文件
- 若 diff 涉及测试文件 → Grep 测试目录已有用例参考

### 3. 审查维度（按重要性）

| # | 维度 | 检查点 |
|---|------|--------|
| 1 | **正确性** | 是否解决了 description 描述的问题；是否引入新 bug |
| 2 | **副作用** | 是否改了不该改的代码（超出 scope）|
| 3 | **测试** | 测试是否覆盖核心路径；是否只测 happy path |
| 4 | **契约对齐** | 涉及跨模块字段时与 CLAUDE.md / 契约仓库是否一致 |
| 5 | **编码规范** | 命名 / 错误处理 / 日志 / 注释（按 CLAUDE.md 中的规范）|
| 6 | **可维护性** | 重复代码 / 过早抽象 / 难理解的命名 |

### 4. 输出格式

```yaml
status: approved | comment_only | request_changes
review_summary:
  strengths:
    - "..."
  issues:
    critical:    # 阻塞 merge
      - file: "src/...:42"
        issue: "未做 null 检查"
        suggestion: "..."
    important:   # 建议修
      - file: "..."
        issue: "..."
    minor:       # 风格 / nice-to-have
      - file: "..."
        issue: "..."
  assessment: "1-2 句总评"
files_reviewed: [...]
files_skipped: [...]   # 二进制 / 自动生成 / 不在 scope 内
```

## 约束

1. **只读不改**：本 agent 不调 Edit / Write 工具
2. **不审查不在 diff 中的代码**：除非为了上下文（往周围读 ±20 行）
3. **scope 优先**：若调用方限定 scope，scope 外的改动只 list 文件名不细审
4. **critical 必须能阻塞**：critical 级别的 issue 都应该是 merge 前必须修的（不是"建议"）
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/agents/code-reviewer.md && git commit -m "feat(v2): agents/code-reviewer.md (framework agent)

通用代码审查 agent，在 /mpdev:fix Step 5 + /mpdev:dev Step 12 被调用。输出 Strengths / Issues / Assessment 三档。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: agents/integration-checker.md

**Files:**
- Create: `mpdev/agents/integration-checker.md`

- [ ] **Step 1: 写文件**

写入 `mpdev/agents/integration-checker.md`：

```markdown
---
name: integration-checker
description: 跨模块契约一致性检查 agent。/mpdev:check 主调；/mpdev:dev Step 12 在涉及跨模块字段时触发。比对各模块 CLAUDE.md / 契约仓库 / 实际代码三者的字段定义是否一致。
allowed-tools: Read, Grep, Glob, Bash
---

# integration-checker — 跨模块契约一致性

## 职责

检查多模块项目中**契约字段**（MQ 事件 / REST API / DB 共享表 / 跨模块 DTO）是否在三个来源对齐：
1. **契约仓库**（contracts/ 或 robot-contracts/）— 权威定义
2. **各模块 CLAUDE.md** — 模块视角的描述
3. **实际代码** — 类 / 注解 / 字段名

任何一处不一致即标 drift。

## 何时被调用

- `/mpdev:check` 主流程
- `/mpdev:dev` Step 12 — 当 impl agent 改动涉及跨模块字段（架构师识别）
- 用户手动 `Agent(subagent_type="integration-checker", ...)`

## 输入

| 字段 | 必填 | 含义 |
|------|------|------|
| `contract_root` | 否 | 契约仓库路径（缺省自动探测 `contracts/` 或 `robot-contracts/`）|
| `modules` | 否 | 要检查的模块列表（缺省所有有 CLAUDE.md 的模块）|
| `focus_contracts` | 否 | 限定到某些契约（如 `["task.created", "TaskCreatedEvent"]`）；缺省全量 |

## 步骤

### 1. 探测契约源

```
若 contract_root 已传 → 用之
否则:
  Glob "contracts/" "robot-contracts/" → 取存在的
  若都不存在 → 单模块项目，跳过；返回 status=no-contract-repo
```

### 2. 列契约清单

```
读 {contract_root}/CLAUDE.md 的"契约总表"或 schemas/openapi/sql 目录
提取 contract_items[]:
  - type: rest_api | mq_event | shared_dto | db_table
  - name
  - fields: [{name, type, required, owner_module, consumer_modules}]
```

### 3. 模块侧对照

```
对每个 contract_item:
  对每个相关模块（owner + consumers）:
    Read 该模块 CLAUDE.md 的"⚠️ 接口字段"节
    查 contract_item 对应的字段定义
    若缺失 → 标 missing_in_module
    若字段名/类型/必填性不一致 → 标 drift
```

### 4. 代码侧对照

```
对每个有 drift 嫌疑的字段:
  Grep 模块代码（按语言）:
    - Java: @JsonProperty / private 字段
    - Python: TypedDict / @dataclass / pydantic Model
    - TypeScript: interface / type alias
  若代码字段与契约 / CLAUDE.md 不一致 → 标 code_drift
```

### 5. 输出

```yaml
status: aligned | drifted | no-contract-repo
drift_count: N
drifts:
  - contract: "task.created"
    field: "taskType"
    sources:
      contract_repo: {type: "String", required: true}
      java_module_claude: {type: "String", required: true}
      java_module_code: {type: "Integer", required: true}   # ← drift
      dispatch_module_claude: {type: "String", required: true}
    severity: critical | warning   # critical=类型不兼容；warning=可选性不一致
    suggestion: "代码或契约二选一，更新另一侧"
files_referenced: [...]
```

## 约束

1. **只读不改**
2. **only flag**：契约 0 命中时不报错，返 `status=no-contract-repo`
3. **drift 也分级**：类型不兼容（int vs String）是 critical；optional 标记不一致是 warning
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/agents/integration-checker.md && git commit -m "feat(v2): agents/integration-checker.md (framework agent)

跨模块契约一致性检查 agent，三源比对（contract / CLAUDE.md / 代码）。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: agents/acceptance-reviewer.md

**Files:**
- Create: `mpdev/agents/acceptance-reviewer.md`

- [ ] **Step 1: 写文件**

写入 `mpdev/agents/acceptance-reviewer.md`：

```markdown
---
name: acceptance-reviewer
description: 验收审查 agent。在 /mpdev:dev Step 13 主流程结尾、/mpdev:test 跑完后触发。对照原始需求 + 验收标准 + 测试结果做最终判定。
allowed-tools: Read, Grep, Glob, Bash
---

# acceptance-reviewer — 验收审查

## 职责

对一次完整的开发（/mpdev:dev 全流程）做最终验收判定。**面向需求**（不是面向代码）——核心问题：「**用户要的东西做出来了吗？**」

## 何时被调用

- `/mpdev:dev` Step 13 — 主流程末尾
- `/mpdev:test` 测试跑完后
- 用户手动 `Agent(subagent_type="acceptance-reviewer", ...)`

## 输入

| 字段 | 必填 | 含义 |
|------|------|------|
| `requirements` | 是 | 原始需求描述（/mpdev:dev 的 $ARGUMENTS）|
| `acceptance_criteria` | 否 | 验收标准列表（架构师在 Step 0.5 产出的；缺省时从需求推断）|
| `implementation_summary` | 否 | impl agent 们的产出汇总（变更文件 / 关键路径）|
| `test_results` | 否 | 测试结果（pass / fail / no_test 统计 + 覆盖率）|
| `mpdev_run_id` | 否 | 关联的 mpdev-runs/{run_id}/ 目录（用于读 02-13 全套文档）|

## 步骤

### 1. 准备验收清单

```
若 acceptance_criteria 已传 → 用之
否则:
  从 requirements 推断 3-7 条 SMART 标准:
    - Specific: 哪个功能
    - Measurable: 如何度量
    - Achievable: 现在能否验证
    - Relevant: 与需求相关
    - Time-bound: 当前迭代内
  示例条目:
    "新增 night_patrol 任务类型，前端下拉框可选，后端可创建并入库"
```

### 2. 逐条评估

```
对每条 acceptance criterion:
  评估状态:
    Met       — 完全满足
    Partial   — 部分满足（具体哪部分缺）
    Missed    — 没做或做错
    Untested  — 做了但没测
  
  评估依据:
    - 改动文件是否覆盖该条
    - 测试是否验证该条
    - 关键路径在 mpdev-runs/{run_id}/ 是否有文档支撑
```

### 3. 总评估

```
若全部 Met → status=accepted
若有任何 Missed → status=rejected, 列出阻塞条目
若部分 Partial / Untested → status=conditional, 列出条件 + 后续 action
```

### 4. 输出

```yaml
status: accepted | conditional | rejected
acceptance_criteria_evaluation:
  - criterion: "..."
    status: Met | Partial | Missed | Untested
    evidence:
      - file: "src/...:42"
      - test: "tests/...:NPE_test"
      - doc: "mpdev-runs/{run_id}/05-impl.md"
    gaps: "..."   # 仅 Partial/Missed/Untested
overall_assessment: "1-2 句"
recommendations:
  - "..."   # 如「dispatch 模块需补 night_patrol 入库测试用例」
follow_up_tasks: [...]   # 立即可操作的后续 action
```

## 约束

1. **不关心代码细节** — 那是 code-reviewer 的职责；本 agent 只关心"需求是否被满足"
2. **必须有证据** — Met 状态要能给出 file / test / doc 引用
3. **拒绝是可接受的** — status=rejected 比 status=accepted-but-missing-things 强，迫使后续闭环
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/agents/acceptance-reviewer.md && git commit -m "feat(v2): agents/acceptance-reviewer.md (framework agent)

验收审查 agent，面向需求做最终判定。逐条评估 acceptance criteria。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 19: agents/doc-refresher.md

**Files:**
- Create: `mpdev/agents/doc-refresher.md`

- [ ] **Step 1: 写文件**

写入 `mpdev/agents/doc-refresher.md`：

```markdown
---
name: doc-refresher
description: CLAUDE.md 增量刷新 agent。在 /mpdev:dev Step 12.5（v1.1.0 起）触发，把 impl 变更和契约新增条目机械化追加到各模块 CLAUDE.md 与契约仓 CLAUDE.md。
allowed-tools: Read, Edit, Grep, Glob, Bash
---

# doc-refresher — CLAUDE.md 增量刷新

## 职责

在一次 `/mpdev:dev` 完成后，自动**机械化追加**改动产生的可推导内容到 CLAUDE.md：

- 新增的 REST API endpoint → 各模块"⚠️ 接口字段"节
- 新增的 MQ 事件 → 同上
- 新增的 DB 表 / 字段 → "DB Schema"节
- 新增的契约条目 → 契约仓 CLAUDE.md"契约总表"

**只追加机械可推导的内容**。需要语义改写的（如重构后整段失效）一律跳过 + 落 TODO。

## 何时被调用

- `/mpdev:dev` Step 12.5（v1.1.0 起）— code-reviewer 通过后、Step 13 汇总前
- 不需要用户手动调

## 输入

| 字段 | 必填 | 含义 |
|------|------|------|
| `mpdev_run_id` | 是 | mpdev-runs/{run_id}/ 路径，含 02-12 全套文档 |
| `affected_modules` | 是 | 本次改动涉及的模块列表 |
| `git_diff_range` | 否 | base..head SHA（缺省 HEAD~1..HEAD）|
| `contract_root` | 否 | 契约仓库根（缺省自动探测）|

## 步骤

### 1. 拉变更摘要

```
Read mpdev-runs/{run_id}/02-architect.md → 接口字段变更
Read mpdev-runs/{run_id}/03-contract-design.md → 契约新条目
Read mpdev-runs/{run_id}/05-impl-*.md → 各模块 impl 报告
Bash("git diff --name-only {git_diff_range}") → 改动文件清单
```

### 2. 识别可机械化追加项

对每个变更，判断是「追加」还是「重写」：

```
可追加（继续）:
  - REST API: 新增 endpoint（CLAUDE.md 表格末尾加一行）
  - MQ event: 新增 event（"MQ 事件"节末尾加 schema）
  - DB column: 现有表加列（表格末尾加列）
  - 契约条目: 契约总表加行

需重写（跳过 + TODO）:
  - API endpoint 改名 / 删除
  - 字段类型变化（不是新增）
  - 模块拆分 / 合并
  - 任何"语义不变但表达需改"的情况
```

### 3. 追加到各模块 CLAUDE.md

```
对每个可追加项:
  定位目标 CLAUDE.md（按 affected_modules）
  Read 找目标章节（"⚠️ 接口字段" / "MQ 事件" / "DB Schema"）
  
  幂等检查: Grep 目标章节是否已含新条目（防重）
    若已存在 → 跳过，不报错
    若不存在 → Edit 在章节末尾追加
```

### 4. 追加到契约仓 CLAUDE.md

```
若 contract_root 存在:
  Read {contract_root}/CLAUDE.md
  对每个契约新条目（mpdev-runs/.../03-contract-design.md 出的）:
    定位"契约总表"
    幂等追加（同步骤 3 的检查）
```

### 5. 跳过项落 TODO

```
对每个需重写项:
  Read 目标模块的 TODO.md（缺省创建）
  Edit 追加:
    [doc-refresh YYYY-MM-DD run_id={run_id}] {跳过原因} — {建议手动改的位置}
```

### 6. 输出

```yaml
status: ok | partial | skipped
refreshed:
  - module: "java"
    file: "java/CLAUDE.md"
    section: "⚠️ 接口字段"
    additions: 2
  - file: "robot-contracts/CLAUDE.md"
    section: "契约总表"
    additions: 1
skipped_to_todo:
  - module: "vue"
    todo_file: "vue/TODO.md"
    reason: "API endpoint renamed, requires semantic rewrite"
git_diff_summary: "..."
```

## 约束

1. **追加幂等** — Edit 前必 Grep 检查目标行不存在
2. **不重写、不删除** — 任何修改性操作都跳过，落 TODO
3. **找不到目标章节 → 跳过 + TODO** — 不创建新章节（会破坏模块作者的文档结构）
4. **失败不阻塞主流程** — `/mpdev:dev` Step 12.5 不依赖本 agent 成功，失败时 warn 进 99-summary
5. **不动 schemas/openapi/sql 契约定义本身**（contract-designer 的领域）
6. **不动 EVENT_CATALOG.md / DATAFLOW.md**（需要 architect 视野）
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/agents/doc-refresher.md && git commit -m "feat(v2): agents/doc-refresher.md (framework agent)

v1.1.0 引入的文档增量刷新 agent，机械化追加 impl 变更到 CLAUDE.md。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 20: docs/ 平移 + 新增

**Files:**
- Create: `mpdev/docs/MPDev-Scheme.md` (从 v1 平移)
- Create: `mpdev/docs/workflow.md` (从 v1 平移)

- [ ] **Step 1: 建 docs 目录 + 拷贝**

```bash
cd F:/claude/superdev && \
  mkdir -p mpdev/docs && \
  cp mpdev-suite/.claude/MPDev-Scheme.md mpdev/docs/ && \
  cp mpdev-suite/.claude/mpdev-suite-workflow.md mpdev/docs/workflow.md
```

- [ ] **Step 2: 替换 docs 内的命令引用**

```bash
cd F:/claude/superdev && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/docs/MPDev-Scheme.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/docs/MPDev-Scheme.md && \
  sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' mpdev/docs/workflow.md && \
  perl -i -pe 's|/mpdev(?![-:a-z])|/mpdev:dev|g' mpdev/docs/workflow.md
```

- [ ] **Step 3: 验证**

```bash
cd F:/claude/superdev && \
  grep -c "/mpdev-" mpdev/docs/MPDev-Scheme.md && \
  grep -c "/mpdev-" mpdev/docs/workflow.md
```

Expected: 0 / 0

- [ ] **Step 4: 提交**

```bash
cd F:/claude/superdev && git add mpdev/docs/ && git commit -m "feat(v2): docs/MPDev-Scheme.md + workflow.md (平移)

从 mpdev-suite/.claude/ 平移 + 替换命令引用。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 21: docs/quickstart.md

**Files:**
- Create: `mpdev/docs/quickstart.md`

- [ ] **Step 1: 写文件**

写入 `mpdev/docs/quickstart.md`：

```markdown
# mpdev v2.0.0 5 分钟速览

新用户 5 分钟跑通第一个 mpdev 流程。

---

## 1. 安装（30 秒）

```bash
# 克隆并准备 plugin
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
```

脚本会引导你在 Claude Code 内跑 2 条命令：

```
/plugin marketplace add file://~/dev/mpdev
/plugin install mpdev@mpdev
```

**重启 Claude Code**。完成。

## 2. 验证（10 秒）

随便打开一个项目，在 Claude Code 输入 `/mpdev:`，应该自动补全 9 个命令：

```
/mpdev:check      /mpdev:commit     /mpdev:contracts
/mpdev:dev        /mpdev:env        /mpdev:fix
/mpdev:init       /mpdev:test       /mpdev:understand
```

看不到？看 [troubleshooting.md](./troubleshooting.md)。

## 3. 第一次跑（4 分钟）

新项目从空仓库开始（30 秒上手）：

```
# 在你的项目根
/mpdev:understand                    # 阶段 0a：生成各模块 CLAUDE.md（90 秒）
/mpdev:contracts                     # 阶段 0b：跨模块项目才需要（60 秒）
/mpdev:init                          # 阶段 1：生成项目特化 impl agent（30 秒）
/mpdev:dev "实现 night_patrol 任务类型"   # 阶段 2：开发（按需求复杂度，3-15 分钟）
```

## 4. 升级（10 秒）

```
/plugin update
```

完成。项目数据零影响。

## 5. 卸载（5 秒）

```
/plugin uninstall mpdev
```

项目里的 `.claude/agents/`、`.claude/mpdev-runs/`、`.claude/.mpdev-env-state.yml` 都不动——你的数据 100% 在你手里。

---

## 下一步

- 9 个命令的详细文档：[workflow.md](./workflow.md)
- 架构与角色设计：[MPDev-Scheme.md](./MPDev-Scheme.md)
- 从 v1.x 升级：[upgrade-guide.md](./upgrade-guide.md)
- 故障排查：[troubleshooting.md](./troubleshooting.md)
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/docs/quickstart.md && git commit -m "feat(v2): docs/quickstart.md (5 分钟速览)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 22: docs/upgrade-guide.md

**Files:**
- Create: `mpdev/docs/upgrade-guide.md`

- [ ] **Step 1: 写文件**

写入 `mpdev/docs/upgrade-guide.md`：

```markdown
# 从 mpdev v1.x 升级到 v2.0.0

v2.0.0 是 BREAKING 变更：命令命名、目录结构、安装方式全变了。本指南帮你迁。

---

## TL;DR

```bash
# 1. 装 v2 plugin（全局，一次性）
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
# 然后在 Claude Code 内:
/plugin marketplace add file://~/dev/mpdev
/plugin install mpdev@mpdev

# 2. 在老 v1 项目根跑迁移脚本
cd /path/to/old-project
bash ~/dev/mpdev/scripts/migrate-from-v1.sh

# 3. 重启 Claude Code，使用新命令名
/mpdev:fix vue 下拉框 bug    # 不再是 /mpdev-fix
```

---

## 主要变化对照

### 命令重命名

| v1.x | v2.x |
|------|------|
| `/mpdev` | `/mpdev:dev` |
| `/mpdev-fix` | `/mpdev:fix` |
| `/mpdev-understand` | `/mpdev:understand` |
| `/mpdev-init` | `/mpdev:init` |
| `/mpdev-env` | `/mpdev:env` |
| `/mpdev-test` | `/mpdev:test` |
| `/mpdev-check` | `/mpdev:check` |
| `/mpdev-commit` | `/mpdev:commit` |
| `/mpdev-contracts` | `/mpdev:contracts` |

CI 脚本批量替换：

```bash
# 注意顺序：先长再短，否则 /mpdev-fix 会被改成 /mpdev:dev-fix
sed -i 's|/mpdev-\([a-z]\+\)|/mpdev:\1|g' .ci/*.sh
sed -i -E 's|/mpdev([^-:a-z]\|$)|/mpdev:dev\1|g' .ci/*.sh
```

### 目录结构

| v1.x（项目里） | v2.x（项目里） |
|---------------|---------------|
| `.claude/commands/*.md` | （删除，plugin 接管）|
| `.claude/templates/*` | （删除，plugin 接管）|
| `.claude/MPDev-Scheme.md` | （删除，plugin 接管）|
| `.claude/mpdev-suite-workflow.md` | （删除，plugin 接管）|
| `.claude/README.md` | （删除，plugin 接管）|
| `.claude/.mpdev-version` | （删除，plugin 自带版本管理）|
| `.claude/agents/{impl-*,architect,...}.md` | **保留**（项目特化 agent）|
| `.claude/agents/{code-reviewer,integration-checker,acceptance-reviewer,doc-refresher}.md` | **可选保留**（项目优先 override） |
| `.claude/mpdev-runs/` | **保留**（运行历史）|
| `.claude/.mpdev-env-state.yml` | **保留** |
| `.claude/.mpdev-runtime-creds.yml` | **保留** |
| `.claude-notes/` | **保留** |
| `CLAUDE.md` | **保留** |

### 安装方式

| v1.x | v2.x |
|------|------|
| 每个项目跑一次 `install.sh` | 一次性全局装 `/plugin install mpdev@mpdev` |
| 升级跑 `update.sh`（三方合并）| `/plugin update` 一键 |
| 框架文件混在项目 `.claude/` | 框架在 `~/.claude/plugins/cache/`，项目零侵入 |

---

## 迁移步骤详解

### Step 1: 装 v2 plugin（一次性）

如 TL;DR 第 1 步。完成后任意项目都能用 `/mpdev:*`。

### Step 2: 在每个老 v1 项目跑 migrate-from-v1.sh

```bash
cd /path/to/old-v1-project
bash ~/dev/mpdev/scripts/migrate-from-v1.sh
```

脚本做的事：
1. 备份 `.claude/` 到 `.claude.v1-backup.{timestamp}/`
2. 删除 plugin 接管的文件：`commands/`、`templates/`、`MPDev-Scheme.md`、`mpdev-suite-workflow.md`、`README.md`、`.mpdev-version`
3. 保留项目数据：`agents/`、`mpdev-runs/`、`.mpdev-env-state.yml`、`.mpdev-runtime-creds.yml`

**框架 agent 处理（4 个）**：

迁移脚本默认保留 `.claude/agents/{code-reviewer,integration-checker,acceptance-reviewer,doc-refresher}.md`。这意味着：
- 项目用的是 v1 时期生成的版本（可能陈旧）
- v2 plugin 自带的版本被 override

推荐做法：在脚本完成后**手动删除** 4 个框架 agent，让 plugin 接管：

```bash
rm .claude/agents/code-reviewer.md
rm .claude/agents/integration-checker.md
rm .claude/agents/acceptance-reviewer.md
rm .claude/agents/doc-refresher.md
```

项目特化的 impl agent（java-impl.md / vue-impl.md / 等）**不要删**——这些是项目语境化的。

### Step 3: 重启 Claude Code

完全退出 + 重启（不仅是 `/clear`）。

### Step 4: 验证

```
/mpdev:        # 应见到 9 个命令自动补全
/mpdev:env status   # 看现有环境状态
```

### Step 5: 改 CI / 自动化脚本

任何调 `/mpdev-fix` 等命令的脚本都要改名。见 §命令重命名 的 sed 替换。

---

## 回滚

如果发现问题想回到 v1：

```bash
# 1. 卸载 v2 plugin
/plugin uninstall mpdev

# 2. 在项目根恢复 .claude/ 备份
cd /path/to/project
rm -rf .claude
mv .claude.v1-backup.{timestamp} .claude

# 3. 在 Claude Code 内重启
```

---

## v1.x 维护期限

mpdev-suite/ v1.x 进入维护模式（仅 bug fix，无新功能）。**预计 2026-11-15 归档**。

期间可用：
- `mpdev-suite/scripts/update.sh` 拉 v1.x 的 patch
- `mpdev-suite/scripts/install.sh` 给老项目装 v1（不推荐新项目用）

---

## 常见问题

**Q: 我有 10 个项目都跑过 /mpdev-init，迁移要在每个项目跑一次脚本？**
A: 是的，但每次只需 10 秒（备份 + 删几个文件）。或者写个 batch：`for p in projects/*/; do (cd $p && bash ~/dev/mpdev/scripts/migrate-from-v1.sh); done`

**Q: v1 项目里如果不迁移会怎么样？**
A: v1 `.claude/commands/` 还在，旧命令名 `/mpdev-fix` 仍可用（项目 .claude/ 的命令优先于 plugin）。但 v2 改进不会到这个项目。**不推荐长期混用**。

**Q: 同事 fork 了 mpdev-suite 改了一些内容，v2 怎么 fork？**
A: v2 用 plugin 模式，fork 体验是改 `superdev/mpdev/` 子目录后修改 `bin/install.sh` 中的 `MPDEV_SOURCE` 默认 URL。比 v1 简单。
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/docs/upgrade-guide.md && git commit -m "feat(v2): docs/upgrade-guide.md (v1→v2 迁移指南)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 23: docs/troubleshooting.md

**Files:**
- Create: `mpdev/docs/troubleshooting.md`

- [ ] **Step 1: 写文件**

写入 `mpdev/docs/troubleshooting.md`：

```markdown
# mpdev v2.0.0 故障排查

按症状索引。

---

## /mpdev: 自动补全没出现

可能原因：

1. **plugin 没装成功**
   ```bash
   /plugin list | grep mpdev
   ```
   没显示 → 重跑 `/plugin install mpdev@mpdev`

2. **Claude Code 没重启**
   `/plugin install` 后必须**完全退出**（不只是 /clear）+ 重新打开 Claude Code

3. **plugin 文件没落地**
   ```bash
   ls ~/.claude/plugins/cache/mpdev/mpdev/commands/
   ```
   应见 9 个 .md 文件。没有 → marketplace add 失败，重跑 `/plugin marketplace add file://~/dev/mpdev`

---

## 命令报"找不到模板"或"templates/runtime-probe/probe-X.md not found"

```bash
ls ~/.claude/plugins/cache/mpdev/mpdev/templates/runtime-probe/
```

应有 5 个文件（README + probe-{db,http,browser,ws}.md）。缺失 → `/plugin update` 拉新版。

---

## ${CLAUDE_PLUGIN_ROOT} 没被解析为实际路径

命令文档里写 `Read ${CLAUDE_PLUGIN_ROOT}/templates/...`，但 Claude 报"file not found"。

诊断：

```bash
# 在 Claude Code 内
ls $CLAUDE_PLUGIN_ROOT/templates/   # 应能 ls
```

如果 `$CLAUDE_PLUGIN_ROOT` 为空 → 重启 Claude Code（env 变量在 plugin context 加载时设置）。

兜底：手动告诉 Claude 路径——`Read ~/.claude/plugins/cache/mpdev/mpdev/templates/runtime-probe/probe-db.md`

---

## /mpdev:fix 报告里所有 verified=skipped

可能原因：
- 服务没在跑 → `/mpdev:env status` 查
- DB 凭据失效 → 编辑 `.claude/.mpdev-runtime-creds.yml`
- state.yml 不存在 → 先跑 `/mpdev:env start`

详见 `${CLAUDE_PLUGIN_ROOT}/templates/runtime-probe/probe-browser.md` 的容错节。

---

## 老 v1 项目自定义的 code-reviewer 仍在生效

v1 项目可能在 `.claude/agents/code-reviewer.md` 有内容。Claude Code agent 查找优先级：**项目优先 → plugin 兜底**。

想用 plugin 自带版：
```bash
rm .claude/agents/code-reviewer.md
```

想保留项目自定义：什么都不做（plugin 版被 override）。

---

## 命令调用时报"unknown subagent: code-reviewer"

不可能——plugin 自带这 4 个框架 agent。检查：

```bash
ls ~/.claude/plugins/cache/mpdev/mpdev/agents/
```

应有 code-reviewer.md / integration-checker.md / acceptance-reviewer.md / doc-refresher.md。缺失 → `/plugin update` 或重装 plugin。

---

## migrate-from-v1.sh 跑完后项目里啥都没了

迁移脚本永远先备份再删。看 `.claude.v1-backup.{timestamp}/`：

```bash
ls .claude.v1-backup.*
```

应该有备份。恢复：

```bash
rm -rf .claude
mv .claude.v1-backup.{timestamp} .claude
```

如果没有备份（脚本异常退出前）→ 翻 git 历史 `git stash list` 或 `git reflog`。

---

## /plugin update 后行为变了

`/plugin update` 拉了新版 plugin，可能引入了新 step 或改了已有 step。看 CHANGELOG：

```bash
cat ~/.claude/plugins/cache/mpdev/mpdev/CHANGELOG.md | head -50
```

不喜欢新版？回退：

```bash
cd ~/dev/mpdev && git log --oneline | head -5   # 找上个稳定 commit
cd ~/dev/mpdev && git checkout <previous-sha>
/plugin update    # 拉本地修改
```

---

## 还有其他问题

提 issue 时附：

```bash
# 收集诊断信息
cd ~/.claude/plugins/cache/mpdev/mpdev && cat VERSION
ls commands/
/plugin list | grep mpdev
```
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/docs/troubleshooting.md && git commit -m "feat(v2): docs/troubleshooting.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 24: bin/install.sh

**Files:**
- Create: `mpdev/bin/install.sh`

- [ ] **Step 1: 建 bin 目录 + 写文件**

```bash
cd F:/claude/superdev && mkdir -p mpdev/bin
```

写入 `mpdev/bin/install.sh`：

```bash
#!/usr/bin/env bash
#
# mpdev v2.0.0 Plugin 一键安装
# ============================
# Usage:
#   bash install.sh                       # 默认 GitHub 源
#   bash install.sh --target=~/dev/mpdev  # 自定义本地路径
#
# 一键 (curl):
#   bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
#

set -e

REPO_URL="${MPDEV_REPO:-https://github.com/wzhiwei0821-coward/superdev.git}"
SUBDIR="${MPDEV_SUBDIR:-mpdev}"
TARGET="${MPDEV_TARGET:-$HOME/dev/mpdev}"

# ---- 参数 ----
for arg in "$@"; do
  case $arg in
    --target=*) TARGET="${arg#*=}"; shift ;;
    --repo=*)   REPO_URL="${arg#*=}"; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's|^# \?||'
      exit 0
      ;;
    *) echo "未知参数: $arg" ; exit 1 ;;
  esac
done

TARGET="${TARGET/#\~/$HOME}"

# ---- 开场 ----
cat <<EOF

╭──────────────────────────────────────────────────────────╮
│  mpdev v2.0.0 Plugin 安装                                  │
│  多模块 AI 协同开发框架 · Claude Code Plugin              │
╰──────────────────────────────────────────────────────────╯

源:     $REPO_URL (subdir: $SUBDIR)
目标:   $TARGET

EOF

# ---- 前置检查 ----
echo "▶ Step 1/4: 前置检查"

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
    [Yy]*) cd "$TARGET" && git pull 2>&1 | tail -3 ;;
    *) echo "已取消"; exit 2 ;;
  esac
fi

# ---- 克隆 ----
echo ""
echo "▶ Step 2/4: 克隆 mpdev"

if [ ! -d "$TARGET/.git" ]; then
  TMP=$(mktemp -d)
  trap "rm -rf $TMP" EXIT

  if ! git clone --depth=1 "$REPO_URL" "$TMP/superdev" 2>&1 | tail -3; then
    echo "❌ clone 失败"
    exit 3
  fi

  if [ ! -d "$TMP/superdev/$SUBDIR" ]; then
    echo "❌ 找不到 $SUBDIR 子目录"
    exit 3
  fi

  mkdir -p "$(dirname "$TARGET")"
  cp -r "$TMP/superdev/$SUBDIR" "$TARGET"
fi

# 验证 manifest
[ -f "$TARGET/.claude-plugin/marketplace.json" ] || { echo "❌ marketplace.json 缺失"; exit 3; }
echo "  ✅ $TARGET 就绪"

# ---- 版本 ----
echo ""
echo "▶ Step 3/4: 版本信息"
VERSION=$(cat "$TARGET/VERSION" 2>/dev/null || echo "unknown")
echo "  📦 mpdev v$VERSION"

# ---- 引导 ----
echo ""
echo "▶ Step 4/4: 在 Claude Code 内完成 plugin 注册"
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

echo "✅ 安装完成"
exit 0
```

- [ ] **Step 2: chmod + bash 语法检查**

```bash
cd F:/claude/superdev && chmod +x mpdev/bin/install.sh && bash -n mpdev/bin/install.sh && echo "syntax ok"
```

Expected: `syntax ok`

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev/bin/install.sh && git commit -m "feat(v2): bin/install.sh — plugin 一键安装

参考 mppm/bin/install.sh 风格。git clone → 拷贝 mpdev/ 子目录 → 提示用户在 Claude Code 内跑 /plugin install。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 25: bin/install.ps1

**Files:**
- Create: `mpdev/bin/install.ps1`

- [ ] **Step 1: 写文件**

写入 `mpdev/bin/install.ps1`：

```powershell
# mpdev v2.0.0 Plugin 一键安装 (PowerShell)
#
# Usage:
#   $wc=New-Object Net.WebClient; $wc.Encoding=[Text.Encoding]::UTF8
#   $s=$wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.ps1')
#   if($s[0]-eq[char]0xFEFF){$s=$s.Substring(1)}; iex $s

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$RepoUrl = if ($env:MPDEV_REPO) { $env:MPDEV_REPO } else { 'https://github.com/wzhiwei0821-coward/superdev.git' }
$Subdir  = if ($env:MPDEV_SUBDIR) { $env:MPDEV_SUBDIR } else { 'mpdev' }
$Target  = if ($env:MPDEV_TARGET) { $env:MPDEV_TARGET } else { Join-Path $HOME 'dev/mpdev' }

function Die  ($m) { Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }
function Info ($m) { Write-Host "[INFO]  $m" -ForegroundColor Cyan }
function Ok   ($m) { Write-Host "[OK]    $m" -ForegroundColor Green }

# preflight
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die 'git 未安装' }

if (-not (Test-Path "$HOME/.claude")) {
    Info "未检测到 ~/.claude，请先装 Claude Code"
    $ans = Read-Host "继续？(y/N)"
    if ($ans -notmatch '^[Yy]$') { Die '已取消' }
}

if (Test-Path $Target) {
    Info "$Target 已存在"
    $ans = Read-Host "覆盖（git pull）/取消？(y/N)"
    if ($ans -match '^[Yy]$') { Push-Location $Target; & git pull; Pop-Location }
    else { Die '已取消' }
}

# clone
Info '克隆 superdev 仓库'
$tmpName = 'mpdev-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) $tmpName
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    & git clone --depth=1 $RepoUrl (Join-Path $Tmp 'superdev')
    if ($LASTEXITCODE -ne 0) { Die 'git clone 失败' }

    $SuiteRoot = Join-Path $Tmp "superdev/$Subdir"
    if (-not (Test-Path $SuiteRoot)) { Die "$SuiteRoot 不存在" }

    New-Item -ItemType Directory -Force -Path (Split-Path $Target -Parent) | Out-Null
    Copy-Item -Path $SuiteRoot -Destination $Target -Recurse -Force

    $manifest = Join-Path $Target '.claude-plugin/marketplace.json'
    if (-not (Test-Path $manifest)) { Die 'marketplace.json 缺失' }
    Ok "$Target 就绪"

    $verFile = Join-Path $Target 'VERSION'
    $Version = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { 'unknown' }
    Info "mpdev v$Version"
} finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

# 引导
Write-Host ''
Write-Host '现在请打开 Claude Code，按顺序输入：'
Write-Host ''
Write-Host "  /plugin marketplace add file://$Target" -ForegroundColor Yellow
Write-Host '  /plugin install mpdev@mpdev' -ForegroundColor Yellow
Write-Host ''
Write-Host '完成后完全重启 Claude Code，/mpdev: 应见 9 个命令补全。'
Write-Host ''
Write-Host "文档:    $Target/docs/quickstart.md"
Write-Host "升级:    $Target/docs/upgrade-guide.md"
Write-Host "排错:    $Target/docs/troubleshooting.md"
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/bin/install.ps1 && git commit -m "feat(v2): bin/install.ps1 — PowerShell 等价 install.sh

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 26: scripts/migrate-from-v1.sh

**Files:**
- Create: `mpdev/scripts/migrate-from-v1.sh`

- [ ] **Step 1: 建目录 + 写文件**

```bash
cd F:/claude/superdev && mkdir -p mpdev/scripts
```

写入 `mpdev/scripts/migrate-from-v1.sh`：

```bash
#!/usr/bin/env bash
#
# v1.x → v2.0.0 项目迁移脚本
# ===========================
# 在 v1 项目根跑。备份 .claude/ → 删 plugin 接管的文件 → 保留项目数据
#

set -e

if [ ! -d .claude ]; then
  echo "❌ 当前目录无 .claude/，不像 v1 项目"; exit 1
fi

if [ ! -f .claude/.mpdev-version ]; then
  echo "⚠️ 未检测到 .mpdev-version。可能已是 v2 或非 mpdev 项目。"
  read -p "继续？(y/N) " yn
  [[ "$yn" =~ ^[Yy]$ ]] || exit 2
fi

TS=$(date +%Y%m%d-%H%M%S)
BACKUP=".claude.v1-backup.$TS"

echo "▶ Step 1/3: 备份 .claude/ → $BACKUP"
cp -r .claude "$BACKUP"
echo "  ✅ 备份完成"

echo ""
echo "▶ Step 2/3: 删除 plugin 接管的文件"

# 删 commands/
if [ -d .claude/commands ]; then
  rm -rf .claude/commands
  echo "  - .claude/commands/ (plugin 接管)"
fi

# 删 templates/
if [ -d .claude/templates ]; then
  rm -rf .claude/templates
  echo "  - .claude/templates/ (plugin 接管)"
fi

# 删顶级 md 文件
for f in MPDev-Scheme.md mpdev-suite-workflow.md README.md .mpdev-version; do
  if [ -f ".claude/$f" ]; then
    rm -f ".claude/$f"
    echo "  - .claude/$f (plugin 接管)"
  fi
done

echo ""
echo "▶ Step 3/3: 检查保留的项目数据"
echo "  📁 .claude/agents/        $(ls .claude/agents 2>/dev/null | wc -l) 个 agent 文件"
echo "  📁 .claude/mpdev-runs/    $(find .claude/mpdev-runs -type f 2>/dev/null | wc -l) 个运行记录"
[ -f .claude/.mpdev-env-state.yml ] && echo "  📄 .claude/.mpdev-env-state.yml"
[ -f .claude/.mpdev-runtime-creds.yml ] && echo "  📄 .claude/.mpdev-runtime-creds.yml"

echo ""
echo "✅ 迁移完成"
echo ""
cat <<'EOF'
后续:
  1. 确认 v2 plugin 已装:
     /plugin list | grep mpdev
  
  2. 推荐删 4 个框架 agent（让 plugin 接管最新版本）:
     rm .claude/agents/code-reviewer.md
     rm .claude/agents/integration-checker.md
     rm .claude/agents/acceptance-reviewer.md
     rm .claude/agents/doc-refresher.md
     （项目特化的 *-impl.md / architect.md / 等不要删）
  
  3. 完全重启 Claude Code，验证 /mpdev: 自动补全
  
  4. 确认无问题后可删备份:
     rm -rf "BACKUP_PATH"
  
  详见 docs/upgrade-guide.md
EOF
echo ""
echo "  备份位置: $BACKUP（保留至少 7 天后再删）"
```

注意 heredoc 里 BACKUP_PATH 是字面量，不展开（保护读者用真实路径替换）。

- [ ] **Step 2: 语法检查**

```bash
cd F:/claude/superdev && chmod +x mpdev/scripts/migrate-from-v1.sh && bash -n mpdev/scripts/migrate-from-v1.sh && echo "syntax ok"
```

Expected: `syntax ok`

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev/scripts/migrate-from-v1.sh && git commit -m "feat(v2): scripts/migrate-from-v1.sh — v1 项目迁 v2 辅助脚本

备份 → 删 plugin 接管的文件 → 保留项目数据。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 27: scripts/migrate-from-v1.ps1

**Files:**
- Create: `mpdev/scripts/migrate-from-v1.ps1`

- [ ] **Step 1: 写文件**

写入 `mpdev/scripts/migrate-from-v1.ps1`：

```powershell
# v1.x → v2.0.0 项目迁移脚本 (PowerShell)
#
# 在 v1 项目根跑。备份 .claude/ → 删 plugin 接管的文件 → 保留项目数据

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

if (-not (Test-Path '.claude')) {
    Write-Host "[ERROR] 当前目录无 .claude/，不像 v1 项目" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path '.claude/.mpdev-version')) {
    Write-Host "[WARN] 未检测到 .mpdev-version。可能已是 v2 或非 mpdev 项目。" -ForegroundColor Yellow
    $ans = Read-Host "继续？(y/N)"
    if ($ans -notmatch '^[Yy]$') { exit 2 }
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = ".claude.v1-backup.$ts"

Write-Host "▶ Step 1/3: 备份 .claude/ → $Backup" -ForegroundColor Cyan
Copy-Item -Path '.claude' -Destination $Backup -Recurse -Force
Write-Host "  ✅ 备份完成" -ForegroundColor Green

Write-Host ''
Write-Host '▶ Step 2/3: 删除 plugin 接管的文件' -ForegroundColor Cyan

if (Test-Path '.claude/commands') {
    Remove-Item -Recurse -Force '.claude/commands'
    Write-Host '  - .claude/commands/ (plugin 接管)'
}
if (Test-Path '.claude/templates') {
    Remove-Item -Recurse -Force '.claude/templates'
    Write-Host '  - .claude/templates/ (plugin 接管)'
}
foreach ($f in @('MPDev-Scheme.md','mpdev-suite-workflow.md','README.md','.mpdev-version')) {
    $p = Join-Path '.claude' $f
    if (Test-Path $p) {
        Remove-Item -Force $p
        Write-Host "  - .claude/$f (plugin 接管)"
    }
}

Write-Host ''
Write-Host '▶ Step 3/3: 检查保留的项目数据' -ForegroundColor Cyan
$agentCount = if (Test-Path '.claude/agents') { (Get-ChildItem '.claude/agents' -File).Count } else { 0 }
$runCount = if (Test-Path '.claude/mpdev-runs') { (Get-ChildItem '.claude/mpdev-runs' -Recurse -File).Count } else { 0 }
Write-Host "  📁 .claude/agents/        $agentCount 个 agent 文件"
Write-Host "  📁 .claude/mpdev-runs/    $runCount 个运行记录"
if (Test-Path '.claude/.mpdev-env-state.yml') { Write-Host '  📄 .claude/.mpdev-env-state.yml' }
if (Test-Path '.claude/.mpdev-runtime-creds.yml') { Write-Host '  📄 .claude/.mpdev-runtime-creds.yml' }

Write-Host ''
Write-Host '✅ 迁移完成' -ForegroundColor Green
Write-Host ''
Write-Host @"
后续:
  1. 确认 v2 plugin 已装:
     /plugin list | grep mpdev
  
  2. 推荐删 4 个框架 agent（让 plugin 接管最新版本）:
     Remove-Item .claude/agents/code-reviewer.md, .claude/agents/integration-checker.md, .claude/agents/acceptance-reviewer.md, .claude/agents/doc-refresher.md
     （项目特化的 *-impl.md / architect.md / 等不要删）
  
  3. 完全重启 Claude Code，验证 /mpdev: 自动补全
  
  4. 确认无问题后可删备份:
     Remove-Item -Recurse -Force $Backup
"@
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/scripts/migrate-from-v1.ps1 && git commit -m "feat(v2): scripts/migrate-from-v1.ps1 — PowerShell 等价

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 28: CHANGELOG.md

**Files:**
- Create: `mpdev/CHANGELOG.md`

- [ ] **Step 1: 写文件**

写入 `mpdev/CHANGELOG.md`：

```markdown
# Changelog

All notable changes to mpdev plugin will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 版本规则

- **Major (X.0.0)**: 不向后兼容（命令重命名、目录结构变更、安装方式变更）
- **Minor (1.X.0)**: 新增命令 / agent / 探针 / flavor / dialect
- **Patch (1.0.X)**: bug 修复、文档完善、模板小调整

## [2.0.0] — 2026-05-15

**BREAKING CHANGES**: mpdev 从「项目级 `.claude/` 复制」模式迁到「Claude Code Plugin」模式。

### Added
- `.claude-plugin/plugin.json` + `marketplace.json`：Claude Code 官方 plugin manifest
- `agents/` 顶级目录：4 个框架级 shared agent（code-reviewer / integration-checker / acceptance-reviewer / doc-refresher）
- `bin/install.sh` + `install.ps1`：plugin 一键安装脚本（参考 mppm 模式）
- `scripts/migrate-from-v1.sh` + `migrate-from-v1.ps1`：v1.x 项目迁移到 v2 的辅助脚本
- `docs/quickstart.md` / `upgrade-guide.md` / `troubleshooting.md`：3 份新用户文档

### Changed
- **命令命名**：所有命令 drop `mpdev-` 前缀
  - `/mpdev` → `/mpdev:dev`
  - `/mpdev-fix` → `/mpdev:fix`（其余 7 个同理）
- **目录结构**：`mpdev-suite/.claude/{commands,templates,...}` → `mpdev/{commands,templates,agents,docs,...}`
- **模板引用**：命令 .md 内的路径从 `.claude/templates/...` → `${CLAUDE_PLUGIN_ROOT}/templates/...`
- **安装方式**：从「项目内跑 install.sh」改为「全局跑 install.sh + /plugin install」
- **升级方式**：从「项目内跑 update.sh + 三方合并」改为「/plugin update 一键」
- **`/mpdev:init` 行为**：不再生成 4 个框架 agent（plugin 自带）；只生成 9 个项目特化 impl agent

### Removed
- `scripts/install.sh` / `install.ps1` / `update.sh` / `update.ps1` / `pack.sh`（被 plugin 机制取代）
- `.claude/` 作为分发根（plugin 用 `.claude-plugin/` + 顶级目录）
- `.mpdev-version` 文件（plugin 系统自带版本管理）

### Migration
- v1.x 用户：跑 `migrate-from-v1.sh` + 装 plugin。详见 [upgrade-guide.md](./docs/upgrade-guide.md)
- 老仓库 `mpdev-suite/` 保留半年（v1.3.x 维护模式），2026-11-15 归档

### Compatibility
- v1.3.0 的所有功能行为在 v2.0.0 中**功能等价**（9 命令 / 4 探针 / 所有 Step / 报告格式）
- 项目数据文件（`.claude/agents/` / `.claude/mpdev-runs/` / `.claude/.mpdev-env-state.yml` / `.claude/.mpdev-runtime-creds.yml` / `.claude-notes/`）位置不变，零迁移
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/CHANGELOG.md && git commit -m "feat(v2): CHANGELOG.md [2.0.0]

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 29: README.md

**Files:**
- Create: `mpdev/README.md`

- [ ] **Step 1: 写文件**

写入 `mpdev/README.md`：

```markdown
# mpdev 📦

> **多模块 AI 协同开发框架** — Claude Code Plugin
>
> 9 个 `/mpdev:*` 命令 + 4 个框架 agent + 5 个 runtime probe + 13 个 AI agent 模板，覆盖「理解项目 → 提取契约 → 框架初始化 → 开发 → 测试 → 修复 → 提交」全生命周期。

[![version](https://img.shields.io/badge/version-2.0.0-blue)](./VERSION) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE) [![claude-code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://docs.claude.com/en/docs/claude-code)

---

## 一句话定位 🎯

**给在多模块（Java + Python + Vue / Spring Cloud / 微服务 + 前端）项目里搞 AI 协作开发的工程师**：从一句话需求 / 一个 bug，自动跑完架构 → 契约 → 实现 → 评审 → 测试 → 提交全流程，不用手动协调多个 agent。

- 👥 **目标场景**: B 端管理后台 / 机器人 IoT / 物联网平台 / 数据中台 / 算法服务
- 📦 **数据解耦**: Plugin 升级**永远不写**项目里的 `.claude/agents/`、`.claude/mpdev-runs/`、`.claude/.mpdev-*`
- 🛡️ **运行时验证**: v1.3.0 起内置 4 个探针（DB / HTTP / Playwright / WS 静态扫描），fix 软门复现 + 验证
- 🌐 **跨项目复用**: 一次装 plugin，所有项目里 `/mpdev:` 自动可用

---

## ⚡ 5 分钟跑通

```bash
# 1. 装 plugin（30 秒）
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
# 然后在 Claude Code 内:
/plugin marketplace add file://~/dev/mpdev
/plugin install mpdev@mpdev

# 2. 任意项目内（4 分钟）
/mpdev:understand           # 阶段 0a: 生成各模块 CLAUDE.md
/mpdev:contracts            # 阶段 0b: 跨模块项目才需要
/mpdev:init                 # 阶段 1: 生成项目特化 impl agent
/mpdev:dev "需求描述"        # 阶段 2: 开始开发
```

详见 [docs/quickstart.md](./docs/quickstart.md)。

---

## 9 个命令

| 命令 | 作用 | 典型用法 |
|------|------|---------|
| `/mpdev:understand` | 各模块代码深度理解 → 生成 CLAUDE.md | 新项目 / CLAUDE.md 过期 |
| `/mpdev:contracts` | 多 CLAUDE.md 交叉比对 → 生成契约仓库 | 跨模块项目首次建立 |
| `/mpdev:init` | 按 CLAUDE.md 生成 9 个项目特化 impl agent | 阶段 0 完成后 |
| `/mpdev:env` | 检测中间件 + 配置 + 启动 / 重启 / 停止 / 状态 | 开发环境一站式管理 |
| `/mpdev:dev` | 主流程：架构 → 契约 → 实现 → 评审 → 测试 → 提交 | 日常开发主入口 |
| `/mpdev:fix` | 轻量修复（单 bug + 批量清单） | bug 修复 |
| `/mpdev:test` | 测试用例生成 / 执行 / bug 导出 | 测试阶段 |
| `/mpdev:check` | 跨模块契约一致性 + 兜底测试 | merge 前体检 |
| `/mpdev:commit` | 智能 commit 消息生成 | 提交前 |

---

## 数据架构

```
┌───────────────────────────────────────────────────────────┐
│  Plugin 自带（只读，住 ~/.claude/plugins/cache/mpdev/）   │
│                                                            │
│   commands/    9 个 /mpdev:* 命令                          │
│   templates/   ├─ 7 个 .tmpl（架构/契约/impl/dba/tester）  │
│                ├─ dialects/      4 DB 方言                  │
│                ├─ test-flavors/  7 测试 flavor              │
│                ├─ understand/    6 语言指南                │
│                └─ runtime-probe/ 5 探针（v1.3.0）           │
│   agents/      4 个框架 agent                              │
│                code-reviewer / integration-checker /        │
│                acceptance-reviewer / doc-refresher          │
│   docs/        架构 / workflow / 快速上手 / 排错 / 升级    │
└────────────────────────┬───────────────────────────────────┘
                         │ ${CLAUDE_PLUGIN_ROOT}/...
                         ▼
┌───────────────────────────────────────────────────────────┐
│  项目数据（写入项目本地，git 管理）                       │
│                                                            │
│   .claude/agents/                项目特化 impl agent (9 个)│
│   .claude/mpdev-runs/            运行历史                  │
│   .claude/.mpdev-env-state.yml   /mpdev:env 维护           │
│   .claude/.mpdev-runtime-creds.yml runtime-probe 凭据      │
│                                  （gitignored）            │
│   .claude-notes/                 第二阶段笔记 + snapshots │
│   CLAUDE.md                      /mpdev:understand 产物    │
└───────────────────────────────────────────────────────────┘
```

---

## 文档

- 📘 [quickstart.md](./docs/quickstart.md) — 5 分钟速览
- 🔄 [upgrade-guide.md](./docs/upgrade-guide.md) — 从 v1.x 升级
- 🛟 [troubleshooting.md](./docs/troubleshooting.md) — 故障排查
- 🏛️ [MPDev-Scheme.md](./docs/MPDev-Scheme.md) — 架构与角色设计
- 📖 [workflow.md](./docs/workflow.md) — 9 命令使用手册

---

## 升级

```bash
/plugin update
```

或手动：

```bash
cd ~/dev/mpdev && git pull
/plugin update
```

---

## License

MIT
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev/README.md && git commit -m "feat(v2): README.md (plugin 风格)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 30: 老仓库 mpdev-suite README deprecation

**Files:**
- Modify: `mpdev-suite/README.md`

- [ ] **Step 1: 在 README 顶部追加 deprecation 横幅**

Read `mpdev-suite/README.md` 第一行（已是 `# mpdev-suite`）。

Use Edit tool:
- old_string:
```
# mpdev-suite

> **多模块 AI 协同开发框架** — 9 个 slash 命令 × 13 个 AI agent，覆盖"理解项目 → 提取契约 → 框架初始化 → 开发 → 测试 → 修复 → 提交 → 运维"全生命周期。
```

- new_string:
```
# mpdev-suite

> ⚠️ **维护模式（v1.x，将于 2026-11-15 归档）**
>
> mpdev v2.0.0 已发布为 [Claude Code Plugin](../mpdev/)，**新用户请直接装 v2**：
> ```
> bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
> ```
> 详见 [v1 → v2 升级指南](../mpdev/docs/upgrade-guide.md)。
>
> 本 README 描述的是 v1.x 用法（项目级 `.claude/` 复制模式），半年内仅修关键 bug。

---

> **多模块 AI 协同开发框架** — 9 个 slash 命令 × 13 个 AI agent，覆盖"理解项目 → 提取契约 → 框架初始化 → 开发 → 测试 → 修复 → 提交 → 运维"全生命周期。
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/README.md && git commit -m "docs(mpdev-suite): mark v1.x maintenance mode + link to v2

老仓库顶部加 deprecation 横幅，引导新用户到 v2 plugin。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 31: 老仓库 mpdev-suite CHANGELOG v1.3.1 维护标记

**Files:**
- Modify: `mpdev-suite/CHANGELOG.md`

- [ ] **Step 1: 在 [1.3.0] 之上加 [1.3.1] 段**

Use Edit tool on `mpdev-suite/CHANGELOG.md`:

old_string:
```
## [1.3.0] — 2026-05-15
```

new_string:
```
## [1.3.1] — 2026-05-15

### Notes
- **维护模式启动**：mpdev v2.0.0 已发布为 Claude Code Plugin。本仓 `mpdev-suite/` 进入维护模式，仅修关键 bug，无新功能。
- **EOL**: 2026-11-15
- **升级**: 详见 [../mpdev/docs/upgrade-guide.md](../mpdev/docs/upgrade-guide.md)

## [1.3.0] — 2026-05-15
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/CHANGELOG.md && git commit -m "docs(mpdev-suite): [1.3.1] 维护模式公告 + EOL 日期

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 32: 整体 grep audit

**Files:** 无修改

- [ ] **Step 1: 全树搜 /mpdev- 残留**

```bash
cd F:/claude/superdev && grep -rn "/mpdev-" mpdev/ 2>/dev/null | head -10
```

Expected: 0 行命中。如有，说明 sed 没替干净，需追究是哪文件。

- [ ] **Step 2: 全树搜 .claude/templates/ 残留**

```bash
cd F:/claude/superdev && grep -rn "\.claude/templates/" mpdev/ 2>/dev/null | head -10
```

Expected: 0 行命中。

- [ ] **Step 3: 全树搜未替换的裸 /mpdev**

```bash
cd F:/claude/superdev && grep -rE "/mpdev(?![-:a-z])" mpdev/ 2>/dev/null | head -10
```

注：单独的 `/mpdev`（如 readme 里"mpdev plugin"）不算 bug；但裸 `/mpdev "需求"` 这种应已被替换。

- [ ] **Step 4: 9 个命令 name 字段全检**

```bash
cd F:/claude/superdev && grep -h "^name:" mpdev/commands/*.md | sort
```

Expected:
```
name: check
name: commit
name: contracts
name: dev
name: env
name: fix
name: init
name: test
name: understand
```

- [ ] **Step 5: 4 个框架 agent name 字段全检**

```bash
cd F:/claude/superdev && grep -h "^name:" mpdev/agents/*.md | sort
```

Expected:
```
name: acceptance-reviewer
name: code-reviewer
name: doc-refresher
name: integration-checker
```

---

## Task 33: 整体目录树检查

**Files:** 无修改

- [ ] **Step 1: 目录树**

```bash
cd F:/claude/superdev && find mpdev -maxdepth 2 -type d | sort
```

Expected:
```
mpdev
mpdev/.claude-plugin
mpdev/agents
mpdev/bin
mpdev/commands
mpdev/docs
mpdev/scripts
mpdev/templates
mpdev/templates/dialects
mpdev/templates/runtime-probe
mpdev/templates/test-flavors
mpdev/templates/understand
```

- [ ] **Step 2: 顶级文件**

```bash
cd F:/claude/superdev && ls mpdev/
```

Expected: `.claude-plugin/` `agents/` `bin/` `commands/` `docs/` `scripts/` `templates/` `CHANGELOG.md` `LICENSE` `README.md` `VERSION`

- [ ] **Step 3: 文件计数**

```bash
cd F:/claude/superdev && \
  echo "commands: $(ls mpdev/commands/*.md | wc -l)" && \
  echo "agents: $(ls mpdev/agents/*.md | wc -l)" && \
  echo "templates total: $(find mpdev/templates -type f | wc -l)" && \
  echo "docs: $(ls mpdev/docs/*.md | wc -l)" && \
  echo "bin: $(ls mpdev/bin/ | wc -l)" && \
  echo "scripts: $(ls mpdev/scripts/ | wc -l)"
```

Expected (大致): commands=9, agents=4, templates total=27, docs=5, bin=2, scripts=2

- [ ] **Step 4: VERSION 内容**

```bash
cd F:/claude/superdev && cat mpdev/VERSION
```

Expected: `2.0.0`

- [ ] **Step 5: JSON 合法**

```bash
cd F:/claude/superdev && python -c "import json; json.load(open('mpdev/.claude-plugin/plugin.json')); json.load(open('mpdev/.claude-plugin/marketplace.json')); print('both ok')"
```

Expected: `both ok`

---

## Task 34: git log + diff stat

**Files:** 无修改

- [ ] **Step 1: 综合 git log**

```bash
cd F:/claude/superdev && git log --oneline fa8d7b1..HEAD
```

Expected: 看到 ~30 个 `feat(v2):` 或 `docs(mpdev-suite):` commit

- [ ] **Step 2: 全部新增行数**

```bash
cd F:/claude/superdev && git diff --stat fa8d7b1..HEAD | tail -3
```

Expected: 数千行新增（templates 整树拷贝 + 命令 + agent + 文档），少量删除（mpdev-suite README/CHANGELOG）

- [ ] **Step 3: mpdev/ 目录大小**

```bash
cd F:/claude/superdev && du -sh mpdev/
```

Expected: ~200-500 KB（视模板大小）

---

## Task 35: 验收剧本 #1 — plugin 装得上

**目的**: 新装到本地能完成 `/plugin install mpdev@mpdev`

**前置**: 本机有 Claude Code，有 git

- [ ] **Step 1: 跑 install.sh dry run（先不真装，只验证语法 + 路径）**

```bash
cd F:/claude/superdev && bash -n mpdev/bin/install.sh && echo "syntax ok"
```

- [ ] **Step 2: 真装到临时目录**

```bash
cd /tmp && rm -rf mpdev-test && MPDEV_TARGET=$(pwd)/mpdev-test MPDEV_REPO=file://F:/claude/superdev bash F:/claude/superdev/mpdev/bin/install.sh
```

Expected: 看到 4 个 Step 的输出 + "现在请打开 Claude Code, 输入..." 引导

- [ ] **Step 3: 在 Claude Code 内**

```
/plugin marketplace add file:///tmp/mpdev-test
/plugin install mpdev@mpdev
```

Expected: 两条命令都成功，无报错

- [ ] **Step 4: 重启 + 验证补全**

完全退出 Claude Code → 重开 → 输入 `/mpdev:` → 应见 9 个命令补全

---

## Task 36: 验收剧本 #2 — migrate-from-v1 不破坏老项目

**目的**: 在 v1 项目跑 migrate 脚本后能正常使用 v2 命令

**前置**: 找一个装过 v1 的真实项目（如 `F:/claude/ult_2.2`，有 `.claude/agents/`、`.claude/mpdev-runs/`、`.claude/.mpdev-env-state.yml`）

- [ ] **Step 1: 备份项目**

```bash
cp -r F:/claude/ult_2.2 F:/claude/ult_2.2.pre-migration-backup
```

- [ ] **Step 2: 跑迁移脚本**

```bash
cd F:/claude/ult_2.2 && bash F:/claude/superdev/mpdev/scripts/migrate-from-v1.sh
```

Expected: 看到 Step 1-3 的输出 + 后续提示

- [ ] **Step 3: 检查保留的项目数据**

```bash
cd F:/claude/ult_2.2 && \
  ls .claude/agents/ && \
  ls .claude/mpdev-runs/ && \
  cat .claude/.mpdev-env-state.yml | head -5 && \
  ls .claude.v1-backup.*
```

Expected: agents/ mpdev-runs/ state.yml 都还在；备份目录也在

- [ ] **Step 4: 检查删除的文件**

```bash
cd F:/claude/ult_2.2 && \
  ls .claude/commands/ 2>&1 | head -3 && \
  ls .claude/templates/ 2>&1 | head -3
```

Expected: 两个目录都报"No such file or directory"

- [ ] **Step 5: 在 Claude Code 内试新命令**

```
/mpdev:env status
```

Expected: 命令执行成功（读 state.yml 显示模块状态）

- [ ] **Step 6: 恢复备份（剧本完成）**

```bash
rm -rf F:/claude/ult_2.2
mv F:/claude/ult_2.2.pre-migration-backup F:/claude/ult_2.2
```

---

## Task 37: 验收剧本 #3 — 功能等价于 v1.3.0

**目的**: 在 v2 plugin 安装的项目上跑 /mpdev:fix，确认行为与 v1.3.0 相同

**前置**: v2 plugin 已装（Task 35 完成）+ 一个用 v2 跑过 init 的项目

- [ ] **Step 1: 准备测试 bug**

在测试项目挑一个真实 bug（或人造一个 NPE），用 v1.3.0 跑过有报告作对照。

- [ ] **Step 2: 跑 v2 fix**

```
/mpdev:fix java "NPE at TaskServiceImpl:127"
```

Expected: 流程跑完，报告生成

- [ ] **Step 3: 对比报告字段**

```bash
ls .claude/mpdev-runs/fixes/
# 找最新的，对照 v1.3.0 的同名 bug 报告
```

应有：相同的 frontmatter 字段 / 相同的 Step 章节 / repro_state 字段 / verified 字段 / similar_fixes_count 字段。

- [ ] **Step 4: 探针调用确认**

报告里"复现证据"节应嵌入 probe-http 或 probe-browser 的产物。证明 plugin 的 `${CLAUDE_PLUGIN_ROOT}/templates/runtime-probe/probe-*.md` 被正确读取。

---

## Task 38: 验收剧本 #4 — 4 个框架 agent 可调用

**目的**: plugin 自带的 4 个框架 agent 能被 Agent() 调用

- [ ] **Step 1: 在 Claude Code 内手动调用 code-reviewer**

```
Agent(
  subagent_type="code-reviewer",
  description="测试 plugin 自带 agent 调用",
  prompt="对最近 1 个 commit 做 quick review"
)
```

Expected: 调用成功，返回 reviewer 输出（不是 "unknown subagent" 错误）

- [ ] **Step 2: 同样测试其他 3 个**

```
Agent(subagent_type="integration-checker", ...)
Agent(subagent_type="acceptance-reviewer", ...)
Agent(subagent_type="doc-refresher", ...)
```

Expected: 都能调用

- [ ] **Step 3: 测试项目级 override**

在项目放一个 `.claude/agents/code-reviewer.md`（内容含特殊标记 "OVERRIDE-TEST"），重启 Claude Code，再调 `Agent(subagent_type="code-reviewer", ...)`。

Expected:
- 若 Claude Code 项目优先：能看到 OVERRIDE-TEST 标记 → 验证 §15.3 预期
- 若 Claude Code plugin 优先：看不到标记，行为是 plugin 自带版

无论哪种结果都要记录到 docs/troubleshooting.md（更新 §"老 v1 项目自定义的 code-reviewer 仍在生效"段）。

---

## Self-Review

实现完成后对照 spec 各节，确认所有要求都有 task 覆盖。

- [ ] §3 决策记录（6 条）：
  - D1 命令命名 → Task 6-14 全实施 ✓
  - D2 框架 agent → Task 16-19 + Task 9 改 init ✓
  - D3 模板路径 → Task 6-14 sed 替换 + Task 32 audit ✓
  - D4 项目状态文件不变 → migrate 脚本 Task 26-27 ✓
  - D5 版本 2.0.0 → Task 4 VERSION + Task 28 CHANGELOG ✓
  - D6 仓库并存 → Task 30-31 老仓 deprecation ✓

- [ ] §5 文件清单：
  - 5.1 plugin 仓库结构 → Task 1-29 ✓
  - 5.2 plugin 物理位置 → 由 Claude Code 维护，无 task ✓
  - 5.3 项目侧不写入 → migrate 脚本 + 留白 ✓
  - 5.4 老仓库维护 → Task 30-31 ✓

- [ ] §6 安装与升级 UX：
  - 6.1 新装 → Task 24-25 + Task 35 ✓
  - 6.2 v1→v2 迁移 → Task 26-27 + Task 36 ✓
  - 6.3 v2 升级 → 由 /plugin update 处理，无 task ✓

- [ ] §7 命令文件改造细节 → Task 6-14 + Task 32 ✓
- [ ] §8 agent 平移 → Task 16-19 + Task 9 ✓
- [ ] §9 plugin.json/marketplace.json → Task 1-2 ✓
- [ ] §10 install.sh → Task 24-25 ✓
- [ ] §11 migrate-from-v1.sh → Task 26-27 ✓
- [ ] §12 文档改造 → Task 20-23 + Task 29 ✓
- [ ] §13 CHANGELOG → Task 28 ✓
- [ ] §14 阶段（7 阶段映射到 Task 1-37）✓
- [ ] §15 风险：
  - 15.1 命令变更影响 → upgrade-guide §命令重命名 ✓
  - 15.2 CLAUDE_PLUGIN_ROOT 解析 → 实测在 Task 35-37 ✓
  - 15.3 agent override 优先级 → 实测在 Task 38 ✓
  - 15.4 不在本期范围（hooks 等）→ 不做 task ✓
- [ ] §16 验收剧本（4 个）→ Task 35-38 ✓
