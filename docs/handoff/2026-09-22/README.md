# OpenCCman 工作交接 — 2026-09-22

本文件交接 2026-09-20 至 09-22 的工作：应用内语言机制重写与两轮修正、登录时启动收尾、`AGENTS.md` 建立，以及跨项目规范仓库的建立。状态均在 2026-09-22 03:48 UTC 重新查询；标明历史的运行证据未在本次重跑。

## 本轮完成

| 事项 | Issue / PR | 结果 |
| --- | --- | --- |
| 登录时启动 | #119 关闭 | 维护者在 TestFlight 2.0(53)、macOS 27.0 实测重新登录自动启动、关闭后不启动；外部改动需重开设置面板才回显，记为 `SMAppService` 拉取式读取的已知行为。三语／深色证据见 #128。macOS 12 隐藏入口转 #16 |
| 语言改用 `AppleLanguages` | #127 → #128 | `Bundle.main` 自己按选定语言解析，sheet、AppKit 与系统界面自动跟随，不再逐 sheet 注入；旧 `selectedLocale` 键在首次启动迁移（实测）；macOS 重新启动经 `NSWorkspace.openApplication` 真实重开（pid 95202 → 97481） |
| 读取补上参数域 | #131 | #128 只读持久域，漏掉 `-AppleLanguages` 所在的参数域；现先读参数域、再读持久域，不读全局域。`scripts/check-app-language.py` 以带 `-AppleLanguages` 的第二个进程覆盖参数域 |
| iOS 不再调用 `exit` | #132 → #133 | 依据 Apple Technical Q&A QA1561，iOS 改为单按钮信息提示；macOS 保持「稍后／重新启动」。#133 未在 macOS 上运行时复测，依据是该分支逻辑未改动 |
| `AGENTS.md` | #129（develop）、#130（main） | main 上的版本不是副本：main 缺少 `docs/BRANCHING.md` 等文件，改为说明分支分工并用绝对链接指向 develop |

## 跨项目规范

多语言、Xcode Cloud、翻译等跨项目规范的事实来源是内部私有仓库 `dev-standards`（`~/git/dev-standards`，`gewill/dev-standards`），不在本仓库维护副本。本仓库为公开仓库，`AGENTS.md` 只写仓库名、不附链接。

语言规范为 `language_sync_guide.md`。**OpenCCman 已完全符合**，是三个项目中第一个。其余项目的剩余项已在各自仓库建 issue（SecretDiary #8–#11、iperfman #293、dev-standards #1），与本仓库无关。

## 当前状态

| 项目 | 状态 |
| --- | --- |
| `develop` | `09e7fe6`（#133 合并） |
| `main` | `260d963`（#130 合并）；应用代码仍停在 2.0 之前，整合由 #122 跟踪 |
| 开放 PR | 无 |
| 开放 Issue | 29 |
| CI | App Regression 跑在 GitHub 托管的 `macos-15`／`macos-26`，是 `develop` 的必需检查。以 `main` 为目标的 PR 不跑任何检查（#130 实测），即 #122 第 3 项要补的门禁 |
| 自动化 `openccman`（完成 OpenCCman 隐私审核与发布） | `PAUSED`，配置在 `~/.codex/automations/openccman/automation.toml`；2026-09-19 交接时为 ACTIVE |

## 工作区

- **应用主工作区** `/Users/rxwill/git/MyApps/OpenCCman`：`develop`，但 HEAD 停在 `c1efdb5`，远落后于 `origin/develop`；仍有未提交的 `OpenCCman.xcodeproj/project.pbxproj`。不得覆盖、重置或顺带提交。
- **worktree 共 47 个**：44 个所在分支已并入 `develop`，但分支合并不代表目录里没有未提交的本地证据（2026-09-16 交接提过有意保留的证据与人工接力环境），清理前逐个确认；1 个是指向旧 main `fb56ea3` 的 detached worktree；1 个未并入——`codex/macos27-lifecycle-validation`，领先 `develop` 一个提交 `1c6114e fix: restore editor and window introspection on macOS 27`，可能已被 #99 取代，清理前需确认。
- 本轮留在远端、已合并未删的分支 5 个：`codex/language-applelanguages-rewrite`、`codex/docs-agents-pointer`、`codex/docs-agents-main`、`codex/language-argument-domain`、`codex/132-ios-restart-prompt`，按惯例随定期清理处理。

## 未完成

- **#17 隐私与发布资料**，2026-09-19 列出的剩余项未变：最终签名包的隐私报告；2.0 发布时确认新的隐私政策 URL 已生效；应用内「隐私政策」「在线帮助」仍指向旧博客（`OpenCCman/Constants.swift:153`，页面带统计脚本），建议改指 `https://openccman.gewill.org`；2.0 版本说明、商品说明、价格与构建关联。
- **#122 发布主线整合**：`main` 落后 `develop` 整个 2.0，且 `main` 没有必需检查。
- **#14 购买、#16 最低系统、#20 辅助功能与输入法**等遗留验收，逐项读 issue，不因相关 PR 已合并而关闭。
- **未建 issue 的发现**：简繁两份 `Localizable.strings` 里 `"OK"` 各定义了两次（「好的」与「确定」），运行时后一个生效，#133 的截图因此显示「确定」。

## 验证时的注意事项

- 这台 Mac 上的 iperfman CI 用自建 runner，只挑处于 `Shutdown` 的模拟器，不足时约 30 秒即失败。本仓库 CI 不受影响，但在本机跑模拟器测试时会挡住 iperfman 的 CI；跑完关闭自己启动的设备。本轮曾因此让 iperfman CI 失败两次。
- 语言相关的改动，先在基线上跑一次再下结论；单独跑几个用例不足以暴露参数域一类问题。细节见 `dev-standards` 的语言规范。
- 本机 `iPhone 17` 只存在于 iOS 26.5，`name:iPhone 17` 加 `OS:latest` 会解析到更新的 runtime 而失败，需用设备 id 指定。
