# OpenCCman

[English](README.md) · 简体中文 · [繁體中文](README.zh-Hant.md)

基于 [OpenCC](https://github.com/BYVoid/OpenCC) 的原生中文转换应用，支持 iPhone、iPad 和 Mac。在设备本地完成简繁转换，并调整地区用词。

[官网](https://openccman.gewill.org/zh-Hans/) · [App Store](https://apps.apple.com/app/id6474449401) · [隐私政策](https://openccman.gewill.org/zh-Hans/privacy.html) · [支持](https://openccman.gewill.org/zh-Hans/support.html)

[![在 App Store 下载](assets/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg)](https://apps.apple.com/app/id6474449401)

## OpenCCman 2.2

- 提供简体中文、OpenCC 繁体、台湾正体与台湾词组、香港繁体四种常用预设，异体字与地区用词仍可在高级选项中调整。简体输出不等于完整的台湾词汇反向转换。
- 在 Mac 和 iPad 上，原文和结果可左右或上下对照。每个窗口保留独立的布局选择，窄窗口临时采用上下排列。iPhone 的工作区按窗口大小排列，宽窗口也可左右对照，并使用紧凑的「转换」按钮，为文字留出更多空间。
- 在 Mac 上，可用自定义全局快捷键转换其他应用中选中的文字，并替换可编辑内容，或把选中文字送到 OpenCCman。兼容的应用也可通过 macOS「服务」调用转换。替换操作需要辅助功能权限，并取决于来源应用是否支持。
- 可导入或拖入单个不超过 10 MiB 的 UTF-8 TXT，支持带 BOM 的文件；最近一次成功结果可导出为不带 BOM 的 UTF-8，并保留换行、空行和 Unicode 字符。在 Mac 上，Pro 可将单个大于 10 MiB、最大 1 GiB 的 UTF-8 TXT 直接转换为文件，显示进度、可以取消，编辑器中的稿件保持不变。在 iPhone 和 iPad 上，Pro 可将单个大于 10 MiB、最大 100 MiB 的 UTF-8 TXT 直接转换为在保存面板中选定的文件；转换在应用打开时进行，切到后台会安全中止。所有设备上的拖放和编辑器仍限 10 MiB。暂不支持批量转换和 Big5／GBK 解码。
- 在 iOS／iPadOS 16 及以上和 macOS 13 及以上，可用免费的「快捷指令」动作自动转换文字：支持四个预设、最多 10 MiB 的 UTF-8 文字，不计入主页转换次数。
- 新稿从空白工作区开始，也可「填入示例」。「清空原文」会先确认，再清除原文和结果。
- 可以取消转换或导入，之后才返回的结果不会覆盖当前文字。取消不会强行中断已在进行的原生转换。
- 免费版每天可完成 12 次成功的主页转换。终身 Pro 解除这一限制并隐藏应用推荐，已有的终身购买继续有效。导入、导出和切换预设不计入每日次数。

OpenCCman 2.2 需要 **iOS／iPadOS 15 或 macOS 12**，可选的「登录时启动」需要 macOS 13 及以上。技术变化与验证边界见 [2.2 发布说明](https://github.com/gewill/OpenCCman/releases/tag/v2.2)（含简体中文段落）和英文 [更新日志](CHANGELOG.md#22---2026-11-01)；之前的 [2.1 发布记录](docs/release/launch-2.1-20261001.md) 仍可查看。

## 开发

日常应用开发以 `develop` 为目标；`main` 承载已发布版本和每周运行的上游同步协调器。只有临时的 `build` 前缀分支会触发 Xcode Cloud 打包。修改发布或构建配置前，先读 [分支规范](docs/BRANCHING.md)、[CI 指南](docs/CI.md) 和 [Xcode Cloud 指南](docs/XCODE_CLOUD.md)。

在装有 Xcode 命令行工具和 Python 3 的 macOS 上，按需运行相关的独立检查：

```sh
bash scripts/check-project.sh
python3 scripts/check-core.py
bash scripts/check-quota.sh
bash scripts/check-whats-new.sh
bash scripts/check-control-labels.sh
bash scripts/check-pasteboard.sh
```

这些检查不能代替 Xcode Cloud 签名构建或设备验收。[自适应工作区验收](docs/validation/adaptive-workspace/README.md)、[性能证据](docs/performance/README.md) 和 [Build 56 记录](docs/validation/build-56/README.md) 说明了已测试的内容和仍未完成的事项。

[2.1 快捷指令动作示例](docs/SHORTCUTS.md) 介绍纯文字自动化及其支持的系统。[移动端大文件说明](docs/IOS_LARGE_FILES.md) 介绍 2.2 在 iPhone／iPad 上的 100 MiB Pro 文件流程及其剩余验证。

[上游同步指南](docs/upstream-sync.md) 说明每周经审查的 SwiftyOpenCC 与 OpenCC 更新流程。引擎相关维护见 [SwiftyOpenCC 仓库](https://github.com/gewill/SwiftyOpenCC/blob/master/docs/upstream-sync.md)。

早期的 [1.3 验收](docs/version-1.3-validation.md)、[项目审计](docs/project-status-and-follow-up-2026-09-13.md) 和 [交接记录](docs/handoff/2026-09-16/README.md) 是带日期的历史记录，不代表当前发布状态。

## 致谢与许可

OpenCCman 基于 BYVoid 的 [OpenCC](https://github.com/BYVoid/OpenCC) 和 ddddxxx 的 [SwiftyOpenCC](https://github.com/ddddxxx/SwiftyOpenCC)，以 [MIT](LICENSE) 协议授权。
