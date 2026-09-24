# TextKit 2 选区第二次滚动消融（#68，2026-09-24）

**结论：在当前私有诊断实现中，去掉“恢复阅读锚点后再次滚到选区”的代码块，早期转换 RSS 增量和文末切轴慢路径都消失；但中部选区在切换布局后仍不在视口内，不能采用此消融作为修复。** 它进一步缩小了 [Allocations 阶段取证](../2026-09-24-textkit-allocation-traces/README.md)所见回归的范围，却还没有证明第二次滚动在转换阶段具体被调用了多少次、由哪一次视口通知触发，或解释 RSS 与 physical footprint 的差额。正式应用仍是 TextKit 1。

## 对照方法

本轮使用 [#156 `firstRect` 候选](../2026-09-24-textkit-selection-candidates/README.md)的源码基点 `be827fc6bbc010d8a1aec7874991c11a6a72c31e`、同一锁定依赖、`textkit2-modern-anchor` Release 诊断模式、1／5／10 MiB 相同输入及 1200×800 pt 英文浅色窗口。B 保留 `firstRect` 可见性查询和有条件的选区 `scrollRangeToVisible`；A 只删除 `restore` 中该条件滚动代码块，保留查询、锚点滚动、异步恢复与其余逻辑。两个私有构建的源码哈希仅在诊断源文件及注入的私有应用副本不同；[A 源码](raw/firstrect-no-selection-scroll/ModernWorkspaceScrollKeeper.swift.txt)与[B 源码](raw/firstrect-with-selection-scroll/ModernWorkspaceScrollKeeper.swift.txt)可逐行比对。[分析脚本](analyze.py)强制校验该唯一源文件差异与其他构建条件。

在 Apple M4 Pro、macOS 27.0、Xcode 27.0 上，先运行 A 三个新进程，再运行 B 三个新进程，最后再次运行 A 三个新进程（A–B–A）。未清系统缓存；每次均为完整 59 阶段，应用前台，原文/结果编辑器与模型一致，`NSTextLayoutManager` 在布局阶段存在。10 MiB 输入/输出 SHA-256 和字节数在九次样本中一致。A 的 Release 可执行文件保留 `selectionIsVisible` 符号和 `firstRectForCharacterRange:actualRange:` 调用 stub；这证明代码被编译，**不等同运行时调用次数证据**。两组为 ad-hoc 签名隔离诊断 App，不能代替发行签名或真实编辑验收。

| 单次流程的阶段指标：中位数（范围） | A：查询保留、无第二次选区滚动，n=6 | B：查询＋第二次选区滚动，n=3 |
| --- | ---: | ---: |
| 1 MiB 转换完成 RSS | 163.0（159.4–164.9）MiB | 163.8（162.1–164.4）MiB |
| 5 MiB 转换完成 RSS | **208.7（204.7–210.7）MiB** | **239.2（238.3–241.0）MiB** |
| 10 MiB 转换完成 RSS | **283.2（279.7–285.6）MiB** | **406.5（405.3–407.9）MiB** |
| 10 MiB 转换完成 physical footprint | 219.1（217.5–219.9）MiB | 232.1（230.4–233.1）MiB |
| 文末切为上下布局后流程峰值 RSS | **292.2（291.6–294.5）MiB** | **547.8（544.9–551.7）MiB** |
| 文末切轴动作 | **8.3（8.0–9.1）ms** | **875.2（859.1–899.0）ms** |
| 10 MiB 文中选区，切为上下布局后仍可见 | **0/6** | **3/3** |
| 同一选区切回左右布局后仍可见 | **0/6** | **3/3** |

动作耗时包含主队列的两轮 display flush，**不是屏幕呈现时延**；RSS 高水位包含整个进程此前工作，不能按表格差额解释为选区对象本身内存。A 的 5／10 MiB RSS 与此前 [#155 现代锚点](../2026-09-24-textkit-composed-geometry/README.md)的 207.1／282.1 MiB 三次中位数接近；本轮 B 的结果也与 [#156 已归档候选](../2026-09-24-textkit-selection-candidates/README.md)接近。A–B–A 是时间漂移控制，但样本数仍小，且并未独立测量每次 `firstRect` 或选区滚动的调用栈、调用次数及寿命。结果支持此**候选实现中的第二次选区滚动路径或其连锁布局工作**与回归密切相关，不应扩展为 AppKit API 的普遍性能结论。

## 原始证据与复核

[raw/firstrect-no-selection-scroll/](raw/firstrect-no-selection-scroll/) 保存 A 的六份完整运行 JSON、源码快照、`metadata.json` 与 `build-complete.json`；[raw/firstrect-with-selection-scroll/](raw/firstrect-with-selection-scroll/) 保存 B 的对应三份运行文件与构建来源。[checksums.json](checksums.json)记录全部原始文件 SHA-256，[run-order.json](run-order.json)记录每份运行 JSON 保存时刻，以复核 A–B–A 顺序；保存时刻是近似进程结束时间，不是精确动作时间。运行以下命令可重新校验归档哈希、构建元数据、唯一代码差异、同条件依赖、九次运行状态、文本哈希，并重算表格：

```bash
python3 docs/performance/2026-09-24-textkit-scroll-ablation/analyze.py
```

复跑时，从上述源码提交创建**隔离工作树**，将相应 `.swift.txt` 放入 `Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift`，使用已锁定的独立 `SourcePackages` 目录，分别运行：

```bash
python3 scripts/benchmark-app.py --output /path/outside/repository --reflow --textkit2-modern-anchor --middle-composed --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /path/outside/repository --reuse-build --reflow --samples 3
```

A 的第二批以 `--start-index 4` 运行；每个变体独立输出目录。每次读回 `metadata.json` 的源码哈希、依赖 checkout、测试条件和 `run-*.json` 的输入输出哈希。实验期间没有更改正式应用、部署下限或发行签名。

下一步应给私有诊断增加最小侵入的调用计数/时间戳，分开视口通知、`firstRect` 捕获、锚点滚动、选区滚动与异步恢复，确认早期转换阶段的真实触发顺序；再探索只在确需恢复选区时避免全文布局的策略。仍需重复编辑、IME、VoiceOver、iOS 15／macOS 12、真实键盘、内存回落及签名包验收。#68 继续开放，不能因 A 的内存结果而迁移编辑器。
