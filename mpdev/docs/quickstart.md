# mpdev v2.0.0 5 分钟速览

新用户 5 分钟跑通第一个 mpdev 流程。

---

## 0. 前置：配 SSH key（仅内网用户首次）

**外网用户跳过本节** — `--source=github` 走 HTTPS，不需要 SSH。

**内网用户**：mpdev 默认从 GitLab `git@10.173.28.211:robot-ai/mppm/mpdev.git` 拉，需要先把本机 SSH 公钥贴到 GitLab。已配过的跑 `ssh -T git@10.173.28.211` 看到 `Welcome to GitLab, @<你>!` 就跳过本节。

### 4 步配 SSH（PowerShell 示例，Git Bash 命令同名）

**① 检查是否已有 key**

```powershell
Get-ChildItem -Force $env:USERPROFILE\.ssh -ErrorAction SilentlyContinue
```

有 `id_ed25519` + `id_ed25519.pub`（或 `id_rsa` + `id_rsa.pub`）→ 跳到 ③。没有 → 继续 ②。

**② 生成 key**（全部按回车用默认）

```powershell
ssh-keygen -t ed25519 -C "你的标签随便填"
```

`-C` 是注释标签，可填邮箱、机器名、随便什么字符串，不参与鉴权。建议填能让你以后认出来的（如 `windows-laptop`）。

**③ 复制公钥并贴到 GitLab**

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | Set-Clipboard
```

浏览器开 `http://10.173.28.211/-/user_settings/ssh_keys`：
- Key 框 `Ctrl+V`
- Title 填刚才的标签
- Add key

**④ 验证**

```powershell
ssh -T git@10.173.28.211
```

首次问 `yes/no` 输 `yes`。期望：`Welcome to GitLab, @<你的用户名>!`

> 失败排查：
> - `Permission denied (publickey)` → ③ 公钥没贴全/贴错账号，重做 ③
> - `Connection refused` → 不在内网，先连 VPN
> - 仍跑不通 → 见 [troubleshooting.md](./troubleshooting.md)

---

## 1. 安装（30 秒）

**内网（默认，从 GitLab）**：

```bash
bash <(curl -fsSL http://10.173.28.211/robot-ai/mppm/mpdev/-/raw/master/bin/install.sh)
```

**外网（GitHub）**：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh) --source=github
```

也可以在已 clone 的本地仓跑 `bash bin/install.sh` 或 `bash bin/install.sh --source=github`。

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
