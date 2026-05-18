---
name: init
description: MPDev 初始化 — 扫描项目模块，读取 CLAUDE.md，从模板生成 agent 定义和编排器
allowed-tools: Agent, Read, Grep, Glob, Bash, Write
---

# /mpdev:init — MPDev 项目初始化器

扫描当前项目结构，读取各模块 CLAUDE.md，从模板自动生成所有 agent 定义和编排器。

**使用场景**：
- 新项目首次配置 MPDev
- 项目结构变化后重新生成
- CLAUDE.md 更新后刷新 agent 定义

## 前置条件

本命令假设以下两项已就绪。若缺失，会引导用户先跑对应的阶段 0 命令。

| 前置 | 检查方式 | 缺失时 |
|------|---------|-------|
| 各模块 `CLAUDE.md` | `Glob("**/CLAUDE.md")` 至少 1 个 | 提示先跑 `/mpdev:understand` |
| `robot-contracts/` 仓库（跨模块项目）| `Glob("**/robot-contracts/")` | 跨模块项目：先跑 `/mpdev:contracts`；单模块项目：跳过 |

**新项目完整流程**：

```
/mpdev:understand     →  各模块 CLAUDE.md
       ↓
/mpdev:contracts      →  robot-contracts/（仅跨模块项目需要）
       ↓
/mpdev:init           →  .claude/agents/         ← 本命令
       ↓
/mpdev:dev 描述需求       →  开始日常开发
```

## 执行流程

### Step 1：扫描项目模块

```
Glob("**/CLAUDE.md")
排除: .claude/ node_modules/ .git/ __pycache__/ target/ dist/ build/
```

对每个找到的 CLAUDE.md，读取前 5 行确认是项目模块（非空、非模板）。

### Step 2：读取每个模块的 CLAUDE.md

对每个模块 CLAUDE.md 提取以下段落（grep ## 标题定位，Read 该段落）：

| 段落 | 用途 | 必须/可选 |
|------|------|----------|
| `## 技术栈` | 识别语言、框架、版本 | 必须 |
| `## 目录结构` | 提取关键路径 | 必须 |
| `## 编码规范` 或 `## 编码风格` | 注入 impl agent | 可选（无则留空） |
| `## 消费的 MQ 事件` | 标记有 MQ 消费 | 可选 |
| `## 发布的 MQ 事件` | 标记有 MQ 发布 | 可选 |
| `## WebSocket 推送` | 标记有 WebSocket | 可选 |
| `## 构建与部署` | 提取构建命令 | 可选 |
| `## 与其他模块的关系` | 构建通信拓扑 | 可选 |

### Step 3：识别语言和角色

从 `## 技术栈` 内容判断：

| 关键词 | 语言 | 模板 |
|--------|------|------|
| Java / Spring Boot / Maven / MyBatis | java | impl-java.tmpl |
| Python / Flask / Django / asyncio / ROS | python | impl-python.tmpl |
| Vue / React / Angular / npm / webpack | frontend | impl-vue.tmpl |

特殊判断：
- 目录下有 `schemas/` + `openapi/` + `sql/` → 契约仓库，不生成 impl，用 contract-designer.tmpl
- CLAUDE.md 中有"纯 HTTP"/"无 MQ"/"无 DB" → 标记 `mode: verify_first`

### Step 4：识别模块依赖

从各模块 `## 与其他模块的关系` 和通信拓扑推断依赖：

规则：
- 前端模块的 `## 与其他模块的关系` 提到"调用后端 API" → `depends_on: [后端模块-impl]`
- 如果无法确定，**询问用户**："{module_A} 是否依赖 {module_B} 的产出？"
- 默认：所有模块无依赖（并行）

### Step 5：生成 Impl Agent 定义

对每个业务模块（非契约仓库）：

1. 读取对应模板 ``${CLAUDE_PLUGIN_ROOT}/templates/impl-{language}.tmpl`
2. 替换占位符：

| 占位符 | 来源 |
|--------|------|
| `{name}` | 目录名简写 + "-impl"（如 mr_ult_java_2.1 → java-impl） |
| `{project_name}` | 从根目录名或用户指定 |
| `{directory}` | 模块目录名 |
| `{tech_stack}` | CLAUDE.md `## 技术栈` 内容 |
| `{module_structure}` | CLAUDE.md `## 目录结构` 内容（Java 模板用） |
| `{architecture}` | CLAUDE.md `## 目录结构` 或核心架构内容（Python 模板用） |
| `{coding_standards}` | CLAUDE.md `## 编码规范` 内容 |
| `{build_cmd}` | 从 `## 构建与部署` 提取，或按语言默认 |
| `{test_cmd}` | 从 `## 构建与部署` 提取，或按语言默认 |
| `{special_notes}` | CLAUDE.md 中的特殊注意/已知隐含知识 |
| `{sub_apps}` | 前端模块的子应用表（如有） |
| `{depends_on}` | Step 4 推断的依赖列表 |

3. 写入 `.claude/agents/{name}.md`

### Step 6：生成 Architect 定义

1. 读取 ``${CLAUDE_PLUGIN_ROOT}/templates/architect.tmpl`
2. 汇总所有模块信息：

| 占位符 | 来源 |
|--------|------|
| `{project_name}` | 项目名 |
| `{modules_table}` | 汇总表（模块名/目录/技术栈/端口） |
| `{communication_chain}` | 从各模块 `## 与其他模块的关系` 汇总 |
| `{naming_conventions}` | 从契约仓库 `## 命名约定` 读取，无则留空 |

3. 写入 `.claude/agents/architect.md`

### Step 7：生成 Contract-Designer 定义

1. 如果找到契约仓库：
   - 读取 ``${CLAUDE_PLUGIN_ROOT}/templates/contract-designer.tmpl`
   - 注入仓库路径、目录结构、校验脚本
   - 写入 `.claude/agents/contract-designer.md`
2. 如果没有契约仓库：
   - 跳过，汇总时告知用户"未找到契约仓库，跳过 contract-designer"

### Step 8：生成 DBA 定义（条件触发）

**前提**：本项目使用关系型数据库（从 Step 2 扫到任何模块含 MySQL/PG/达梦/金仓等关键词）。纯前端/算法/无 DB 项目跳过。

#### 8.1 识别数据库引擎

按优先级扫描：

1. Glob `**/docker-compose*.yml` 看 `image:` 字段（`mysql:*` / `postgres:*` / `dm8` / `kingbase*` 等）
2. Grep 各模块 CLAUDE.md `## 技术栈` 中的数据库关键词
3. Grep 配置文件 `application.yml` / `config.yaml` 的 `driver-class-name` / `url` / `jdbc:*`
4. 若仍不确定 → `AskUserQuestion`：
   ```
   "未自动识别出数据库类型。请选择：
    [MySQL / MariaDB] [PostgreSQL / openGauss / GaussDB]
    [达梦 DM] [人大金仓 KingbaseES] [Oracle] [其他]"
   ```

#### 8.2 选择 dialect 文件

| 识别结果 | dialect 文件 |
|---------|-------------|
| `mysql` / `mariadb` | ``${CLAUDE_PLUGIN_ROOT}/templates/dialects/mysql.md` |
| `postgres` / `postgresql` / `opengauss` / `gaussdb` | ``${CLAUDE_PLUGIN_ROOT}/templates/dialects/postgresql.md` |
| `dm7` / `dm8` / `dameng` / `达梦` / `dm.jdbc` | ``${CLAUDE_PLUGIN_ROOT}/templates/dialects/dameng.md` |
| `kingbase` / `kingbase8` / `人大金仓` / `com.kingbase8` | ``${CLAUDE_PLUGIN_ROOT}/templates/dialects/kingbase.md` |
| 其他（Oracle / SQL Server / TiDB / OceanBase 等）| 兜底 `mysql.md`，在生成的 dba.md 顶部加注释"⚠️ 检测到 {DB}，当前无专用方言文件，已用 MySQL 方言兜底，需人工补充差异" |

#### 8.3 合并占位符

1. 读 ``${CLAUDE_PLUGIN_ROOT}/templates/dba.tmpl`
2. 读选定 dialect 文件，提取：
   - 顶部 yaml 元数据（`db_engine`, `db_engine_short`, `charset`, `pk_convention`, `fk_policy`, `entity_paths`, `migration_dir`）
   - 所有 `<!-- BLOCK:XXX -->` ... `<!-- /BLOCK:XXX -->` 标签内容
3. 替换 dba.tmpl 中的占位符：
   - 元数据类：`{{DB_ENGINE}}`, `{{CHARSET}}`, `{{PK_CONVENTION}}`, `{{FK_POLICY}}`, `{{ENTITY_PATHS}}`, `{{MIGRATION_DIR}}`
   - 区块类：`{{DB_CONFIG_BLOCK}}`, `{{DIALECT_CAVEATS_BLOCK}}`, `{{TYPE_CHOICES_BLOCK}}`, `{{DDL_SAFETY_BLOCK}}`, `{{BIG_TABLE_TOOLS_BLOCK}}`, `{{INDEX_TYPES_BLOCK}}`, `{{BATCH_UPDATE_BLOCK}}`, `{{AUDIT_FIELDS_SQL_BLOCK}}`, `{{DIALECT_CONSTRAINTS_BLOCK}}`
   - `{{PROJECT_NAME}}` 来自 mpdev-init 上下文
4. 写入 `.claude/agents/dba.md`

#### 8.4 多数据库场景

若项目同时用多种 DB（主库 + 分析库等）：

- 重复 7.5.2-7.5.3，每种 DB 生成一份 dialect 片段
- 将多份片段合并到同一个 dba.md，每个 BLOCK 前加二级标题区分（如 `### 主库 MySQL` / `### 分析库 PostgreSQL`）
- 在 `平台数据库概览` 段明确各 DB 的用途和分工

### Step 9：生成 Tester 定义（条件触发）

**前提**：项目存在可测试代码（不是纯文档/资源仓库）。

#### 9.1 识别项目类型（flavor）

按优先级扫描：

```
1. Glob `**/docker-compose*.yml` 看 services 数量与镜像
2. Glob 各模块 package.json / pom.xml / requirements.txt / go.mod
3. 综合判断:
```

| 检测信号 | flavor 文件 |
|---------|-------------|
| compose 含 nacos/eureka/consul + 5+ 服务 / Spring Cloud / Dubbo / gRPC | `microservices.md` ✅ |
| `package.json` 含 vue/react/angular/svelte | `web-frontend.md` ✅ |
| `pom.xml` 含 spring-boot-starter-web / `requirements.txt` 含 fastapi/flask / `go.mod` 含 gin | `http-api.md` ✅ |
| airflow / pyspark / kafka consumer / dbt project | `data-pipeline.md` ✅ |
| YOLO/PaddleOCR/torch/tensorflow/onnx + 模型文件 | `algo-service.md` ✅ |
| ROS / `package.xml` / 嵌入式工具链 / 硬件 SDK | `robot-iot.md` ✅ |
| iOS xcodeproj / Android `app/build.gradle` / Flutter / React Native | `mobile-app.md` ✅ |
| 都不命中 | 兜底 `http-api.md` + 警告"项目类型未识别" |

**当前实现**：7 个 flavor 全部就位，覆盖 90% 主流项目类型。

**多类型混合识别**：项目同时命中多个信号时（如算法服务嵌前端管理页），按"主导信号"选 flavor，其他作为补充段。详见 §9.3。

不确定 → AskUserQuestion 让用户从 7 个可用 flavor 列表选择。

#### 9.2 合并 tester.tmpl + flavor

1. 读 ``${CLAUDE_PLUGIN_ROOT}/templates/tester.tmpl`
2. 读 ``${CLAUDE_PLUGIN_ROOT}/templates/test-flavors/{flavor}.md`，提取：
   - 顶部 yaml 元数据（`project_type` / `project_type_short` / `default_test_dir` 等）
   - 8 个 `<!-- BLOCK:XXX -->` 区块（PROJECT_TYPE_SCOPE / TEST_LEVELS / KEY_RISK_AREAS / AUTOMATION_STACK / CI_INTEGRATION / METRICS / NON_FUNCTIONAL / SAMPLE_CASES / DIALECT_CONSTRAINTS）
3. 替换 tester.tmpl 中的占位符：
   - 元数据：`{{PROJECT_NAME}}` / `{{PROJECT_TYPE}}` / `{{PROJECT_TYPE_SHORT}}`
   - 区块：`{{XXX_BLOCK}}`（共 8 个）
4. 写入 `.claude/agents/tester.md`

#### 9.3 多类型混合项目

若识别到多个 flavor 命中（如算法服务里嵌前端管理页）：
- 选**主导 flavor**（行数最多/类型最强的模块）
- 其他 flavor 的 SAMPLE_CASES 作为补充段追加
- 在 tester.md 顶部 `## 项目类型` 段说明"主类型 X，含 Y/Z 子类型"

### Step 10：通用 Agent 由 plugin 自带（v2.0.0 起）

以下 4 个框架级 agent 由 mpdev plugin 自带（位于 `${CLAUDE_PLUGIN_ROOT}/agents/`），**本步骤不生成、不复制**：

- `code-reviewer`（plugin 自带）
- `integration-checker`（plugin 自带）
- `acceptance-reviewer`（plugin 自带）
- `doc-refresher`（plugin 自带）

调用方式不变：仍是 `Agent(subagent_type="code-reviewer", ...)`。Claude Code 会先查项目 `.claude/agents/<name>.md`，再回退到 plugin `agents/<name>.md`。

**项目级 override**：用户在 `.claude/agents/code-reviewer.md` 等位置写自定义内容会优先于 plugin 自带版本。

**v1 项目迁移注意**：v1 在 `.claude/agents/` 下生成过这 4 个 agent。可手动删除让 plugin 接管（推荐），或保留用项目自定义版本。

### Step 11：生成 mpdev.md 编排器

读取当前 `.claude/commands/mpdev:dev.md`（如存在），保留通用编排框架，更新：
- Step 4 的模块列表和依赖关系（从 Step 4 结果）
- Step 2 的上下文提取关键词映射（从各模块特征推断）

如果 mpdev.md 不存在，按通用编排模式生成。

### Step 12：输出汇总

```markdown
## MPDev Init 完成

### 项目: {project_name}
### 检测到的模块:
| 模块 | 目录 | 语言 | 模板 | 依赖 |
|------|------|------|------|------|
| ... | ... | ... | ... | ... |

### 生成的文件:
- .claude/agents/architect.md ← architect.tmpl + 全局汇总
- .claude/agents/contract-designer.md ← contract-designer.tmpl + 契约仓库
- .claude/agents/dba.md ← dba.tmpl + dialects/{db}.md（条件触发：本项目有 DB 时）
- .claude/agents/tester.md ← tester.tmpl + test-flavors/{type}.md（按项目类型）
- .claude/agents/{name}-impl.md × N ← impl-{lang}.tmpl + CLAUDE.md
- (code-reviewer / integration-checker / acceptance-reviewer / doc-refresher 由 plugin 自带，本命令不生成)

### 建议:
1. Review 生成的 agent 定义，确认技术栈和编码规范提取准确
2. 检查模块依赖关系是否正确
3. 可用 `/mpdev:check` 检测契约一致性
4. 用 `/mpdev:dev 需求描述` 开始开发
```

## 约束

1. **不覆盖已有的自定义修改** — 如果 `.claude/agents/` 下已有同名文件，询问用户是否覆盖
2. **CLAUDE.md 是唯一信息源** — 不猜测，不硬编码，所有信息从 CLAUDE.md 提取
3. **无法识别的模块** — 询问用户而非跳过
4. **命名推断** — 目录名过长时（如 mr_ult_java_2.1），取有意义的简写（java-impl），确认后使用
