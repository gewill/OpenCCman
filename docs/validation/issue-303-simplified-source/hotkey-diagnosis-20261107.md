# #303：全局快捷键注册排查

2026-11-07。直接在隔离 QA 进程中截获 `RegisterEventHotKey`：⌥⌘T 和 ⌥⌘R 的系统返回值都为 `noErr`。这排除了本次启动时注册失败的假设，**没有证明按键回调、选文读取或替换成功**；全局快捷键四配置验收仍未完成，#303 保持开放。

## 环境与方法

- 沿用 [11 月 5 日隔离包](mac-entry-acceptance-20261105.md)：源码 `fdb3798843469a7a3af538f17507c232fa36806d`，版本 2.2(30)，Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`。没有重编译、重签名或修改 App 代码。
- 本次重新计算 `OpenCCman.debug.dylib` SHA-256，仍为 `54ae5102382a5a5cc2c3b31592e76ffc6212f58dd67fe189ec9049df9cdeadb1`。该包由 Xcode 27.1 构建；本轮调试器来自 `/Applications/Xcode.app/Contents/Developer`，实际版本 Xcode 27.2（27B52）。主机 macOS 27.2（26B123）。未切换全局 `xcode-select`。
- 用 LLDB 启动该 QA 可执行文件，在系统 `RegisterEventHotKey` 入口停下，读取 arm64 参数寄存器和调用栈；单独执行 `thread step-out` 后读取 `w0`，再继续至下一次注册。
- LLDB 报告构建用 Swift 6.4.0.34.1 与调试器内 Swift 6.4.2.1.9 不匹配。因此只使用原生符号断点、寄存器和调用栈，没有依赖 Swift 表达式求值。
- 前轮临时辅助功能授权已撤销，本次没有重新授权。注册探针不读取其他 App 的文字。

## 观察结果

| 注册 | 键码 `x0` | 修饰键 `x1` | 返回值 `w0` | 结论 |
| --- | --- | --- | --- | --- |
| ⌥⌘T | `0x11`（17） | `0x900`（2304） | `0x0` | 注册成功 |
| ⌥⌘R | `0x0f`（15） | `0x900`（2304） | `0x0` | 注册成功 |

第一处调用栈经过 `CarbonKeyboardShortcuts.register` → `KeyboardShortcuts.onKeyUp` → `GlobalShortcutService.setupKeyboardShortcuts`，确属被测 App 的转换快捷键注册，不是独立探针模拟注册。

随后在 `GlobalShortcutService.swift:108` 的真实转换快捷键回调，以及 `UnregisterEventHotKey` 处保留断点并继续运行。CUA 对 QA 前台窗口发送一次 `alt+super+t`，未观察到回调断点命中或权限提示。该次工具输入不能代表硬件按键，已请求手动按键对照；在取得回调与业务结果前，不判定 App 有缺陷，也不将此次注册成功追溯为 11 月 5 日两次手动尝试成功。

之前“独立进程尝试注册同一组合”的占用探针，在非独占注册的正对照下同样返回成功，不能用于推断 QA 是否注册，已弃用该推断。本轮以真实进程内系统调用返回值代替。

## 复核与未验证范围

1. 用同一隔离包启动 LLDB，设置 `breakpoint set -n RegisterEventHotKey`。
2. 每次命中后执行 `register read x0 x1`、`bt 8`、`thread step-out`，确认停止后执行 `register read w0`；分别记录两次返回值。
3. 设置 `breakpoint set -f GlobalShortcutService.swift -l 108`，继续运行，再从前台窗口手动按 ⌥⌘T，确认是否命中真实回调。
4. 仅在回调可达且另获当次权限授权后，用隔离测试稿验证四种配置的选文读取、转换和替换；逐字节核对宿主最终文本。注册与回调命中均不能替代这一步。

本机最少证据位于仓库外 `~/Library/Application Support/Codex/ui-evidence/OpenCCman/303-hotkey-20261107/registration-lldb.txt`，不是远程可访问附件。本轮为排障记录补充，只做文档核对与 `git diff --check`，未新增 App 构建或运行完整测试。未验证：硬件按键回调、四配置全局替换、正式签名包及最低系统行为。PR 和 CI 状态以远端当前提交为准。
