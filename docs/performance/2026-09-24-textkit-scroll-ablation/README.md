# TextKit 2 选区滚动消融与单次目标候选（#68，2026-09-24）

**结论：当前私有诊断里，连续先滚阅读锚点、再滚选区的路径同时伴随高 RSS 和文末切轴慢路径。** 删除第二次滚动可恢复性能，却让中部选区切轴后不可见。改为“原选区可见时只滚选区，否则只滚阅读锚点”的单次目标候选，在六次新进程中同时得到接近基线的内存/时延与中部选区 6/6 可见。它改变了选区在视口中的相对位置，仍未验证真实编辑、输入法、VoiceOver、长段落和最低系统，**不接入正式 App；正式 App 继续使用 TextKit 1**。

## 对照方法

以 [#156 `firstRect` 候选](../2026-09-24-textkit-selection-candidates/README.md)的源码基点 `be827fc6bbc010d8a1aec7874991c11a6a72c31e`、同一锁定依赖、`textkit2-modern-anchor` Release 诊断模式、1／5／10 MiB 相同输入和 1200×800 pt 英文浅色窗口构建三个**私有**变体：

| 变体 | 锚点捕获与恢复 |
| --- | --- |
| A：无第二次滚动 | 保留 `firstRect` 选区可见性查询；恢复时仅滚到阅读锚点。 |
| B：原候选双目标滚动 | 保留查询；恢复时先滚阅读锚点，若原选区可见，再滚到选区。 |
| C：单次目标滚动 | 保留查询；原选区可见时只滚选区，否则只滚阅读锚点。 |

完整快照：[A](raw/firstrect-no-selection-scroll/ModernWorkspaceScrollKeeper.swift.txt)、[B](raw/firstrect-with-selection-scroll/ModernWorkspaceScrollKeeper.swift.txt)、[C](raw/firstrect-single-target-scroll/ModernWorkspaceScrollKeeper.swift.txt)。[分析脚本](analyze.py)强制校验 A、C 与 B 的差异仅在 `restore` 的目标选择；元数据的其他源码哈希、依赖、实际 checkout 修订及构建条件一致。A 的 Release 可执行文件仍保留 `selectionIsVisible` 符号和 `firstRectForCharacterRange:actualRange:` 调用 stub；这证明代码被编译，**不等同运行时调用次数证据**。

环境为 Apple M4 Pro、macOS 27.0、Xcode 27.0。先运行 A 三个新进程，再运行 B 三个，再运行 A 三个，最后运行 C 六个（A–B–A–C）。未清系统缓存；每次均完成 59 个阶段，应用前台，转换后原文/结果编辑器与模型一致；布局阶段均报告 `NSTextLayoutManager`。各次 1／5／10 MiB 输入和输出的 SHA-256、字节数一致。三个变体均为 ad-hoc 签名的隔离诊断 App，不能代替发行签名或真实编辑验收。

| 单次流程阶段指标：中位数（范围） | A：只滚阅读锚点，n=6 | B：双目标滚动，n=3 | C：单次目标滚动，n=6 |
| --- | ---: | ---: | ---: |
| 1 MiB 转换完成 RSS | 163.0（159.4–164.9）MiB | 163.8（162.1–164.4）MiB | 164.5（159.5–165.8）MiB |
| 5 MiB 转换完成 RSS | 208.7（204.7–210.7）MiB | 239.2（238.3–241.0）MiB | 209.7（207.9–211.2）MiB |
| 10 MiB 转换完成 RSS | 283.2（279.7–285.6）MiB | 406.5（405.3–407.9）MiB | **285.4（278.5–286.2）MiB** |
| 10 MiB 转换完成 physical footprint | 219.1（217.5–219.9）MiB | 232.1（230.4–233.1）MiB | 219.9（217.8–220.3）MiB |
| 文末切为上下布局后流程峰值 RSS | 292.2（291.6–294.5）MiB | 547.8（544.9–551.7）MiB | **294.5（290.6–295.1）MiB** |
| 文末切轴动作 | 8.3（8.0–9.1）ms | 875.2（859.1–899.0）ms | **8.3（7.6–12.8）ms** |
| 1／5／10 MiB 文中选区切上下后仍可见 | 各 0/6 | 各 3/3 | **各 6/6** |
| 同一选区切回左右后仍可见 | 各 0/6 | 各 3/3 | **各 6/6** |

文末阅读时中部选区原本不在屏幕内，C 的文末切轴仍为 0/6 可见，不会强制把阅读位置拉回该选区。动作耗时包含主队列两轮 display flush，**不是屏幕呈现时延**；峰值 RSS 属于整个进程此前工作，不能按表格差额解释为选区对象本身内存。

C 仍有重要的交互差异：10 MiB 文中选区切回左右布局后，选区距可视区底缘的 Y 为 **331.9 pt**，B 为 **103.3 pt**；两者都可见，但阅读位置不同。当前协议未测试用户主动滚离光标、组合输入期间调整布局、长时间编辑或撤销。A–B–A 控制了部分时间漂移，C 在其后单独运行；样本数仍有限，未清缓存，也未独立记录每次 `firstRect`、视口通知或选区滚动的调用次数、栈与对象寿命。结果只支持**当前诊断实现里，双目标滚动路径或其连锁布局工作与回归密切相关**，不能外推为 AppKit API 的普遍性能结论。

## 原始证据与复核

三个 [raw/](raw/) 子目录分别保存完整运行 JSON、源码快照、`metadata.json` 和 `build-complete.json`：[A](raw/firstrect-no-selection-scroll/)、[B](raw/firstrect-with-selection-scroll/)、[C](raw/firstrect-single-target-scroll/)。[checksums.json](checksums.json)记录全部 24 份原始文件 SHA-256；[run-order.json](run-order.json)记录 15 份 JSON 保存时刻，用于复核 A–B–A–C 顺序。保存时刻近似进程结束，不是精确动作时间。运行以下命令可校验原始哈希、构建元数据、两处代码消融、同条件依赖、15 次状态与语料哈希，并重算表格：

```bash
python3 docs/performance/2026-09-24-textkit-scroll-ablation/analyze.py
```

复跑时，从上述源码提交创建**隔离工作树**，将相应 `.swift.txt` 放入 `Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift`，使用锁定的独立 `SourcePackages` 目录；每个变体独立输出目录：

```bash
python3 scripts/benchmark-app.py --output /path/outside/repository --reflow --textkit2-modern-anchor --middle-composed --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /path/outside/repository --reuse-build --reflow --samples 3
```

A 与 C 的第二批分别以 `--start-index 4` 运行。复跑后必须读回 `metadata.json` 源码哈希、依赖 checkout、测试条件和 `run-*.json` 的输入输出哈希。实验期间没有更改正式应用、部署下限或发行签名。

下一步在私有诊断中最小侵入地计数和标记视口通知、`firstRect` 捕获、锚点滚动、选区滚动与异步恢复的时间顺序，再核对 C 是否始终维持用户期望的阅读锚点。#68 仍需覆盖单个无换行长段落、重复操作后的内存回落、真实编辑与 IME、VoiceOver、iOS 15／macOS 12、键盘及签名包。只有这些门槛与设备证据满足后，才考虑正式迁移。
