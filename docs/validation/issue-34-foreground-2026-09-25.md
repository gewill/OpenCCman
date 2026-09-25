# What’s New 前台与签名包状态补验（#34，2026-09-25）

## 当前来源

应用 `develop` 为 `fc5a901d76e88109547397704e9037a7d9cefa05`，版本 2.0。Xcode 27.0 (27A266a)。本次没有修改卡片产品代码、发布分支或 App Store Connect。

## 真实 Mac 前台

在 macOS 27.0 将同一源码的 Debug Mac App 复制为独立 `org.gewill.OpenCCman.TextSizeKeyboardQA20260925`，移除副本的 `NSServices`，保留沙盒与用户选定文件读写 entitlement，再 ad-hoc 签名。`codesign --verify --deep --strict` 通过。QA 窗口经 CGWindow 读回为 1024×768 pt，英语／浅色、应用内 150%。

应用初次显示工作区时没有立刻展示卡片；在 QA 窗口实际获得前台焦点后，**未通过设置页请求，也未传卡片 QA 参数**，2.0 What’s New 自动出现。AX 树含标题、版本、四张卡片及 Done；点击 Done 后原文和已转换结果仍在。[#34 的前后真实截图](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5826546401)只摄录独立 QA 应用。这支持“活动前台才自动展示”，不能把后台阶段的工作区截图误判为失败。

同一 QA 包从设置页再次手动打开卡片、点击 Done 返回设置。[20.05 秒真实窗口录像](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5826597289)只证明**手动重看与关闭**，不伪称录像展示了首次自动弹出。

## iOS 与云端边界

- 在 iPhone 18 Pro / iOS 27 Simulator 上构建独立 bundle `org.gewill.OpenCCman.WhatsNewForegroundSimQA20260925`。无卡片参数的 XcodeBuildMCP 启动停留主页；临时诊断显示版本 2.0、路由 `/home`、未读偏好为空，但 `scenePhase` 始终为 `inactive`。诊断代码已撤销。此为无可见前台的运行条件，不能据此判断真实前台路径。既有隔离 QA 参数下的 13/13 回归见 [iOS 27 VoiceOver 复核](issue-34-voiceover/followup-2026-09-25.md)。
- 独立 iOS Debug QA 包 `org.gewill.OpenCCman.WhatsNewDeviceQA20260925` 已通过现有签名、`codesign --verify --deep --strict`，并安装到配对的 iPhone 16 Pro / iOS 27.0，未替换正式版。设备仍需密码解锁；本次**未启动该包，也未得到真机 UI 结论**。
- `asc builds list --app 6474449401 --sort -uploadedDate --limit 10` 的最新 iOS/macOS 构建仍为 2.0 Build 53，均 `VALID`，上传于 2026-09-16。它的来源 `82b8478` 早于卡片 PR #137，不可作为新卡片的最终 Xcode Cloud/TestFlight 签名验收。

真实 iPhone/iPad 前台、长任务与弹窗剩余组合、iOS 15/macOS 12 原生 sheet、完整朗读和包含卡片的新 Xcode Cloud/TestFlight 包仍待验收，#34 保持开放。此次没有发新包或改价格。
