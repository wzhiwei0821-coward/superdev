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

本仓库是 mpdev 套件的**分发源**。各项目通过 `install.sh` 一键拉取，独立运行不依赖本仓库。

---

## 30 秒上手

**Linux / macOS / Git Bash：**
```bash
curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/install.sh | bash
```

**Windows PowerShell**（强制 UTF-8 解码，避免 `???` 乱码）：
```powershell
$wc = New-Object Net.WebClient
$wc.Encoding = [Text.Encoding]::UTF8
$s = $wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/install.ps1')
if ($s[0] -eq [char]0xFEFF) { $s = $s.Substring(1) }
iex $s
```

然后 4 个命令完成首次跑通：
```
/mpdev-understand          # 阶段 0a：生成各模块 CLAUDE.md
/mpdev-contracts           # 阶段 0b：跨模块项目才需要
/mpdev-init                # 阶段 1：生成 13 个 agent
/mpdev "需求描述"            # 阶段 2：日常开发
```

预计 30 分钟内完成首次实跑。

---

## 仓库结构

```
mpdev-suite/
├── .claude/                      # 套件本体（install.sh 拷贝这里）
│   ├── commands/                 # 9 个 slash 命令
│   ├── templates/                # 模板（.tmpl + dialects + test-flavors + understand/references）
│   ├── mpdev-runs/INDEX.md       # 空索引模板
│   ├── MPDev-Scheme.md           # 方案说明书（架构师视角）
│   ├── mpdev-suite-workflow.md   # 详细使用手册
│   └── README.md                 # 顶层入口（5 步激活流 + FAQ）
├── scripts/
│   ├── install.sh / install.ps1  # 首次安装（bash + PowerShell 双版本）
│   ├── update.sh  / update.ps1   # 升级（保留项目实例 + 三方合并）
│   └── pack.sh                   # 离线 tarball 打包
├── VERSION                       # 单一版本号源（语义化）
├── CHANGELOG.md                  # 版本变更
└── README.md                     # 本文件
```

---

## 安装方式

### 1. Linux / macOS / Git Bash（bash）

```bash
# 安装
curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/install.sh | bash

# 升级
curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/update.sh | bash

# 指定版本
curl -fsSL .../install.sh | MPDEV_VERSION=1.0.0 bash
```

### 2. Windows PowerShell（原生）

**推荐**（强制 UTF-8 解码避免乱码）：

```powershell
# 安装
$wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8
$s = $wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/install.ps1')
if ($s[0] -eq [char]0xFEFF) { $s = $s.Substring(1) }
iex $s

# 升级
$wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8
$s = $wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/update.ps1')
if ($s[0] -eq [char]0xFEFF) { $s = $s.Substring(1) }
iex $s

# 指定版本（在 iex 之前 set env）
$env:MPDEV_VERSION = '1.0.0'
# ... 然后跑上面的安装命令
```

**简化版**（仅当 raw URL 返回头声明了 charset=utf-8 时不乱码 — 实测 GitHub raw 不一定声明，慎用）：
```powershell
iwr -useb https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/install.ps1 | iex
```

> **为什么需要强制 UTF-8**：`raw.githubusercontent.com` 不一定在 Content-Type 声明 `charset=utf-8`，PS 5.1 的 `iwr` 缺省按 ISO-8859-1 解码字节流。脚本里的中文字符串 + UTF-8 BOM 都会被破坏 → 控制台显示为 `???`。`Net.WebClient` 配 `Encoding=UTF8` 强制按 UTF-8 解码。

> **PowerShell 别名陷阱**：在 PowerShell 里 `curl` 是 `Invoke-WebRequest` 的别名，不接 Unix 风格参数。如必须用 curl，用 `curl.exe`。

> **私有仓库**：GitHub 私有仓 raw URL 需要带 token —— `iwr` 加 `-Headers @{Authorization='token ghp_xxx'}`，或直接用 `git clone https://USER:TOKEN@github.com/...`。Public 仓不需要。

> **本仓库 Monorepo 模式**：mpdev-suite 作为 `superdev` 仓的 `mpdev-suite/` 子目录分发。脚本默认 `MPDEV_SUBDIR=mpdev-suite`，所以**用户跑命令零环境变量**。如果同事 fork 后改成独立仓（无 subdir），跑命令时 export `MPDEV_SUBDIR=''` 禁用即可。

### 3. 升级策略（适用所有平台）

备份当前 `.claude/` → 拉新版 → 覆盖框架文件 → **保留 agents/** 和 **mpdev-runs/** → dialects/test-flavors 三方合并（用户自定义保留为 `*.new` 待手工合并）。

### 4. 离线安装（内网无 GitHub 访问）

从 [GitHub Releases](https://github.com/wzhiwei0821-coward/superdev/releases) 下载 tarball：
```bash
# Linux / macOS / Git Bash
wget https://github.com/wzhiwei0821-coward/superdev/releases/download/v1.0.0/mpdev-suite-v1.0.0.tar.gz
tar -xzf mpdev-suite-v1.0.0.tar.gz
cd mpdev-suite-v1.0.0 && ./install.sh
```

```powershell
# Windows PowerShell
iwr https://github.com/wzhiwei0821-coward/superdev/releases/download/v1.0.0/mpdev-suite-v1.0.0.tar.gz -OutFile mpdev-suite.tar.gz
tar -xzf mpdev-suite.tar.gz   # Windows 10+ 自带 tar
cd mpdev-suite-v1.0.0 ; bash ./install.sh   # 离线包附带的 install.sh 仍是 bash 版
```

---

## 安装后效果

`.claude/` 目录下 38 个框架文件 + 1 个版本标识：

```
.claude/
├── commands/             9 .md
├── templates/
│   ├── *.tmpl            7 个（architect / contract-designer / impl-java/python/vue / dba / tester）
│   ├── dialects/         5 个（4 DB 方言 + README）
│   ├── test-flavors/     7 个项目类型 flavor
│   └── understand/references/  6 个语言指南
├── mpdev-runs/           空骨架（INDEX.md + 6 子目录）
├── MPDev-Scheme.md
├── mpdev-suite-workflow.md
├── README.md
└── .mpdev-version        当前安装版本号
```

`agents/`（13 个 AI agent 定义）由 `/mpdev-init` 在项目内自动生成，**不在套件分发范围**。

---

## 发布新版本（维护者用）

1. 改 `VERSION`（如 `1.1.0`）
2. 在 `CHANGELOG.md` 顶部加 `## [1.1.0] — YYYY-MM-DD` 段
3. commit + tag：
   ```bash
   git add VERSION CHANGELOG.md
   git commit -m "release: v1.1.0"
   git tag v1.1.0
   git push origin main --tags
   ```
4. 离线包（可选）：
   ```bash
   ./scripts/pack.sh
   # → dist/mpdev-suite-v1.1.0.tar.gz + .sha256
   ```
5. 在 [GitHub Releases](https://github.com/wzhiwei0821-coward/superdev/releases) 页面 attach `dist/*.tar.gz` 文件

---

## fork 给同事使用（修改默认 URL）

如果同事 fork 本套件到自己的仓库（如 `colleague/myrepo`），需修改脚本默认值。**两种 fork 形态**：

### A. 同事也作为 monorepo subdir（如 `colleague/myrepo/mpdev-suite/`）

```bash
# Git Bash / Linux：只需替换 owner/repo 名
sed -i 's|wzhiwei0821-coward/superdev|colleague/myrepo|g' \
  scripts/install.sh scripts/install.ps1 \
  scripts/update.sh  scripts/update.ps1 \
  scripts/pack.sh README.md
```

### B. 同事作为独立仓（无 subdir，如 `colleague/mpdev-suite`）

除了替换 owner/repo，还要把脚本里的 `SUBDIR` 默认值清空：

```bash
sed -i \
  -e 's|wzhiwei0821-coward/superdev|colleague/mpdev-suite|g' \
  -e 's|MPDEV_SUBDIR-mpdev-suite|MPDEV_SUBDIR-|g' \
  -e "s|else { 'mpdev-suite' }|else { '' }|g" \
  scripts/install.sh scripts/install.ps1 \
  scripts/update.sh  scripts/update.ps1 \
  scripts/pack.sh README.md

# raw URL 路径里的 /mpdev-suite/ 前缀也要去掉
sed -i 's|colleague/mpdev-suite/main/mpdev-suite/scripts/|colleague/mpdev-suite/main/scripts/|g' \
  scripts/*.sh scripts/*.ps1 README.md
```

```powershell
# Windows PowerShell 等价（只改 owner/repo，monorepo 模式 A）
$old = 'wzhiwei0821-coward/superdev'
$new = 'colleague/myrepo'
@('scripts/install.sh','scripts/install.ps1','scripts/update.sh','scripts/update.ps1','scripts/pack.sh','README.md') |
  ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_)
    $content = $content.Replace($old, $new)
    if ($_.EndsWith('.ps1')) {
      [System.IO.File]::WriteAllText($_, $content, (New-Object System.Text.UTF8Encoding $true))
    } else {
      [System.IO.File]::WriteAllText($_, $content, (New-Object System.Text.UTF8Encoding $false))
    }
  }
```

---

## License

Internal use.
