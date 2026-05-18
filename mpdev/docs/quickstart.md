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
