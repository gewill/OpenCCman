# #20 Mac 工作区键盘焦点顺序（2026-09-23）

## 问题与修改

macOS 打开「使用键盘导航在控件间移动焦点」后，在左右工作区从 Source 的 Paste Text 按一次 Tab，会越过同栏 Import TXT，跳到 Result 的 Copy Result，再回到 Import TXT。布局由稳定的 `ZStack` 叠放两个 pane，以保留原生编辑器的选区、组合文字和焦点；单纯的 VoiceOver `accessibilitySortPriority` 不规定 Tab 顺序。

对 SourcePane 和 ResultPane 分别应用 SwiftUI `focusSection()`，使顺序导航先访问同一 pane 的可聚焦后代。Apple 的 [focusSection 文档](https://developer.apple.com/documentation/swiftui/view/focussection())明确包含 Tab 键导航。本机 Xcode 27 SDK 标注它从 macOS 13 开始可用；macOS 12 编译走原视图路径，不提高应用的 macOS 12 部署下限，也不宣称已修复旧系统的顺序。iOS 路径保持原行为。

## 可复核来源与条件

- 修复前应用源码：`8984ba17b1f23d149014086bbd4f4d7b3e7f570b`（PR #140 候选；被测视图与合并提交 `d2b76777f3b7db8efd87d05bd818a5c2dfe6356d` 相同）。
- 修改源码：`02dc56de76acea5265cd4cb5f3e0888b961135a3`；两版均用不同 bundle ID、ad-hoc 签名的 Debug 应用运行，不是 App Store 分发包。
- 设备：macOS 27.0（26A428），Xcode 27.0（27A266a），Mac 窗口内容 1024 × 768pt，英文、浅色、默认字号、非 Pro、台湾预设，原文「鼠标里面的硅二极管坏了，导致光标分辨率降低。」；两版输出逐字相同。
- 系统 Keyboard Navigation 测试前为 off（`AppleKeyboardUIMode=0`），临时设为 on，结束后关闭并读回 0；VoiceOver 未开启。测试应用已退出，正式安装应用未操作。隔离 Info.plist 仅在构建产物中禁用 Services 注册；仓库文件未改。

| 从 Paste Text 按一次 Tab | 修复前 | 修改后 |
| --- | --- | --- |
| 聚焦控件 | 右栏 Copy Result | 左栏 Import TXT |
| 后续遍历 | Export TXT → Import TXT → Source | Source → Control-Tab → Copy Result → Export TXT → Result |

修改版在左右和上下布局均观察到同栏优先；Cmd-T 转换成功后结果、原文及结果区焦点保留。源编辑器内普通 Tab 会插入制表符，应使用 Control-Tab 离开，这与现有原生编辑器行为一致。

| 修复前 | 修改后 |
| --- | --- |
| ![修复前焦点](https://github.com/user-attachments/assets/e94809f4-bbfa-4efa-a020-6eba52a3a26f) | ![修复后焦点](https://github.com/user-attachments/assets/bc5a0072-63d4-4954-995f-2304d5e84a04) |
| [Tab 遍历视频](https://github.com/user-attachments/assets/abc85958-0582-4d56-ab1c-1f544ae5bbb5) | [Tab 遍历视频](https://github.com/user-attachments/assets/11d398ee-86f6-4754-ae1e-4d9ae01c8308) |

截图为 ScreenCaptureKit 的实际应用窗口 2048 × 1536px，视频为同窗口 1024 × 768px、H.264，无声音、麦克风或桌面内容。均已在 [#20 评论](https://github.com/gewill/OpenCCman/issues/20#issuecomment-5792941769)通过 `gh --attach` 上传并读回链接。

## 检查与边界

- `bash scripts/check-project.sh` 通过；macOS Debug（部署目标 macOS 12）和通用 iOS Simulator Debug `xcodebuild` 均成功；`git diff --check` 通过。PR 的 App Regression 是合并门禁。
- macOS 12、最终签名分发包、完整 Tab/工具栏/系统面板流程尚未运行。Xcode 编译通过不等于 macOS 12 运行通过。
- 自动化按键输入只得到 ASCII `nihao`，未出现中文输入法候选窗或 marked text；未执行 VoiceOver 真实朗读、完整多语言/大字号矩阵。#20 继续开放，最低系统由 #16 跟踪。

2026-09-24 基于当前 `develop` `f09f6ce` 的[后续运行子集](../issue-20-keyboard-runtime/README.md)补验收了工具栏预设按钮的键盘打开、四项预设与高级选项的 Tab 顺序，以及简体选中时高级项的禁用状态；附同源码两种状态的真实截图和键盘操作录像。VoiceOver 朗读、真实中文 IME 和最终签名包仍未因此完成。
