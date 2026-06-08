# mpdev v2.1.1 1 分钟速览

新用户 1 分钟跑通第一个 mpdev 流程。

---

## 1. 安装（30 秒）— 推荐方式

**在 Claude Code 内直接装（自动更新）**：

```
/plugin marketplace add https://github.com/wzhiwei0821-coward/superdev
/plugin install mpdev@superdev
```

**完全重启 Claude Code**（不仅 `/clear`）。完成。

> **更新**：只需 `/plugin update`，自动从 GitHub 拉最新版。

---

### 备选：内网用户（GitLab 私有仓，需 SSH key）

> GitLab 私有仓需先配 SSH key：`ssh -T git@10.173.28.211` 看到 `Welcome to GitLab` 即可。未配见 [troubleshooting.md](./troubleshooting.md)。

```bash
git clone git@10.173.28.211:robot-ai/mppm/mpdev.git ~/dev/mpdev
```
然后在 Claude Code 内：
```
/plugin marketplace add ~/dev/mpdev
/plugin install mpdev@mpdev
```
更新：`cd ~/dev/mpdev && git pull`，然后 Claude Code 内 `/plugin update`。

> ⚠️ v2.1.0 用户 `/mpdev:*` 命令失效？运行修复脚本：
> ```bash
> bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/scripts/fix-v2.1.168.sh)
> ```

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
