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
