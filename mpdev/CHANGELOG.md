# Changelog

All notable changes to mpdev plugin will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 版本规则

- **Major (X.0.0)**: 不向后兼容（命令重命名、目录结构变更、安装方式变更）
- **Minor (1.X.0)**: 新增命令 / agent / 探针 / flavor / dialect
- **Patch (1.0.X)**: bug 修复、文档完善、模板小调整

## [2.1.0] — 2026-05-18

### Added
- **3 个 hooks**（位于 `${CLAUDE_PLUGIN_ROOT}/hooks/`）:
  - **SessionStart** (`hooks/session-start.sh`): 启动时自动检测项目里所有 CLAUDE.md，提取「## 技术栈」节摘要注入 Claude 上下文。省去手工说明项目背景。
  - **UserPromptSubmit** (`hooks/inject-keyword-hint.sh`): 用户输入含 7 种模式关键词时（"修 bug" / "新需求" / "理解项目" / "启动服务" / "写测试" / "检查契约" / "生成 commit"），systemMessage 提示对应 `/mpdev:*` 命令。
  - **SubagentStop** (`hooks/post-subagent-check.sh`): impl agent 输出 `cross_module_issue` 字段非 null 时，additionalContext 提示跨模块影响 + 启发式抽出目标模块名建议下一步。
- **`MPDEV_NO_HOOKS=1` 一开关**全禁所有 hook（适合 CI / 噪声敏感场景）
- `hooks/_lib.sh` 共享工具（禁用检查 / 项目根定位 / YAML 解析）
- `docs/troubleshooting.md` 新增 hook 章节

### Changed
- `plugin.json` 新增 `"hooks": "./hooks/hooks.json"` 字段
- `install.sh` 末尾 chmod +x hooks/*.sh
- `install.ps1` 末尾把 .sh 行尾从 CRLF 转 LF（防 Windows git autocrlf 引入 \r\n 破坏 shebang）

### Notes
- hook 脚本为 bash；Windows 用户需 Git Bash for Windows
- v2.0.x 用户 `/plugin update` 直接拉到 v2.1.0
- 3 个 hook 全 fail-silent + 3-5 秒超时
- hooks 全部只读（不写项目数据）

### 未做（推迟到 v2.2+）
- PostToolUse(git commit) 自动归档 — 与 /mpdev:commit 重叠分析未完成
- PreToolUse(git push) 调 /mpdev:check — 高侵入，需 opt-in 设计
- PostToolUse(Edit/Write) doc-refresher — 需 batch 机制
- PowerShell 原生 hook 支持（.ps1）
- 项目级 `.claude/.mpdev-hooks.yml` 细粒度开关

## [2.0.1] — 2026-05-18

### Fixed
- **install BOM 自检**：T42 audit 发现的 bug — 中文 Windows 上无 BOM 的 .ps1 被 GBK 解码 → migrate 等脚本完全无法运行。install.sh / install.ps1 末尾扫描 mpdev/**/*.ps1，缺 BOM 自动补齐。同时保护 fork 场景（同事用无 BOM 编辑器改 .ps1 后 push 回仓的情况）。

### Added
- **`--auto-clean-framework-agents` flag**（migrate-from-v1.sh + .ps1）：opt-in 删除 4 个框架 agent（code-reviewer / integration-checker / acceptance-reviewer / doc-refresher）让 plugin 接管。默认不删（保护项目自定义）。
- migrate 脚本支持 `--help` / `-h` 输出 usage。

### Notes
- v2.0.0 用户无需 migrate，直接 `/plugin update` 即可。
- semver patch：完全向后兼容，未改任何命令行为或文件格式。

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
