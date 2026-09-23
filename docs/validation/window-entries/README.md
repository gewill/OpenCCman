# 全部关窗后的外部入口（#19）

## 2026-09-24：真实 Services 的零窗回写

基于当前 `develop` `458fcd2` 的隔离、ad-hoc 签名 Debug 应用，在进程存活但无可见窗口时分别调用两次 Convert、一次 Open 服务。三次均在同一 PID 重开一扇主窗口；Convert 的 pasteboard 结果逐字节匹配同版本 OpenCC CLI，应用中可见当次原文与结果；Open 保留原文且结果为空。测试细节、合成语料、原始 JSONL、截图和交互录屏见 [2026-09-24 Services 验证](2026-09-24-services/README.md)。

调用方使用 `NSPerformService` CLI；TextEdit 菜单项虽然可见，本次自动化未能点击执行，不能把它算作目标 App 菜单通过。状态栏、全局快捷键、连续请求、多窗口与最终签名包尚未验收，#19 继续开放。下文历史“Services 尚未运行”的表述是当时状态，以本段及专项报告为准。

2026-09-15，进行中。独立分支 `codex/closed-window-entries` 从 #76 的 `59cad17` 继续；依赖链为 #74 → #76 → 本修复。没有触发 Xcode Cloud，也没有修改依赖或最低系统。

## 2026-09-23：同进程重开子项

当前 `develop` 源码 `8619bec06b44075c1b0d53371bf830bb2c6fac65` 在 macOS 27.0／Xcode 27.0 上以 Debug 构建，覆盖独立 bundle ID `org.gewill.OpenCCman.WindowEntryValidation` 后进行 ad-hoc 签名。测试仅使用该 bundle 的独立偏好，未操作已安装的 TestFlight 包。完整构建成功，签名含应用现有 Sandbox、用户选取文件读写和客户端网络 entitlement。

用 CUA 关闭隔离应用唯一主窗口后，测试进程 PID `70881` 仍运行且无窗口；通过 CUA 的系统应用选择（Launch Services）重开同一 bundle，PID 仍为 `70881`，可见一个新主窗口。[交互录屏](https://github.com/user-attachments/assets/44fbc1c8-7c78-4db0-8d26-d8a3387e8ff1) 使用 ScreenCaptureKit 仅录测试应用，不含其他应用、音频或麦克风；[Issue 验收记录](https://github.com/gewill/OpenCCman/issues/19#issuecomment-5792108636)。原始视频 SHA-256 为 `cb943f0e9b7004b856491f1cfe83a6b40d2488f1db5d4b2a66cf6da0880e235f`，测试可执行文件 SHA-256 为 `a6eb9cf3c94ba42bf71f09e4d24c037a69358d49ca3da7dd331e19818ddde03a`。

这仅证明当前源码的同进程 Launch Services 重开路径。Dock 实际点击、Services、全局快捷键、状态栏菜单、连续请求及最终分发签名包仍未验收；最低 macOS 12 运行证据仍由 #16 追踪。不能据此关闭 #19。

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

### 2026-09-16：已有窗口通知接收回归

基于应用源码 `c28e2a0`，新增 [WindowNotificationChecks.swift](../../../Tests/Regression/WindowNotificationChecks.swift)，已接入原有 `python3 scripts/check-core.py` 和 App Regression。macOS 27.0 (26A428) / arm64 本地完整核心回归通过：[完整日志](2026-09-16-notifications/core.log)、[环境、来源与校验和](2026-09-16-notifications/results.json)。

测试创建两个不显示的 NSWindow，把两个真实 HomeViewModel 分别绑定，并保留一个未绑定模型作为负对照。通过真实 NotificationCenter/Combine 订阅检查 Services 和快捷键结果仅写入明确目标、未绑定模型忽略通知、NUL/CRLF/组合字符保持、导出快照替换、仅导入原文时清空旧结果、缺字段不破坏文稿、主页额度不变。主队列 FIFO 屏障等待通知处理，未使用固定睡眠猜测完成。

旧 Services 观察来自 `eab5003`；该版本 RootView 的窗口回调仅列 macOS 11–26，在本机 macOS 27 不执行（见 [#98 的独立原生负对照](../../performance/macos27-introspection/README.md)）。当前 #77 继承的 MainWindowReader 不依赖该版本列表。这是重新验收已有窗口的具体理由，不能据此把旧观察直接算成当前版本失败或通过。

本测试直接绑定窗口并投递通知，不覆盖 AppDelegate 选窗/等待队列、MainWindowReader 实际绑定、NSPerformService 注册调用、系统菜单或渲染。未启动/修改待人工验收的 Services Probe，也未改系统设置；不替代下列真实应用前后截图与交互视频门槛。

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
