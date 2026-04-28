# 移动 App 测试 flavor

> 适用原生 iOS（Swift/Obj-C）、原生 Android（Kotlin/Java）、跨平台（Flutter / React Native / Uniapp 原生编译）App。H5 移动端请用 `web-frontend.md` flavor。

## 元数据

```yaml
project_type: 移动 App（原生 / 跨平台）
project_type_short: mobile-app
identification_signals:
  - "存在 *.xcodeproj / *.xcworkspace（iOS）"
  - "存在 app/build.gradle 含 com.android.application（Android）"
  - "存在 pubspec.yaml（Flutter）"
  - "存在 package.json + react-native（React Native）"
  - "存在 manifest.json + uni-app + 原生编译（Uniapp APP）"
default_test_dir:
  - iOS: "{Project}Tests/ 单测；{Project}UITests/ UI 测试"
  - Android: "app/src/test/ 单测；app/src/androidTest/ instrumented"
  - Flutter: "test/ 单测；integration_test/ 集成"
  - RN: "__tests__/ 单测；e2e/ Detox 测试"
```

<!-- BLOCK:PROJECT_TYPE_SCOPE -->
- **项目定位**：原生 / 跨平台移动 App
- **主要交付**：UI 渲染（多设备/多 OS 版本）、原生功能（相机/定位/推送/扫码）、离线能力、数据持久化
- **测试焦点**：UI 在不同设备渲染 / 原生 API 可用性 / 应用生命周期（前后台、内存警告）/ 横竖屏 / 网络切换 / 推送权限 / 性能（启动 / 内存 / 电量）/ 升级兼容（旧版本数据迁移）
- **不做**：服务端业务（独立测）、SDK 内部实现（信任三方）、上架审核流程（手动）
<!-- /BLOCK:PROJECT_TYPE_SCOPE -->

<!-- BLOCK:TEST_LEVELS -->
| 级别 | 工具 | 占比 | 关注 |
|------|------|------|------|
| **单元测试** | XCTest（iOS）/ JUnit + Mockito-Kotlin（Android）/ Flutter test | **60%** | ViewModel / Service / Repository / 工具函数 |
| **UI 单元测试** | XCUITest / Espresso / Flutter widget test | **25%** | 单页面组件渲染 + 交互（不依赖真后端）|
| **集成测试**（设备）| XCUITest（真机/模拟器）/ UIAutomator / Flutter integration_test | **10%** | 多页面流转 + 真实存储 |
| **E2E 全链路** | Appium / Detox（RN）/ Maestro（跨平台）| **5%** | 关键流（登录、下单），覆盖主要设备/OS |

**测试矩阵**（每次 release 必跑）：

| 平台 | 最低支持 | 主流 | 最新 |
|------|---------|------|------|
| iOS  | iPhone 11 / iOS 15 | iPhone 13 / iOS 17 | iPhone 15 / iOS 18 |
| Android | Pixel 4a / API 28 | Pixel 7 / API 33 | Pixel 8 / API 34 |

国内项目额外覆盖：华为（鸿蒙模拟）、小米、OPPO（不同 ROM）。
<!-- /BLOCK:TEST_LEVELS -->

<!-- BLOCK:KEY_RISK_AREAS -->
| 风险域 | 关注点 | 必测场景 |
|--------|--------|---------|
| **设备碎片化** | 不同屏幕尺寸 / DPI / 切角刘海 | 至少 3 档屏幕：4.7"（小屏）/ 6.1"（主流）/ 6.7"（大屏 Plus）|
| **OS 版本兼容** | 新 API 在老 OS 不可用 / 老 API 在新 OS 弃用 | 最低支持版 + 主流版 + 最新版三档 |
| **应用生命周期** | 前后台切换、内存警告、被系统杀进程 | 后台 > 5 分钟回前台数据是否保留；内存警告时不崩 |
| **网络切换** | WiFi → 4G → 断网 | 切换瞬间正在的请求是否优雅失败 / 重试 |
| **推送权限** | 拒绝 / 允许 / 受限 | 三种状态下推送通知行为 |
| **存储 / 数据迁移** | 升级 App 后老数据可读 | v1.0 → v2.0：CoreData / Room schema 升级 |
| **横竖屏** | 横屏 layout / 状态保持 | 旋转后 EditText 内容不丢、视频继续播 |
| **深链接 / Universal Links** | URL Scheme / Universal Link 跳转 | `myapp://order/123` 正确跳到订单详情 |
| **支付 / 内购** | 支付 SDK / In-App Purchase 沙盒 | 沙盒环境完整跑通付款 + 验证回调 |
| **崩溃和 ANR** | Crash-free rate / Application Not Responding | 长任务在主线程触发 ANR 检测 |
<!-- /BLOCK:KEY_RISK_AREAS -->

<!-- BLOCK:AUTOMATION_STACK -->
**iOS（Swift）**：

| 类型 | 工具 |
|------|------|
| 单元 | `XCTest` + `Quick`/`Nimble`（可选 BDD 风格）|
| UI 自动化 | `XCUITest` |
| 真机 / 模拟器 | Xcode Simulator + Fastlane Scan |
| 性能 | Instruments（Time Profiler / Allocations / Energy）|
| 崩溃监控 | Crashlytics / Bugly |

**Android（Kotlin）**：

| 类型 | 工具 |
|------|------|
| 单元 | `JUnit 5` + `Mockito-Kotlin` + `Robolectric`（无设备）|
| UI 自动化 | `Espresso`（应用内）/ `UIAutomator`（跨应用）|
| 集成 | `androidx.test` + `JUnit 4` |
| 性能 | Android Studio Profiler / Macrobenchmark |
| 崩溃监控 | Firebase Crashlytics / Bugly |

**Flutter**：`flutter_test`（widget）+ `integration_test`（端到端）+ Mockito。

**React Native**：`Jest` + `Detox`（E2E）+ Reanimated 测试。

**云真机平台**（设备碎片化必备）：
- 国外：Firebase Test Lab / BrowserStack App Live
- 国内：腾讯 WeTest / 阿里 MQC / 华为 DevEco Cloud
<!-- /BLOCK:AUTOMATION_STACK -->

<!-- BLOCK:CI_INTEGRATION -->
**iOS（Fastlane + GitHub Actions）**：

```yaml
test:ios:
  runs-on: macos-14
  steps:
    - uses: actions/checkout@v4
    - run: bundle install
    - run: bundle exec fastlane test
    # Fastfile:
    # lane :test do
    #   scan(scheme: 'MyApp', devices: ['iPhone 13', 'iPhone 15 Pro'])
    # end
    - uses: actions/upload-artifact@v4
      with:
        name: ios-test-results
        path: fastlane/test_output/
```

**Android（Gradle + GitHub Actions）**：

```yaml
test:android:
  runs-on: macos-14
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-java@v4
      with: { distribution: 'zulu', java-version: '17' }
    - run: ./gradlew test                    # 单测
    - run: ./gradlew connectedAndroidTest     # 模拟器 instrumented
    # 多设备并行：
    - uses: reactivecircus/android-emulator-runner@v2
      with:
        api-level: [28, 33]
        script: ./gradlew connectedAndroidTest
```

**关键约束**：
- 单元测必跑（无设备依赖，快）
- instrumented test 用模拟器矩阵（API 28 + API 33 至少 2 档）
- E2E 走云真机（Firebase Test Lab + 腾讯 WeTest）
- 每个 PR 跑单测；nightly 跑 instrumented；release 前跑全矩阵 E2E
<!-- /BLOCK:CI_INTEGRATION -->

<!-- BLOCK:METRICS -->
| 指标 | 阈值 | 工具 |
|------|------|------|
| 单元覆盖率（Line）| ≥ **70%** | XCTest / JaCoCo Android |
| UI 测试覆盖关键流 | **100%**（登录/支付/下单 必有）| XCUITest / Espresso |
| Crash-free Sessions | ≥ **99.5%** | Crashlytics |
| ANR rate（Android）| < **0.47%**（Google Play 标准）| Vitals / Crashlytics |
| 冷启动时间 | iOS < **1.5s** / Android < **2s** | Instruments / Macrobenchmark |
| App 包体（安装后）| iOS < **150 MB** / Android APK < **80 MB** | Xcode Size Report / APK Analyzer |
| 内存峰值 | < **200 MB**（一般使用）| Instruments Allocations |
| 电量（30 分钟使用）| < **5%**（前台主流程）| Energy Log |
| 升级兼容 | **0 数据丢失** | 测试矩阵 |
<!-- /BLOCK:METRICS -->

<!-- BLOCK:NON_FUNCTIONAL -->
**性能测试矩阵**（每次 release 必跑）：

| 维度 | iOS | Android |
|------|-----|---------|
| 冷启动 | Instruments → Time Profiler | Macrobenchmark startup |
| 内存 | Instruments → Allocations | Profiler Memory |
| 电量 | Instruments → Energy Log | Battery Historian |
| 帧率 | Instruments → Animation Hitches | GPU Profiler / FrameMetrics |
| 包体 | Xcode → Show Project Navigator → Size | APK Analyzer / Bundle Tool |

**安全 / 隐私**：
- 敏感字段加密存储（iOS Keychain / Android EncryptedSharedPreferences）
- 网络通信全 HTTPS + 证书 pinning
- App Transport Security（iOS）/ Network Security Config（Android）
- 检测 Jailbreak / Root（金融类必做）
- iOS App Tracking Transparency / Android 13+ 通知权限
- 隐私合规（GDPR / 《个人信息保护法》）

**兼容性矩阵**（每个 release 跑全矩阵）：
- iOS：iPhone SE2/13/15 + iOS 15/17/18
- Android：Pixel 5/7 + 华为/小米/OPPO 各一台 + API 28/33/34
- 平板（如有）：iPad Air + 1-2 台 Android Pad
<!-- /BLOCK:NON_FUNCTIONAL -->

<!-- BLOCK:SAMPLE_CASES -->
**典型用例**（登录 + 推送 + 横竖屏场景）：

```markdown
| TC-ID | 标题 | 设计技术 | 优先级 | 期望 |
|-------|------|---------|--------|------|
| TC-001 | 合法账号登录 | 等价类(有效) | P0 | 跳到主页，token 存 Keychain/EncryptedSP |
| TC-002 | 错误密码 | 等价类(无效) | P0 | 提示"密码错误"，不存敏感数据 |
| TC-003 | 网络切 4G→断网 | 错误推测 | P0 | 进行中请求优雅失败，显示离线提示 |
| TC-004 | 后台 5min 回前台 | 状态转换 | P0 | 数据保留，token 不过期则免重登 |
| TC-005 | 内存警告 | 错误推测 | P1 | App 不崩，可缓存的资源被清 |
| TC-006 | 推送通知点击进 App | 集成 | P0 | 跳到对应订单详情页 |
| TC-007 | 推送权限被拒 | 等价类(无效) | P1 | App 不崩，引导用户去设置 |
| TC-008 | 横屏旋转 | 状态转换 | P1 | layout 自适应，EditText 内容不丢 |
| TC-009 | App v1.0 → v2.0 升级 | 兼容性 | P0 | 老用户数据完整迁移到新 schema |
| TC-010 | 深链接 myapp://order/123 | 集成 | P1 | 从 Safari/Chrome 跳到订单详情 |
| TC-011 | 沙盒支付 99 元 | 场景法 | P0 | 苹果/支付宝/微信沙盒回调正确 |
```

**iOS XCUITest 示例**（TC-001 + TC-008）：

```swift
import XCTest

class LoginTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    func test_validLogin_navigatesToHome() {
        app.textFields["username"].tap()
        app.textFields["username"].typeText("admin")
        app.secureTextFields["password"].tap()
        app.secureTextFields["password"].typeText("Test@123")
        app.buttons["loginButton"].tap()

        XCTAssertTrue(app.tabBars["MainTabBar"].waitForExistence(timeout: 5))
    }

    func test_rotateToLandscape_preservesUsername() {
        app.textFields["username"].tap()
        app.textFields["username"].typeText("admin")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(app.textFields["username"].value as? String, "admin")
    }
}
```

**Android Espresso 示例**（TC-002）：

```kotlin
@Test
fun wrongPassword_showsError() {
    onView(withId(R.id.usernameInput)).perform(typeText("admin"))
    onView(withId(R.id.passwordInput)).perform(typeText("wrong"))
    onView(withId(R.id.loginButton)).perform(click())

    onView(withText("密码错误")).check(matches(isDisplayed()))
    // 验证敏感数据未存
    val sp = ApplicationProvider.getApplicationContext<Context>()
        .getSharedPreferences("auth", Context.MODE_PRIVATE)
    assertNull(sp.getString("token", null))
}
```
<!-- /BLOCK:SAMPLE_CASES -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
8. **设备矩阵 P0** — 每个 release 至少跑 iOS 主流 + Android 主流（4 档以上）
9. **应用生命周期必测** — 前后台切换、内存警告、被杀回到时数据保留
10. **数据迁移 P0** — 每次 schema 变更必须有"老版本 → 新版本"用例
11. **崩溃监控接入** — 全部生产构建必接 Crashlytics / Bugly，PR 模板带 crash-free 检查
12. **包体守卫** — App 包体超阈值（iOS 150MB / Android 80MB）→ CI 警告
13. **隐私合规自查** — 接入 SDK 必登记，按个保法做权限说明
14. **沙盒支付测试** — 涉及支付的 release 必跑沙盒完整流程
15. **云真机覆盖** — 主流国产 ROM（华为/小米/OPPO）每个 release 至少跑一次
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
