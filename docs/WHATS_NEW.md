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

关闭按钮固定可见；卡片区域可滚动。使用系统字体、前景色、装饰图标的辅助功能隐藏和按卡片组合的阅读顺序。sheet 显式传递应用当前语言，支持同一进程内切换语言后再次查看。

## 维护下一版内容

1. 在 `OpenCCman/Model/WhatsNew.swift` 的 `WhatsNewRelease.content(for:)` 中定义该营销版本及卡片。当前提供 `1.3` 与 `2.0`，不要为无内容的未来版本展示旧卡片。
2. 在三份 `Localizable.strings` 中补齐所有标题和正文。只陈述已交付行为；取消不意味着正在运行的 C++ 已被强制中断。
3. 更新 `Tests/Regression/WhatsNewChecks.swift` 和 `scripts/check-whats-new.sh` 的内容/语言预期，然后运行检查。
4. 不要因为添加卡片而修改营销版本或构建号。PR 以 `develop` 为目标；正式打包从 `build*` 分支通过 Xcode Cloud 发布。

普通 UI 回归可传入启动参数 `-skip-whats-new`，只跳过自动卡片，设置入口仍可使用。首次展示专项检查不要传入该参数。当前仓库没有 XCUITest target；新增的自动化检查是隔离状态测试，不能替代真实 UI 验收。

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

- VoiceOver 连续朗读、最大辅助功能字号、iPhone/iPad 横竖屏和交互式下滑关闭；沿用 [辅助功能验收 #20](https://github.com/gewill/OpenCCman/issues/20)。
- 当前最低 iOS 15 / macOS 12 的原生 sheet 行为；沿用 [最低系统验收 #16](https://github.com/gewill/OpenCCman/issues/16)。
- 转换尚未完成、导入/导出面板、其他错误提示期间的实际 UI 延后与关闭后恢复；额度提示和 Pro sheet 的 Mac 实测见下节，尚未完成三端矩阵。
- 2.0 的 Xcode Cloud 签名版本及 TestFlight。历史 1.3(44) 不包含这些新卡片。本次不触发发布分支或提交 App Review。

## 2.0 内容接入（2026-09-23）

工程已改为 `MARKETING_VERSION = 2.0`。此前内容函数仅接受 `1.3`，使 2.0 自动展示与设置页手动入口均不可用；本次按当前版本新增四张三语卡片，不修改既有弹窗互斥规则或已持久化的 1.3 记录。新的 2.0 构建首次实际展示后写入 `lastPresentedWhatsNewVersion = 2.0`。在无可见 Device Hub 窗口的模拟器 CLI 启动中，初始 `scenePhase` 为 `inactive`，因此未自动弹出；经交互使场景转为 `active`、回到主页后能自动展示。这个无窗口状态不能代替正常前台启动验收。

本节只记录内容接入。#34 的任务中延后、系统面板、设备方向、VoiceOver、最低系统及签名包验证仍需分别记录实际结果。

## 2.0 Mac 额度与 Pro 延后实测（2026-09-25）

在 `develop` 的 `2fefef4` 上使用 Xcode 27.0 (27A266a)、macOS 27.0 构建无正式签名的隔离 Debug 应用，英文／浅色、1024×768 px 窗口。只为测试 bundle 预置当日 12/12 次额度，并在额度提示显示期间把已展示版本从 2.0 改为 1.0：提示没有被更新卡片覆盖，进入 Pro sheet 后仍未覆盖；关闭 Pro sheet 回主页时卡片出现一次，点完成后不再重复展示。读回隔离偏好显示已展示版本为 2.0、当日计数仍为 12、`isPro=0`；原文未变、结果为空。

[Issue #34 实测记录、截图与交互录像](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5818116935)。隔离 bundle 没有真实商店配置，录像中的 RevenueCat offerings 错误不代表正式应用的购买状态。这次只验证 Mac 额度／Pro 延后；转换进行中、系统面板、其他错误提示、触控设备方向和手势、辅助功能、最低系统及最终签名包仍按 #34/#20/#16 继续验收。
