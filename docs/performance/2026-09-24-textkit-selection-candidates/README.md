# TextKit 2 选区恢复的两个未采用候选（#68，2026-09-24）

结论：两个私有候选都让 10 MiB 文中家庭 Emoji 在上下再回左右布局后重新可见，但都重新触发文末切轴的约 0.85 秒等待和约 546 MiB 流程峰值 RSS。**不采用这些候选，不改正式 TextKit 1 编辑器。**本报告保留失败结果，避免把位置正确误当作完整修复。

## 对照条件

以已合并 [PR #155](https://github.com/gewill/OpenCCman/pull/155) 的现代锚点诊断为基线。本轮从其候选提交 `be827fc6bbc010d8a1aec7874991c11a6a72c31e` 建立两个私有 Release 快照。三个变体的源码 SHA-256 清单差异仅为 `ModernWorkspaceScrollKeeper.swift` 及被注入的私有 `WorkspaceScrollKeeper.swift`；其余应用源码、`Package.resolved` 和构建参数相同。`metadata.json` 记录完整来源、依赖锁、机器与工具链；`build-complete.json` 记录二进制哈希。三个变体均用相同的 10 MiB 短段文稿，输入/输出哈希一致。

环境：Apple M4 Pro（`Mac16,7`）、macOS 27.0（26A428）、Xcode 27.0（27A266a），1200×800 pt 英文浅色隔离窗口，ad-hoc 签名。每个候选各跑三个新进程，未交错运行或清系统缓存；六次均 `status=complete`，原文/结果编辑器与模型逐字节一致，诊断始终报告 `NSTextLayoutManager` 存在。正式应用代码未编入候选。

第一个候选在捕获锚点时以插入点的 `firstRect` 判断选区是否可见；第二个候选只查询顶部与底部的现代文本布局片段。两者都在保存的选区仍相同时，先恢复顶部阅读锚点，再有条件地调用第二次 `scrollRangeToVisible`。完整的候选源码快照作为 `.swift.txt` 放在 [raw/](raw/) 下，不会被应用编译。

| 10 MiB 家庭 Emoji 目标，三次新进程 | #155 现代锚点 | `firstRect` 候选 | 可视片段候选 |
| --- | ---: | ---: | ---: |
| 首次文中滚动后可见 | 3/3 | 3/3 | 3/3 |
| 切为上下布局后可见 | 0/3 | 3/3 | 3/3 |
| 切回左右布局后可见 | **0/3** | **3/3** | **3/3** |
| 切回左右后目标相对可视区底缘 Y | −181 pt | 103.3 pt | 103.3 pt |
| 文末 10 MiB 切为上下布局动作中位数 | **14.0 ms** | **852.4 ms** | **862.8 ms** |
| 同流程峰值 RSS 中位数 | **291.5 MiB** | **546.6 MiB** | **545.8 MiB** |

这两个候选共享“在锚点恢复后滚动选区”的步骤，因此额外滚动可能与旧慢路径有关；但本次没有独立剥离几何查询、二次滚动和异步回调的成本，不能据此作精确归因。两者在首次文中滚动时的流程峰值已升到约 412 MiB，而基线约 292 MiB，也说明不能只在文末加一个例外就宣称解决。表中动作耗时包括主队列动作和两轮 display flush，**不是屏幕呈现延迟**；峰值 RSS 包含转换、两编辑器和语料，不是单个选区对象的分配量。

## 原始证据与复核

[raw/first-rect/](raw/first-rect/) 和 [raw/visible-fragments/](raw/visible-fragments/) 各保存候选源码、元数据、构建产物清单、三次完整运行 JSON 和摘要。根目录 [checksums.json](checksums.json) 给出所有归档文件的 SHA-256。对照基线见 [PR #155 的原始样本](../2026-09-24-textkit-composed-geometry/raw/tk2-anchor/)。在三组 `run-*.json` 中检查 `scroll_end_10_2256432`、`layout_end_10_2256432_{vertical,horizontal}` 和 `layout_end_10_4512863_vertical` 即可核对上表。

复跑需从候选源码快照构建私有诊断，而不是编译正式应用。将对应 `.swift.txt` 内容置于 `Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift`，在隔离工作区运行：

```bash
python3 scripts/benchmark-app.py --output /tmp/textkit-selection-candidate --reflow --textkit2-modern-anchor --middle-composed --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/textkit-selection-candidate --reuse-build --reflow --samples 3
```

`--output` 必须是新的仓库外目录，`SourcePackages` 使用锁定修订的独立副本。运行后比较 `metadata.json` 中的源码/依赖与本报告归档，再比较完整状态、哈希与阶段数据。

下一步应分别量化捕获几何、阅读锚点滚动、选区滚动及异步回调所产生的布局片段和分配；同时验证用户主动滚离光标时，不能强迫视图回到光标。没有连续手动滚动、键盘/IME、撤销、VoiceOver、iOS 15、macOS 12 和签名发行包验收。#68 保持开放。
