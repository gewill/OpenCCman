# What’s New cards

参考 [Pingman #33](https://github.com/gewill/Pingman/issues/33)，OpenCCman 在应用内用原生 sheet 展示当前营销版本的新功能。当前 2.0 内容包括自适应工作区、常用转换预设、单个 TXT 文件导入与导出、取消和原稿保护；保留 1.3 旧内容供历史版本使用。使用英文、简体中文、繁体中文三种语言。

## 展示规则

- 新安装或上次查看版本不同于当前版本时，在主页首次满足条件后自动展示一次。构建号变化不重新展示。
- 设置页的“新功能”支持手动重看。没有与 `CFBundleShortVersionString` 精确匹配的内容时，隐藏入口且不自动展示；不会用旧版本内容兜底。
- 只有 sheet 内容实际 `onAppear` 后才写入 `lastPresentedWhatsNewVersion`。手动查看也计为已展示。仅创建预约、等待、窗口提前关闭均不写入。
- `OpenCCmanApp` 持有跨窗口共享的 `WhatsNewCoordinator`；同一时间只有一个窗口能预约展示。其他窗口关闭、失效回调不会释放当前窗口的预约。
- 自动展示仅在主页、前台且窗口就绪时发生。macOS 还要求主窗口。转换、导入、文件面板、错误提示、额度提示、Pro 页面或 sheet 期间延后；Pro sheet 的阻塞持续到 `onDismiss`。手动请求也遵守前台和任务/弹窗条件。
- 延迟触发的系统评价请求遇到已展示的系统 sheet 时跳过，避免叠加。
- 内容为本地静态图标和文字，不请求远程内容、不引导购买、不改变额度或转换选项。

关闭按钮固定可见；卡片区域可滚动。使用系统字体、前景色、装饰图标的辅助功能隐藏和按卡片组合的阅读顺序。VoiceOver 前向导航从标题、版本、卡片依次到达“完成”，按钮视觉位置不变。sheet 显式传递应用当前语言，支持同一进程内切换语言后再次查看。[iOS 27 模拟器朗读顺序实测](validation/issue-34-voiceover/README.md)。

## 维护下一版内容

1. 在 `OpenCCman/Model/WhatsNew.swift` 的 `WhatsNewRelease.content(for:)` 中定义该营销版本及卡片。当前提供 `1.3` 与 `2.0`，不要为无内容的未来版本展示旧卡片。
2. 在三份 `Localizable.strings` 中补齐所有标题和正文。只陈述已交付行为；取消不意味着正在运行的 C++ 已被强制中断。
3. 更新 `Tests/Regression/WhatsNewChecks.swift` 和 `scripts/check-whats-new.sh` 的内容/语言预期，然后运行检查。
4. 不要因为添加卡片而修改营销版本或构建号。PR 以 `develop` 为目标；正式打包从 `build*` 分支通过 Xcode Cloud 发布。

普通 UI 回归可传入启动参数 `-skip-whats-new`，只跳过自动卡片，设置入口仍可使用。首次展示专项检查不要传入该参数。`Tests/UI/WhatsNewPresentation` 提供独立 iOS XCUITest 工程与隔离 QA 包；`scripts/check-whats-new.sh` 仍是纯状态测试，两者都不能替代最终签名包与最低系统验收。

## 1.3 历史验证记录（2026-09-13）

环境：Xcode 26.6（17F113），macOS 26.6.2，Apple Silicon。工程部署下限保持 iOS 14 / macOS 11，版本保持 1.3，依赖锁文件未改变。

| 检查 | 结果与边界 |
| --- | --- |
| `bash scripts/check-whats-new.sh` | 通过；当前/未知版本、首次/升级/重启、实际出现才持久化、手动先看、关闭未出现的窗口、失效回调、多窗口预约、全部阻塞条件、测试跳过开关；三个语言各 8 个键完整且非空 |
| `bash scripts/check-project.sh` | 通过；工程、Swift 语法、plist 与三份 strings |
| `python3 scripts/check-core.py` | 使用与锁文件完全一致的本地依赖通过；7 组配置 × 8 语料、预设、文件、取消/替换及 provider 回归 |
| `bash scripts/check-quota.sh` | 通过；预约、并发上限、失败/取消释放、跨日与 Pro |
| `bash scripts/check-pasteboard.sh` | 通过；隔离剪贴板内容与所有权保护 |
| macOS Debug 完整构建 | `BUILD SUCCEEDED`，`CODE_SIGNING_ALLOWED=NO` |
| iOS Simulator Debug 完整构建 | `BUILD SUCCEEDED`，`CODE_SIGNING_ALLOWED=NO` |
| macOS 实际 UI | 隔离 bundle ID 的本地测试版；首次前台展示、Escape/完成关闭、重启不再自动显示、新建窗口不重复、设置手动查看、后台请求回前台后展示均通过 |
| macOS 语言/外观 | 英文浅色、繁体深色可读；同一进程中切换到简体后手动重看使用简体。修复了首次 sheet 语言被缓存的问题；关闭按钮和卡片可在辅助功能树定位 |

构建保留既有依赖/资源警告（例如 SwiftyUserDefaults 泛型遮蔽、颜色符号冲突）；本次不把编译通过等同于无警告或正式签名发布通过。

复现构建命令（依赖及 derived data 目录可自行指定）：

```bash
xcodebuild -project OpenCCman.xcodeproj -scheme OpenCCman \
  -destination 'generic/platform=macOS' \
  -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO build
xcodebuild -project OpenCCman.xcodeproj -scheme OpenCCman \
  -destination 'generic/platform=iOS Simulator' \
  -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO build
```

## 发布前仍需验收

统一跟踪：[What’s New 设备与弹窗延后 UI 验收 #34](https://github.com/gewill/OpenCCman/issues/34)。

以下项目尚未完整执行，不记作通过；状态测试已覆盖的分支也需要在设备上确认系统交互：

- iOS 27 模拟器已验证 VoiceOver 前向导航可从标题经过四张卡片到达“完成”；其他系统、真机与完整段落朗读仍待 [辅助功能验收 #20](https://github.com/gewill/OpenCCman/issues/20)。最大辅助功能字号、iPhone/iPad 横竖屏和交互式下滑关闭已在部分模拟器实测，见下节，仍需最终签名包与最低系统复核。
- 当前最低 iOS 15 / macOS 12 的原生 sheet 行为；沿用 [最低系统验收 #16](https://github.com/gewill/OpenCCman/issues/16)。
- 真实长转换、长导入、导入/导出面板与其他错误提示的完整三端矩阵；iPhone/iPad 的可控延迟转换、失败、取消和导入取消已有专项 UI 测试，额度提示和 Pro sheet 的 Mac 实测见下节。
- 2.0 的 Xcode Cloud 签名版本及 TestFlight。历史 1.3(44) 不包含这些新卡片。本次不触发发布分支或提交 App Review。

## 2.0 内容接入（2026-09-23）

工程已改为 `MARKETING_VERSION = 2.0`。此前内容函数仅接受 `1.3`，使 2.0 自动展示与设置页手动入口均不可用；本次按当前版本新增四张三语卡片，不修改既有弹窗互斥规则或已持久化的 1.3 记录。新的 2.0 构建首次实际展示后写入 `lastPresentedWhatsNewVersion = 2.0`。在无可见 Device Hub 窗口的模拟器 CLI 启动中，初始 `scenePhase` 为 `inactive`，因此未自动弹出；经交互使场景转为 `active`、回到主页后能自动展示。这个无窗口状态不能代替正常前台启动验收。

本节只记录内容接入。#34 的任务中延后、系统面板、设备方向、VoiceOver、最低系统及签名包验证仍需分别记录实际结果。

## 2.0 Mac 额度与 Pro 延后实测（2026-09-25）

在 `develop` 的 `2fefef4` 上使用 Xcode 27.0 (27A266a)、macOS 27.0 构建无正式签名的隔离 Debug 应用，英文／浅色、1024×768 px 窗口。只为测试 bundle 预置当日 12/12 次额度，并在额度提示显示期间把已展示版本从 2.0 改为 1.0：提示没有被更新卡片覆盖，进入 Pro sheet 后仍未覆盖；关闭 Pro sheet 回主页时卡片出现一次，点完成后不再重复展示。读回隔离偏好显示已展示版本为 2.0、当日计数仍为 12、`isPro=0`；原文未变、结果为空。

[Issue #34 实测记录、截图与交互录像](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5818116935)。隔离 bundle 没有真实商店配置，录像中的 RevenueCat offerings 错误不代表正式应用的购买状态。这次只验证 Mac 额度／Pro 延后；触控设备方向和手势另见下节，转换进行中、其他错误提示、VoiceOver、最低系统及最终签名包仍按 #34/#20/#16 继续验收。

## 2.0 iPhone 与 iPad 交互复核（2026-09-25）

同一 `develop` 应用源码 `2fefef4` 的独立 iOS Simulator Debug 包，在 iPhone 15 Pro Max / iOS 18.6 和 iPad Air 11-inch (M2) / iPadOS 26.5 上各运行三个相互隔离的 XCUITest：普通字号竖横屏与横屏 Done、竖屏交互下滑、最大辅助字号竖横屏与 Done。六项均通过，每项 1 次、0 失败。英文／浅色；每项从全新安装的 QA 包开始，最大辅助字号测试后恢复为 `large`。[Issue #34 的真实截图、视频和测试边界](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5818592627)。

一次未隔离的前置试跑曾用 `-lastPresentedWhatsNewVersion 1.0` 启动参数持续覆盖偏好，造成关闭后立即重新判为未读；删除该测试参数、每项全新安装后六项通过，没有产品代码修复。横屏 XCTest 截图抓到旋转过渡帧，因此不作为稳定横屏图片；成功交互由用例结果与录像支持，先前 #34 的稳定横屏截图继续保留。此次模拟器回归不替代 VoiceOver、长任务取消、最低系统、真实设备或最终签名包验收。

## 2.0 弹窗竞态与系统评分补验（2026-09-25）

在 `develop` `636ee84` 基础上的隔离 Debug QA bundle 中，用独立 XCUITest 工程固定了五条真实 UI 路径：系统导入面板取消、延迟转换成功、延迟转换取消、模拟转换失败，以及已读更新卡片后的正常评分请求。测试参数仅对精确 QA bundle ID 和 Debug 构建生效，延迟和失败为可控注入；不改变正式包行为，也不宣称能中断 C++。运行入口与边界见 [`Tests/UI/WhatsNewPresentation/README.md`](../Tests/UI/WhatsNewPresentation/README.md)。

补验发现原实现会在首次转换成功、What’s New 随后出现且被快速关闭时，紧接着弹出 StoreKit 评分提示。iPadOS 26.5 的失败前测试明确命中 `Not Now`，连续录屏保留了这一顺序。修复后，当前营销版本的更新卡片尚未读完时不预约评分，也不消耗 `lastVersionPromptedForReview`；后续一次成功转换仍可请求系统评分。Apple 的[评分与评论建议](https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews)强调避免首次启动及打断用户任务，这里据真实界面行为消除了连续弹窗。

最终候选在 iPhone 15 Pro Max / iOS 18.6 和 iPad Air 11-inch (M4) / iPadOS 26.5 模拟器各跑五项，均 5/5 通过；iPad 的原失败断言修复后通过。Xcode 27.0，两端英文／浅色／常规字号，专用 QA 安装；`scripts/check-whats-new.sh`、核心回归和 macOS/iOS Debug 构建通过。前后截图、视频与精确来源提交附在本轮 PR／#34 评论。仍需真实 10 MiB 任务、VoiceOver 连续朗读、iOS 15/macOS 12、真机与最终签名包，Issue 继续开放。

## 2.0 系统面板、Pro 与旋转补验（2026-09-25）

在 #185 合并提交 `ab62b99` 上扩展隔离 XCUITest。iPhone 15 Pro Max / iOS 18.6 与 iPad Air 11-inch (M4) / iPadOS 26.5 的七项基础矩阵各 7/7 通过：原五项、真实系统导出面板打开时不叠加卡片，以及真实免费额度耗尽后的自定义 Pro 提示 → Pro sheet → 关闭后出现卡片。两端的横屏 Done 和系统下滑关闭测试通过；最大辅助字号 `accessibility-extra-extra-extra-large` 下的横屏 Done 亦在两端通过，测试后恢复到原 `large`。英文／浅色、Xcode 27.0，独立 QA bundle。系统横屏截图以 `simctl io screenshot` 采集，因 XCTest 截图曾捕获旋转过渡帧；截图、交互录像及测试日志随 PR 附上。

导出面板的可见“取消”由系统 `com.apple.DocumentManager.Service` 扩展绘制，iOS 18 的 app-scoped XCUITest 将其误识别为屏外宿主节点；本轮只将**面板显示期间不叠加**记作通过，不把自动点击失败记作产品故障，也不把导出取消后的恢复记作已验收。隔离 QA bundle 的 RevenueCat 产品目录与正式 bundle ID 不匹配，Pro sheet 的商品可用性、购买和恢复均不在本轮结论内。VoiceOver 连续朗读、iOS 15/macOS 12、真实设备与最终签名包仍需补验，#34 保持开放。

## 2.0 iPhone 导出取消后恢复补验（2026-09-25）

在 `develop` `1df42cb` 的独立 iPhone 15 Pro Max / iOS 18.6 Simulator QA 包上，实际打开系统文件导出面板，确认卡片未叠加；从“On My iPhone”返回“Browse”顶层，点击系统“Cancel”后，2.0 卡片出现一次，关闭后没有重复展示。Xcode 27.0、英文、浅色、普通字号；`testExportPanelDoesNotOverlapCards` 以屏幕左上导航点击回退，随后断言系统面板消失及卡片出现，在 iPhone 15 Pro Max / iOS 18.6 和 iPhone 17 Pro / iOS 26.5 两个专用模拟器各 1/1 通过。系统扩展的导航按钮未稳定出现在 app-scoped 无障碍树中，因此该回归仅在 iPhone 竖屏使用已实测坐标；iPad 保持原有“面板显示时不叠加”断言，取消路径未在 iPad 自动化。截图、交互录像与测试日志随本轮 PR 归档。此项是隔离 Debug 模拟器验收，未替代真机、最低系统及最终签名包。
