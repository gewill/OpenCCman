# 2026-11-01 依赖审计与升级候选

基线：develop `f487e0efa8c6a6d306e80d6dd87b152e7b1c1c0a`。逐项核对 GitHub 正式发布、标签、Package.swift 和应用调用；不把所有最新版本都视为必须升级。#27 不因本候选关闭。

## 范围与选择

| 依赖 | 原锁定 | 候选／决定 | 依据 |
| --- | --- | --- | --- |
| BetterSafariView | 2.4.2 | 保留 | 最新正式发布；应用的 Safari 页仍使用它 |
| ColorfulX | 5.8.3 | 6.2.1 | [发布说明](https://github.com/Lakr233/ColorfulX/releases/tag/6.2.1)：修复跨线程解锁，并移除每帧主线程 waitUntilScheduled；用于 Pro 卡片，不宣称本轮已量出性能收益 |
| ColorVector | 1.0.5 | 2.0.0 | ColorfulX 的传递依赖；新最低系统与应用相容 |
| MSDisplayLink | 2.1.0 | DisplayLink 3.0.1 | ColorfulX 正式迁移的包名／仓库；替换旧 pin，不同时引入两个实现 |
| SpringInterpolation | 1.4.0 | 3.0.1 | ColorfulX 的传递依赖；Sendable／Swift 6.2 版本链 |
| IQKeyboardManager | 6.5.16 | 保留 | 新版 8.0.3 拆分 toolbar、return 和通知模块；应用仅禁用位移／工具条并启用点外部收键盘。没有本次相关故障依据，暂不扩大为键盘模块迁移 |
| KeyboardShortcuts | 2.4.0 | 保留；3.1.0 阻塞 | [发布说明](https://github.com/sindresorhus/KeyboardShortcuts/releases/tag/3.1.0)的 macOS 27／菜单／recorder 修复有收益，但本工程 iOS 完整构建失败，见下方实际失败记录；未引入临时 fork |
| Neumorphic | 2.4.1 | 保留 | 当前 fork 最新正式发布 |
| RevenueCat / RevenueCatUI | 5.78.0 | 精确锁定 5.100.0 | [版本对比](https://github.com/RevenueCat/purchases-ios/compare/5.78.0...5.100.0)：权益变化通知与 iOS 16/17 Customer Center 单次购买历史卡住修复；不启用新支付功能 |
| SwiftUI Introspect | 26.0.0 | 27.1.0 | [27 系列升级说明](https://github.com/siteline/swiftui-introspect/releases/tag/27.0.0)：正式 v27 selector；移除本项目的临时 v26 范围＋运行时判断，保留明确版本列表、不自动接纳 28 |
| SwiftUIRouter | 1.4.0 | 保留 | 最新正式发布 |
| SwiftyOpenCC | 564b094 | 保留 | 当前 fork master 与锁定 revision 一致；继续遵守两层同步流程，不直追上游未验证提交 |
| SwiftyUserDefaults | 5.3.0 | 保留 | 最新正式发布 |

候选涉及三个直接依赖及三个传递依赖，总 pin 数仍为 13。Swift tools 至少 6.2；既有 CI 的 Xcode 26.3 及本机 Xcode 27.1 支持该要求。应用部署下限仍是 iOS/iPadOS 15、macOS 12；Introspect 独立检查宿主由旧 macOS 11 对齐到应用的 12，不提高应用下限。

## KeyboardShortcuts 候选被实际构建拒绝

3.1.0 在本机 iOS Simulator 编译 `Sources/KeyboardShortcuts/Utilities.swift:660` 时失败：`no type named 'Name' in module 'KeyboardShortcuts'`。`Name.swift` 的声明位于 `#if os(macOS)` 内，而 Utilities 中 `Notification.keyboardShortcutsName` 没有相同保护。

保留 `ios-build.json`、`ios-build-02.json`、`ios-build-03.json` 及对应完整日志：先验原工程，再尝试 PBXBuildFile 的 macOS platformFilter，再移除重复的 target product dependency；三种情况下 Xcode 图均仍包含 KeyboardShortcuts，错误相同。已完整撤回这些实验与 `initial:` 迁移，保留 2.4.0 和原工程接入方式；没有修改包缓存源码、添加 fork 或抬高系统下限。

3.1.0 上游 Mac Release `swift test` 返回 0，但日志未显示整个 Swift Testing suite 的完成结论，因此不把它写成全套通过，更不能抵消 iOS 构建失败。待上游修正多平台编译或另行完成条件依赖方案后，再独立升级。

## RevenueCat 集成边界

遵循内部 [RevenueCat 披露核对指南](https://github.com/gewill/dev-standards/blob/main/revenuecat_privacy_guide.md)。5.78.0 与 5.100.0 的 `Sources/PrivacyInfo.xcprivacy` 解析结果完全一致。新 Configuration 中 IAM 和外部支付自定义链接默认关闭，App 没有调用这些选项；配置仍只设置现有 API endpoint 和 UI locale，没有新增属性／账号／广告采集调用。

隐私 manifest 相同不能证明所有运行数据流完全相同。新 SDK 支持远端诊断配置，注释要求开发者请求／明确批准；本轮未修改 RevenueCat 后台、没有启用诊断，没有核查后台实时配置或签名包隐私报告。真实购买／恢复、Customer Center 后台行为和分发包仍由 #14／#71／#15 验收。

## 验证记录

本机：Apple M4 Pro、48 GiB、macOS 27.2（26B123）；进程级 Xcode 27.1（27A9275），不切换全局 Xcode。证据位于仓库外 `~/Library/Application Support/Codex/ui-evidence/OpenCCman/dependency-audit-20261101/`，其中 `upstream.json`、`candidates.json` 保存来源版本与 SHA。

- Xcode 依赖解析成功；实际图仍为 13 项，未带入上游 Package.swift 中仅用于测试的 Nimble／SnapshotTesting。
- 工程／语言／控件标签／workspace／workspace-editor／conversion-diff／pro-access／pasteboard／control-sizing／introspection 检查均通过，完整输出见外部 `checks/results.json`。
- 原生 Introspection 检查实际在 macOS 27.2 执行，验证 source/result、只读结果、TextKit 1、内容／样式、window callback 和旧列表负对照；不是仅扫描源码。
- `bash scripts/check-storekit.sh <外部输出目录>`：7 项本地 StoreKit 测试通过，包括购买、恢复、退款、重复购买和取消；这是独立 StoreKit harness，不是 RevenueCat 真实后台交易。
- 最终 Debug 构建：iOS Simulator arm64、macOS arm64/x86_64 均 `BUILD SUCCEEDED`，Xcode 原生命令 exit 0，axbuild 最终日志采集 complete。原始 SDK/最低系统读回：iOS SDK 27.1、最低 15.0；macOS SDK 27.0、最低 12.0。未重跑签名分发包，也没有声称没有编译警告。
- iOS 初次成功构建还暴露 `MyAppView` 间接使用 Combine 的警告，补显式 `import Combine` 后重跑最终 iOS 构建；macOS 构建也包含此修正。

### 构建复现

使用 `xcodebuild -project OpenCCman.xcodeproj -scheme OpenCCman -configuration Debug`，两端共有参数 `-disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -jobs 2 CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO PRODUCT_BUNDLE_IDENTIFIER=org.gewill.OpenCCman.WhatsNewUITests build`。iOS 的 destination 为 `generic/platform=iOS Simulator`、`ARCHS=arm64`、`OTHER_SWIFT_FLAGS=$(inherited) -D OPENCCMAN_DUO_SDK`；Mac destination 为 `platform=macOS`、`ARCHS=arm64 x86_64`。外部独立 DerivedData 分别为 `~/Library/Caches/Codex/OpenCCman-dependency-audit-20261101/ios` 与 `mac`，Mac 复用本任务 iOS 的 SourcePackages。

`ios-build-final-artifacts/build.log`、`mac-build-artifacts/build.log` 保留完整调用和原生结果，`ios-artifact.json`、`mac-artifact.json` 保存 bundle、生成 plist、架构和全部代码载荷哈希。本轮构建时工作区尚未提交，来源为基线 f487e0e 加本候选改动；App／工程／检查脚本 diff 的 SHA-256 为 `52bb75f8b5a432b4c7d3dd22e3c6c0be1e146d90970ab380c04b756507518a87`，不以基线 SHA 代表候选。

iOS `OpenCCman.debug.dylib` SHA-256 `4924f8c9b8a8e0deb9e567e42f0d4f37944f090ee4c6f37857d4846cddb7f534`；Mac 为 `1b8d8387abfdc36f8107f1a02683fb8868aaa1e188c863db1bc039508e0e894f`。实际安装 iOS bundle 的代码哈希与最终构建再次核对一致。

### 实际运行与媒体边界

- iPhone SE3 / iOS 18.6，375×667 pt、英语、默认字号：示例→真实转换（正体／OpenCC）→开启差异→下一处 1/4→Pro 卡片→返回；AX 文本显示两侧内容和 1/4 保持。运行中系统评分弹窗遮挡了首次点按，截图识别后点 Not Now，未提交评分；之后差异开关与导航生效。不将被遮挡的点按误判为依赖故障。
- Mac / macOS 27.2：沿用 QA 最小窗口和既有缩放偏好，示例→转换→差异 4 处→导航 1/4→View 菜单下一处 2/4→Pro→返回，正文及 2/4 保留。完整树保存在 `mac-diff-state.txt`、`mac-return-state.txt`；本次没有重新完成 100%／150% 全矩阵。
- 两端 Pro 卡片以隔离 QA 的 `-isPro YES` 启动参数显示，只用于渐变渲染，不是付费权益或商品加载证据。iPhone 商品请求出现 offerings 无法获取的提示，并按既有 `showError` 两秒清除逻辑消失；录像保留该状态，真实 RevenueCat 购买链路未通过本轮验收。
- iPhone 前后截图都采用同一 QA bundle、设备、英语、字号和卡片状态。前包复用上一轮构建（源码 6abf992 的应用内容到本轮基线未变），实际 dylib hash `efcb18d63df12f8222474c54490a98481d545d29d9c226225df259070b1cb23d`；颜色是动画的不同时间帧，不做像素相等或性能改善结论。
- 精选 12.333333 秒录像 `iphone-card-return.small.mp4` 完整解码，并在本地浏览器从 0 播放至 ended；1280 高、15fps 副本只作交互证据。完整首次流程原件 `iphone-flow.mp4` 留在本地。
- 任务模拟器 `42C71610-575F-482E-A329-7637CD51D10F` 从 Shutdown 启动，记录与 QA 进程结束后恢复 Shutdown。Mac QA 已退出；既有 iPerfman tvOS 模拟器／测试未中断。

本轮升级不代表最低系统实机、VoiceOver、真实交易、签名包或性能收益通过。
