# mpdev v2.0.0 故障排查

按症状索引。

---

## /mpdev: 自动补全没出现

可能原因：

1. **plugin 没装成功**
   ```bash
   /plugin list | grep mpdev
   ```
   没显示 → 重跑 `/plugin install mpdev@mpdev`

2. **Claude Code 没重启**
   `/plugin install` 后必须**完全退出**（不只是 /clear）+ 重新打开 Claude Code

3. **plugin 文件没落地**
   ```bash
   ls ~/.claude/plugins/cache/mpdev/mpdev/commands/
   ```
   应见 9 个 .md 文件。没有 → marketplace add 失败，重跑 `/plugin marketplace add file://~/dev/mpdev`

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

## 还有其他问题

提 issue 时附：

```bash
# 收集诊断信息
cd ~/.claude/plugins/cache/mpdev/mpdev && cat VERSION
ls commands/
/plugin list | grep mpdev
```
