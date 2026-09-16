# 全部关窗后的外部入口（#19）

2026-09-15，进行中。独立分支 `codex/closed-window-entries` 从 #76 的 `59cad17` 继续；依赖链为 #74 → #76 → 本修复。没有触发 Xcode Cloud，也没有修改依赖或最低系统。

## 当前证据

- 本地 ad-hoc 签名的 Debug 基线应用，应用源码 `6af5ded`（与 `59cad17` 应用代码一致），在 macOS 27.0 关闭全部主窗口后，进程仍在，CGWindowList 显示该进程没有可见窗口。
- 重新通过界面工具查询该应用时观察到窗口再次出现，因此这种观察方式可能掩盖“外部入口没有创建窗口”的问题，不能作为状态栏/Services 通过的证据。状态栏实际点击已请求人工补验，当前未取得结果。
- 独立 SwiftUI `WindowGroup` 实验对比现有激活逻辑与公开的 `NSWorkspace.openApplication`。基线在关窗后到实验结束一直为 0 个窗口；后者产生 reopen 事件，在同一 PID 创建 1 个窗口。原始结果见 [baseline](probe-baseline.json) / [workspace](probe-workspace.json)。三秒观察窗口是实验期限，不是用户操作性能数据。
- 实验源码 [WindowReopenProbe.swift](../../../Tests/Diagnostics/WindowReopenProbe.swift) 独立于应用和依赖，激活函数是冻结的基线比较代码。它证明所选系统机制可行，**不证明完整应用、Services、全局快捷键或最终签名包验收通过**。

## 实现

`AppDelegate.activateMainWindow()` 优先激活已有窗口，并恢复最小化窗口；没有窗口时，通过 Launch Services 重开当前 bundle，显式设置 `createsNewApplicationInstance = false`，由 SwiftUI 创建其原生 WindowGroup。

`MainWindowReopenController` 将连续入口请求合并到一个重开过程。Launch Services 成功回调不等于窗口已绑定，因此直到 `registerReadyWindow` 才结束等待。失败允许重试，过期回调不能清除后续请求。既有待投递通知仍仅保留最新一项，在窗口绑定后投递一次。

Dock/reopen delegate 只激活已有窗口并返回 true，让 SwiftUI 完成正常重开；不能在该回调再次请求 Launch Services 重开，否则会递归或重复开窗。关闭窗口的延迟绑定回调不再消费待处理通知。

Apple 文档：[openApplication](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication(at:configuration:completionhandler:))、[reopen delegate](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldhandlereopen(_:hasvisiblewindows:))。本机 SDK 的 NSWorkspace.h 标注该 API 从 macOS 10.15 可用；仍需 #16 的 macOS 11 实际运行证据。

## 已运行检查

- `bash scripts/check-window-reopen.sh`：连续请求合并、进程成功与窗口就绪的区别、失败重试、过期回调、就绪后的迟到错误均通过。
- `bash scripts/check-project.sh`：工程/plist 与 Swift 语法检查通过。
- `git diff --check` 通过。

## 未完成

- [ ] 最终应用完整编译和 App Regression。
- [ ] 实际状态栏 Settings/Help/Convert 的全部关窗前后对照和交互视频。
- [ ] Services、全局快捷键、冷启动、Dock、最小化、多窗口及连续请求，确认结果可见、最新请求仅投递一次。
- [ ] 真实签名分发包及最低系统验证，分别保留 #15/#16；本 issue 不提前关闭。

## 复现实验

用 `xcrun swiftc -parse-as-library Tests/Diagnostics/WindowReopenProbe.swift -o <独立 app>/Contents/MacOS/WindowReopenProbe` 构建仅包含实验的 app，Info.plist 指定 CFBundleExecutable、独立 CFBundleIdentifier、APPL 及 NSApplication。实验在自己的进程中关闭自己的窗口，写出 JSON 后退出；不操作其他应用窗口。

分别以 `-mode baseline -report <新的绝对 JSON 路径>` 与 `-mode workspace -report <另一 JSON 路径>` 启动，两次应独立运行。必须检查报告 PID 相同、关窗阶段为 0、workspace 最终为 1，不把仅启动成功视为验收通过。本轮使用当前 Xcode 27 构建这个独立实验；没有用它改变应用的 macOS 11 下限。

## 2026-09-16 依赖整合

无冲突整合 #76 最新父分支 `b48e0de`，同时继承当前 MainWindowReader、窗口尺寸与 macOS 27 编辑器适配。相对父分支保持原有重开控制器及 AppDelegate 调用改动，未重写系统入口或文稿业务。精确依赖与父分支相同。

[本次命令与结果](2026-09-16-integration/results.json)：请求合并、进程/窗口就绪区分、失败重试与过期回调；原生首次/历史尺寸恢复、MainWindowReader 和 sheet 关闭校正；窗口布局解析；61 个 Swift 源文件与 3 套语言均通过。完整应用构建以新 HEAD CI 为准。

这些是整合回归，不等同于实际应用的全部关窗后 Settings/Services/快捷键/状态栏验收。原系统入口基线继续保留人工接力；没有重新激活该基线应用来掩盖零窗状态。PR 继续 Draft，仍依赖 #76/#74；#19、#15/#16 的原验收门槛保持不变。历史截图/独立 WindowGroup 实验保留原始来源。
