# TextKit 2 可见字符锚点诊断（#68）

**结论：仍不迁移正式编辑器。** 在本机这组 10 MiB 短段文稿的应用级基准中，使用现代 TextKit API 保存可见字符并在变宽时恢复，可避开[上一轮无锚点候选](../2026-09-23-textkit-app-bridge/README.md)的文末布局对象暴涨。它仍未通过产品验收：TextKit 2 的文中 `scrollRangeToVisible` 在本次基准中连续两次也没有把目标字符带入可视区；选区保护修正了切到文末后旧锚点将视图拉回文中的问题，但没有修正这一现代编辑器导航差异。

## 对照方式与来源

使用 `benchmark-app.py --reflow` 建立三个**私有 Release 快照**：正式 TextKit 1、TextKit 2 不挂旧 glyph 锚点、TextKit 2 加诊断用 `ModernWorkspaceScrollKeeper`。后两者只在快照中以 `NSTextView(usingTextLayoutManager: true)` 替换原生编辑器网络，诊断 keeper 也只被注入私有快照；正式应用源码、构建目标和用户偏好未改变。基线是 `fa1f5a6d38c16058f91497e3f34120f3de7ddbb3`，本 PR 对基准增加了同条件几何检查、至多一次的额外目标滚动，以及现代锚点候选。三个快照的源文件哈希、锁定依赖、构建产物哈希和本机环境见各自的 [metadata](raw/) 与 `build-complete.json`。

环境：Xcode 27.0 / macOS 27.0、同一台 Mac、可见前台 1200×800 pt 窗口、Light / English、独立诊断 bundle 与偏好、相同 1/5/10 MiB 文稿、两编辑器和转换配置。每个变体连续运行三个独立新进程；三个变体的运行没有交错，因此数值只能代表本机诊断，不是总体速度承诺。所有样本 `status=complete`，滚动和布局阶段 `app_active=true`；原文／结果哈希、选区和编辑器身份在布局前后保持一致；现代变体的两编辑器全程保留 `NSTextLayoutManager`，无兼容模式回退。完整 [TK1](raw/tk1/)、[TK2 无锚点](raw/tk2-no-anchor/)和[TK2 现代锚点](raw/tk2-modern-anchor/)逐次 JSON 已归档。

| 10 MiB 短段流程，三轮中位数 | TK1 正式 | TK2 无锚点 | TK2 现代锚点诊断 |
|---|---:|---:|---:|
| 流程峰值 RSS | 381.9 MiB | 550.4 MiB | 293.1 MiB |
| 文中远端定位 | 73.0 ms | 6.8 ms | 5.9 ms |
| 文末切至上下布局 | 12.6 ms | 878.2 ms | 8.6 ms |
| 文末再切回左右布局 | 16.9 ms | 203.3 ms | 10.5 ms |

文末上下动作三轮范围：TK1 12.0–13.2 ms；TK2 无锚点 868.2–894.4 ms；TK2 现代锚点 7.9–10.0 ms。峰值 RSS 是进程高水位，包含两编辑器、转换、文稿和诊断入口，不能解释为单个编辑器的分配量。测量的是主队列动作与两次 display flush，不是屏幕实际呈现或人工输入响应。三个快照的环境、锁定依赖和基准入口相同；源哈希差异仅为私有快照的 `WorkspaceTextEditor.swift`，现代锚点变体另有 `WorkspaceScrollKeeper.swift` 注入。现代锚点改善与定位缺陷并存，不能只根据表中速度推进正式迁移。

## 位置正确性

基准在滚动、切成上下布局和切回左右布局后，用 `firstRect(forCharacterRange:)` 与可视区屏幕矩形检查目标选区。10 MiB 文末：两个 TK2 变体和 TK1 在滚动后均为 3/3 可见；上下布局后均为 0/3 可见；再回左右布局后均为 3/3 可见。缩窄后可视区变矮而保持阅读锚点，光标落出屏幕这一现象不是本候选独有。

10 MiB 文中：TK1 滚动后及返回左右布局后均为 3/3 可见；两个 TK2 变体均为 0/3。对 TK2 目标在首次滚动后不可见时，基准又调用了一次 `scrollRangeToVisible` 并经过两轮 UI flush，仍为 0/3；不能把现代锚点的快速滚动数字解读为导航已经正确。未做连续手动滚动、真实键盘／输入法组合、撤销、焦点、VoiceOver、iOS 编辑器路径和最低 macOS 12 验收。

诊断锚点记录顶部可见字符与保存时的选区；如果用户改变选区再切布局，旧锚点失效，不将视图拉回旧位置。这修复了本轮试验初版在文末变宽时跳回文中的错误。首版用像素偏移直接滚动也产生不可见目标，已移除；当前候选只使用现代 `textLayoutFragment(for:)` 取字符和 `scrollRangeToVisible` 恢复。这个行为仍不足以满足 #68 的滚动位置与交互验收。

## 复现与下一步

```bash
# 使用与 Package.resolved 匹配且干净的 SourcePackages，各变体取新的 /tmp 目录。
python3 scripts/benchmark-app.py --output /tmp/tk1-geometry --reflow --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/tk2-geometry --reflow --textkit2-no-anchor --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/tk2-anchor --reflow --textkit2-modern-anchor --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/tk2-anchor --reuse-build --reflow --samples 3
```

先查清 TK2 在大文稿中部目标字符已定位却不在屏幕内的原因，并验证变宽时顶部阅读位置、光标与输入法状态。之后应对正常段落长度与不同字体／窗口尺寸复测，运行人工交互和辅助功能验收；若证实正确性和资源收益，才考虑生产迁移。Apple 的 [TextKit 2 迁移说明](https://developer.apple.com/videos/play/wwdc2022/10090/)提示旧 `layoutManager` 访问会触发单向兼容，后续验证必须持续检查两编辑器的实际 manager。
