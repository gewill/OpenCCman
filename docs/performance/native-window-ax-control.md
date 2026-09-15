# 真实应用的窗口观察方式对照

跟踪 [#93](https://github.com/gewill/OpenCCman/issues/93)，依赖 #90 的隔离诊断和已合并的 #99、#100。

最小 WindowGroup 的同二进制对照发现，新增一次 CUA 窗口查询会改变模型存活数。它尚不能证明真实 OpenCCman 的业务模型是否存在相同影响；此前 3/5/7 记录保留，但不能单凭这些记录判定生产泄漏。

## 协议

```sh
# 只准备源代码，不启动应用；目录必须不存在。
python3 scripts/prepare-window-lifecycle.py --automatic --output .build/native-auto

# 本地运行后只读核验原始日志，不启动/控制应用。
python3 scripts/check-native-window-lifecycle.py --raw /absolute/path/lifecycle-PID-UUID.jsonl --output .build/native-auto-report
```

- 使用真实 RootView、Router、HomeViewModel、系统编辑器及窗口注册路径；不替换模型持有关系。
- 保留 #90 的隔离：私有 bundle、免费偏好、禁用购买配置及全局 Services/快捷键注册。自动模式另用 `org.gewill.OpenCCman.NativeWindowLifecycleAuditAuto`，抑制首次 What’s New 弹窗，避免遮挡主窗口。
- 仅在准备副本中为 WindowGroup 添加 `lifetime` 标识和驱动背景。共享 #100 已实测的 `WindowLifetimeDriver.swift`，只替换日志出口。
- 首窗口停留 10 秒，使用 SwiftUI `openWindow` 创建第二窗口，停留 10 秒后使用 AppKit `performClose` 关闭。分别在第二窗口关闭、最后窗口关闭后 +5/+20 秒记录，最后退出自身；总超时 80 秒。
- 驱动只保留窗口标识，窗口引用局限在当次回调；创建第二窗口后立即释放 OpenWindowAction。记录器只弱持有业务模型。
- 本地对照使用同一包、全新进程：首次启动工具可能查询首窗口；基线之后不再查询，对照仅在第二窗口存在期间额外查询一次。记录明确区分“没有额外查询”和“完全没有 AX 访问”。
- 工具不调整 VoiceOver，不涉及模拟输入、其他应用窗口或正式用户偏好。运行后恢复该诊断 bundle 原偏好。

`openWindow` 要求 macOS 13，因此只将自动诊断构建的 `MACOSX_DEPLOYMENT_TARGET` 设为 13.0；产品仍支持 macOS 11，原手动诊断入口保持不变。自动包不能作为最低系统验收或正式发布包。

## CI 与证据

手动运行 App Regression 的 `automatic_window_lifecycle=true`：在 macOS 15/Xcode 26.3 构建隔离 Release 包，随后运行真实应用自驱动协议。使用已有只读权限和固定 SHA 的 Action；无定时任务、无发布。

产物 `native-window-lifecycle-app` 包含源 SHA、锁文件、准备清单、构建日志、应用 zip 及 `automatic` 原始日志/报告。启动器只在 macOS GitHub Actions 中运行，并校验私有 bundle。超时只结束其直接创建的子进程，失败也保留日志。

**校验成功只表示测量协议完整**：同一个 PID，模型编号合法，确实创建两窗、依次关闭、等待足够时长。存活数是结果，不用 `alive == 0` 替代协议验证，也不把进程 exit 0 当作业务释放通过。

截至本提交，43 项 Python 校验测试通过、项目语法检查通过；真实应用的自动构建和运行待补。测试中的转换格式 fixture 不是真实应用运行证据。

这一步只校准空/默认内容的双窗诊断。三轮窗口循环、1/10 MiB 文稿、转换中关闭以及最低系统验收仍保留在 #90/#93 和发布前清单；不关闭问题，不据跨机器结果计算优化百分比。

API 依据：[WindowGroup](https://developer.apple.com/documentation/swiftui/windowgroup)、[OpenWindowAction](https://developer.apple.com/documentation/swiftui/openwindowaction)、[NSWindow.performClose](https://developer.apple.com/documentation/appkit/nswindow/performclose(_:))。
