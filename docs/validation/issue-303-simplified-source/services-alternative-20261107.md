# #303：服务入口替代方式实测

2026-11-07，macOS 27.2（26B123）。[独立 QA 快捷键复验](hotkey-isolation-20261107.md)确认，App 自己的全局快捷键在 App Sandbox 下无法原位替换。本记录实测**现有** macOS 服务的两种调用方式：TextEdit「服务」菜单，以及给同一服务配置的系统服务快捷键。两种方式都在 TextEdit 原位替换成功，输出与 OpenCC CLI 逐字节一致，⌘Z 能恢复原文；QA 未获辅助功能权限，沙箱保持开启。

服务是已有功能，本记录只验证它的调用方式，**不是全局快捷键原位替换的修复**，不计为该项通过。#303 保持开放。

## 产物与条件

- 沿用独立 QA `OpenCCman303IsolatedQA.app`：Bundle ID `org.gewill.OpenCCman.ShortcutIsolation20261107`，源码 `fdb3798843469a7a3af538f17507c232fa36806d`，Debug 2.2(30)。本轮读回 `OpenCCman.debug.dylib` SHA-256 仍为 `54ae5102382a5a5cc2c3b31592e76ffc6212f58dd67fe189ec9049df9cdeadb1`，`codesign --verify --strict --all-architectures` 通过，entitlement 仍为 app-sandbox、user-selected read-write、network client。未改 App 代码，未重新编译或签名。
- QA 偏好中的配置：目标简体、原文香港标准，即 `hk2s`；先前选中的台湾用词保留但不生效。
- 两轮都未开启 QA 的辅助功能权限：菜单轮结束时 QA 设置显示 `Accessibility permission required`，快捷键轮未改动权限。服务处理函数 `TextConversionService.convertSelectedText`（`OpenCCman/AppDelegate.swift`）只读写服务 pasteboard，不调用 AX。
- 宿主 TextEdit 1.21。测试稿是仓库外的 UTF-8 文件：`滑鼠裡面的軟體，著衣與衞生紙。` 加 CRLF，47 字节，SHA-256 `2e6b1e5a6199275906ebc2bfd5be10164b408181ae188593334fb6f40f667f0a`。预期由 OpenCC 1.4.2 CLI `opencc -c hk2s` 独立生成：`滑鼠里面的软体，著衣与卫生纸。` 加 CRLF，47 字节，SHA-256 `e4e3571697339fdb21e12ff273153a40e12bf1170481e2c51c77fbc411c92843`。

## 服务菜单

17:58（UTC+8）在 TextEdit 全选测试稿，从「服务」菜单选择 `OpenCCman 303 Isolated QA OpenCCman 303 QA Convert`。原文被原位替换；宿主全选复制后读回 47 字节，含 CRLF，与预期一致。随后 ⌘Z 恢复原文，文稿回到未修改状态。

## 服务键盘快捷键

**设置：** 用 `defaults write pbs NSServicesStatus` 给该服务写入 `key_equivalent = "@^~$y"`，即 ⌃⌥⇧⌘Y，执行 `pbs -update` 后新启动 TextEdit。这与「系统设置 › 键盘 › 键盘快捷键 › 服务」写入的是同一偏好项，但本轮没有经过系统设置界面录入。⌃⌥⇧⌘Y 与 QA 自己的全局快捷键 ⌃⌥⇧⌘T／⌃⌥⇧⌘R 不同。

**输入：** 仓库外的 Swift 工具按以下顺序操作。运行实例、原文及前台检查不满足时停止；全选匹配只记录结果，不作为停止条件。本次三轮的全选匹配记录均为 true：

1. 确认运行中的 OpenCCman App 只有本 QA，或者没有。
2. 打开测试稿，读取 AX 全文，确认是原文。
3. 发送 ⌘A，确认选中的是全文。
4. 以 CGEvent HID 事件发送 ⌃⌥⇧⌘Y，不是物理按键。
5. 每 0.1 秒读一次 AX 全文，最多 20 秒；之后发送 ⌘Z 再读回。

| 轮次 | 条件 | 宿主全文 | 发出组合键到读到变化 | ⌘Z |
| --- | --- | --- | --- | --- |
| 冷启动 | QA 未运行，由服务拉起 | 原位替换，与预期逐字节一致 | 0.92 秒 | 恢复原文 |
| 已运行 | 同一 QA 进程 | 原位替换，与预期逐字节一致 | 0.52 秒 | 恢复原文 |
| 对照 | 移除该快捷键，`pbs -update` 后重启 TextEdit | 20 秒内无变化 | — | 原文不变 |

对照说明，替换由服务快捷键触发，不是其他响应同一组合的程序。

「已运行」轮的前两次尝试停在第 2 步：重新打开已打开的测试稿后，立即读到的 AX 全文与原文不符，工具没有发送快捷键；随后单独读取，内容是原文。给第 2 步加上最多 3 秒的轮询后，这一轮通过。两次停止记录都保留在证据中。

## 沙箱日志

用 `/usr/bin/log show` 按 `com.apple.sandbox.reporting` 查询 18:21:30–18:24:30（UTC+8），本 QA 只有 1 条拒绝：

```text
Sandbox: OpenCCman(59948) deny(1) mach-lookup com.apple.universalaccessAuthWarn
GlobalShortcutService.checkAccessibilityPermission() (GlobalShortcutService.swift:131)
GlobalShortcutService.init() (GlobalShortcutService.swift:102)
AppDelegate.applicationDidFinishLaunching(_:) (AppDelegate.swift:53)
```

这条记录在 18:22:17.948，发生在冷启动初始化阶段：`checkAccessibilityPermission()` 调用 `AXIsProcessTrusted()` 时，系统框架内部的查找被拒。它不在服务转换路径上。三轮内没有 `com.apple.axserver` 拒绝。

同一查询对复验记录中 17:28:50–17:31:56 的时段做正对照，取回了 4 条 axserver 拒绝，说明查询有效。启动时这条拒绝是否每次出现、是否影响权限状态判断，本轮没有单独核对。

## 与全局快捷键的关系

- 服务入口由系统把选中文字交给服务 pasteboard，再由宿主写回结果。OpenCCman 不需要读取其他 App 的 AX 信息，也不需要辅助功能权限，所以不受沙箱的 AX 限制。权限未开启、没有 axserver 拒绝，与这一点一致。
- 和 App 自己的全局快捷键相比，有三点不同：
  - 用户要自己在系统设置里给服务配置组合键。
  - 仓库 `Info.plist` 的 NSServices 目前没有 `NSKeyEquivalent` 默认建议。
  - 只适用于支持服务的宿主 App。
- 全局快捷键原位替换仍记为未通过。帮助文案中自动原位替换的承诺仍待处理。

## 收尾、证据与边界

TextEdit 与 QA 已退出。测试前用 `defaults export pbs` 备份 Services 设置；结束后从备份导入并执行 `pbs -update`，导出结果与备份一致，磁盘上的 `pbs.plist` 中也没有本 QA 的条目。测试稿是仓库外副本，结束时哈希与原文一致。原版和其他 QA 的设置、权限均未修改；未启动或关闭模拟器。

结构化结果见 [services-alternative-results-20261107.json](services-alternative-results-20261107.json)。快捷键轮的原始输出、工具源码和沙箱日志保存在仓库外 `~/Library/Application Support/Codex/ui-evidence/OpenCCman/303-services-shortcut-20261107/`，菜单轮的证据在同级目录 `303-services-alternative-20261107/`；未上传媒体。

**未验证：**
- 通过系统设置界面手动录入服务快捷键，以及 `NSKeyEquivalent` 默认建议。
- `t2s`／`tw2s`／`tw2sp` 在服务快捷键下的运行，以及打开选文服务。
- 其他宿主，例如 Electron、浏览器网页输入框、终端。
- 快捷键冲突，以及物理按键。
- 分发签名包，以及 App Review。

本次仓库只新增或更新验收文档和结果 JSON。检查包括全文哈希、JSON 解析、本地文档链接和 `git diff --check`；没有新增 App 构建、本地全量测试或 UI 测试套件。
