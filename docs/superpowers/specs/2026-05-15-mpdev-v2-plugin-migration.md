---
title: mpdev v2.0.0 — Claude Code Plugin 标准化迁移
status: approved
date: 2026-05-15
author: brainstorming session (D1-D6 决策)
target_version: 2.0.0
breaking_change: true
---

# mpdev v2.0.0 — Plugin 标准化迁移设计

## 1. 问题陈述

mpdev v1.x 用「复制 `.claude/` 整包到项目」的方式分发，每个项目独立装一份。这套方式的缺点：

1. **每装一个项目要跑 install.sh + git add 一堆框架文件**，框架和项目实例混在 `.claude/` 下，区分不清
2. **升级靠 update.sh 走三方合并**（用户自定义 vs 新版框架 vs 备份），实现复杂、状态多
3. **命令在每个项目都重新出现一次**，没法跨项目共享
4. **不符合 Claude Code 官方 plugin 标准**（marketplace + plugin manifest + `${CLAUDE_PLUGIN_ROOT}` hook 机制）

参考实现 `mppm-master` 已把同类问题用 plugin 模式解决：用户跑一次 `/plugin install mppm@mppm` 后所有项目自动有 `/mppm:pm-*` 命令，升级 `/plugin update` 一键完成。

## 2. 设计目标

把 mpdev 从 v1.x 的"项目级 .claude/ 复制"模式迁到 v2.0.0 的"Claude Code Plugin"模式，达到：

- **一次安装，全局可用**：用户跑 `/plugin install mpdev@mpdev` 后，所有项目里 `/mpdev:fix` 等命令都可用
- **框架与项目数据彻底解耦**：plugin 文件只读（住在 `~/.claude/plugins/cache/...`）；项目数据（agents/runs/state/creds）仍在 `<project>/.claude/`
- **升级零代价**：`/plugin update` 一键，不动项目数据
- **命名规范**：所有命令走 `/mpdev:<verb>` namespace，避免与其他工具冲突

成功标准：
- 用户 5 分钟内可完成 v1.x → v2.0.0 迁移（跑 1 个迁移脚本 + 在 Claude Code 内 2 条命令）
- v1.3.0 已有的所有功能在 v2.0.0 中**功能等价**——9 个命令、4 个探针、所有 Step 行为
- 不破坏 v1.x 用户的 `.claude/agents/`、`.claude/mpdev-runs/`、`.claude/.mpdev-env-state.yml`、`.claude/.mpdev-runtime-creds.yml`

## 3. 决策记录（已与用户对齐）

| 决策点 | 选项 | 理由 |
|--------|------|------|
| **D1 命令命名** | `mpdev-` 前缀全部 drop，调用变 `/mpdev:fix` 等 | namespace 已由 plugin 提供；保留前缀变成 `/mpdev:mpdev-fix` 难看且冗余 |
| **D2 框架 agent** | 4 个框架级 agent（code-reviewer / integration-checker / acceptance-reviewer / doc-refresher）进 `plugin/agents/`；9 个项目特化 impl agent 仍由 `/mpdev:init` 生成 | 框架 agent 的改进能随 plugin 升级自动 propagate；项目特化 agent 与具体技术栈强绑定 |
| **D3 模板路径** | 所有命令 .md 内的模板路径用 `${CLAUDE_PLUGIN_ROOT}/templates/...` | Claude Code 官方约定 env var；mppm 的 hooks 已验证此模式 |
| **D4 项目状态文件** | 保持 `.claude/.mpdev-env-state.yml` / `.claude/.mpdev-runtime-creds.yml` / `.claude/agents/` / `.claude/mpdev-runs/` 位置不变 | 避免老用户做数据迁移；与 `.claude/agents/` 同根方便整组管理 |
| **D5 版本号** | 1.3.0 → 2.0.0（major bump） | 命令命名变更 + 目录结构重排 + 安装方式变更，三个都是 MAJOR 信号 |
| **D6 仓库结构** | 新建 `superdev/mpdev/` 与 `superdev/mpdev-suite/` 并存；后者进入 v1.x 维护期，半年后归档 | 老用户的 install/update URL 不破；新用户走新目录；git 历史保持连贯 |

## 4. 命令命名映射表（D1 应用结果）

| v1.x | v2.x | 文件 | 说明 |
|------|------|------|------|
| `/mpdev` | `/mpdev:dev` | `commands/dev.md` | 主流程；避免 `/mpdev:mpdev` 的尴尬，重命名为 dev |
| `/mpdev-fix` | `/mpdev:fix` | `commands/fix.md` | |
| `/mpdev-understand` | `/mpdev:understand` | `commands/understand.md` | |
| `/mpdev-init` | `/mpdev:init` | `commands/init.md` | |
| `/mpdev-env` | `/mpdev:env` | `commands/env.md` | |
| `/mpdev-test` | `/mpdev:test` | `commands/test.md` | |
| `/mpdev-check` | `/mpdev:check` | `commands/check.md` | |
| `/mpdev-commit` | `/mpdev:commit` | `commands/commit.md` | |
| `/mpdev-contracts` | `/mpdev:contracts` | `commands/contracts.md` | |

## 5. 目标目录结构

### 5.1 plugin 仓库结构（`superdev/mpdev/`）

```
mpdev/                                            (新增目录)
├── .claude-plugin/                               (新增 — plugin manifest)
│   ├── plugin.json                               name=mpdev, version=2.0.0
│   └── marketplace.json                          self-host marketplace 描述
├── commands/                                     (从 .claude/commands/ 上提一层 + 重命名)
│   ├── dev.md                                    9 个命令，去 mpdev- 前缀
│   ├── fix.md
│   ├── understand.md
│   ├── init.md
│   ├── env.md
│   ├── test.md
│   ├── check.md
│   ├── commit.md
│   └── contracts.md
├── templates/                                    (从 .claude/templates/ 平移)
│   ├── architect.tmpl
│   ├── contract-designer.tmpl
│   ├── dba.tmpl
│   ├── impl-java.tmpl
│   ├── impl-python.tmpl
│   ├── impl-vue.tmpl
│   ├── tester.tmpl
│   ├── dialects/                                 4 DB 方言 + README
│   ├── test-flavors/                             7 测试 flavor
│   ├── understand/references/                    6 语言指南
│   └── runtime-probe/                            5 探针（v1.3.0 新增）
├── agents/                                       (新增 — 框架级 shared agents)
│   ├── code-reviewer.md
│   ├── integration-checker.md
│   ├── acceptance-reviewer.md
│   └── doc-refresher.md
├── docs/                                         (从 .claude/ 平移)
│   ├── MPDev-Scheme.md
│   ├── workflow.md                               (was mpdev-suite-workflow.md)
│   ├── quickstart.md                             (新写)
│   ├── upgrade-guide.md                          (新写 — v1 → v2 迁移指南)
│   └── troubleshooting.md                        (新写)
├── bin/
│   └── install.sh                                (新写，参考 mppm bin/install.sh)
├── scripts/
│   └── migrate-from-v1.sh                        (新写 — 帮老项目从 v1 迁到 v2)
├── VERSION                                       2.0.0
├── CHANGELOG.md                                  顶部加 [2.0.0] 段
├── README.md                                     重写
└── LICENSE
```

### 5.2 plugin 在用户机器上的物理位置

由 Claude Code 维护：
```
~/.claude/plugins/cache/mpdev/mpdev/          ← plugin 内容（只读）
├── .claude-plugin/
├── commands/
├── templates/
├── agents/
└── ...
```

命令 .md 里用 `${CLAUDE_PLUGIN_ROOT}` 代指此根目录。

### 5.3 用户项目侧（plugin 不写入）

```
<your-project>/                                   (用户项目根)
├── .claude/
│   ├── agents/                                   /mpdev:init 生成的 9 个 impl agent
│   ├── mpdev-runs/                               执行历史（commits/fixes/setup/test-*）
│   ├── .mpdev-env-state.yml                      /mpdev:env 维护
│   └── .mpdev-runtime-creds.yml                  runtime-probe 维护，gitignored
├── .claude-notes/                                第二阶段笔记（含 dict-snapshots, ws-endpoints）
└── CLAUDE.md                                     /mpdev:understand 产物
```

**关键**：plugin 永远不写这些文件。所有写操作由命令/探针/agent 在运行时完成。

### 5.4 老仓库 `superdev/mpdev-suite/`（v1.x 维护模式）

不动。继续支持 v1.3.0 的 install.sh / update.sh。README 顶部加一条 deprecation 提示：

> ⚠️ v1.x 进入维护模式（仅 bug fix）。新用户请使用 [mpdev v2.0.0 plugin](../mpdev/)。半年后（2026-11-15）归档。

## 6. 安装与升级 UX

### 6.1 v2.0.0 新装

**用户操作**（一次性，全局生效）：
```bash
# 1. 克隆 plugin 仓
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
# install.sh 内部:
#   git clone https://github.com/wzhiwei0821-coward/superdev /tmp/superdev
#   mkdir -p ~/dev/mpdev && cp -r /tmp/superdev/mpdev/* ~/dev/mpdev/
#   提示用户跑下面 2 条 Claude Code 命令

# 2. 在 Claude Code 内
/plugin marketplace add file://~/dev/mpdev
/plugin install mpdev@mpdev

# 3. 重启 Claude Code（重要）
```

之后所有项目里都能用 `/mpdev:fix` `/mpdev:understand` 等。

### 6.2 v1.x → v2.0.0 迁移

老项目（已装 v1.x，`.claude/` 下有框架文件 + 项目实例混合）：

```bash
# 1. 全局装 v2 plugin（同 6.1）
bash <(curl -fsSL .../mpdev/bin/install.sh)
/plugin marketplace add file://~/dev/mpdev
/plugin install mpdev@mpdev

# 2. 在老项目根跑迁移脚本
cd /path/to/old-project
bash ~/dev/mpdev/scripts/migrate-from-v1.sh
# 脚本动作:
#   备份 .claude/ → .claude.v1-backup.{timestamp}/
#   保留: .claude/agents/  .claude/mpdev-runs/  .claude/.mpdev-*  .claude-notes/
#   删除: .claude/commands/ .claude/templates/ .claude/MPDev-Scheme.md .claude/mpdev-suite-workflow.md .claude/README.md .claude/.mpdev-version
#   提示: "本项目使用 v2 plugin。框架文件已交由 plugin 管理。"
```

### 6.3 v2.x 升级

`/plugin update` 一键。plugin 内容更新，项目数据零影响。

## 7. 命令文件改造细节

### 7.1 `mpdev-` 前缀替换

每个命令文件做 3 类替换：
1. **文件名**：`mpdev-fix.md` → `fix.md` 等（9 个文件重命名）
2. **frontmatter `name:` 字段**：`name: mpdev-fix` → `name: fix`
3. **正文内交叉引用**：把所有 `/mpdev-<verb>` 替换为 `/mpdev:<verb>`，把 `/mpdev` 主命令替换为 `/mpdev:dev`

数量级：grep 显示 9 个命令文件里**约 190 处** `/mpdev-*` 引用需要逐一替换。规则化的 sed 替换即可。

**替换顺序很重要**（因 `/mpdev` 是 `/mpdev-fix` 的前缀子串）：
1. 先替换 `/mpdev-<verb>` 类（如 `/mpdev-fix` → `/mpdev:fix`），正则 `/mpdev-([a-z]+)` → `/mpdev:$1`
2. 再替换裸 `/mpdev` 主命令 → `/mpdev:dev`，正则 `/mpdev(?![-:a-z])` → `/mpdev:dev`（负向 lookahead 防止已替换的再次被改）
3. 逆操作不允许（会把 `/mpdev:fix` 错改成 `/mpdev:dev:fix`）

### 7.2 模板路径替换（${CLAUDE_PLUGIN_ROOT}）

旧路径模式（4 处命中）：
- `Read .claude/templates/runtime-probe/probe-db.md`
- `Read .claude/templates/runtime-probe/probe-browser.md`
- `Read .claude/templates/runtime-probe/probe-ws.md`
- `Read .claude/templates/understand/references/...`

新路径：
- `Read ${CLAUDE_PLUGIN_ROOT}/templates/runtime-probe/probe-db.md`
- 等等

加之命令文件可能还隐式引用其他 `.claude/templates/` 路径（如 `architect.tmpl`、`dialects/` 等），需要 grep 全量扫描后逐项替换。

### 7.3 frontmatter 标准化

参考 mppm 的 SKILL.md 模式：
```yaml
---
name: fix
description: 轻量修复 — 单 bug 或批量清单
allowed-tools: Agent, Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion, mcp__playwright__*, mcp__mysql__*
argument-hint: "<模块> <bug 描述> | --batch | @file.md"
---
```

新增 `argument-hint`，与 mppm 一致，便于用户输入时看到提示。

## 8. agent 平移细节

### 8.1 从 `/mpdev:init` 抽出 4 个框架 agent

`/mpdev:init`（原 `mpdev-init.md`）的 Step 10 当前会生成 13 个 agent。改造后：

- **保留生成** 9 个项目特化 agent（按检测到的技术栈）：
  - architect、contract-designer（架构层）
  - impl-java / impl-python / impl-vue / dba（实现层）
  - tester（测试层）
  - 这些都依赖项目特化的占位符（package 名、模块名、技术栈细节）

- **改为 plugin 自带**（写在 `mpdev/agents/`，不再生成）：
  - `code-reviewer.md`
  - `integration-checker.md`
  - `acceptance-reviewer.md`
  - `doc-refresher.md`

`/mpdev:init` Step 10 文档要改：明确"4 个框架 agent 由 plugin 提供，无需生成；只生成 9 个项目特化 agent"。

### 8.2 agent 间的引用怎么找到？

v2 中 Agent 调用 `subagent_type="code-reviewer"`，Claude Code 会先查项目 `.claude/agents/code-reviewer.md`，找不到再查 plugin 自带的 `agents/code-reviewer.md`。两边都没就报错。

这给了用户**项目级 override** 的能力：想自定义 code-reviewer 行为？直接在 `.claude/agents/code-reviewer.md` 写自己的就行，覆盖 plugin 的。

## 9. plugin.json / marketplace.json 内容

### 9.1 `.claude-plugin/plugin.json`

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

**注意**：不在 `plugin.json` 里声明 hooks 字段（一期不做 hooks，第七阶段再加）。

### 9.2 `.claude-plugin/marketplace.json`

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

## 10. install.sh 内容（参考 mppm 风格）

`mpdev/bin/install.sh`（简化版，去掉 mppm 的 SSH 内网逻辑）：

```bash
#!/usr/bin/env bash
set -e

SOURCE="${MPDEV_SOURCE:-https://github.com/wzhiwei0821-coward/superdev.git}"
TARGET="${MPDEV_TARGET:-$HOME/dev/mpdev}"
SUBDIR="${MPDEV_SUBDIR:-mpdev}"

# 1. 前置检查（git + Claude Code 目录）
# 2. clone 到临时目录
# 3. 把 mpdev/ 子目录拷到 $TARGET
# 4. 提示用户在 Claude Code 内跑:
#    /plugin marketplace add file://$TARGET
#    /plugin install mpdev@mpdev
# 5. 提示重启 Claude Code
```

PowerShell 等价的 `install.ps1` 同步提供。

## 11. migrate-from-v1.sh 内容

`mpdev/scripts/migrate-from-v1.sh`（项目根跑）：

```bash
#!/usr/bin/env bash
set -e

# 0. 前置: 必须在项目根 + .claude/ 存在 + 是 v1.x（有 .mpdev-version）
[ -d .claude ] || { echo "❌ 当前目录无 .claude/，不像是 v1 项目"; exit 1; }
[ -f .claude/.mpdev-version ] || { echo "⚠️ 未检测到 .mpdev-version，可能已迁移"; }

# 1. 备份
TS=$(date +%Y%m%d-%H%M%S)
cp -r .claude .claude.v1-backup.$TS
echo "✅ 已备份: .claude.v1-backup.$TS"

# 2. 删 plugin-managed 文件
rm -rf .claude/commands
rm -rf .claude/templates
rm -f .claude/MPDev-Scheme.md
rm -f .claude/mpdev-suite-workflow.md
rm -f .claude/README.md
rm -f .claude/.mpdev-version

# 3. 保留项目数据（.claude/agents/, .claude/mpdev-runs/, .claude/.mpdev-*）
echo "✅ 框架文件已移除，项目数据保留:"
ls .claude/

# 4. 引导
cat <<EOF
✅ 迁移完成。请确认:
  1. v2 plugin 已装（运行 /plugin list | grep mpdev 应见到）
  2. 重启 Claude Code 后，/mpdev: 应触发命令自动补全
  3. 备份目录 .claude.v1-backup.$TS 在确认无误后可删
EOF
```

## 12. 文档改造

### 12.1 新建 `docs/quickstart.md`

5 步速览（参考 mppm README §5 分钟跑通）。

### 12.2 新建 `docs/upgrade-guide.md`

v1.x → v2.0.0 迁移完整手册：
- 命令重命名映射表（第 4 节）
- 项目目录变化（哪些保留 / 哪些删）
- CI 脚本里 `sed -i 's|/mpdev-|/mpdev:|g' .ci/*.sh` 类的批量替换示例
- 回滚方案：v1.x 备份在 `.claude.v1-backup.{timestamp}/`，最坏情况复原即可

### 12.3 新建 `docs/troubleshooting.md`

常见问题：
- `/mpdev:` 自动补全没出现 → 检查 `/plugin list` 是否含 mpdev + 重启 Claude Code
- 命令报"找不到模板" → 检查 plugin 安装完整性（`ls ~/.claude/plugins/cache/mpdev/mpdev/templates/runtime-probe/`）
- 老 `.claude/agents/` 里的 agent 调用失败 → 重跑 `/mpdev:init` 让 4 个框架 agent 由 plugin 接管

### 12.4 重写 `README.md`

参考 mppm 风格：
- 顶部 badge（version / license / claude-code-plugin）
- 一句话定位
- 5 步速览
- 整体架构图（plugin 自带 vs 项目数据 vs 用户级记忆三层）
- 完整命令清单（9 个）+ 各自一句话定位

## 13. CHANGELOG 草稿

```markdown
## [2.0.0] — 2026-05-15

**BREAKING CHANGES**：mpdev 从「项目级 `.claude/` 复制」模式迁到「Claude Code Plugin」模式。

### Added
- `.claude-plugin/plugin.json` + `marketplace.json`：Claude Code 官方 plugin manifest
- `agents/` 顶级目录：4 个框架级 shared agent（code-reviewer / integration-checker / acceptance-reviewer / doc-refresher）
- `bin/install.sh`：plugin 一键安装脚本（参考 mppm 模式）
- `scripts/migrate-from-v1.sh`：v1.x 项目迁移到 v2 的辅助脚本
- `docs/quickstart.md` / `upgrade-guide.md` / `troubleshooting.md`

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

## 14. 7 个实施阶段（writing-plans 会展开为 task）

| 阶段 | 工作 | 估时 |
|------|------|------|
| 1 | plugin 骨架：`.claude-plugin/*.json` + 平移 templates/ + 新 README + LICENSE | 0.5 天 |
| 2 | 9 个命令文件平移 + 重命名 + 路径改写 + 命令交叉引用替换 | 1.5 天 |
| 3 | 4 个框架 agent 抽出到 `agents/` + `/mpdev:init` 文档调整 | 0.5 天 |
| 4 | `bin/install.sh` + `scripts/migrate-from-v1.sh`（含 PowerShell 版） | 0.5 天 |
| 5 | docs/ 4 个新文档（quickstart / upgrade-guide / troubleshooting / workflow） | 0.5 天 |
| 6 | VERSION 2.0.0 + CHANGELOG + 老仓库 README 加 deprecation 提示 | 0.5 天 |
| 7（可选） | hooks/ 框架（SessionStart 注入 CLAUDE.md 摘要等） | 1 天 |

**合计 4 天**（不含可选阶段 7）。

## 15. 风险与对策

### 15.1 命令命名变更影响

**风险**：所有用户脚本 / CI / 文档里写的 `/mpdev-fix` 等需要逐一改 `/mpdev:fix`。

**对策**：
- upgrade-guide.md 里给出 `sed -i 's|/mpdev-\([a-z]*\)|/mpdev:\1|g' file.sh` 类的批量替换示例
- v1.x 仍保留（半年维护期）；不愿改的用户可以继续用 v1
- README 突出 BREAKING CHANGES，明示迁移路径

### 15.2 `${CLAUDE_PLUGIN_ROOT}` 在命令 .md 内被 Claude 正确解析

**风险**：env var 在 hook context 里自动替换，但在命令 .md 这种"给 Claude 看的 prompt"里，Claude 是否能识别？

**对策**：
- 验证：参考 mppm 的 hooks 已用过 `${CLAUDE_PLUGIN_ROOT}`（在 shell 上下文里替换）。对命令 .md 这种 prompt 文本，需要在命令开头加锚点说明：
  > 本命令位于 plugin 目录；下文出现的 `${CLAUDE_PLUGIN_ROOT}/templates/...` 指代 plugin 安装根。Claude Code 运行时这是 `~/.claude/plugins/cache/mpdev/mpdev/`。
- 兜底：如果 Claude 不能用 env var，命令文件改为相对路径 `../templates/...`（命令在 `commands/`，模板在同级 `templates/`，相对路径 `../templates/...`）

### 15.3 4 个框架 agent 的项目级 override 行为

**风险**：现有项目可能已经在 `.claude/agents/code-reviewer.md` 里有自定义内容（如果 `/mpdev-init` 跑过的话）。v2 后这文件还会被 Claude Code 找到，**预期行为**是「项目优先 → plugin 兜底」（参考 mppm 也用同样模式）。

**未验证项**：Claude Code 当 agent 同名存在于项目和 plugin 两处时的查找优先级**需在实施阶段 3 用一个最小测试 case 验证**（建个空项目放自定义 `.claude/agents/code-reviewer.md` 看 `Agent(subagent_type="code-reviewer")` 调到哪个）。如查找顺序与预期相反，需要改文档说明 + 让 migrate-from-v1.sh 主动删 4 个框架 agent 文件（项目侧不留旧版）。

如果项目版本陈旧而优先级真是项目优先，会用旧版 review 逻辑。

**对策**：
- migrate-from-v1.sh **不删** `.claude/agents/` 下任何文件
- migrate-from-v1.sh 结尾打印提示：「检测到 .claude/agents/ 下有 N 个 agent。如想用 plugin 自带的最新版本，可删 .claude/agents/code-reviewer.md 等 4 个框架 agent；保留项目特化的 java-impl.md 等。」
- upgrade-guide.md 单写一节解释 override 优先级

### 15.4 不在本期范围

- **hooks 阶段（阶段 7）**：SessionStart 自动注入 CLAUDE.md 摘要、PostToolUse 自动归档等。先实现核心 plugin 化，hook 体验改进留到 v2.1.0
- **GUI 配置工具**：不做
- **MCP server 模式**：不做（mpdev 当前架构是 command + agent，不是 MCP server）
- **i18n**：英文版本不做，保持中文文档

## 16. 验收剧本（实施完成后跑）

1. **新装**：在没装过 mpdev 的机器上跑 `install.sh` + `/plugin install` → 在任意项目里 `/mpdev:` 应见到 9 个命令补全
2. **迁移**：在 v1.x 项目跑 `migrate-from-v1.sh` → `.claude/` 内只剩项目数据，备份完整；之后 `/mpdev:fix vue 测试 bug` 应正常执行
3. **升级**：用 `git -C ~/dev/mpdev pull` 拉新版 + `/plugin update` → 命令更新到新版本，项目数据零影响
4. **功能等价**：跑 v1.3.0 的 6 个验收剧本（Task 21-26），全部应 ✅ 通过
5. **override**：在项目放一个自定义 `.claude/agents/code-reviewer.md` → `/mpdev:fix` 触发 review 时应优先用项目版
6. **gitignore**：`migrate-from-v1.sh` 后，`.claude/.mpdev-runtime-creds.yml` 仍在 .gitignore 里
