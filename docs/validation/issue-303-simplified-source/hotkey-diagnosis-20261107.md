# #303：全局快捷键注册排查

2026-11-07。快捷键实际注册、手动触发、选文读取和四种配置的转换回写均已验证，输出与独立 OpenCC 1.4.2 CLI 逐字节一致。**原位替换四组均未成功**：运行时断点和系统拒绝日志定位到 App Sandbox 阻止 AX 焦点窗口读取。本记录不将安全回退到 App 的结果算作原位替换通过，#303 保持开放。本轮只补证据，未改 App 代码、签名配置或沙箱限制。

## 环境与方法

- 沿用 [11 月 5 日隔离包](mac-entry-acceptance-20261105.md)：源码 `fdb3798843469a7a3af538f17507c232fa36806d`，版本 2.2(30)，Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`。没有重编译、重签名或修改 App 代码。
- 本次重新计算 `OpenCCman.debug.dylib` SHA-256，仍为 `54ae5102382a5a5cc2c3b31592e76ffc6212f58dd67fe189ec9049df9cdeadb1`。该包由 Xcode 27.1 构建；本轮调试器来自 `/Applications/Xcode.app/Contents/Developer`，实际版本 Xcode 27.2（27B52）。主机 macOS 27.2（26B123）。未切换全局 `xcode-select`。
- 用 LLDB 启动该 QA 可执行文件，在系统 `RegisterEventHotKey` 入口停下，读取 arm64 参数寄存器和调用栈；单独执行 `thread step-out` 后读取 `w0`，再继续至下一次注册。
- LLDB 报告构建用 Swift 6.4.0.34.1 与调试器内 Swift 6.4.2.1.9 不匹配。注册阶段使用原生符号断点、寄存器和调用栈；后续局部变量用 `frame variable` 读取，来源对象的 Bundle ID 用 Objective-C 表达式读取。没有依赖 Swift 表达式求值。
- 注册探针阶段，前轮临时辅助功能授权已撤销，没有重新授权；该探针不读取其他 App 的文字。后续四配置验收另获当次授权及用户身份认证，仅操作隔离 TextEdit 测试稿，结束后已撤销，详见下文。

## 观察结果

| 注册 | 键码 `x0` | 修饰键 `x1` | 返回值 `w0` | 结论 |
| --- | --- | --- | --- | --- |
| ⌥⌘T | `0x11`（17） | `0x900`（2304） | `0x0` | 注册成功 |
| ⌥⌘R | `0x0f`（15） | `0x900`（2304） | `0x0` | 注册成功 |

第一处调用栈经过 `CarbonKeyboardShortcuts.register` → `KeyboardShortcuts.onKeyUp` → `GlobalShortcutService.setupKeyboardShortcuts`，确属被测 App 的转换快捷键注册，不是独立探针模拟注册。

随后在 `GlobalShortcutService.swift:108` 的真实转换快捷键回调，以及 `UnregisterEventHotKey` 处保留断点并继续运行。CUA 对 QA 前台窗口发送一次 `alt+super+t`，未观察到回调断点命中或权限提示。该次工具输入不能代表硬件按键，已请求手动按键对照；在取得回调与业务结果前，不判定 App 有缺陷，也不将此次注册成功追溯为 11 月 5 日两次手动尝试成功。

**手动对照后续：** 用户回复“已按”后，CUA 读取到 QA 的权限提示弹层，正文为 “OpenCCman needs accessibility permission to read selected text from other applications.”，按钮为 “Open System Preferences” 与 “Cancel”。源码 `GlobalShortcutService.performAction` 在读取选文前检查权限，未授权时调用 `requestAccessibilityPermission`。本次结果与该处理路径一致：手动快捷键有响应，当前被撤销的辅助功能权限阻止了后续读取。此时原 LLDB 会话已失效，调试器 PID 已不存在，QA PID 25490 仍运行、父进程为 1，**没有获得断点命中记录，不能将弹层证据写成断点证据**。调试器退出时间和原因未确定，也不追溯解释 11 月 5 日已授权状态下的失败。需重新取得本轮授权后继续隔离测试稿的四配置验收。

之前“独立进程尝试注册同一组合”的占用探针，在非独占注册的正对照下同样返回成功，不能用于推断 QA 是否注册，已弃用该推断。本轮以真实进程内系统调用返回值代替。

## 授权后定位：沙箱阻止焦点窗口读取

用户另行明确授权仅本轮使用辅助功能，并亲自完成系统认证。系统 `OpenCCman303QA` 开关读回 on，QA 的快捷键设置显示 “Accessibility permission granted”、全局快捷键开启、转换组合为 ⌥⌘T。之后从 TextEdit 的隔离稿手动触发，QA 确实读到全文并完成 `t2s` 转换，但 TextEdit 原文及选区保持不变。

附加 LLDB 到同一个 QA 进程，在 `GlobalShortcutService.swift:243` 读取局部变量：`selection = nil`、`verifiedSelection = nil`，复制所得 `text` 是带 CRLF 的完整原文。来源 `NSRunningApplication` 的 Bundle ID 是 `com.apple.TextEdit`。这说明自动替换被选区保护跳过，不是转换失败，也没有执行到粘贴。

进一步对 `ShortcutSelection.capture` 内前三次 `AXUIElementCopyAttributeValue` 的返回地址设置自动继续断点，避免等待人工回复期间暂停 App 改变前台条件。手动再触发一次，读取焦点窗口的断点命中 1 次，`w0 = 0xffff9d8c`，即 `kAXErrorCannotComplete = -25204`；读取焦点元素和选区范围的两个断点均为 0 次。失败发生在 `GlobalShortcutService.swift:48`，早于选区范围读取。

系统 `sandboxd` 日志同时记录：

```text
Sandbox: OpenCCman(25490) deny(1) mach-lookup com.apple.axserver (per-pid)
static ShortcutSelection.capture(in:) + 552 (GlobalShortcutService.swift:48)
GlobalShortcutService.getSelectedText(from:forReplacement:) + 236 (GlobalShortcutService.swift:226)
```

14:50:49（调试器附加前）、14:52:16、14:54:43 三份拒绝记录都指向同一进程和调用点，因此并非只在断点停顿时出现。实际签名 entitlement 含 `com.apple.security.app-sandbox = true`，与仓库配置一致。[Apple DTS 对相同的“已受信任但返回 cannotComplete”现象的解释](https://developer.apple.com/forums/thread/794253)指出，沙箱 App 不支持这类 Accessibility API；授权与沙箱限制是不同层次。结合本机拒绝日志，本次原位替换失败的直接原因已定位为沙箱阻止 AX 焦点窗口读取。

本轮不移除沙箱、不添加未受支持的例外 entitlement，也不跳过选区保护。当前安全回退是把转换结果交给 QA 查看／复制。`help_method1_content` 和 `shortcut_instructions_enabled` 仍承诺自动原位替换，与本次沙箱运行结果不符；应另行确定产品处理方式，不能将配置输出正确写成原位替换验收通过。

## 四配置手动触发结果

同一 QA 进程中，用设置控件依次选择四种配置。TextEdit 打开本轮隔离文件 `OpenCCman-303-hotkey-test.txt`，全文为 `滑鼠裡面的軟體，著衣與衞生紙。` 加 CRLF，共 47 字节。每组均在宿主全选原文，由用户手动按 ⌥⌘T；读取宿主与 QA 界面，再实际点击 QA 的“复制结果”并用 `pbpaste` 读回全文。预期用本机 OpenCC 1.4.2 对该完整短稿重新计算，不依赖旧剪贴板或仅比较截图。

| 配置 | QA 回写与复制读回 | 字节数 | TextEdit 原位替换 |
| --- | --- | --- | --- |
| `t2s` | 滑鼠里面的软体，著衣与衞生纸。 + CRLF | 47，与预期完全一致 | 未成功，原文仍在 |
| `tw2s` | 滑鼠里面的软体，着衣与衞生纸。 + CRLF | 47，与预期完全一致 | 未成功，原文仍在 |
| `tw2sp` | 鼠标里面的软件，着衣与衞生纸。 + CRLF | 47，与预期完全一致 | 未成功，原文仍在 |
| `hk2s` | 滑鼠里面的软体，著衣与卫生纸。 + CRLF | 47，与预期完全一致 | 未成功，原文仍在 |

香港来源时，台湾用词保留为选中但禁用，实际输出仍为 `hk2s`。每组之后宿主 AX 文本与选区保持原文；最后另在 TextEdit 执行全选、复制，读回 47 字节，与输入及原文件完全相同。完整输出哈希和结果字段见 [shortcut-results-20261107.json](shortcut-results-20261107.json)。这四组证明保存配置被全局快捷键转换入口正确读取；结合 [11 月 5 日的十二组](mac-entry-acceptance-20261105.md)，四入口的配置输出均有实际证据，但不代表四入口的全部交互均通过。

本轮未重跑旧记录的编辑器、Services API、大文件矩阵；未新增构建，也未实测冲突快捷键录入弹窗、系统 Services 菜单点击、其他宿主、VoiceOver、最低系统或分发签名包。手动快捷键不用于证明 CUA 自动组合键可用。

## 快捷键冲突与隔离边界

设置页使用 `KeyboardShortcuts.Recorder`。当前锁定版本在录入时检查本 App 主菜单、系统已登记的快捷键和禁止组合；主菜单冲突会拒绝保存，系统占用提示可选“仍然使用”。项目没有追加两项自定义快捷键互相重复的检查，也没有覆盖所有第三方 App 的全局注册。本轮只读源码确认此范围，未逐项实测冲突弹窗。

依赖实际传给 `RegisterEventHotKey` 的 `inOptions` 是 0，即非独占注册。本机 Apple SDK `CarbonEvents.h` 的 `HotKeyOptions`／`RegisterEventHotKey` 注释明确说明：多个 App 可以注册同一组合，非独占注册者可同时收到事件；独占注册者还可能抑制其他注册者的通知，而其他注册仍返回成功。因此不同 Bundle ID 不会隔离全局快捷键，“注册成功”不等于“没有冲突”。

本轮没有完整记录手动触发时所有原版／其他 QA 的全局注册状态，**不能排除它们同时响应**。这不否定本 QA 的输出和沙箱拒绝证据，但不能把本次记录视为互不干扰的全局快捷键验收。收尾时进程清单已无 OpenCCman 或同名 QA 实例。后续应先记录实际运行实例，使用任务独有的 QA 组合，检查可检测冲突并记录／恢复 QA 设置；不擅自关闭其他任务或修改原版设置。

## 收尾

临时辅助功能权限已在系统设置关闭，读回 `OpenCCman303QA` 开关为 off。调试器已 detach 并退出；隔离 TextEdit 文档已关闭，未修改原文件。QA 退出复核期间 CUA 曾重新启动同一 QA 包，随后仅终止该任务包的准确 PID，进程复核确认退出。没有启动或关闭任何模拟器，没有改变其他 App 的权限。

## 复核与未验证范围

1. 用同一隔离包启动 LLDB，设置 `breakpoint set -n RegisterEventHotKey`。
2. 每次命中后执行 `register read x0 x1`、`bt 8`、`thread step-out`，确认停止后执行 `register read w0`；分别记录两次返回值。
3. 从前台隔离测试稿手动按 ⌥⌘T，分别核对 QA 原文／结果与宿主实际文本。需要断点时从当前二进制重新解析地址，不复用本机加载地址。
4. 取得当次权限授权后，按上述四配置矩阵完成实际入口验证，分别记录“转换回写”和“宿主替换”，不相互替代；结束后撤销临时权限。

本机最少证据位于仓库外 `~/Library/Application Support/Codex/ui-evidence/OpenCCman/303-hotkey-20261107/`：`registration-lldb.txt`、`manual-key-observation.json`、`selection-capture-lldb.txt`、`ax-window-return-lldb.txt`、`sandbox-ax-denial.log`，以及四组 `expected-*.txt`、`actual-*.txt`、`host-after.txt` 和结构化结果。这些不是远程可访问附件。本轮只做文档／JSON／本地链接核对与 `git diff --check`，没有新增 App 构建或运行完整测试。PR 与 CI 状态以远端当前提交为准；没有合并、发布或关闭 Issue。
