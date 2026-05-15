# HTTP API 后端 测试 flavor

> 适用 Spring Boot / Spring Cloud / Express / Koa / FastAPI / Flask / Django / Gin / Echo 等 REST/GraphQL 后端服务。

## 元数据

```yaml
project_type: HTTP API 后端服务
project_type_short: http-api
identification_signals:
  - "pom.xml 含 spring-boot-starter-web / spring-cloud-starter-*"
  - "build.gradle 含 spring-boot 或 micronaut"
  - "package.json 含 express / koa / fastify / nestjs"
  - "requirements.txt 含 fastapi / flask / django-rest-framework"
  - "go.mod 含 gin-gonic / echo / fiber / chi"
default_test_dir:
  - Java: "src/test/java/"
  - Python: "tests/"
  - Node: "test/"
  - Go: "*_test.go"
```

<!-- BLOCK:PROJECT_TYPE_SCOPE -->
- **项目定位**：HTTP API 后端服务（REST / GraphQL）
- **主要交付**：业务接口、数据持久化、外部集成、鉴权授权
- **测试焦点**：接口契约一致性 / 业务正确性 / 异常处理 / 鉴权 / 幂等性 / 并发 / 性能
- **不做**：UI 测试（前端独立）、嵌入式硬件测试（不适用）、机器人物理交互
<!-- /BLOCK:PROJECT_TYPE_SCOPE -->

<!-- BLOCK:TEST_LEVELS -->
| 级别 | 工具 | 占比（Test Pyramid）| 关注 |
|------|------|---------------------|------|
| **单元测试**（Unit） | JUnit 5 + Mockito（Java）/ pytest + mock（Py）/ Jest（Node）| **70%** | 函数级，Service/Repository/Mapper 各层独立 |
| **集成测试**（Integration） | Spring Boot Test + Testcontainers / pytest-asyncio + 真实 DB | **20%** | DB + 缓存 + MQ 真实启动 |
| **API 测试**（端到端）| REST Assured / Postman+Newman / pytest+httpx | **10%** | 完整 HTTP 调用，含鉴权 |

**Test Pyramid 70/20/10**：单测多、集成测中、E2E 少。**禁止倒置**（80% E2E 是反模式）。

**契约测试**（可选，Spring Cloud / 微服务推荐）：Spring Cloud Contract / Pact。
<!-- /BLOCK:TEST_LEVELS -->

<!-- BLOCK:KEY_RISK_AREAS -->
| 风险域 | 关注点 | 必测场景 |
|--------|--------|---------|
| **鉴权授权** | JWT/Session 过期、权限越界 | 无 token / 过期 token / 低权限访问高权限接口 |
| **参数校验** | 必填、类型、长度、范围、格式 | null、空字符串、超长、SQL 注入字符、Unicode、负数 |
| **幂等性** | 重复提交、网络重试 | 同一请求 ID 提交 N 次（特别是支付/扣减） |
| **并发** | 资源竞争、超卖、死锁 | 多线程同时下单、库存边界、悲观/乐观锁验证 |
| **事务** | 部分失败、回滚 | 主操作成功 + 副操作失败的回滚验证 |
| **错误码** | 4xx/5xx 一致性 | 各异常路径的状态码 + 错误消息格式 |
| **数据库交互** | 事务边界、N+1、慢查询 | 大表 IN 查询、深分页、事务隔离级别 |
| **外部依赖** | 超时、限流、熔断 | 下游服务慢/挂、重试策略生效、熔断后降级 |
| **消息队列**（如有 MQ） | 消息丢失、重复、顺序 | 消费失败重试、死信队列、幂等消费 |
| **缓存一致性** | 缓存击穿/穿透/雪崩 | 缓存与 DB 一致性、过期策略 |
<!-- /BLOCK:KEY_RISK_AREAS -->

<!-- BLOCK:AUTOMATION_STACK -->
**Java（Spring Boot 生态，推荐）**：

| 类型 | 工具 |
|------|------|
| 单元测试 | `JUnit 5` + `Mockito` + `AssertJ` |
| 集成测试 | `@SpringBootTest` + `Testcontainers`（真实 MySQL/Redis/RabbitMQ）|
| API 测试 | `REST Assured` 或 `MockMvc` |
| 契约测试（Cloud）| `Spring Cloud Contract` 或 `Pact` |
| 覆盖率 | `JaCoCo` |
| Mock 服务 | `WireMock` / `MockServer` |

**Python（Flask/FastAPI/Django）**：

| 类型 | 工具 |
|------|------|
| 单元/集成 | `pytest` + `pytest-asyncio` + `pytest-mock` |
| API 测试 | `httpx` 或 `requests` + `pytest` |
| DB fixture | `pytest-postgresql` / `pytest-mysql` / `pytest-redis` |
| 覆盖率 | `coverage.py` + `pytest-cov` |

**Node.js（Express/Koa/Nest）**：

| 类型 | 工具 |
|------|------|
| 单元/集成 | `Jest` 或 `Vitest` |
| API 测试 | `Supertest` |
| 覆盖率 | 内置（Jest）|

**通用辅助**：
- API 编排：Postman 集合 + Newman 跑 CI
- 性能基准：JMeter / k6 / wrk / Apache Bench
- 数据生成：Faker / Bogus
<!-- /BLOCK:AUTOMATION_STACK -->

<!-- BLOCK:CI_INTEGRATION -->
**示例：GitLab CI**（Java + JaCoCo）：

```yaml
test:unit:
  stage: test
  script:
    - mvn test -Dtest='*Test' jacoco:report
  coverage: '/Total.*?([0-9]{1,3})%/'
  artifacts:
    reports:
      junit: target/surefire-reports/TEST-*.xml
      coverage_report:
        coverage_format: jacoco
        path: target/site/jacoco/jacoco.xml

test:integration:
  stage: test
  services:
    - mysql:8.0
    - redis:7
  script:
    - mvn verify -Dtest='*IT' -Pintegration

test:api:
  stage: test
  script:
    - newman run postman-collection.json -e env-staging.json
  artifacts:
    paths: [newman-report.html]
```

**示例：GitHub Actions**：

```yaml
- name: Run tests with Testcontainers
  run: mvn verify
- name: Upload coverage
  uses: codecov/codecov-action@v4
  with:
    files: ./target/site/jacoco/jacoco.xml
    fail_ci_if_error: true
```

**关键约束**：
- 单测 + 集成测必须都跑（不能只跑 unit）
- 覆盖率 < 阈值 → 阻断 merge（建议线行覆盖 ≥ 70%）
- API 测试在独立 stage，依赖 Docker 起 Testcontainers
- 失败重试最多 1 次（避免掩盖 flaky test 问题）
<!-- /BLOCK:CI_INTEGRATION -->

<!-- BLOCK:METRICS -->
| 指标 | 阈值（建议）| 工具 |
|------|------------|------|
| 行覆盖率（Line）| ≥ **70%** | JaCoCo / coverage.py / Istanbul |
| 分支覆盖率（Branch）| ≥ **60%** | 同上 |
| 用例通过率 | **100%**（不通过阻断 merge）| JUnit/pytest/Jest |
| P0 用例自动化率 | **100%** | 手工统计 |
| P1 用例自动化率 | ≥ **80%** | 同上 |
| 关键接口平均响应时间 | ≤ **200ms**（业务定）| JMeter / k6 |
| 关键接口 P99 延迟 | ≤ **500ms** | 同上 |
| 缺陷密度 | < **0.5 缺陷/KLOC** | 缺陷登记 / 代码行数 |
| 测试代码 / 业务代码比 | 0.6 ~ 1.0 | 行数统计 |
| flaky test 占比 | < **2%** | 历史执行记录 |
<!-- /BLOCK:METRICS -->

<!-- BLOCK:NON_FUNCTIONAL -->
**性能基准**（每次 release 跑一次，结果归档）：

```bash
# JMeter 示例
jmeter -n -t test-plan.jmx \
  -Jusers=100 -Jramp=10 -Jduration=60 \
  -l result.jtl
jmeter -g result.jtl -o report/   # 生成 HTML 报告
```

或 k6（更简洁，推荐新项目用）：

```js
// k6 script
import http from 'k6/http';
export const options = {
  stages: [
    { duration: '30s', target: 100 },  // ramp up
    { duration: '1m',  target: 100 },  // stay
    { duration: '10s', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% 请求 < 500ms
  },
};
```

**关注指标**：吞吐量（QPS/RPS）、响应时间（P50/P95/P99）、错误率、并发能力。

**安全基础**（不做完整安全扫描，但要测）：

| 漏洞类型 | 测试输入 | 期望 |
|---------|---------|------|
| SQL 注入 | `' OR 1=1--` 或 `1'; DROP TABLE--` | 400 或安全过滤 |
| XSS | `<script>alert(1)</script>` | 转义或拒绝 |
| 越权（IDOR）| 用户 A 的 token 访问用户 B 的资源 | 403 |
| 信息泄露 | 错误响应不含堆栈 / SQL 原文 | 脱敏的友好错误消息 |
| 暴力破解 | 短时间多次错误密码 | 限流 / 锁定 |

**兼容性**：
- API 版本兼容（v1/v2 共存）
- 数据库版本兼容（MySQL 5.7 vs 8.0）
- JDK 版本兼容（如多版本部署）
<!-- /BLOCK:NON_FUNCTIONAL -->

<!-- BLOCK:SAMPLE_CASES -->
**8 个典型用例样板**（以 `POST /api/task/create` 接口为例）：

```markdown
| TC-ID | 标题 | 设计技术 | 优先级 | 输入 | 期望 |
|-------|------|---------|--------|------|------|
| TC-001 | 合法输入创建任务 | 等价类(有效) | P0 | {name:"巡检A", type:1} | 200, task_id 非空 |
| TC-002 | 缺少必填 name | 等价类(无效) | P0 | {type:1} | 400, code=PARAM_MISSING |
| TC-003 | name 长度=0 | 边界值 | P1 | {name:"", type:1} | 400 |
| TC-004 | name 长度=最大允许 | 边界值 | P1 | {name:"A"*50, type:1} | 200 |
| TC-005 | name 长度=超限 | 边界值 | P1 | {name:"A"*51, type:1} | 400 |
| TC-006 | type 不存在 | 等价类(无效) | P1 | {name:"X", type:999} | 400, code=TYPE_INVALID |
| TC-007 | 无 token 访问 | 鉴权 | P0 | header 无 Authorization | 401 |
| TC-008 | 重复提交（idempotency-key）| 幂等 | P0 | 同 key 提交两次 | 第二次 200 + 同 task_id |
```

**自动化代码示例**（REST Assured / Java）：

```java
@SpringBootTest
@AutoConfigureMockMvc
class TaskControllerTest {

    @Autowired MockMvc mvc;
    String validToken;

    // TC-001
    @Test
    void createTask_validInput_returns200() throws Exception {
        mvc.perform(post("/api/task/create")
                .header("Authorization", "Bearer " + validToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"巡检A\",\"type\":1}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.task_id").exists());
    }

    // TC-007
    @Test
    void createTask_noToken_returns401() throws Exception {
        mvc.perform(post("/api/task/create")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"x\",\"type\":1}"))
            .andExpect(status().isUnauthorized());
    }

    // TC-008 幂等性
    @Test
    void createTask_duplicateIdempotencyKey_returnsSameTaskId() throws Exception {
        String idempKey = "test-key-001";
        // 第 1 次
        String resp1 = mvc.perform(post("/api/task/create")
                .header("Authorization", "Bearer " + validToken)
                .header("Idempotency-Key", idempKey)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"重试任务\",\"type\":1}"))
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        // 第 2 次（同 key）
        String resp2 = mvc.perform(post(...).header("Idempotency-Key", idempKey)...)
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        // 同一 task_id
        assertThat(extractTaskId(resp1)).isEqualTo(extractTaskId(resp2));
    }
}
```

**Python 等价示例**（pytest + httpx）：

```python
import pytest
import httpx

@pytest.fixture
def client(): return httpx.Client(base_url="http://localhost:8080", headers={"Authorization": f"Bearer {valid_token}"})

# TC-001
def test_create_task_valid_input(client):
    r = client.post("/api/task/create", json={"name": "巡检A", "type": 1})
    assert r.status_code == 200
    assert r.json()["data"]["task_id"]
```
<!-- /BLOCK:SAMPLE_CASES -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
8. **集成测试必须用真实 DB / Redis / MQ**（Testcontainers / pytest-fixture），**不要全 mock**
9. **每个 4xx/5xx 错误码至少一条用例覆盖**
10. **幂等接口必有重复提交测试**（即使没声明幂等，也要确认重复提交的行为）
11. **鉴权接口必有 401 / 403 用例**（无 token / 过期 token / 低权限）
12. **性能基线提交**：每次 release 跑一次 JMeter/k6，结果归档到 `mpdev-runs/{run_id}/perf-baseline.json`
13. **Spring Cloud 项目额外测**：Feign 客户端 fallback、Hystrix/Resilience4j 熔断、Gateway 限流
14. **flaky test 零容忍**：连续 3 次失败的随机用例，停止合并到主线，定位修复
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
