# PR #284 评论复核与 alert 修复（2026-10-28）

审查基线 `83db406f2d715e39095cec77228fdf0c003b45bf`，关联
[评论](https://github.com/gewill/OpenCCman/pull/284#issuecomment-6468828525)。

## 实际处理

HomeScene 原先以 `showingProAlert || error != nil` 驱动同一 alert，关闭时无条件清除两个状态。
两者同时存在时，用户只看到 Pro 提示，未展示的错误也会被清除。
这是同一 MainActor 上的状态消费问题，不需要并发线程才能触发。

iOS 改为按内容标识的 alert，保存实际展示内容的快照。关闭只消费该类状态；
打开 Pro sheet 时，错误保留至 sheet 的实际 onDismiss 回调后再展示。
保留 Pro 优先级、取消与打开语义，不加任意延迟，不改额度或交易逻辑。
Mac 保留既有提示机制。

新增两个真实 UI 用例：Pro 取消后显示原错误；Pro sheet 中不抢先显示错误，返回后显示原错误。
两条用例均核对错误正文、关闭后无残留提示和原文保持，并回归已有的单独 Pro 取消／打开／关闭流程。
`-qa-error-with-pro-alert` 仅在 Debug 和精确的隔离 QA Bundle ID 下，配合真实额度耗尽转换入口
注入一个明确命名的错误。它证明状态冲突处理，不证明自然文件导入时序发生该冲突。
不向正式 App 添加注入入口，也不进行购买／恢复操作。

## Customer Center：保留 SDK 自带导航

依赖锁定 RevenueCatUI 5.78.0 / revision `629a56ecef190469914b8f0914bf0446363eb09f`，
本机 checkout HEAD 与锁文件一致且干净。
`CustomerCenterScene` 只传入 onCloseHandler，其他选项沿用默认值。

- [默认 usesExistingNavigation=false](https://github.com/RevenueCat/purchases-ios-spm/blob/629a56ecef190469914b8f0914bf0446363eb09f/RevenueCatUI/CustomerCenter/Views/CustomerCenterNavigationOptions.swift#L65)。
- [组件自行创建 CompatibilityNavigationStack](https://github.com/RevenueCat/purchases-ios-spm/blob/629a56ecef190469914b8f0914bf0446363eb09f/RevenueCatUI/CustomerCenter/Views/CustomerCenterView.swift#L171)。
- [iOS 16+ 为 NavigationStack，iOS 15 为 NavigationView](https://github.com/RevenueCat/purchases-ios-spm/blob/629a56ecef190469914b8f0914bf0446363eb09f/RevenueCatUI/CustomerCenter/Views/CompatibilityNavigationStack.swift#L28)。
- [关闭按钮在系统 toolbar 中](https://github.com/RevenueCat/purchases-ios-spm/blob/629a56ecef190469914b8f0914bf0446363eb09f/RevenueCatUI/CustomerCenter/ButtonStyles.swift#L171)，
  [新系统使用 Button(role: .close)](https://github.com/RevenueCat/purchases-ios-spm/blob/629a56ecef190469914b8f0914bf0446363eb09f/RevenueCatUI/CustomerCenter/ButtonStyles.swift#L106)。

因此“没有本次文件改动”等同“缺系统导航”的判断不成立，不额外套一层导航栈。
iOS 14 分支低于当前 iOS 15 产品下限，也不构成本次可达路径的遗漏。
这里仅确认源码结构；Customer Center 的真实 Duo 姿态、业务配置和关闭体验仍未验收，保留 #280/#14/#71。
轻微的重复、命名和缩进建议不影响本次缺陷，未扩大修改范围。

## 本次运行

环境沿用专用 OpenCCman Duo QA 277 / iOS 27.1 (24A94425)、Xcode 27.1 (27A9275)，
最低系统仍 iOS 15 / macOS 12，依赖锁、功能开关与云端配置未改。
源码／测试哈希、原生命令、产物与 UI 结果在仓库外的 284-alert 证据目录留存；媒体见本 PR 的补充证据评论。

- 修复前：只加 QA 前置和用例，保留旧 HomeScene；取消用例 1 项失败，22.116 秒，原生退出 65。
  失败点为“未展示的错误不应被 Pro 取消消费”。Xcode 自动启动 600 秒 verbose 诊断后，
  核对父进程和目标 UDID，仅提前终止本次诊断子进程；测试断言、原图和已完成 xcresult 保留。
- 后续用例显式使用本机帮助支持的 `-collect-test-diagnostics never`，保留普通日志、截图和 xcresult。
- 修复版 iOS arm64 / macOS arm64+x86_64 Debug 构建与产物校验通过。
- 额度、Pro 权益、What’s New 和工程解析回归通过。
- 默认字号：上述 3 项针对性 UI 测试通过，0 失败、0 跳过，39.369 秒。
- 为录屏补跑两条冲突路径，2 项通过，24.754 秒；不重复计为新增验收范围。
- XXXL：相同 3 项通过，0 失败、0 跳过，43.352 秒；结束恢复默认 large。
- 构建与 UI 绑定 [本次精简证据](alert-followup.json) 的源码 diff／逐文件哈希；文档更新不冒充应用重测。

两档字号只覆盖本次受影响提示；不重复既有三语导航、连续尺寸或整个姿态矩阵。
原始 [首轮记录](README.md) 与 evidence.json 继续对应原候选，不能视为新提交的全套复跑。
Duo 真机、自然文件失败时序、真实交易、最低系统和 VoiceOver 体验仍未验证；本轮不关闭原 Issues。
