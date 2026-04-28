# Vue 前端 — 分轮执行指令

> 本文件由 SKILL.md 在检测到 Vue 项目时加载。按 Prompt 1-6 逐轮执行。

---

## Prompt 1 — 项目骨架

笔记写入 `.claude-notes/round1.md`。

1. 依赖：
   cat package.json
   → 提取：Vue 版本、UI 框架（Element Plus / Ant Design Vue / Naive UI / 无）、
     状态管理（Pinia / Vuex / 无）、路由、HTTP 库、构建工具（Vite / Webpack）、TS 还是 JS

2. 构建配置：
   cat vite.config.ts 2>/dev/null || cat vite.config.js 2>/dev/null || cat vue.config.js 2>/dev/null
   cat tsconfig.json 2>/dev/null
   → 提取：路径别名、代理配置

3. 环境变量：
   cat .env.development 2>/dev/null
   cat .env.production 2>/dev/null
   cat .env 2>/dev/null
   → 提取：API 地址、其他环境变量

4. 目录结构：
   find src -type d | sort

5. 入口文件：
   cat src/main.ts 2>/dev/null || cat src/main.js 2>/dev/null
   → 提取：全局注册的插件、组件、指令

6. 样式方案：
   ls tailwind.config.* 2>/dev/null; ls postcss.config.* 2>/dev/null; ls src/styles/ 2>/dev/null

笔记格式：

```
# 第 1 轮：项目骨架
## 技术栈
- Vue 版本：
- 语言：TS / JS
- UI 框架：
- 状态管理：
- 路由：
- HTTP 库：
- 构建工具：
- 样式方案：
## 目录约定
（每个 src 子目录一句话说明）
## 全局注册
（插件、组件、指令）
## 环境配置
（API 地址、其他）
## 存疑项
```

---

## Prompt 2 — 接口边界

先 `cat .claude-notes/round1.md`，笔记写入 `.claude-notes/round2.md`。

A. API 调用层全量读取：
   find src -path "*/api/*" \( -name "*.ts" -o -name "*.js" \) | sort
   → 逐个 cat（前端 api 文件通常 20-50 行）
   → 提取每个函数：名称、路径、HTTP 方法、参数类型、返回类型

B. HTTP 请求封装：
   find src -name "request.ts" -o -name "http.ts" -o -name "axios.ts" -o -name "request.js" | head -3
   → cat → 提取：baseURL、请求拦截器、响应拦截器、超时
   fallback：grep -rn "axios\|fetch(" src/ --include="*.ts" --include="*.js" -l | head -3

C. 路由：
   cat src/router/index.ts 2>/dev/null || cat src/router/index.js 2>/dev/null
   → 提取：所有路由 path/name/component/meta
   → 路由守卫 beforeEach 逻辑
   大文件防护：超 200 行只提取路由表部分

D. WebSocket：
   grep -rn "WebSocket\|useWebSocket\|socket\.\|ws://" src/ --include="*.ts" --include="*.js" --include="*.vue" -l
   → cat → 提取：连接地址、监听事件、处理方式
   fallback：grep -rn "onmessage\|addEventListener.*message\|EventSource" src/ -l

E. 页面列表：
   ls src/views/ 2>/dev/null || ls src/pages/ 2>/dev/null
   → 与路由表交叉对照

笔记格式：

```
# 第 2 轮：接口边界
## API 调用（共 x 个）
| 函数名 | 路径 | 方法 | 参数 | 说明 |
|---|---|---|---|---|
## HTTP 封装
（baseURL、拦截器、超时）
## 路由（共 x 个页面）
| 路径 | 页面名 | 组件 | 权限要求 |
|---|---|---|---|
## 路由守卫
## WebSocket
| 连接地址 | 监听事件 | 处理方式 |
|---|---|---|
## 存疑项
```

---

## Prompt 3 — 核心页面与状态管理

先读取前两轮笔记：
   cat .claude-notes/round1.md
   cat .claude-notes/round2.md选 3-5 个核心页面完整读取。笔记写入 `.claude-notes/round3.md`。
选择标准：涉及 CRUD 的优先、涉及 WebSocket 的优先、路由表中权重高的优先。
大文件防护：.vue 超 400 行先 grep -n "const\|function\|watch\|onMounted" 看结构。

对每个页面：
1. cat src/views/XxxPage.vue → template 结构、调了哪些 API/Store、watch/computed 逻辑、表单校验
2. 找到它用的 Store：cat src/stores/xxx.ts → state/actions/getters
3. 找到它用的 composable：从 import 中找 useXxx → cat
4. 找到跨页面复用的自定义组件 → 提取 props/emits

笔记格式：

```
# 第 3 轮：核心页面与状态管理
## 页面 1：XxxPage
路由路径：
用户操作：
  - 操作 A → 调用 xxxApi.method() → 刷新列表
  - 操作 B → 调用 store.action() → 更新状态
数据来源：（API / WebSocket / Store 缓存）
数据刷新方式：（手动 / 轮询 / WebSocket / 路由进入时）
表单校验：
分页：（前端/后端，每页大小）
## 页面 2：...
## 状态管理全局视图
| Store | state 字段 | 主要 action | 数据来源 |
|---|---|---|---|
## 跨页面复用组件
| 组件名 | props | emits | 使用页面 |
|---|---|---|---|
## 存疑项
```

---

## Prompt 4 — 基础设施与编码风格

先 `cat .claude-notes/round3.md`，笔记写入 `.claude-notes/round4.md`。

A. 工具函数：
   find src/utils -name "*.ts" -o -name "*.js" 2>/dev/null | sort → 逐个 cat
   fallback：find src -name "utils.*" -o -name "helpers.*" | head -5

B. 布局组件：
   find src/layouts -name "*.vue" 2>/dev/null | head -3 → cat 主布局

C. 权限控制：
   grep -rn "v-permission\|v-auth\|v-role\|hasPermission\|checkAuth" src/ --include="*.vue" --include="*.ts" | head -15

D. 编码风格采样（从第 3 轮读过的 .vue 文件归纳）：
   - 组件写法：<script setup> 还是 Options API？
   - 命名风格：文件名 PascalCase / kebab-case？变量 camelCase？
   - CSS 写法：scoped / module / Tailwind / SCSS？
   - 响应式：ref 还是 reactive？
   - 组件通信：props/emit / provide/inject / Pinia store？
   - TypeScript 深度：严格类型还是 any 多？
   - 注释习惯

E. 代码质量配置：
   cat .eslintrc.* 2>/dev/null || cat eslint.config.* 2>/dev/null | head -50
   cat .prettierrc* 2>/dev/null

笔记格式：

```
# 第 4 轮：基础设施与编码风格
## 工具函数
| 函数名 | 用途 |
|---|---|
## 布局结构
## 权限控制
## 编码风格（从代码采样归纳）
- 组件风格：
- 命名约定：
- CSS 方案：
- 响应式偏好：
- 组件通信方式：
- TypeScript 深度：
- 注释习惯：
## ESLint/Prettier 要点
## 存疑项
```

---

## Prompt 4.5 — 接口完整性校验

先 `cat .claude-notes/round2.md` 回顾已提取的 API 调用列表。
然后用以下策略重新扫描，与 round2 的结果交叉比对。

```bash
# 策略 A：找所有 HTTP 请求调用（不只是 api/ 目录下的，覆盖组件中直接调 axios 的情况）
grep -rn "axios\.\|request\.\|fetch(\|\.get(\|\.post(\|\.put(\|\.delete(" src/ --include="*.ts" --include="*.js" --include="*.vue" | grep -v "node_modules\|test\|mock\|\.d\.ts"

# 策略 B：找 .vue 和 .ts 中直接写的 API 路径字符串
grep -rn '"/api/\|/api/' src/ --include="*.vue" --include="*.ts" --include="*.js" | grep -v "node_modules\|test\|mock"

# 策略 C：找 WebSocket 相关（覆盖非标准封装）
grep -rn "WebSocket\|ws://\|wss://\|socket\.\|onmessage\|EventSource\|SSE" src/ --include="*.ts" --include="*.js" --include="*.vue" | grep -v "node_modules"

# 策略 D：找已有接口文档
find . -name "*.http" -o -name "*.rest" -o -name "postman*" | head -5
find docs/ -type f 2>/dev/null | head -10
```

将比对结果追加写入 `.claude-notes/round2.md` 末尾，格式：

```
## 完整性校验补充
### 新发现（round2 遗漏）
| 类型 | 内容 | 发现方式 | 置信度 |
|---|---|---|---|
（如果有新发现逐行填写，没有就写"无新发现"）
### 需在 Prompt 5 中追加确认的问题
```

---

## Prompt 5 — 验证与补盲

先读取全部笔记：
   cat .claude-notes/round1.md
   cat .claude-notes/round2.md
   cat .claude-notes/round3.md
   cat .claude-notes/round4.md

1. 读测试文件（如有）：find src -name "*.test.ts" -o -name "*.spec.ts" | head -3 → cat
2. git log --oneline -20
3. head -100 README.md 2>/dev/null
4. 汇总存疑项提问。每个问题说明：问题、为什么代码看不出、猜测。
5. 接口完整性定向确认：
   - "我发现前端调用了以下后端 API：[列出]。是否还有遗漏？特别是在组件中直接调 axios 没走 api/ 封装层的？"
   - "我发现以下 WebSocket 连接：[列出]。是否还有其他 channel？"
   - 如果 Prompt 4.5 发现了新调用，逐个向用户确认

6. 将分析过程中发现的所有代码问题整理为 TODO 清单，写入 `.claude-notes/todo.md`，格式：
   ```
   # 深度理解发现的待优化项
   ## 🔴 Bug / 潜在风险
   - [ ] 问题描述（出处：组件名/文件名 L行号）
   ## 🟡 设计优化
   - [ ] 问题描述（出处）
   ## 🟢 规范改进
   - [ ] 问题描述（出处）
   ## ❓ 待确认
   - [ ] 问题描述（出处）— 我的猜测：...
   ```
   同时在对话中向用户展示这份清单。

---

## Prompt 6 — 合成 CLAUDE.md

先读取全部笔记：
   cat .claude-notes/round1.md
   cat .claude-notes/round2.md
   cat .claude-notes/round3.md
   cat .claude-notes/round4.md
   cat .claude-notes/todo.md

结合用户回答的内容，生成两个文件：

### 文件 1：CLAUDE.md（写入项目根目录）

必须包含的区块：
1. 技术栈（Vue 版本、UI 框架、状态管理、构建工具、样式方案）
2. 目录结构
3. API 调用层（表格，含置信度列）
4. WebSocket 连接（含置信度列）
5. 路由表（表格）
6. 核心页面用户操作路径
7. 状态管理（每个 Store 的 state/action/getter）
8. 跨页面复用组件（props/emits）
9. ⚠️ 接口字段（发给后端的请求字段 + 从后端取的响应字段，改了必须同步契约仓库）
10. 内部字段（Store 中仅前端使用的 state、computed）
11. 编码风格（从第 4 轮采样归纳，标注依据）
12. 构建与部署
13. 与其他模块的关系
14. 已知隐含知识

### 文件 2：TODO.md（写入项目根目录）

基于 .claude-notes/todo.md，结合用户回答更新后生成最终版。

接口置信度标注规则：
- ✅ 高：代码扫描找到 + 用户确认
- ⚠️ 中：代码扫描找到但用户未确认
- ❓ 低：仅从字符串推测
