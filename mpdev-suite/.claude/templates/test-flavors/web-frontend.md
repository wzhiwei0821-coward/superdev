# Web 前端 测试 flavor

> 适用 Vue 2/3 + Element/AntD + Vant、React 16+/Hooks + AntD/MUI、Angular 14+、Svelte、Solid 等单页应用 / 静态站点。

## 元数据

```yaml
project_type: Web 前端 SPA / 静态站点
project_type_short: web-frontend
identification_signals:
  - "package.json 含 vue / react / angular / svelte / solid-js"
  - "package.json 含 @vue/cli-service / vite / next / nuxt / create-react-app"
  - "存在 vue.config.js / vite.config.* / next.config.* / angular.json"
default_test_dir:
  - Vue: "src/**/__tests__/ 或 tests/unit/ + e2e/"
  - React: "src/**/*.test.* 或 __tests__/"
  - Angular: "src/app/**/*.spec.ts"
```

<!-- BLOCK:PROJECT_TYPE_SCOPE -->
- **项目定位**：Web SPA / 静态站点 / 管理后台 / 营销页
- **主要交付**：UI 渲染、用户交互、API 集成、路由权限
- **测试焦点**：组件正确性 / 用户流程 / 跨浏览器兼容 / 响应式断点 / 表单校验 / 状态管理 / 性能（首屏 / Bundle 大小）/ 可访问性
- **不做**：后端业务逻辑（独立测）、SDK 内部实现（信任第三方包）、设备级原生 API（H5 简化版除外）
<!-- /BLOCK:PROJECT_TYPE_SCOPE -->

<!-- BLOCK:TEST_LEVELS -->
| 级别 | 工具 | 占比 | 关注 |
|------|------|------|------|
| **单元测试**（Unit） | Vitest（推荐）/ Jest | **60%** | 工具函数 / store / composables / hooks |
| **组件测试**（Component）| Vue Test Utils / @testing-library/react / Storybook | **30%** | 组件渲染 + props + events，**不挂真实 API** |
| **E2E 测试**（End-to-End）| Cypress / Playwright（推荐）| **10%** | 关键用户流（登录、下单、提交）|

**Test Pyramid**: 60/30/10。E2E 慢、易 flaky，**不要倒置**。

**视觉回归**（可选）：Percy / Chromatic / Loki — 适合设计系统/组件库。
<!-- /BLOCK:TEST_LEVELS -->

<!-- BLOCK:KEY_RISK_AREAS -->
| 风险域 | 关注点 | 必测场景 |
|--------|--------|---------|
| **路由守卫** | 未登录跳转 / 权限不足重定向 | 直接访问 /admin（未登录）→ 跳 /login；低权限访问 → 403 页 |
| **状态管理** | Pinia/Vuex/Redux 跨组件同步 | 多组件同时改 store，UI 是否同步刷新 |
| **表单校验** | 必填、格式、异步、提交 | 空提交、超长、邮箱格式、异步用户名查重 |
| **API 错误处理** | 超时、4xx、5xx、断网 | mock 后端各种错误，验证 UI 降级展示 |
| **跨浏览器** | Chrome / Firefox / Safari / Edge | 至少 Chrome + Safari（移动 H5 必测）|
| **响应式断点** | 手机 / 平板 / 桌面三档 | 320 / 768 / 1280 三档，组件不溢出 |
| **首屏性能** | LCP / FCP / TTI | Lighthouse Performance ≥ 90 |
| **XSS / 注入** | 用户输入渲染 | `<script>` / `javascript:` URL 是否被转义 |
| **国际化** | 中英文切换 / 长文本溢出 | 切换语言 + 中文 30 字 / 英文 100 字 |
| **键盘可访问性** | Tab 顺序 / Enter 提交 / Esc 关闭弹窗 | 全键盘走通主流程 |
<!-- /BLOCK:KEY_RISK_AREAS -->

<!-- BLOCK:AUTOMATION_STACK -->
**Vue 生态（推荐组合）**：

| 类型 | 工具 |
|------|------|
| 单元测试 | `Vitest`（Vite 项目首选）/ `@vue/test-utils` |
| 组件测试 | `@vue/test-utils` + `@testing-library/vue` |
| E2E | `Cypress` 或 `Playwright`（**新项目推荐 Playwright**） |
| 视觉 | `Storybook` + `Chromatic` |
| 覆盖率 | Vitest 内置（`--coverage`）|

**React 生态**：

| 类型 | 工具 |
|------|------|
| 单元/组件 | `Jest` + `@testing-library/react` |
| E2E | `Playwright` / `Cypress` |
| 视觉 | `Storybook` + `Chromatic` 或 `Loki` |
| 覆盖率 | Jest 内置 |

**Angular**：`Karma` + `Jasmine`（默认）+ `Cypress` E2E。

**通用辅助**：MSW（Mock Service Worker，API mock 标准化）、Lighthouse CI（性能基线）、axe-core（可访问性扫描）。
<!-- /BLOCK:AUTOMATION_STACK -->

<!-- BLOCK:CI_INTEGRATION -->
**GitHub Actions（推荐）**：

```yaml
name: Frontend Test
on: [push, pull_request]
jobs:
  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npm run test:unit -- --coverage
      - uses: codecov/codecov-action@v4

  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run build && npm run preview &
      - run: npx playwright test
      - uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: playwright-report/

  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: treosh/lighthouse-ci-action@v11
        with:
          urls: 'http://localhost:3000'
          uploadArtifacts: true
```

**关键约束**：
- 单元 + 组件测必跑（合并为 `test:unit`）
- E2E 可放 nightly，PR 只跑 smoke
- 覆盖率 < 阈值阻断 merge
- Playwright 浏览器至少 Chrome + Firefox（Safari 用 WebKit）
<!-- /BLOCK:CI_INTEGRATION -->

<!-- BLOCK:METRICS -->
| 指标 | 阈值（建议）| 工具 |
|------|------------|------|
| 单元 + 组件覆盖率（Line）| ≥ **80%** | Vitest / Jest |
| 分支覆盖率 | ≥ **70%** | 同上 |
| E2E 关键流通过率 | **100%** | Cypress / Playwright |
| Lighthouse Performance | ≥ **90** | Lighthouse CI |
| LCP（最大内容绘制）| < **2.5s** | Web Vitals |
| FID（首次输入延迟）| < **100ms** | 同上 |
| CLS（累计布局偏移）| < **0.1** | 同上 |
| Bundle Size（gzip 后主包）| < **300 KB** | webpack-bundle-analyzer / vite-plugin-visualizer |
| 可访问性（a11y）评分 | ≥ **95** | axe-core / Lighthouse |
| flaky test 占比 | < **2%** | CI 历史 |
<!-- /BLOCK:METRICS -->

<!-- BLOCK:NON_FUNCTIONAL -->
**性能基准**：每次 release 跑 Lighthouse + Web Vitals：

```bash
# Lighthouse CLI
npx lighthouse https://staging.example.com \
  --output=html --output=json \
  --output-path=./lighthouse-report

# Web Vitals 实时采集
npm install web-vitals
# 在 main.ts/main.js 加 reportWebVitals(metric => sendBeacon('/analytics', metric))
```

**安全基础**：

| 漏洞类型 | 测试方式 |
|---------|---------|
| XSS | 注入 `<script>alert(1)</script>` 到所有用户可输入字段，看是否转义 |
| CSP | 检查响应头含 `Content-Security-Policy` |
| 敏感信息泄露 | DevTools Network 看 token 是否带 HttpOnly + Secure |
| 依赖漏洞 | `npm audit` / Snyk |

**兼容性**：

- **浏览器矩阵**（最低支持）：Chrome 100+、Firefox 100+、Safari 15+、Edge 100+
- **移动 H5**：iOS Safari 15+、Android Chrome 100+
- **屏幕断点**：320px / 768px / 1024px / 1440px

**可访问性（a11y）**：每次 PR 跑 axe-core 扫，零 critical 违规。
<!-- /BLOCK:NON_FUNCTIONAL -->

<!-- BLOCK:SAMPLE_CASES -->
**典型用例样板**（登录表单 + 路由守卫场景）：

```markdown
| TC-ID | 标题 | 设计技术 | 优先级 | 期望 |
|-------|------|---------|--------|------|
| TC-001 | 合法登录跳转主页 | 等价类(有效) | P0 | 200, localStorage 含 token, router 跳 /home |
| TC-002 | 用户名为空 | 等价类(无效) | P0 | 提交按钮 disabled 或表单错误提示"请输入用户名" |
| TC-003 | 用户名超 50 字符 | 边界值 | P1 | 显示"用户名最多 50 字符"，提交按钮 disabled |
| TC-004 | 错误密码 | 错误推测 | P0 | API 返回 401，UI 显示"密码错误"，不跳转 |
| TC-005 | 网络断开 | 错误推测 | P1 | 显示"网络异常，请重试"，含重试按钮 |
| TC-006 | 未登录访问 /admin | 鉴权 | P0 | router 拦截，跳 /login?redirect=/admin |
| TC-007 | 低权限用户访问 /admin/users | 鉴权 | P0 | 显示 403 页面 |
| TC-008 | 移动端响应式（375x667） | 兼容性 | P1 | 表单单列，按钮全宽 |
| TC-009 | XSS 注入 username | 安全 | P0 | `<script>alert(1)</script>` 被转义渲染 |
| TC-010 | Tab 键依次聚焦 username/password/submit | a11y | P1 | 顺序正确，Enter 提交 |
```

**Vue + Vitest 单元测试示例**：

```ts
import { mount } from '@vue/test-utils'
import { describe, it, expect, vi } from 'vitest'
import LoginForm from '@/views/Login.vue'

describe('LoginForm', () => {
  // TC-002
  it('disables submit when username empty', async () => {
    const wrapper = mount(LoginForm)
    await wrapper.find('input[name=password]').setValue('123456')
    expect(wrapper.find('button[type=submit]').attributes('disabled')).toBeDefined()
  })

  // TC-004
  it('shows error on 401', async () => {
    const wrapper = mount(LoginForm, {
      global: { mocks: { $api: { login: vi.fn().mockRejectedValue({ status: 401 }) } } }
    })
    await wrapper.find('input[name=username]').setValue('admin')
    await wrapper.find('input[name=password]').setValue('wrong')
    await wrapper.find('form').trigger('submit')
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).toContain('密码错误')
  })
})
```

**Playwright E2E 示例**（TC-006 路由守卫）：

```ts
import { test, expect } from '@playwright/test'

test('redirects to login when not authenticated', async ({ page }) => {
  await page.context().clearCookies()
  await page.goto('/admin')
  await expect(page).toHaveURL(/\/login\?redirect=%2Fadmin/)
})
```
<!-- /BLOCK:SAMPLE_CASES -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
8. **不挂真实后端跑组件测试** — 用 MSW 拦截 API，避免组件测试依赖网络
9. **E2E 必须可重复**（idempotent）— 每个 case 自带 setup/teardown，不依赖前序测试结果
10. **视觉断言用 data-testid，不用 class**（class 改样式时容易破坏）
11. **a11y 零容忍 critical**：axe-core 扫到的 critical 违规必须修
12. **Bundle Size 守卫**：超过阈值 → CI 警告或阻断（用 size-limit 或 bundlewatch）
13. **flaky test 隔离**：连续 3 次失败的随机用例移到 `quarantine/` 目录，不阻断主线
14. **国际化场景**：中英文切换至少跑一次完整登录+提交流程
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
