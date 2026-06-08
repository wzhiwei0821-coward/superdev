# mpdev v2.2.0 故障排查

按症状索引。

---

## /mpdev: 自动补全没出现

可能原因：

1. **plugin 没装成功**
   ```
   /plugin list
   ```
   应看到 `mpdev@superdev`。没显示 → 重装：
   ```
   /plugin marketplace add https://github.com/wzhiwei0821-coward/superdev
   /plugin install mpdev@superdev
   ```

2. **Claude Code 没重启**
   `/plugin install` 后必须**完全退出**（不只是 /clear）+ 重新打开 Claude Code

3. **plugin 文件没落地**
   ```
   ls ~/.claude/plugins/cache/mpdev/mpdev/*/commands/
   ```
   应见 9 个 .md 文件。没有 → `/plugin update` 或重装

---

## 命令报"找不到模板"或"templates/runtime-probe/probe-X.md not found"

```bash
ls ~/.claude/plugins/cache/mpdev/mpdev/templates/runtime-probe/
```

应有 5 个文件（README + probe-{db,http,browser,ws}.md）。缺失 → `/plugin update` 拉新版。

---

## ${CLAUDE_PLUGIN_ROOT} 没被解析为实际路径

命令文档里写 `Read ${CLAUDE_PLUGIN_ROOT}/templates/...`，但 Claude 报"file not found"。

诊断：

```bash
# 在 Claude Code 内
ls $CLAUDE_PLUGIN_ROOT/templates/   # 应能 ls
```

如果 `$CLAUDE_PLUGIN_ROOT` 为空 → 重启 Claude Code（env 变量在 plugin context 加载时设置）。

兜底：手动告诉 Claude 路径——`Read ~/.claude/plugins/cache/mpdev/mpdev/templates/runtime-probe/probe-db.md`

---

## /mpdev:fix 报告里所有 verified=skipped

可能原因：
- 服务没在跑 → `/mpdev:env status` 查
- DB 凭据失效 → 编辑 `.claude/.mpdev-runtime-creds.yml`
- state.yml 不存在 → 先跑 `/mpdev:env start`

详见 `${CLAUDE_PLUGIN_ROOT}/templates/runtime-probe/probe-browser.md` 的容错节。

---

## 老 v1 项目自定义的 code-reviewer 仍在生效

v1 项目可能在 `.claude/agents/code-reviewer.md` 有内容。Claude Code agent 查找优先级：**项目优先 → plugin 兜底**。

想用 plugin 自带版：
```bash
rm .claude/agents/code-reviewer.md
```

想保留项目自定义：什么都不做（plugin 版被 override）。

---

## 命令调用时报"unknown subagent: code-reviewer"

不可能——plugin 自带这 4 个框架 agent。检查：

```bash
ls ~/.claude/plugins/cache/mpdev/mpdev/agents/
```

应有 code-reviewer.md / integration-checker.md / acceptance-reviewer.md / doc-refresher.md。缺失 → `/plugin update` 或重装 plugin。

---

## migrate-from-v1.sh 跑完后项目里啥都没了

迁移脚本永远先备份再删。看 `.claude.v1-backup.{timestamp}/`：

```bash
ls .claude.v1-backup.*
```

应该有备份。恢复：

```bash
rm -rf .claude
mv .claude.v1-backup.{timestamp} .claude
```

如果没有备份（脚本异常退出前）→ 翻 git 历史 `git stash list` 或 `git reflog`。

---

## /plugin update 后行为变了

`/plugin update` 拉了新版 plugin，可能引入了新 step 或改了已有 step。看 CHANGELOG：

```bash
cat ~/.claude/plugins/cache/mpdev/mpdev/CHANGELOG.md | head -50
```

不喜欢新版？回退：

```bash
cd ~/dev/mpdev && git log --oneline | head -5   # 找上个稳定 commit
cd ~/dev/mpdev && git checkout <previous-sha>
/plugin update    # 拉本地修改
```

---

## Hooks 故障排查

### Hook 不生效

可能原因：

1. **plugin 版本太旧**
   ```bash
   cat ~/.claude/plugins/cache/mpdev/mpdev/VERSION
   ```
   显示 < 2.0.0 → `/plugin update` 拉新版

2. **plugin.json 未注册 hooks**
   ```bash
   grep hooks ~/.claude/plugins/cache/mpdev/mpdev/.claude-plugin/plugin.json
   ```
   应见 `"hooks": "./hooks/hooks.json"`。缺失 → 重装 plugin

3. **hooks/*.sh 不可执行**（仅 Linux/Mac）
   ```bash
   ls -l ~/.claude/plugins/cache/mpdev/mpdev/hooks/
   ```
   `*.sh` 应有 `x` 权限位。缺失 → 重跑 install.sh

4. **Windows 用了 cmd.exe / PowerShell 而非 Git Bash**
   mpdev hooks 都是 bash 脚本。Windows 必须装 Git for Windows，Claude Code 会用 Git Bash 执行 hook。如未装 → 装 [Git for Windows](https://gitforwindows.org/)

5. **hook 静默失败**
   bash hook 设计成 fail-silent。临时调试：
   ```bash
   bash -x ~/.claude/plugins/cache/mpdev/mpdev/hooks/session-start.sh < /dev/null
   ```
   查找 `cannot execute` / `command not found` 等错误。

### Hook 太吵 / 不想要

```bash
# 一开关全禁（当前 shell 生效）
export MPDEV_NO_HOOKS=1

# 永久禁用（写入 ~/.bashrc 或 PowerShell profile）
echo 'export MPDEV_NO_HOOKS=1' >> ~/.bashrc
```

或卸载 plugin：`/plugin uninstall mpdev`

### Hook 报错"jq: command not found"

hooks 优先用 jq；缺失会退化到 grep/sed 但可能不够准。装 jq：

```bash
# macOS:   brew install jq
# Ubuntu:  sudo apt install jq
# Windows Git Bash: 通常自带
```

### SessionStart hook 注入的项目类型不对

hook 扫的是项目里**所有** CLAUDE.md。如果版本太旧/不准 → `/mpdev:understand` 刷新各模块 CLAUDE.md。

如果 hook 注入了不该有的模块（如已删除的子项目目录）→ 删 `.claude/agents/<X>-impl.md` 或重跑 `/mpdev:init`。

### Windows .sh 文件 CRLF 行尾报错

Windows git autocrlf 可能把 .sh 转 CRLF，bash 报 `\r: command not found`。修复：

```bash
cd ~/.claude/plugins/cache/mpdev/mpdev
dos2unix hooks/*.sh
# 或者
for f in hooks/*.sh; do sed -i 's/\r$//' "$f"; done
```

install.ps1 自动处理这步；如果你跑的是 install.sh（Linux/Mac/Git Bash）不会出现这个问题。

---

## 还有其他问题

提 issue 时附：

```bash
# 收集诊断信息
cd ~/.claude/plugins/cache/mpdev/mpdev && cat VERSION
ls commands/
ls hooks/
/plugin list | grep mpdev
```
