# #303：独立 QA 快捷键复验

2026-11-07，macOS 27.2（26B123）。本轮以独立 QA 组合重新执行四种来源配置，转换回写与复制输出全部逐字节通过，**TextEdit 原位替换四组仍未成功**。每次真实触发同时产生本 QA 的沙箱拒绝日志；原版／其他 OpenCCman QA 在本轮触发检查和进程采样中均未运行。#303 保持开放，不将本记录或 PR 合并视为关闭标准达成。

## 产物与隔离

- 从已有 Debug 验收产物复制，源码 `fdb3798843469a7a3af538f17507c232fa36806d`，版本 2.2(30)。未重新编译 App，`OpenCCman.debug.dylib` SHA-256 仍为 `54ae5102382a5a5cc2c3b31592e76ffc6212f58dd67fe189ec9049df9cdeadb1`。
- 新包 `OpenCCman303IsolatedQA.app`，Bundle ID `org.gewill.OpenCCman.ShortcutIsolation20261107`，显示名 `OpenCCman 303 Isolated QA`。仅修改生成产物的身份、Services 名称与端口，并使用仓库原有 sandbox entitlement 重新 ad-hoc 签名；`codesign --verify --strict --all-architectures` 通过。未改仓库 App 代码、entitlement 或原版设置。
- 新 QA 自己的偏好域保存转换 **⌃⌥⇧⌘T**、打开选文 **⌃⌥⇧⌘R**。CUA 鼠标点击录入框只选中文字，未进入录制；用 Tab 进入 `Press Shortcut` 状态后，两组均由工具录入成功，无需用户手动设置。退出后读取该偏好文件，T/R 键码为 17/15，Carbon 修饰位均为 6912（`0x1b00`）。
- LLDB 附加 PID 21290，通过设置页关闭／开启全局快捷键，观察真实 `RegisterEventHotKey` 调用：R/T 均为上述键码及修饰位，step-out 后返回值均为 0。注册成功只证明注册，不代替隔离证据。调试器在业务复验前 detach 并退出。
- CUA 向 TextEdit 发送组合键后，转换回调 `GlobalShortcutService.swift:108` 的两个已解析断点命中次数均为 0。后续原生工具的前台检查还发现，CUA 操作窗口不保证它是系统前台；不能将此前无响应归为 App 缺陷。
- 用户明确授权本轮改用 CGEvent。独立 Swift 工具先核对运行的 OpenCCman App 仅有准确 Bundle ID／路径的本 QA，再将 TextEdit 激活并确认其为系统前台，最后经 HID 事件入口发送指定组合。任一检查不满足即停止，未绕过 App 处理函数或直接调用转换服务。最初实例筛选把 WebKit XPC 也计入，保护检查停止发送；核对它是系统 WebKit 后，将 App 筛选限定为 `.app`，保留下面的独立进程采样。
- 17:28:50.327–17:31:55.620（UTC+8）共 335 次 `ps pid/comm` 采样，设置间隔 0.5 秒，实际最大间隔 0.57531 秒。仅见本 QA 和不注册快捷键的本轮发送工具；每次发送前另核对 NSWorkspace 运行 App 清单。本证据覆盖四次转换和一次打开选文，不能排除短于采样间隔的进程，也不是对所有第三方 App 全局快捷键的普查。

## 实际结果

TextEdit 打开本轮独立 UTF-8 文件，内容为 `滑鼠裡面的軟體，著衣與衞生紙。` 加 CRLF，共 47 字节。通过 QA 设置界面依次选配置，每次全选宿主原文、发送独立转换快捷键，读取两侧界面，再点击 QA 的 Copy Result，用 `pbpaste` 获取真实剪贴板全文，与 OpenCC CLI 1.4.2 独立生成的预期比较。

| 配置 | 触发时间（UTC+8） | QA 输出（另含 CRLF） | 全文比较 | 宿主原位替换 |
| --- | --- | --- | --- | --- |
| `t2s` | 17:28:57 | 滑鼠里面的软体，著衣与衞生纸。 | 47 字节一致 | 未成功 |
| `tw2s` | 17:29:38 | 滑鼠里面的软体，着衣与衞生纸。 | 47 字节一致 | 未成功 |
| `tw2sp` | 17:30:15 | 鼠标里面的软件，着衣与衞生纸。 | 47 字节一致 | 未成功 |
| `hk2s` | 17:30:47 | 滑鼠里面的软体，著衣与卫生纸。 | 47 字节一致 | 未成功 |

香港来源下，先前选中的台湾用词仍显示选中但禁用，实际输出正确采用 `hk2s`。每组宿主 AX 文本和选区均保持原文；四组结束后实际复制 TextEdit 全文，读回 47 字节，与原文及磁盘测试文件完全相同，SHA-256 为 `2e6b1e5a6199275906ebc2bfd5be10164b408181ae188593334fb6f40f667f0a`。这证明宿主未被改写，不证明自动替换成功。

17:31:46 另发送独立打开选文组合 ⌃⌥⇧⌘R：QA 原文为完整测试稿，旧结果清空，Copy Result 禁用，宿主原文与选区不变。本项核对打开选文基本行为，未扩展为它的四配置转换矩阵。

四次转换触发时间对应的 `sandboxd` 日志均包含：

```text
Sandbox: OpenCCman(21290) deny(1) mach-lookup com.apple.axserver (per-pid)
static ShortcutSelection.capture(in:) (GlobalShortcutService.swift:48)
GlobalShortcutService.getSelectedText(from:forReplacement:) (GlobalShortcutService.swift:226)
```

日志签名 ID、容器和可执行路径均指向新 QA。本轮无需断点介入转换过程，就重现了[前轮已定位的 AX 选区读取失败](hotkey-diagnosis-20261107.md)。独立组合与进程隔离后仍失败，不能归因于原版／其他 QA 同时响应；保留安全回退，未移除沙箱或跳过选区保护。现有自动原位替换帮助文案与实际行为的差距仍待处理。

## 收尾、证据及边界

用户当次授权仅限新 QA 与隔离测试稿。系统权限开关和 QA 的 `Accessibility permission granted` 均已读回；结束后新 QA 权限开关读回 off，测试稿关闭、QA 退出、调试器退出、进程监测停止。两组独立快捷键保留在新 QA 的偏好域，原版及其他 QA 的设置／权限未修改。未启动或关闭模拟器。

结构化结果与输出哈希见 [hotkey-isolation-results-20261107.json](hotkey-isolation-results-20261107.json)。原始结果、签名来源、发送工具源码、系统日志及进程 JSONL 保存在仓库外 `~/Library/Application Support/Codex/ui-evidence/OpenCCman/303-hotkey-isolated-20261107/`，未上传媒体。轮询边界已明确，不宣称绝对排除所有第三方快捷键占用。

本次仓库只新增／更新验收文档和结果 JSON；实际检查包括全文字节比较、JSON 解析及字段一致性、本地文档链接、`git diff --check`。只编译了仓库外的输入工具，没有新增 App 构建、本地全量测试或 UI 测试套件。未验证：原位替换成功路径、其他宿主、所有冲突弹窗、Services 菜单、批量入口、真机、最低系统、VoiceOver、分发签名包、购买恢复。PR 当前 HEAD 的 CI 独立核对，未合并、发布或关闭 Issue。
