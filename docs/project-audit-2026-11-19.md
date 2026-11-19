# OpenCCman 项目代码审计（2026-11-19）

日期：2026-11-18 至 19。基线：`0fca3a2`（Release OpenCCman 2.3，#346），审计前后工作区干净，审计开始时 `develop` 的内容与它相同。审计期间这个提交被打上 `v2.3` 标签并上架；2026-11-19 读回 App Store Connect，iOS 与 macOS 的 2.3 均为 READY_FOR_SALE。下文的问题因此存在于线上版本。同期合入的 #348 只改了 CHANGELOG、README 和发布记录（`docs/release/launch-2.3-20261119.md`），没有改源码。

本次只做审计，没有修改源码。这是源码审查、针对性回归和独立复现的记录，不把「未发现问题」解释为所有运行环境都没有缺陷。

结论：没有发现会崩溃或损坏用户数据的缺陷。确认 3 个高优先级、4 个中优先级问题，已建 Issue；另有 10 项低优先级问题、3 项卫生问题和 7 项待验证风险只记录在本文。

| # | 问题 | 级别 | Issue |
| --- | --- | --- | --- |
| 1 | 非英语界面下「隐私政策」「在线帮助」链接 404 | 高 | [#349](https://github.com/gewill/OpenCCman/issues/349) |
| 2 | 窗口最小化或应用隐藏时，Services、全局快捷键、状态栏的请求被丢弃 | 高 | [#350](https://github.com/gewill/OpenCCman/issues/350) |
| 3 | 大文件与批量导出到 exFAT、FAT 卷时新建文件必然失败 | 高 | [#351](https://github.com/gewill/OpenCCman/issues/351) |
| 4 | Mac 大文稿每次按键做两次整文比较 | 中 | [#352](https://github.com/gewill/OpenCCman/issues/352) |
| 5 | 必需检查不编译 iOS 目标与分享扩展 | 中 | [#353](https://github.com/gewill/OpenCCman/issues/353) |
| 6 | 「启用全局快捷键」开关重启后恢复为开启 | 中 | [#354](https://github.com/gewill/OpenCCman/issues/354) |
| 7 | iOS 大文件任务中途取消后，「任务已停止」页反复弹出 | 中 | [#355](https://github.com/gewill/OpenCCman/issues/355) |

## 范围与方法

- **范围**：应用与分享扩展的全部 Swift 源码（87 个文件，约 1.3 万行）、工程配置与隐私清单、两个 GitHub Actions 工作流、上游同步脚本和回归检查脚本。
- **方法**：按模块分七路独立审查，再逐条回到源码复核。七路分别是 Mac 文件与流式转换、iOS 大文件、Mac 系统集成、工作区与编辑器、内购与扩展及工程配置、CI 与供应链、已有记录台账。高、中两级都运行了复现；两条初步结论在复核时被推翻，见「未采纳的结论」。
- **去重**：对照审计开始时的 48 个 open Issue、缺陷类的已关闭 Issue、近期 PR 和 `docs/` 下的既有记录。
- **级别**：高指常见场景下功能失效或对外入口失效，Issue 标 P1；中标 P2；低与待验证只记录在本文。
- **环境**：Apple M4 Pro，macOS 27.2.1（26B131），Xcode 27.2（Swift 6.4.2）。CI 使用 Xcode 26.3，本次没有在该环境复跑。

## 已运行的验证

| 项目 | 结果 |
| --- | --- |
| 19 项轻量检查：`CheckScriptChecks.py`、`check-project`、`check-quota`、`check-conversion-diff`、`check-batch-conversion`、`check-pro-access`、`check-workspace`、`check-window-sizing`、`check-window-reopen`、`check-text-action`、`check-whats-new`、`check-launch-transition`、`check-control-labels`、`check-app-language`、`check-iap-locale`、`check-pasteboard`、`check-shortcut-transaction`、`check-editor-scroll`、`check-workspace-editor` | 全部 PASS |
| `python3 scripts/check-core.py`（锁定的 SwiftyOpenCC `f5ba852`） | 21 条 PASS |
| 上游同步协调器单元测试（在仓库外的副本里运行） | 30 项 OK |
| 变异检查：把额度判断的 `<` 改成 `<=` 后重跑 `check-quota`、`check-pro-access`（同样在副本里） | 两者都失败，说明这类检查能发现被测代码出错 |
| 各问题的独立复现 | 见各条「证据」 |

没有运行：完整的 App Regression、完整 App 构建、模拟器、真机、签名包、VoiceOver。

## 高优先级

### 1. 非英语界面下「隐私政策」「在线帮助」链接 404（[#349](https://github.com/gewill/OpenCCman/issues/349)）

- **位置**：[Constants.swift:152](../OpenCCman/Constants.swift#L152)，调用处 [SettingsScene.swift:74](../OpenCCman/Scene/SettingsScene.swift#L74)、[HelpScene.swift:31](../OpenCCman/Scene/HelpScene.swift#L31)。由 `a7834c5`（2026-09-23）引入，v2.0 至 v2.3 都包含。
- **触发条件**：界面语言是简体或繁体；或选「跟随系统」而系统语言不是英语（其他语言回落到繁体）。
- **影响**：链接拼成 `/zh_Hans/…`、`/zh_Hant/…`，网站目录是 `zh-Hans`、`zh-Hant`。主要用户群的隐私政策和帮助都打不开。
- **原因**：`websiteLanguage` 用的是 `identifier`，它返回带下划线的 rawValue；连字符形式在 `languageTag`。
- **证据**：抽出 `LocaleConstants` 编译运行得到下划线路径。2026-11-19 用 curl 实测，`zh_Hans`、`zh_Hant` 的 privacy 与 support 四个地址返回 404，`en`、`zh-Hans`、`zh-Hant` 三组返回 200。
- **验证状态**：已确认，已运行复现。
- **最小修复**：`websiteLanguage` 改用 `languageTag`。已发布的 2.0–2.3 只能靠网站补救，给 `/zh_Hans/*`、`/zh_Hant/*` 加重定向。
- **回归测试**：在 `AppLanguageChecks` 里断言各语言和「跟随系统」解析出的路径段只会是 `en`、`zh-Hans`、`zh-Hant`。
- **与已有记录的关系**：新问题。`docs/handoff/2026-09-22` 记录的是链接仍指向旧博客，改到网站的那次修复引入了这个错误。

### 2. 窗口最小化或应用隐藏时，外部入口的请求被静默丢弃（[#350](https://github.com/gewill/OpenCCman/issues/350)）

- **位置**：[AppDelegate.swift:146](../OpenCCman/AppDelegate.swift#L146)（选窗）、[:158](../OpenCCman/AppDelegate.swift#L158)（投递）、[:169](../OpenCCman/AppDelegate.swift#L169)（就绪登记），[MainWindowReopenController.swift:11](../OpenCCman/Model/MainWindowReopenController.swift#L11)，[MainWindowSizing.swift:128](../OpenCCman/View/MainWindowSizing.swift#L128)。
- **触发条件**：主窗口最小化到 Dock，或应用被 ⌘H 隐藏，然后使用任一外部入口：Services 的打开或转换、快捷键的打开选文或转换回退、状态栏菜单、窗口最小化时的主菜单命令。
- **影响**：
  - 窗口被系统恢复，但文字或命令没有送达，用户看到旧内容。Services 转换的结果仍会写回来源 App。
  - 请求留在内存里，之后新开窗口时才被投递。
  - 重开控制器从此卡住：之后把窗口全部关掉再触发外部入口，不会再开窗，直到用户自己点 Dock。
- **原因**：选窗条件是 `canBecomeMain`，最小化或隐藏的窗口为 false，于是走「重开应用」。系统恢复的是原窗口，而 `registerReadyWindow` 只在窗口首次绑定时调用一次，挂起的通知无人领取，`pendingID` 也不清除。
- **证据**：最小的 SwiftUI `WindowGroup` 宿主，使用真实的 `MainWindowSizing.swift`、`MainWindowReopenController.swift` 和从 `AppDelegate.swift` 逐字抽取的路由方法。

  | 触发外部入口前的状态 | 结果 |
  | --- | --- |
  | 窗口打开 | 送达 |
  | 窗口已关闭（零窗） | 重开出新窗口，送达 |
  | 窗口最小化 | 窗口被恢复；未送达，请求仍挂起 |
  | 应用被隐藏 | 应用取消隐藏；未送达，请求仍挂起 |
  | 最小化丢失一次后关窗，再触发一次 | 没有窗口出现，未送达 |

- **验证状态**：已确认，组件级复现；没有在完整签名 App 里复测。
- **最小修复**：选窗时把已登记的最小化窗口也算进去并先 `deminiaturize`，应用隐藏时先 `unhide`，然后直接投递；重开请求加超时。
- **回归测试**：断言上述状态下通知各送达一次；原生检查覆盖「最小化、隐藏后选窗仍返回该窗口」。
- **与已有记录的关系**：新确认的缺陷，落在 #19 尚未完成的验收范围内（清单里「最小化」未勾选）。CHANGELOG 2.0 写的 "restoring minimized windows" 与实测不符。

### 3. 大文件与批量导出到 exFAT、FAT 卷时新建文件必然失败（[#351](https://github.com/gewill/OpenCCman/issues/351)）

- **位置**：[StreamingTextFileService.swift:245](../OpenCCman/Services/StreamingTextFileService.swift#L245)（`renamex_np` 带 `RENAME_EXCL`），[MacBatchConversionCoordinator.swift:72](../OpenCCman/Services/MacBatchConversionCoordinator.swift#L72)、[:250](../OpenCCman/Services/MacBatchConversionCoordinator.swift#L250)。
- **触发条件**：Pro 用户把大文件另存为新文件名到 exFAT 或 FAT32 卷；或批量输出文件夹在这类卷上。覆盖已有文件不受影响。
- **影响**：整个文件转完后在提交阶段报 "Operation not supported"，没有输出。批量会逐个转完再逐个失败。临时文件会清理，旧目标保留，没有数据损坏。
- **原因**：`RENAME_EXCL` 只在 APFS、HFS+ 上可用，exFAT 与 FAT32 返回 `ENOTSUP`。批量固定走新文件名，`isNameRace` 也不把 `ENOTSUP` 当作可重试的情况。
- **证据**：
  - 用 `hdiutil` 建的 exFAT 与 FAT32 映像上，`VOL_CAP_INT_RENAME_EXCL` 都是不支持，`renamex_np(RENAME_EXCL)` 返回 errno 45，flags 为 0 时成功。
  - 用生产源码原样编译的 `StreamingTextFileService` 在 exFAT 映像上运行：新文件名失败，批量方式失败，覆盖已有文件成功；APFS 对照成功。
  - 两路独立复现，结果一致。
- **验证状态**：已确认，已运行复现（服务层，非沙盒）。SMB、NFS 和沙盒签名包在外接卷上的行为待验证。
- **最小修复**：遇到 `ENOTSUP` 时在同一提交锁内降级，确认目标仍不存在后再 `rename`，期间目标出现就报 `destinationChanged`。至少应在转换开始前用 `volumeSupportsExclusiveRenaming` 判断。
- **回归测试**：给提交函数加可注入的错误钩子断言降级与竞态保护；CI 里用 `hdiutil` 建 exFAT 映像跑单文件和批量各一例。
- **与已有记录的关系**：新问题。`docs/validation/mac-experimental-capacity-2026-10-02/review-fixes.md` 记录过建 exFAT 映像失败、外接卷未复现；#217 是异常中断恢复，不含此项。
- **验证提示**：64 MiB 的写入余量会让可用空间不足约 64 MiB 的小卷直接报空间不足，映像要建得足够大。

## 中优先级

### 4. Mac 大文稿每次按键做两次整文比较（[#352](https://github.com/gewill/OpenCCman/issues/352)）

- **位置**：[HomeViewModel.swift:27](../OpenCCman/Scene/HomeViewModel.swift#L27)，[WorkspaceTextEditor.swift:305](../OpenCCman/View/WorkspaceTextEditor.swift#L305)、[:350](../OpenCCman/View/WorkspaceTextEditor.swift#L350)。
- **触发条件**：在大文稿的源文编辑器里打字。
- **影响**：每次按键在主线程额外耗时，随文稿大小线性增长。

  | 文稿大小 | 每次按键的比较耗时（Apple M4 Pro） |
  | --- | --- |
  | 1 MiB | 约 50–67 ms |
  | 3 MiB | 约 150–205 ms |
  | 10 MiB | 约 0.5–0.7 秒 |

- **原因**：`NSTextView` 返回的字符串桥接自 `NSString`，不是连续 UTF-8。`inputText.didSet` 的 `elementsEqual` 要扫到第一个不同字节；`matchesRenderedBytes` 里注释所说的常数时间路径走不到，退回整文比较。
- **证据**：独立程序在真实 `NSTextView` 里插入一个字，按 `textDidChange` 的顺序分别计时两处比较。两路独立量测结果一致。
- **验证状态**：已确认，独立程序复现同一函数；没有在 App 内量端到端延迟。
- **最小修复**：编辑器自己的回声用版本号跳过字节比较；`didSet` 先比 `utf16.count`。
- **回归测试**：`WorkspaceTextEditorChecks` 加 10 MiB 插入一字的耗时上限。
- **与已有记录的关系**：新问题。#65 与 #18 关注重排和基线，没有覆盖按键耗时。

### 5. 必需检查不编译 iOS 目标与分享扩展（[#353](https://github.com/gewill/OpenCCman/issues/353)）

- **位置**：[app-regression.yml:167](../.github/workflows/app-regression.yml#L167)（只有 macOS Debug 构建），[:235](../.github/workflows/app-regression.yml#L235)（iOS 构建仅手动触发）。
- **影响**：iOS 专用代码和扩展的编译错误可以合入 `develop`、`main`，到 Xcode Cloud 才暴露。应用和扩展里有 25 个 Swift 文件含 iOS 条件编译分支；扩展的 4 个 Swift 文件里只有 `TextActionModel.swift` 会被 `check-core.py` 以 macOS 方式编译。也没有必需检查构建 Release 配置。
- **验证状态**：已确认，读工作流得出。
- **最小修复**：在回归 job 里加一步 iOS Simulator 构建，或把 iOS 构建设为 PR 默认并列为必需。
- **与已有记录的关系**：`docs/CI.md` 只写了没有建立模拟器矩阵，没有说明 iOS 目标不在必需检查里。

### 6. 「启用全局快捷键」开关不持久化（[#354](https://github.com/gewill/OpenCCman/issues/354)）

- **位置**：[GlobalShortcutService.swift:333](../OpenCCman/Services/GlobalShortcutService.swift#L333)，[ShortcutSettingsScene.swift:90](../OpenCCman/Scene/ShortcutSettingsScene.swift#L90)。
- **触发条件**：关闭开关后退出并重启 App。
- **影响**：开关恢复为开启，默认的 ⌥⌘T、⌥⌘R 重新注册为全局快捷键。
- **原因**：`isEnabled` 只是初始值为 true 的内存属性；锁定版本 KeyboardShortcuts 的 `isEnabled` 也不持久化。
- **验证状态**：已确认，代码无歧义。
- **最小修复**：存入 UserDefaults，初始化时应用到 `KeyboardShortcuts.isEnabled`。
- **回归测试**：初始化读取偏好的单元检查。

### 7. iOS 大文件任务中途取消后，「任务已停止」页反复弹出（[#355](https://github.com/gewill/OpenCCman/issues/355)）

- **位置**：[MobileLargeFileCoordinator.swift:167](../OpenCCman/Services/MobileLargeFileCoordinator.swift#L167)、[:215](../OpenCCman/Services/MobileLargeFileCoordinator.swift#L215)、[:276](../OpenCCman/Services/MobileLargeFileCoordinator.swift#L276)，[RootView.swift:109](../OpenCCman/Scene/RootView.swift#L109)、[:261](../OpenCCman/Scene/RootView.swift#L261)。
- **触发条件**：转换中取消或进后台，然后点「完成」关闭任务页。
- **影响**：之后每次回到前台同一页面再次弹出，直到重启或导入新文件；期间 What's New 被抑制。
- **原因**：取消后进入 `.interrupted` 但 `session` 保留；`dismissPresentation()` 只清 owner；场景激活时 `claimPresentation` 因 `session != nil` 再次占用。
- **证据**：用生产源码原样编译协调器与服务并驱动状态机。取消并点完成后，`claimPresentation` 连续三次返回 true；在确认页取消的对照返回 false。视图一侧的触发是读代码得出的。
- **验证状态**：已确认（状态机层）；没有在模拟器或真机上实际操作。
- **最小修复**：`dismissPresentation()` 在 `.interrupted` 时清空 `session` 并回到 `.idle`。
- **回归测试**：`MobileCoordinatorChecks` 加一条断言。

## 低优先级

| 问题 | 位置 | 触发与影响 | 验证状态 | 修复与回归 |
| --- | --- | --- | --- | --- |
| 隐私清单缺 System boot time | [MobileLargeFileCoordinator.swift:326](../OpenCCman/Services/MobileLargeFileCoordinator.swift#L326)，`PrivacyInfo.xcprivacy` | iOS 构建用了 `systemUptime`，清单只声明了磁盘空间、文件时间戳、UserDefaults | 代码已确认；审核后果待验证（2.2、2.3 已过审） | 加原因码 35F9.1；`check-project` 扫到 `systemUptime` 时要求清单含该类别 |
| 评价请求先记「已提示」再判断 | [ReviewHandler.swift:15](../OpenCCman/Helpers/ReviewHandler.swift#L15)，[HomeViewModel.swift:685](../OpenCCman/Scene/HomeViewModel.swift#L685) | 转换后 2 秒内失焦或有弹层时没有弹出，但该版本不再提示 | 代码已确认 | 真正调用系统接口后再回写版本；给延后块加可注入的场景状态做断言 |
| 粘贴和编辑器输入没有 10 MiB 上限 | [WorkspaceComponents.swift:110](../OpenCCman/View/WorkspaceComponents.swift#L110) | 超限文本可进入编辑器，与导入、Shortcuts 的行为不一致 | 代码已确认；内存表现待验证 | 统一检查上限；`CoreChecks` 加 10 MiB 加 1 字节的断言 |
| 移动端清理顺序 | [MobileLargeFileService.swift:441](../OpenCCman/Services/MobileLargeFileService.swift#L441) | 导出成功后删除作业目录中途被杀，下次启动报「无法验证」，需手动删除 | 已确认（代码加目录顺序实验） | 先删 `ready.json`；结果缺失的作业按未完成清理；加 `discard` 路径的探针 |
| 输出文件权限 0600，覆盖时丢失原文件的权限与标签 | [StreamingTextFileService.swift:208](../OpenCCman/Services/StreamingTextFileService.swift#L208) | 其他用户不可读；覆盖已有文件时扩展属性丢失 | 0600 已在 `docs/validation/issue-25-batch-txt` 记录但未处理；覆盖丢元数据为新细节，已复现 | 提交前按 umask 改权限，覆盖时复制原文件元数据 |
| 同步脚本的 workflow 拦截可被非 ASCII 路径绕过 | [sync-upstream.py:291](../scripts/sync-upstream.py#L291) | `git diff --name-only` 给非 ASCII 路径加引号，前缀判断失效 | 已复现 git 输出；GitHub App 没有 Workflows 权限这一兜底未实测 | 加 `-z` 或关闭 `core.quotePath`；协调器测试加一例 |
| 手动诊断会取消同分支的必需检查 | [app-regression.yml:76](../.github/workflows/app-regression.yml#L76) | push 与 `workflow_dispatch` 共用并发组 | 代码已确认 | 并发组加事件名 |
| 测试替身重写了偏好键 | [CoreSupport.swift:12](../Tests/Regression/CoreSupport.swift#L12) | 改持久化键名或默认值不会让 `check-core` 失败 | 代码已确认 | 编译真实的 `UserDefaultsKeys.swift` |
| 导入文件名在手动改写后残留 | [HomeViewModel.swift:25](../OpenCCman/Scene/HomeViewModel.swift#L25) | 来源标签和导出默认名仍是旧文件 | 代码已确认；是否有意待定 | 清空，或写进规格 |
| 分享扩展只处理第一个文本项 | [TextActionInput.swift:10](../OpenCCmanTextAction/TextActionInput.swift#L10) | 多项输入的其余部分被忽略，没有提示 | 代码已确认 | 拼接或提示 |

卫生问题：

- LaunchAtLogin-Modern 的 MIT 署名没有进入应用内的开源列表（源码头和 `docs/licenses` 里有）。
- `OpenCCman/InfoPlist.xcstrings` 残留 `NSAppleEventsUsageDescription`。
- 简繁 `Localizable.strings` 有重复键。`docs/handoff/2026-09-22` 只记录了 `OK`；现在还包括 `Settings`、`Cancel`、`Help`、`Convert`，其中繁体的 `Settings`、`Help` 两个值不同，后一个生效。

## 待验证风险

| 风险 | 位置 | 已有依据 | 还缺什么 |
| --- | --- | --- | --- |
| 恢复剪贴板时丢失「仅本机」属性，且改变 changeCount | [GlobalShortcutService.swift:662](../OpenCCman/Services/GlobalShortcutService.swift#L662) | 恢复用的是普通写入；临时结果已用 `.currentHostOnly`，原内容没有 | 两台设备加密码管理器实测：是否同步到其他设备，自动清除是否失效 |
| 首次授权没有调用系统提示 | [GlobalShortcutService.swift:372](../OpenCCman/Services/GlobalShortcutService.swift#L372) | 只调 `AXIsProcessTrusted()`，未授权时在发送事件前就返回；文案却让用户在列表里找 OpenCCman | 干净的权限状态下实测 App 是否出现在列表里 |
| ⌘C、⌘V 用固定物理键位 | [GlobalShortcutService.swift:247](../OpenCCman/Services/GlobalShortcutService.swift#L247)、[:305](../OpenCCman/Services/GlobalShortcutService.swift#L305) | 虚拟键码是键位而不是字符，Dvorak 等布局下该键位不是 C、V | 在对应布局实测 |
| 外部入口和粘贴按钮无确认替换草稿并清空撤销 | [HomeViewModel.swift:435](../OpenCCman/Scene/HomeViewModel.swift#L435)，[WorkspaceTextEditor.swift:315](../OpenCCman/View/WorkspaceTextEditor.swift#L315) | 行为由代码确定；「清空来源」有确认，这几条没有 | 产品确认是否有意 |
| 文件提供方的源指纹可能误报「源已更改」 | [TextFileService.swift:36](../OpenCCman/Services/TextFileService.swift#L36)，[MobileLargeFileService.swift:249](../OpenCCman/Services/MobileLargeFileService.swift#L249) | 导入时非协调打开，转换时协调读取后按设备号、inode、大小、修改时间全字段比较 | 真机加未下载的 iCloud 文件和第三方提供方，属 #260 范围 |
| 卷挂起时取消和退出会卡住 | [TextFileService.swift:142](../OpenCCman/Services/TextFileService.swift#L142)，[AppDelegate.swift:67](../OpenCCman/AppDelegate.swift#L67) | 阻塞 I/O 不可取消，导入共用串行队列，退出等待没有超时 | 断连的 SMB 卷实测 |
| Release 主菜单里未本地化的 "Test" 菜单 | [AppDelegate.swift:79](../OpenCCman/AppDelegate.swift#L79) | 没有被 `#if DEBUG` 包住 | 运行确认 SwiftUI 重建主菜单时是否会冲掉它 |

## 对照已有记录

**已记录、仍未解决（本文不重复展开）**

- #217：强制终止会残留目标同卷的临时正文。
- #22：Services 在主线程同步处理大文本。
- #15：快捷键的边界，包括慢于 1.5 秒的宿主和读取剪贴板的输入法。
- #29：分享扩展处理 10 MiB 输入的内存余量。
- #260：iPad、文件提供方和内存的真机验收。
- #218、#212：Xcode 27 下的 StoreKit 测试，英国区币种不一致。

**有意限制**

- 取消不会中断已经进入原生 OpenCC 的转换，只保证迟到结果不回写。
- 额度不防改系统时间，`QuotaChecks` 明确只保留当天。
- Services、全局快捷键、Shortcuts 和分享扩展不计额度。

**上次审计（2026-09-12）已修的项**

这次复核了迟到结果回写、额度预留、剪贴板保存恢复和多窗口路由，没有看到回归。

**未采纳的结论**

- 「关窗后复用旧窗口会丢失外部文字」：实测已关闭窗口的 `canBecomeMain` 为 false，不会被选中，走重开路径后正常送达。
- 「批量拖放的文件地址在回调外失效」：`docs/validation/issue-25-batch-txt` 已有沙盒实测通过。

## 测试缺口

- 第 1、2、3、4 条所在的代码没有任何行为级检查：链接生成、`AppDelegate` 窗口路由、非 APFS 卷、大文稿按键耗时。
- `check-storekit.sh` 测的是 Apple 的 StoreKit 测试目录，宿主不含 RevenueCat，不经过 App 的购买代码。
- `check-iap-locale.py`、`check-mobile-file-jobs.py`、`check-streaming-core.py` 没有接入任何工作流。
- 按文件名粗略统计，约 47 个生产源文件没有被任何检查编译，主要是应用入口、设置与购买界面、iOS 专用文件和视图层。
- 没有针对 App 本身的 XCTest 或 UI 测试在 CI 里运行；`Tests/UI/WhatsNewPresentation` 只能手动运行。

## 文档与现状不一致

- 基线时 CHANGELOG 把 2.3 标为 Release candidate、README 仍写 2.2；审计期间合入的 #348 已更新这两处。
- `docs/IOS_LARGE_FILES.md` 仍写移动端两个生产开关保持关闭、移动端拒绝超过 10 MiB 的导入，而 2.2 起 `MobileFileRuntime.productionEnabled` 已为 true。

## 复现材料

复现程序、输出和回归检查日志保存在仓库外：`~/Library/Application Support/Codex/ui-evidence/OpenCCman/project-audit-20261119/0fca3a2/`。这是本机路径，不是远程可见的链接；目录内的 `README.md` 是索引。

| 子目录 | 内容 |
| --- | --- |
| `links` | 各语言隐私与帮助地址的 HTTP 状态 |
| `window-route` | 窗口路由探针的源码与五种状态的报告 |
| `exfat-export` | 排他重命名探针、端到端导出工具及输出 |
| `keystroke` | 按键比较耗时的量测程序与输出 |
| `mobile-interrupted` | 协调器状态机的复现程序与输出 |
| `checks` | 19 项轻量检查与 `check-core` 的日志 |
| `module-notes` | 各模块审查时用到的小程序 |

窗口路由探针运行时会短暂取得前台焦点；它在偏好设置和 LaunchServices 里留下的痕迹已清除，临时磁盘映像已卸载删除。
