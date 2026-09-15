# 依赖与生成符号审计（#24，2026-09-15）

## 问题与处理

| 项目 | 依据 | 处理及收益边界 |
| --- | --- | --- |
| SwiftUIOverlayContainer 2.4.1 | App 源码没有 import／直接符号使用；实际 Mac 构建图把它列为 App 的直接依赖并生成两个 target 节点；解析后的其他 Package.swift 无引用 | 删除工程的 package/product/framework 引用和这一项 pin。其余 13 项依赖不漂移。不把删除两个节点换算成未经测量的秒数或内存收益 |
| pinkColor／purpleColor／separator 生成冲突 | 本机 actool 从原始资产生成 5 条 `#warning`；Mac CI 激活其中 3 种，UIKit 另有 purple／separator 冲突 | 关闭 Debug／Release 的可选 Apple 类型符号扩展，保留全部资产及 11 个类型化资源映射。三处原有 `Color.main`／`Color.separator`／`Color.accent` 改为相同资产名称查找 |
| AppIntents metadata extraction skipped | 当前应用没有 AppIntents framework；工具跳过未使用的提取 | 保留提示，不为了消除提示引入无用框架 |
| Swift 6 历史预警 | 本次提取的 Xcode 26.3 Mac 构建日志未出现明确 Swift 6 语言模式诊断 | 本轮不据历史概括迁移语言模式。候选 Mac／iOS 完整构建只有 AppIntents 提取提示，未发现明确 Swift 6 语言模式诊断 |
| Neumorphic 的 Text 拼接弃用 | Xcode 27 本地控件检查曾报告第三方 `NeumorphicStepper` 的 `Text + Text` 弃用 | 属于第三方新 SDK 弃用，不等同 Swift 6 编译错误。本轮不改依赖缓存、不升级包；该控件不是当前应用的调用路径 |

Apple [构建设置参考](https://developer.apple.com/documentation/xcode/build-settings-reference) 将 `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` 定义为在 Apple 框架颜色／图片类型上生成扩展的可选能力，区别于基础资产符号生成。

已有生成代码在冲突处只输出警告，不定义 SwiftUI `Color.pink`／`Color.purple`。应用里的 `.pink`／`.purple` 原本就是系统颜色，本次继续保持；没有改颜色值、资源名称、布局或本地化。原来的 `Color.main`、`Color.separator`、`Color.accent` 来自主应用 bundle 的 `mainColor`／`separator`／`AccentColor`；显式名称查找仍使用同一个主应用 bundle。

## 验证

- [来源](sources.json)：应用基线 `714f6bf`；参考 Mac CI 为 [34943136246](https://github.com/gewill/OpenCCman/actions/runs/34943136246) / `53d1beb`。该 CI 属于独立 UI 候选，不当作本次代码的最终构建。
- [原始警告及构建图节选](baseline-warning-excerpts.log)。重复编译产生多条同类警告，不把行数当成不同缺陷数。
- 本机 Xcode 27 actool 对当前未修改资产实际生成的[扩展开启前](asset-before.swift.txt)／[关闭后](asset-after.swift.txt)输出；[比较](asset-comparison.json)确认 5→0 警告指令、11 项资源名称／bundle 映射相同。资产树未修改。
- 精确解析成功，删除一个 pin 后其余 13 个 pin 与基线逐项完全相同；[工程、Swift 语法和本地化检查](project-check.log)通过。
- `0639218` 的 [PR 完整回归与 Mac universal 构建](https://github.com/gewill/OpenCCman/actions/runs/34947427072)、[手动 iOS arm64 Simulator 构建及回归](https://github.com/gewill/OpenCCman/actions/runs/34947421008) 均成功。两端实际日志只剩 AppIntents 提取提示，颜色冲突消失，Mac 构建图不再包含 SwiftUIOverlayContainer。

## CI 构建

当前 develop 的 App Regression 只跑回归 harness，不能证明删除包后整套应用还能链接。复用待审 #76 中已有的 Xcode 26.3 Mac 构建及手动 iOS artifact 步骤，排除仅属于 #57 的 window-sizing 检查。与后续 UI PR 的相同步骤保持一致，不接入 ci-config、不推送 build 分支或触发 Xcode Cloud。

Mac 完整构建作为 PR 回归步骤；iOS 模拟器构建仅手动打开，输出未签名的测试包。本机 Xcode 27 与 macOS 11 应用 target 的兼容问题继续使用既有 CI 工具链处理，不提高最低系统。

## 完整编译捕获的遗漏

首次候选 `0fa0ee3` 的 iOS 完整编译发现帮助页还引用 `Color.accent`，语法检查无法发现该类型成员缺失。修正为原 `AccentColor` 资产，并从真实生成代码提取全部 11 个成员名扫描三端源码，区分 DispatchQueue／Bundle／枚举／Neumorphic 与生成资源调用。修正后的 `0639218` 已重新通过完整 Mac 和 iOS 构建。

## 真实外观对照与边界

[十二张原始截图及前后表格](https://github.com/gewill/OpenCCman/pull/80#issuecomment-5677341106) 已通过 `gh --attach` 上传。运行环境由当场 `sw_vers` 确认为 macOS 27.0（26A428）；English、默认字号、1920×990 pt，浅深色各覆盖外观／Pro／帮助页。之前沿用旧环境的附件标注已经更正。

前包源码 `6af5ded`，三处页面及全部资产与本 PR 基线 `714f6bf` 的 diff 为空；包含独立窗口 UI 改动，不当作整个应用完全相同的基线。后包源码 `0639218` 来自上述 PR CI，均为 Xcode 26.3 构建，复制后使用独立测试 bundle ID 并 ad-hoc 签名。前后截图保留原始系统阴影，窗口内容均为 3840×1980 像素；画布尺寸差异来自阴影占位。背景及本轮涉及的卡片／链接边框未见颜色变化，不声称整图逐像素一致。

Pro 页面未加载可购买商品，未点击购买／恢复；深色的 AD free／无限图标原本也为低对比黑色，由 #37 继续验收。本轮 iOS 仅完整编译，不伪称新增 iPhone／iPad 运行矩阵；真实交易、最低系统和最终签名产物分别仍由 #14／#16／#15 跟踪。这些边界不扩大 #24 的依赖与警告清理关闭条件。

两份隔离 Mac 测试应用均已退出，测试偏好清理为运行前不存在；没有修改系统主题或开启 VoiceOver。
