# 从 mpdev v1.x 升级到 v2.0.0

v2.0.0 是 BREAKING 变更：命令命名、目录结构、安装方式全变了。本指南帮你迁。

---

## TL;DR

```bash
# 1. 装 v2 plugin（全局，一次性）

# 1a. 内网用户 — clone-first（GitLab 私有仓必须走 SSH）
git clone git@10.173.28.211:robot-ai/mppm/mpdev.git ~/dev/mpdev
bash ~/dev/mpdev/bin/install.sh --target=~/dev/mpdev

# 1b. 外网用户 — one-liner（GitHub 公开仓）
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh) --source=github

# 然后在 Claude Code 内:
/plugin marketplace add file://~/dev/mpdev
/plugin install mpdev@mpdev

# 2. 在老 v1 项目根跑迁移脚本
cd /path/to/old-project
bash ~/dev/mpdev/scripts/migrate-from-v1.sh

# 3. 重启 Claude Code，使用新命令名
/mpdev:fix vue 下拉框 bug    # 不再是 /mpdev-fix
```

> Windows PowerShell 等价命令见 [quickstart.md §1](./quickstart.md#1-安装30-秒)。

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
