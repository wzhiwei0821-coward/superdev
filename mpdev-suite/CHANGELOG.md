# Changelog

All notable changes to mpdev-suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 版本规则

- **Major (X.0.0)**: 不向后兼容（BLOCK 命名变更、命令重命名、Step 重排、目录结构变更）
- **Minor (1.X.0)**: 新增 flavor / dialect / 命令 / agent
- **Patch (1.0.X)**: bug 修复、文档完善、模板小调整

## [1.0.0] — 2026-04-28

首发版本。

### Added
- **9 个 slash 命令**：mpdev, mpdev-init, mpdev-fix, mpdev-test, mpdev-check, mpdev-env, mpdev-commit, mpdev-understand, mpdev-contracts
- **12 个 AI agent**（运行时通过 mpdev-init 生成）：3 架构 + 5 实现 + 2 审查 + 1 验收 + 1 测试
- **DBA 双层模板**：dba.tmpl 骨架 + 4 数据库方言（mysql / postgresql / dameng / kingbase）
- **Tester 双层模板**：tester.tmpl 骨架 + 7 项目类型 flavor（http-api / web-frontend / microservices / mobile-app / algo-service / data-pipeline / robot-iot）
- **三阶段测试嵌入**：mpdev 主流程 Step 7 / 9 / 12（IEEE 829 标准）
- **缺陷生命周期闭环**：/mpdev-test bug export → markdown → /mpdev-fix --batch
- **project-understanding 本地副本**：6 份 references（2333 行）随套件分发，免依赖外部 skill 安装
- **install.sh / update.sh / pack.sh**：一行命令安装、保留实例升级、离线 tarball
- **install.ps1 / update.ps1**：Windows PowerShell 原生支持，不依赖 bash（绕开 PowerShell `curl` 别名陷阱）
- **分发渠道**：GitHub（raw.githubusercontent.com 拉脚本 / Releases 发离线包）

### Notes
- mpdev 主流程 Step 编号已用整数（0-13），不再使用 0.5 / 1.5 等小数
- 套件总规模约 6000 行 markdown + 50+ 文件
- 适用范围：单模块 / 跨模块（monorepo）/ Spring Cloud + Nacos / 多语言混合栈
