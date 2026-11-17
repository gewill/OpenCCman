# #27：iOS 原生拼音组合与 iPad 文件导出补验

日期：2026-11-01。#27 保持打开。本轮未发现需要修改 App 的缺陷，只新增本记录；失败／未验范围不追认为通过。

## 合并与运行来源

- #317 HEAD `32d53b4a4868a0af597984266e9b459099da779f` 的需求与规范双路审查均为 0 项未解决问题，无未解决 review thread；[当前 HEAD CI 41262051562](https://github.com/gewill/OpenCCman/actions/runs/41262051562) 的 App Regression 与 App icon 均成功后，Squash 合入 develop 为 `859b41b05aeca486bc3daf812702acddc97a14dd`。
- 本轮分支 `codex/27-ime-ipad-validation` 从该合并提交创建。复用上一轮已双端构建的 iOS Simulator Debug QA App，没有重新构建，也不将其标为合并 SHA 的新构建。`git diff --exit-code 32d53b4 859b41b -- OpenCCman OpenCCman.xcodeproj` 通过；此前 `6abf992` 到 `32d53b4` 的 App 内容一致，构建来源与报告见[上一轮记录](local-export-acceptance.md)。
- 实际安装程序为隔离 Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`；主代码载荷 `OpenCCman.debug.dylib` SHA-256 `efcb18d63df12f8222474c54490a98481d545d29d9c226225df259070b1cb23d` 与上一轮报告一致。iPhone 复用原安装，iPad 安装该构建后又从实际 bundle 核对主文件与相邻 dylib。
- Apple M4 Pro / 48 GiB / macOS 27.2（26B123），进程级 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`，Xcode 27.1（27A9275），devicectl 651.32，AXe 1.8.0。没有切换全局 Xcode，没有修改用户 Mac 输入法。

## iPhone：真实输入法组合与失效

设备：iPhone SE3 / iOS 18.6，375×667 pt，英语、默认字号，UDID `42C71610-575F-482E-A329-7637CD51D10F`。通过模拟器 Settings 的 General → Keyboard → Keyboards 添加系统 Chinese, Simplified – Pinyin（QWERTY）；结束时移除本次新增键盘，恢复原有 English (US) / Emoji。

1. 在 App 使用示例 `鼠标里面的硅二极管坏了，导致光标分辨率降低。`，台湾标准＋台湾词组，真实转换后开启差异，计数为 3 处。
2. 点击原文末尾，Control-Space 切换键盘并通过 Next keyboard 选择简体拼音；AXe HID 输入 `nihao`。这是系统硬件键盘输入路径，候选条真实出现，没有用 `setMarkedText`、绑定赋值或调试器注入文字。
3. 只读 LLDB 捕获原生 UITextView 状态后立即 detach；点击候选“你好”，再次读取状态；最后点击转换与下一处。

| 阶段 | 原生状态与界面结果 |
| --- | --- |
| 正在组合 | 原文是原句＋`ni\u2006hao`，UTF-16 marked range `{22,6}`，selectedRange `{28,0}`；结果清空，出现重新转换提示，AX 树中上一处／下一处按钮消失 |
| 点选候选后 | 原文是原句＋`你好`，marked range 为 nil，selectedRange `{24,0}`；结果继续为空，旧差异没有复活 |
| 重新转换并导航 | 结果为 `滑鼠裡面的矽二極體壞了，導致游標解析度降低。你好`，恢复 3 处，下一处显示 1/3；两侧原生正文 UTF-8 与预期逐字节一致 |

原生状态将 `text` 编码为 base64 后离线比对，并记录 `markedTextRange` 起点／长度与 `selectedRange`；不是用 AX 转义字符串充当字节证明。观测仅在静止阶段读取，录像包含附加调试器的停顿，不用于性能结论。

这证明上述 iOS 18.6 系统拼音／硬件输入路径没有破坏这次组合文字，且旧差异及时失效；不外推触屏逐键输入、其他输入法、iPad/macOS 的实际 IME 或所有 marked-text 路径。

### 整篇分享尝试保留为未通过

同一结果全文 24 个 UTF-16 单元。Cmd+A 没有选中全文，原生选区仍是 `{10,1}`；通过拖动选择手柄，依次观察到 `{17,7}`、最终 `{0,24}`。之后原生编辑菜单未稳定重新显示，未到达整篇 Share → Copy 的最终结果，因此本轮不计整篇分享通过，也没有将失败归因为 App。该尝试的完整原件、选区及最终正文仍保留在本地；之前[高亮词分享通过](local-export-acceptance.md)的范围不变。

## iPad：真实文件保存与读回

设备：iPad A16 / iOS 27.0，820×1180 pt 全屏、左右布局，英语、默认字号，UDID `737A20AC-4B6E-4B43-9C2D-0306F6266B6C`。

使用上一轮同一特殊字符夹具，经模拟器剪贴板准备、App Paste Text → Convert → Show Differences → Next（1/3）→ Export TXT。系统文件提供方的 AX 树只返回背景 App，依据当时实际截图点击 Save；保存至 On My iPad 后返回 App。

直接读回 File Provider Storage 中实际 `OpenCCman-converted.txt`，与预期全文比较：**107 字节，完全一致**；SHA-256 `f76f6f6d21a681b1ad311b8770dcb7a8ea0b96b0380ef65cda4af4737ad2549e`。覆盖 NUL 后内容、CRLF、CR、U+2028/U+2029、Emoji 与组合字符。开头 BOM 已在夹具准备／粘贴边界消失，不作为 BOM 保留测试。保存完成后只读读取两侧 UITextView，原文和结果也与预期字节一致；没有只凭 Save 返回成功判定。

本轮只证明全屏默认字号下 On My iPad 的保存路径；不外推窄窗口／XXXL 的导出面板、iCloud／第三方提供方、iPad 分享或签名包。

## 重跑与证据索引

外部根目录：`~/Library/Application Support/Codex/ui-evidence/OpenCCman/27-ime-acceptance/32d53b4/`。以下是开发机索引，不作为远程附件路径。

- `before-ime.json`、`marked-ui.json`、`committed-ui.json`、`reconverted-ui.json`：界面状态；`marked.png`、`reconverted.png` 与 `ime-flow.mp4`：实际画面及动作。
- `marked-native.json`、`committed-native.json`、`final-native.json` 及同名 `.log`：原生文字、组合范围和选区；`verification.json`：逐字节断言结果。
- `full-selection-native.json`、`full-selection-02-native.json`、`full-share.mp4`：整篇分享未完成的尝试，不能当成功证据。
- `ipad-before-export.json`、`ipad-after-export.json`、`ipad-export.mp4`、`ipad-exported.txt`、`ipad-export-verification.json`、`ipad-final-native.json`：实际保存和全文读回；`ipad-installed-code.json`：实际安装的代码哈希。
- `keyboard-added.json`、`keyboard-restored.json`、`simulators-initial.json`、`simulators-final.json`：准备与收尾。

重跑时使用隔离 QA App 和指定归属的模拟器，先记录工具链、来源与实际代码载荷。重复上述操作；iOS 18.6 的 AXe 点按显式加 `--tap-style physical`。按最新 AX 范围或当前截图取坐标，系统键盘／菜单的可见区域和坐标会改变，不照抄本轮点位。

本轮断言实际输出：`PASS: native Pinyin composition, immediate diff invalidation, candidate commit and reconversion exact text`；`PASS: iPad native source/result unchanged and installed code payload matches tested build`。媒体完整解码通过。纯文档变更仅执行内容／链接／`git diff --check`；未重跑此前已通过的算法、构建或性能矩阵。

两个模拟器均从 Shutdown 由本任务依次启动，完成后停止录制、detach 调试器、终止 QA App，指定 UDID shutdown 后读回确认。没有中断其他模拟器或服务。

## 仍需验收

- 整篇分享、其他文件提供方，以及没有本轮实际证据的布局／字号／输入法组合。
- 真机 VoiceOver 体验、真实设备近上限性能、长期内存／帧时间、iOS 15 / macOS 12 运行、签名分发包。
- PR 合并与本机局部通过均不关闭 #27；容量、默认关闭、快捷键和最低系统保持不变。

远程证据见 [#27 本轮补验评论](https://github.com/gewill/OpenCCman/issues/27#issuecomment-6552076565)。两个录像压缩副本已完整解码，并在隔离本地浏览器播放器从头播放至 ended（46.4 秒／26.466667 秒），检查了实际候选条、结果和保存路径画面；15fps 副本不作为帧时证据。三份附件下载 SHA-256 与本地副本一致，后续 PR 复用链接。

| 附件 | SHA-256 |
| --- | --- |
| [marked.png](https://github.com/user-attachments/assets/b1991c67-1cef-4a34-9549-9986c79e4a2f) | `102b3b2e0afc97dbb5fc9526a5d9ab87269fc0428f3a9aaa4621d1682e95077a` |
| [ime-flow.small.mp4](https://github.com/user-attachments/assets/9e80d8f9-e401-47c7-8f60-3a4a47073770) | `245e30173098b1f02f3d79e51f161cc13e5b3c444db3bc80357b3f94296f0cd5` |
| [ipad-export.small.mp4](https://github.com/user-attachments/assets/f4b1befd-7f7e-48d9-a8e3-a289fd3d3926) | `d8adcfa02cb864215567237c3853f7c27e7d58b3486fb27fd8d66f2735f4157c` |
