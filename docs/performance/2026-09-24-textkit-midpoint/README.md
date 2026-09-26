# TextKit 2 文中目标字符对照（#68，2026-09-24）

**结论：历史的“文中远端导航失败”需要缩小范围。**在同一应用提交、同一 10 MiB 文稿及 TextKit 2 现代锚点诊断实现下，旧基准用 UTF-16 中点选中了家庭 Emoji；三次新进程均未将该目标带进可视区。把目标改为中点后 12 个 UTF-16 单位处的普通汉字，三次均在一次 `scrollRangeToVisible` 后可见。这证明本次失败与目标字符选择有关，**不能证明**是纯粹的测量误判、TextKit 2 的普遍缺陷，或生产编辑器已经可以迁移。正式 App 仍使用 TextKit 1。

## 来源和条件

- 应用基线：`develop` `17ba89080b3493194a39bbff0f7ea2fd53cdda56`。两份隔离 Release 诊断包均注入同一个 `ModernWorkspaceScrollKeeper`，保留同一依赖锁与 1/5/10 MiB 转换、滚动、布局流程；生产工程、依赖缓存和偏好未修改。
- 唯一源码哈希差异为 `Tests/Benchmarks/AppPerformanceAudit.swift` 和 `scripts/benchmark-app.py`：前者将文中目标换成附近的普通汉字，并记录真实目标位置；后者在条件清单标记目标规则。`original/metadata.json` 的源码状态为空；`plain/metadata.json` 记录这两处待提交诊断修改。两组产物哈希和依赖修订分别保存在各自的 `build-complete.json`、`metadata.json`，本目录 `checksums.json` 保护归档文件。
- Apple M4 Pro（`Mac16,7`）、macOS 27.0（26A428）、Xcode 27.0（27A266a）；1200×800 pt 英文浅色前台隔离窗口，ad-hoc 签名；每组分别运行三个新进程，未清空系统文件缓存。所有六次均 `status=complete`，源文/结果 SHA-256 在两组完全一致（输入 `30dd4e4c…`，输出 `324edfbb…`），编辑器均未回退到 TextKit 1。
- 固定语料的 10 MiB 输入 UTF-16 长度为 4,512,865。`count/2 = 2,256,432` 落入 `👨‍👩‍👧‍👦` 的组合字符范围 `2,256,426…2,256,436`；新目标是普通“汉”字，位置 `2,256,444`。这些范围由同一 Swift `NSString.rangeOfComposedCharacterSequence` 与 `range(of:)` 算出。

| 10 MiB 文中目标，三个独立进程 | 原始组合 Emoji | 附近普通汉字 |
| --- | ---: | ---: |
| 目标进入可视区 | 0/3 | 3/3 |
| `scrollRangeToVisible` 调用次数 | 2、2、2 | 1、1、1 |
| 目标相对可视区底缘的 Y | −181 pt，三次一致 | 199.8 pt，三次一致 |
| 滚动动作计时中位数（范围） | 5.87 ms（5.69–7.06） | 12.29 ms（10.52–14.55） |

计时包含主队列操作和两次显示刷新，不是屏幕呈现或实际键盘响应；两组目标字符不同，**不得把计时差解释为优化或回归**。三个普通汉字目标的选区、完整文本哈希和编辑器身份在随后布局切换中保持。文末切为上下布局后光标暂时离开可视区，两组都出现，属于另一个待验收现象。进程峰值 RSS 两组中位数约 293 / 291 MiB，只是流程高水位，不是该目标字符的内存成本。

## 复现

在一个干净的 `17ba890` 工作区运行原始入口，在包含本次诊断改动的工作区运行普通汉字入口。分别使用新的输出目录与已核实锁定修订的 `SourcePackages` 副本：

```bash
python3 scripts/benchmark-app.py --output /tmp/textkit-mid-original --reflow --textkit2-modern-anchor --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/textkit-mid-original --reuse-build --reflow --samples 3

# 在本次 PR 的源码中重复上面两条命令，输出目录另用 /tmp/textkit-mid-plain。
```

`benchmark-app.py --reuse-build` 会复核源码、依赖和应用产物哈希后运行。六个逐次 JSON、两份摘要和各自的来源/构建清单位于 [original/](original/) 与 [plain/](plain/)；每轮的 `scroll_end_10_2256432` 记录可见性，plain 组额外记录 `target_character` 与 `target_kind`。

## 判断边界与下一步

Apple 的 [TextKit 2 迁移说明](https://developer.apple.com/videos/play/wwdc2022/10090/)允许 `NSTextView` 继续使用 `NSRange` 的 `scrollRangeToVisible`，同时要求与 `NSTextLayoutManager` 的 `NSTextRange` 通过内容管理器换算。现有证据只定位到**家庭 Emoji 组合字符目标**与普通字目标的差异，尚未分清是 `scrollRangeToVisible` 本身、`firstRect(forCharacterRange:)` 的单个 UTF-16 单位几何，还是布局估计更新时机。下一轮应对同一 Emoji 记录完整组合范围、目标屏幕矩形及实际画面，并试验有限、可验证的现代 TextKit 布局/滚动步骤；不能以滚到光标替代保留阅读位置。

在此之前不修改生产编辑器。#68 原有的长段/单段、重复滚动、键盘/IME/撤销/VoiceOver、iOS 路径、最低系统与 Instruments 取证仍未完成；诊断包不代表签名发行包。
