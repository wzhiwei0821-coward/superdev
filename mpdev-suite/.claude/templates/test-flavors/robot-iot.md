# 机器人 / IoT / 嵌入式 测试 flavor

> 适用 ROS / ROS 2 机器人、嵌入式 Linux（树莓派 / 工控机）、STM32 等 MCU、硬件 SDK 集成（CAN / 串口 / GPIO / I2C）、IoT 设备网关。

## 元数据

```yaml
project_type: 机器人 / IoT / 嵌入式
project_type_short: robot-iot
identification_signals:
  - "存在 package.xml + CMakeLists.txt（ROS）"
  - "存在 src/main/cpp + STM32CubeMX 工程（嵌入式 C/C++）"
  - "依赖 rospy / rclpy / pyserial / can / RPi.GPIO"
  - "存在 launch/ 目录（ROS launch 文件）"
  - "硬件相关代码：串口 baud rate / CAN ID / I2C 地址"
default_test_dir: "test/ 含 test_*.cpp / test_*.py + simulation/ 仿真场景文件"
```

<!-- BLOCK:PROJECT_TYPE_SCOPE -->
- **项目定位**：机器人控制软件 / IoT 设备 / 嵌入式硬件交互
- **主要交付**：传感器数据处理、运动控制、状态机、硬件通信、远程命令
- **测试焦点**：**仿真先行 → 实机验证** / **时序正确性**（消息顺序、延迟）/ **硬件接口可靠性** / **异常处理**（断电、信号丢失、传感器故障）/ **状态机** / **物理约束**（运动学边界、安全限速）/ **OTA 升级**
- **不做**：底层硬件设计（电路）、驱动层内部（信任厂商）、机械结构验证（属机械工程）
<!-- /BLOCK:PROJECT_TYPE_SCOPE -->

<!-- BLOCK:TEST_LEVELS -->
| 级别 | 工具 | 占比 | 关注 |
|------|------|------|------|
| **单元测试** | gtest（C++）/ pytest（Python）+ mock 硬件 | **50%** | 算法 / 状态机 / 工具函数 |
| **节点测试**（ROS）| rostest / launch_testing | **15%** | 单 node 行为，mock 上下游 topic |
| **仿真集成测试** | Gazebo / Webots / Isaac Sim | **20%** | 多 node 联测 + 物理仿真 |
| **HIL 测试**（硬件在环）| 真实传感器 + 模拟驱动 | **10%** | 软件接真硬件传感器，模拟执行器 |
| **实机测试** | 真实机器人 + 控制台 | **5%** | 关键功能在真实环境完整跑 |

**核心原则**：仿真测试是主战场（廉价、可重复）；HIL 验证硬件接口；实机用于最终验收。
<!-- /BLOCK:TEST_LEVELS -->

<!-- BLOCK:KEY_RISK_AREAS -->
| 风险域 | 关注点 | 必测场景 |
|--------|--------|---------|
| **状态机** | 启动 / 待机 / 运动 / 故障 / 停机 状态转换 | 启动→待机正常；故障下能否正确进入急停；停机后状态文件清理 |
| **时序** | 控制周期 / 消息顺序 / 延迟敏感 | 控制环 50Hz 不丢周期；A 消息必须在 B 之前到达；> 100ms 延迟视为离线 |
| **传感器异常** | 数据丢失 / 跳变 / 噪声 / 漂移 | 激光雷达停发 → 状态进 EMERGENCY；GPS 跳变（大于阈值）→ 平滑过滤 |
| **硬件通信** | 串口超时 / CAN 总线繁忙 / I2C ACK 失败 | 串口断开 5s 自动重连；CAN 错误帧不阻塞主循环 |
| **安全限速 / 边界** | 运动学约束 | 速度 > 设定上限 → 限速；操作空间边界附近减速 |
| **断电恢复** | 突然断电后状态一致性 | kill -9 后重启，机器人能从最近 checkpoint 恢复 |
| **多机器人协同**（如有）| 通信冲突 / 任务分配 | 2 台机器人接近时让步；任务调度不会同时分配同一目标 |
| **网络中断** | WiFi 切换 / 5G/WiFi 漫游 | 短暂断网（< 30s）任务继续；长断重连后报告状态 |
| **OTA 升级** | 升级失败回滚 | 升级中断电 → 自动回退到上一版本 |
| **资源限制** | 嵌入式 CPU / 内存 / Flash 紧张 | 长时运行不内存泄漏；Flash 写入次数控制 |
<!-- /BLOCK:KEY_RISK_AREAS -->

<!-- BLOCK:AUTOMATION_STACK -->
**ROS 1 / ROS 2 生态**：

| 类型 | 工具 |
|------|------|
| C++ 单元 | `gtest` / `Catch2` |
| Python 单元 | `pytest` |
| 节点测试 | `rostest`（ROS 1）/ `launch_testing`（ROS 2）|
| 仿真 | **Gazebo Classic / Gazebo Sim**（推荐）/ Webots / Isaac Sim |
| 录制回放 | `rosbag` / `rosbag2` — 用于回归测试 |
| 性能 | `rqt_plot` / `rqt_console` / 自定义 latency 测试 |

**嵌入式 C/C++**：

| 类型 | 工具 |
|------|------|
| 单元 | `Unity` / `CppUTest` / `Ceedling`（Unity 配套） |
| 嵌入式仿真 | QEMU / Renode（无硬件跑 firmware）|
| HIL | 自定义 + 测试夹具（test fixture） |
| 静态分析 | `cppcheck` / `clang-tidy` / `splint` |
| 覆盖率 | `gcov` + `lcov` / `bullseye` |

**通用**：
- 仿真录制：`rosbag` 记录场景，CI 中回放
- 故障注入：自定义工具（断电、网络抖、传感器噪声）
- 数据可视化：RViz / Foxglove Studio / PlotJuggler
<!-- /BLOCK:AUTOMATION_STACK -->

<!-- BLOCK:CI_INTEGRATION -->
**ROS 2 + GitHub Actions**：

```yaml
test:unit:
  runs-on: ubuntu-22.04
  container: osrf/ros:humble-desktop
  steps:
    - uses: actions/checkout@v4
    - run: |
        cd /ros2_ws/src && ln -s $GITHUB_WORKSPACE my_pkg && cd ..
        colcon build --packages-select my_pkg
        colcon test --packages-select my_pkg
        colcon test-result --verbose

test:simulation:
  runs-on: ubuntu-22.04
  container: osrf/ros:humble-desktop  # 含 Gazebo
  steps:
    - run: |
        cd /ros2_ws && source install/setup.bash
        # headless 仿真
        ros2 launch my_pkg sim_test.launch.py headless:=true &
        sleep 30
        pytest test/integration/test_navigation_sim.py
```

**嵌入式（GitLab CI + Ceedling）**：

```yaml
test:unit-mcu:
  image: stm32cube-ide
  script:
    - cd firmware
    - ceedling test:all      # 跑所有 *.test.c
    - ceedling gcov:all      # 覆盖率

test:hil-nightly:
  stage: nightly
  tags: [hardware]   # 自托管 + 真实板子
  script:
    - flash-firmware ./build/firmware.bin
    - python tests/hil/run_hardware_tests.py
```

**关键约束**：
- 单元 + ROS 节点测试每个 PR 跑（无硬件依赖）
- 仿真测试 nightly（慢，且需要 X server / VNC）
- HIL 测试 release 前跑（硬件资源稀缺，专用 runner）
- 实机测试人工触发（无法 CI 化）
<!-- /BLOCK:CI_INTEGRATION -->

<!-- BLOCK:METRICS -->
| 指标 | 阈值 | 工具 |
|------|------|------|
| 单元覆盖率（Line）| ≥ **70%** | gcov / pytest-cov |
| 仿真测试通过率 | **100%** | rostest / launch_testing |
| 控制周期 jitter | < **5ms**（50Hz 控制环）| 自定义 latency |
| 平均无故障运行时间（MTBF）| > **24 小时**（仿真）/ > **8 小时**（实机）| 长时压测 |
| 启动到 ready 时间 | < **30s** | 自动化脚本 |
| 急停响应时间 | < **100ms** | HIL 测试 |
| 内存增长率 | < **5%/小时** | 长时监控 |
| OTA 升级成功率 | ≥ **99%** | release 测试 |
| 仿真 / 实机一致性差异 | < **5%** | A/B 对比 |
<!-- /BLOCK:METRICS -->

<!-- BLOCK:NON_FUNCTIONAL -->
**仿真测试核心**（rosbag 回放回归）：

```python
# tests/integration/test_navigation_with_rosbag.py
import subprocess
import pytest

def test_navigation_passes_obstacle_course():
    """回放预录制的 obstacle_course.bag，验证 amcl 定位 + 路径规划"""
    sim_proc = subprocess.Popen(
        ["ros2", "launch", "nav2_bringup", "tb3_simulation_launch.py"]
    )

    # 回放传感器数据
    rosbag_proc = subprocess.Popen(
        ["ros2", "bag", "play", "tests/data/obstacle_course.bag"]
    )

    # 检查 /tf 中机器人是否在 60s 内到达目标点
    final_pose = wait_for_robot_at_goal(timeout=60)
    assert distance_to_goal(final_pose) < 0.1, "机器人未到达目标点"

    sim_proc.terminate()
    rosbag_proc.terminate()
```

**控制周期 jitter 测试**：

```python
def test_control_loop_50hz_no_jitter():
    """验证控制环以 50Hz±5ms 稳定运行"""
    timestamps = []
    for _ in range(1000):
        msg = wait_for_topic('/cmd_vel', timeout=0.1)
        timestamps.append(msg.header.stamp)

    intervals = [t2 - t1 for t1, t2 in zip(timestamps, timestamps[1:])]
    jitter = max(intervals) - min(intervals)
    assert jitter < 0.005, f"控制周期 jitter {jitter*1000:.1f}ms 超过 5ms"
```

**故障注入测试**：

```python
@pytest.mark.parametrize("fault", [
    'lidar_no_data',          # 激光雷达停发
    'imu_high_noise',         # IMU 噪声 +50%
    'wheel_encoder_drift',    # 编码器漂移
    'wifi_disconnect_30s',    # WiFi 短断
])
def test_robot_handles_fault(fault):
    inject_fault(fault)
    state = wait_for_robot_state(timeout=10)
    assert state in ['EMERGENCY', 'DEGRADED', 'IDLE'], \
        f"故障 {fault} 下机器人状态非法: {state}"
```

**安全**：
- 操作空间边界（最大速度、加速度）硬限制
- 急停按钮硬件级测试（不依赖软件）
- 远程命令鉴权（防止误触发或恶意控制）
- 物理碰撞预防（碰撞前 lookahead 检查）
- 固件签名（OTA 升级前验证签名）

**长时稳定性**（必跑）：
- 仿真：连续跑 24 小时，无 crash、无内存泄漏、控制周期稳定
- 实机：连续跑 8 小时，监控温度、电量、磁盘、内存
<!-- /BLOCK:NON_FUNCTIONAL -->

<!-- BLOCK:SAMPLE_CASES -->
**典型用例**（自主导航机器人为例）：

```markdown
| TC-ID | 标题 | 设计技术 | 优先级 | 期望 |
|-------|------|---------|--------|------|
| TC-001 | 启动 → 自检通过 → 进入 IDLE | 状态转换 | P0 | 30s 内进 IDLE，所有传感器在线 |
| TC-002 | 收到任务后规划路径 + 执行 | 场景法 | P0 | 路径无碰撞，到达目标点（< 10cm 误差）|
| TC-003 | 路径中突然出现障碍物 | 错误推测 | P0 | 1s 内停止 + 重新规划 |
| TC-004 | 激光雷达停发 5s | 错误推测 | P0 | 进入 EMERGENCY，停止运动 + 报警 |
| TC-005 | IMU 噪声 +50% | 边界值 | P1 | 滤波后定位误差 < 20cm |
| TC-006 | 急停按钮触发 | 安全 | P0 | < 100ms 内停止所有运动 |
| TC-007 | 控制环 50Hz 稳定性 | 性能 | P0 | 1000 周期 jitter < 5ms |
| TC-008 | WiFi 断开 30s | 错误推测 | P1 | 任务继续；恢复后报告状态 |
| TC-009 | 突然断电 + 重启 | 状态转换 | P0 | 从最近 checkpoint 恢复，状态一致 |
| TC-010 | OTA 升级中断电 | 错误推测 | P0 | 重启后回退到上一版本，不变砖 |
| TC-011 | 连续运行 24 小时（仿真） | 性能 | P1 | 无 crash，内存增长 < 5%/h |
| TC-012 | 速度超限指令（10 m/s）| 边界值 | P0 | 限速到 max 配置（如 1 m/s）|
```

**rostest 单元测试**（ROS 1）：

```python
import unittest
import rospy
from geometry_msgs.msg import Twist

class NavigationNodeTest(unittest.TestCase):
    def test_obstacle_triggers_stop(self):
        rospy.init_node('test_navigation')
        cmd_pub = rospy.Publisher('/cmd_vel_in', Twist, queue_size=1)
        # 发布障碍物到 /scan
        publish_obstacle_at_distance(0.5)  # 50cm 处有障碍

        twist = wait_for_message('/cmd_vel_out', Twist, timeout=2)
        self.assertAlmostEqual(twist.linear.x, 0.0, places=2,
                               msg="发现障碍后未停止")

if __name__ == '__main__':
    import rostest
    rostest.rosrun('navigation', 'navigation_node_test', NavigationNodeTest)
```

**Gazebo 仿真集成**（launch_testing for ROS 2）：

```python
# test/test_robot_navigation.launch.py
import launch_testing
import unittest

def generate_test_description():
    return LaunchDescription([
        IncludeLaunchDescription("gazebo_warehouse.launch.py"),
        IncludeLaunchDescription("nav2_bringup.launch.py"),
        launch_testing.actions.ReadyToTest(),
    ])

class TestRobotInWarehouse(unittest.TestCase):
    def test_robot_reaches_pickup_point(self, proc_output):
        send_goal_to_robot(x=5.0, y=3.0)
        # 等 60s
        proc_output.assertWaitFor("Goal reached", timeout=60)
```

**嵌入式硬件 HIL**（Python + pyserial）：

```python
def test_serial_command_response_under_50ms():
    import serial, time
    ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=1)

    t0 = time.time()
    ser.write(b'GET_STATUS\n')
    response = ser.readline()
    elapsed = time.time() - t0

    assert response.startswith(b'STATUS:')
    assert elapsed < 0.05, f"响应延迟 {elapsed*1000:.1f}ms 超过 50ms"
```
<!-- /BLOCK:SAMPLE_CASES -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
8. **仿真先行** — 任何新功能先在仿真完整跑通，再上 HIL，再实机；不允许"代码改了直接上机"
9. **rosbag 回归测试集** — 关键场景录制 bag 文件入库，每次 release 必跑回放对比
10. **故障注入必有用例** — 至少覆盖：传感器停发、噪声超标、网络断开、断电
11. **安全极限测试** — 急停响应 < 100ms / 速度限制 / 边界减速 全部 P0
12. **长时稳定性** — release 前必跑 24 小时仿真 + 8 小时实机
13. **状态机覆盖** — 状态转换图所有边都要有测试用例
14. **OTA 升级双向验证** — 既测升级成功路径，也测升级失败回滚路径
15. **嵌入式资源监控** — 内存、Flash 写入、温度、电量全程监控
16. **不允许只在实机测** — 实机测试结果若仿真未覆盖，必须补回仿真用例
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
