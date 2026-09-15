# #93：模型释放、WindowGroup 对照与本地内存图

## 结论与边界

独立于 UI 的 30 个真实 `HomeViewModel` 都释放了；原生 OpenCCman 关窗后保留模型的现象，在没有第三方依赖、转换业务、通知订阅或编辑器的最小 SwiftUI `WindowGroup` 中也出现。**目前不足以将现象归因于应用的业务持有环，也不足以提出一个有依据的产品修复。**

本次只有本机 macOS 27.0 (26A428) 测试版的运行证据。下一步先在较早的 macOS 运行时执行相同对照，再决定是否需要应用修复或系统反馈。各最小变体只执行了一轮两窗口新建／关闭，不证明无界泄漏，也不能排除 OpenCCman 另有持有问题。

关联 [#93](https://github.com/gewill/OpenCCman/issues/93)、[#18](https://github.com/gewill/OpenCCman/issues/18)、[原生诊断 PR #90](https://github.com/gewill/OpenCCman/pull/90)。本 PR 没有产品 UI 修改；实际 OpenCCman 窗口外观及之前三轮交互见 [#90 的真实截图和视频](https://github.com/gewill/OpenCCman/pull/90#issuecomment-5680208835)。该视频属于之前的三轮测量，不冒充本次最小对照录制。

## 测量结果

| 对照 | 观察 | 结论范围 |
|---|---|---|
| 真实 HomeViewModel，无 UI 宿主 | 3 批 × 10 个；每批释放后存活 0，额度消耗 0 | 本次初始订阅和正文修改不产生独立模型持有环 |
| 实际 OpenCCman，2 个窗口关闭为 0 | 连续 40 个零窗口样本；20 秒后模型仍为 2 | 无窗口保持已单独观察，不能以模型存活判定窗口自动重开 |
| 最小 WindowGroup + StateObject + EnvironmentObject + TextEditor + onReceive | 关闭第二窗口约 5/20 秒后均存活 2 | 没有 Router、Neumorphic 或 OpenCC 仍可出现 |
| 上一对照仅移除 onReceive | 约 5/20 秒后均存活 2 | 通知订阅不是最小复现的必要条件 |
| 上一对照仅将 TextEditor 改为 Text | 约 5/20 秒后均存活 2 | 文本编辑器不是最小复现的必要条件 |

每轮最小对照均为新进程，用系统 New Window（Command-N）创建第二个窗口，Command-W 关闭，保留第一个窗口；采样表只持有弱引用。完整日志及精确相对时间在 [result.json](result.json) 和三个 `minimal-*.jsonl`。它们不包含输入正文、购买记录或个人信息。

### 原生零窗口观察

实际应用使用 #90 构建的 Release 诊断二进制，源码 `aec0368fac73646fb3168204c0b150881bd7e55d`，Xcode 26.3，固定隔离 bundle。诊断变体关闭购买 SDK 初始化、Services 与全局快捷键注册。创建两个原生窗口并分别清空样文；先关闭第二个，再关闭最后一个。

关闭最后窗口后只通过进程 JSONL 观察，不调用会激活应用的 CUA 界面查询。首次零窗口样本约 92.003 秒，约 113.003 秒时仍零窗口、模型 `[1,2]`；直到约 133.002 秒均未重开。之后为退出诊断进程调用 CUA `getAXState()`，才观察到新窗口／模型 3。这个受控序列说明旧测试的界面查询不能作为“不影响应用”的观察手段；不改变产品重新打开应用的行为。

内存图通过系统 `leaks --noContent --outputGraph=... <owned-pid>` 获取。关掉第二窗口和全部窗口的两张图都显示：

```text
AttributeGraph Owned
  SwiftUI.ChildEnvironment<Optional<HomeViewModel>>
    HomeViewModel
```

保留了 `--referenceTree=HomeViewModel` 的内容关闭摘要。反向扫描也包含环境、视图图和通知视图引用，但图中的扫描路径不能直接等同于已证明的业务强持有链。**原始 memgraph 和完整反向扫描仅留本地，没有上传。**

日志中的绝对 RSS／footprint 包含诊断采样、界面操作及内存图工具干扰；不用于宣称性能改善。原始数据保留退出前重开事件，没有把不符合预期的记录裁掉。

## 复现

真实模型使用应用锁定依赖和原始业务源文件，测试支持层隔离偏好与购买集成：

```sh
python3 scripts/check-core.py --model-lifetime
python3 scripts/check-core.py
```

最小窗口工具只构建，不自动启动、关闭或操作其他应用；输出目录必须不存在：

```sh
python3 scripts/prepare-minimal-window-lifetime.py --variant notifications --output .build/lifetime-notifications
python3 scripts/prepare-minimal-window-lifetime.py --variant editor --output .build/lifetime-editor
python3 scripts/prepare-minimal-window-lifetime.py --variant text --output .build/lifetime-text
```

通过正常系统 UI 打开生成的 app，创建并关闭第二个窗口。日志位于当前用户临时目录的 `OpenCCman-MinimalLifetime-<PID>.jsonl`；可通过 `getconf DARWIN_USER_TEMP_DIR` 查目录。等待关窗后至少 20 秒，之后退出自己启动的诊断 app。检查 `visible` 从 2 降到 1 后的 `alive`，不能只看累计 `created`。日志使用固定合成文本，不访问用户文稿。若需零窗口测量，关闭最后一个窗口后不要再查询或激活其 UI。

最小对照统一使用本机 Swift 6.4 编译器的 Swift 5 模式，`-O`、arm64、macOS 11 部署目标，独立 ad-hoc app。编译部署目标不等于已验收最低系统；精确编译器、系统、源文件 SHA-256 在 `result.json`。三个准备命令已重新构建成功，并核对生成源码 SHA-256 与实际测量的源码逐字相同；重复输出目录拒绝覆盖。

## 已验证与后续

- 本轮真实模型生命周期检查、原有核心回归均通过；原始日志随文档保留。
- 全部本轮诊断进程已退出、临时 app 已注销并改为 inactive；实际 app 的隔离偏好已恢复。未改动原工作区、依赖缓存、正式签名或 build 分支。VoiceOver 最后读回为关闭，测试中未启用。
- 待执行：在较早 macOS 运行时复测三个最小对照和真实 app；再定位跨系统一致的持有路径。本轮没有用测试版现象作产品生命周期重写的依据。
- #93 的多轮修复前后比较、1/10 MiB 完整工作流、任务执行时关窗、其他窗口状态和额度仍未完成。#18 整体性能、#19 入口、最低系统与签名发布验收继续开放。
