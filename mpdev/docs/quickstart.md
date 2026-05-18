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

### 1A. 内网用户 — clone-first（GitLab 私有仓）

> GitLab 私有仓的 HTTP raw 端点不接受未认证请求，所以无法 curl one-liner，必须走 SSH 协议 clone。前置：[§0 SSH key 已配](#0-前置配-ssh-key仅内网用户首次)。

**Linux / macOS / Git Bash**：

```bash
git clone git@10.173.28.211:robot-ai/mppm/mpdev.git ~/dev/mpdev
bash ~/dev/mpdev/bin/install.sh --target=~/dev/mpdev
```

**Windows PowerShell**：

```powershell
git clone git@10.173.28.211:robot-ai/mppm/mpdev.git $env:USERPROFILE\dev\mpdev
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\dev\mpdev\bin\install.ps1 --target=$env:USERPROFILE\dev\mpdev
```

install 脚本检测到 `$target/.git` 存在时会跳过 clone，仅做 `git pull` + BOM 自检 + hook chmod。

### 1B. 外网用户 — curl one-liner（GitHub 公开仓）

**Linux / macOS / Git Bash**：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh) --source=github
```

**Windows PowerShell**（强制 UTF-8 解码避免乱码）：

```powershell
$wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8
$s = $wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.ps1')
if ($s[0] -eq [char]0xFEFF) { $s = $s.Substring(1) }
$env:MPDEV_SOURCE='github'
iex $s
```

### 1C. 在 Claude Code 内注册并装

install 脚本末尾会**直接打印** marketplace add 命令（含已解析的绝对路径），复制即可。
不要手工拼 `file://...`，Claude Code 不收 URI scheme，只接受 `owner/repo` / `https://...` / 文件系统路径。

通用形式：

```
/plugin marketplace add ~/dev/mpdev
/plugin install mpdev@mpdev
```

> **Windows 注解**：如果 Claude Code 不展开 `~`（不同版本行为不一致），就用脚本输出的绝对路径，**必须正斜杠**：
> ```
> /plugin marketplace add C:/Users/<你的用户名>/dev/mpdev
> ```

**完全重启 Claude Code**（不仅 `/clear`）。完成。

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
