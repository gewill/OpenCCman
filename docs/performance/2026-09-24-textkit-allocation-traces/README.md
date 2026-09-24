# TextKit 2 选区恢复的 Allocations 对照（#68，2026-09-24）

**结论：同机各一份带录制开销的完整应用样本显示两个不同阶段。**`firstRect` 候选在 5／10 MiB 转换结束时比 [#155 现代锚点基线](../2026-09-24-textkit-composed-geometry/README.md) 多约 30／116 MiB RSS；对应的首次滚动前时间窗内，TextKit 段落与位置对象的 *分配事件* 大幅增加，窗口的 persistent 对象数却仍接近基线。10 MiB 文末切为上下布局后，候选留下约 26.6 万个 `NSTextParagraph`、66.4 万个 `NSCountableTextRange` 和 39.8 万个 `NSCountableTextLocation`，基线各只有数百个。**这支持“早期大量临时分配、后期大型留存对象图”的阶段区分，不足以把开销精确归因于 `firstRect` 查询或第二次滚动，更不是泄漏证明。正式应用继续使用 TextKit 1。**

## 来源、采集与可比性

| 条件 | 现代锚点基线 | `firstRect` 候选 |
| --- | --- | --- |
| 来源提交 | `17e6d6b63c0f436f7b3bcc18fc5e5177796156f4` | `be827fc6bbc010d8a1aec7874991c11a6a72c31e` |
| 诊断模式 | `textkit2-modern-anchor` | 同模式，仅私有滚动诊断文件不同 |
| 归档来源 | [#155 元数据](../2026-09-24-textkit-composed-geometry/raw/tk2-anchor/metadata.json) | [#156 候选元数据](../2026-09-24-textkit-selection-candidates/raw/first-rect/metadata.json) |
| trace／应用阶段 | [摘要](baseline/trace-summary.json) · [59 阶段 JSON](baseline/run-01.json) | [摘要](first-rect/trace-summary.json) · [59 阶段 JSON](first-rect/run-01.json) |
| 完整 Allocations Statistics | [原始 XML](baseline/allocations-statistics.xml) | [原始 XML](first-rect/allocations-statistics.xml) |

两个构建的源码哈希、依赖锁、实际 checkout 修订和条件与各自归档元数据逐项核对；10 MiB 输入/输出字节数与 SHA-256 在两次运行中一致。基线构建通过 `scripts/benchmark-app.py` 的 `verify_build`；候选从归档提交重新构建，`source_commit`、源码哈希、依赖和条件与原候选元数据一致。环境为 Apple M4 Pro、macOS 27.0、Xcode/Instruments 27.0；两次测试未交错、未清系统缓存，**各只有一个新进程**，不能当作统计性能结论。

每次仅复制隔离 Release 诊断 App，在**测试副本**签入 `com.apple.security.get-task-allow`，并通过 `codesign --verify --deep --strict`；原构建、正式 App 和发行签名未修改。Apple [公证说明](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)明确要求发行包移除该调试 entitlement。`xctrace` 使用 Allocations 模板，在 Launch Services reopen 握手、开始转换前附加；两次 trace 的目标 PID 均与应用 JSON 一致，目标均 `exit(0)`，应用各记录 59 个完整阶段，转换阶段 `app_active=true`。VM Tracker 轨道存在，但本机命令行 `Regions Map` 导出没有行，尚无 VM 分类归因。

## 进程阶段：录制期间的单次观察

| 指标（MiB，除注明外） | 现代锚点 | `firstRect` 候选 |
| --- | ---: | ---: |
| 1 MiB 转换结束 RSS | 195.8 | 197.3 |
| 5 MiB 转换结束 RSS | 241.8 | 271.8 |
| 10 MiB 转换结束 RSS | 317.6 | 434.1 |
| 10 MiB 转换结束 physical footprint | 251.7 | 261.1 |
| 文末切为上下布局后峰值 RSS | 329.3 | 570.6 |
| 文末切为上下布局后 physical footprint | 255.8 | 275.2 |
| 文末切轴动作耗时（ms） | 17.9 | 3367.4 |

最后一行动作耗时被 Allocations 录制显著放大，**不是用户可见时延**；未录制的三次中位数另见 [#156 报告](../2026-09-24-textkit-selection-candidates/README.md)。本次 10 MiB 转换结束的 RSS 差约 116.5 MiB，同阶段 physical footprint 差约 9.4 MiB；二者不是同一指标，也不能仅从差额判断泄漏或具体保留对象。

## 分配事件从转换阶段开始，持续对象在后期增多

利用应用最终 JSON 的保存时间、末行 elapsed time 和 trace 起止时间估算两者的时间轴；两次 JSON 保存到 trace 结束相隔约 33／46 ms。选择的截止点分别是基线 3.0／4.5 秒、候选 3.5／6.8 秒，均位于对应的 5／10 MiB 转换记录和该文稿首次滚动记录之间；边距与算法写入 [trace 摘要](baseline/trace-summary.json)及[候选摘要](first-rect/trace-summary.json)。这种对齐有保存与退出延迟，**时间窗是近似证据，不是同步采样的瞬时堆快照**。

| 截至阶段的 Allocations 时间窗 | 基线 persistent | 候选 persistent | 基线 events | 候选 events |
| --- | ---: | ---: | ---: | ---: |
| 5 MiB：`NSTextParagraph` | 331 | 331 | 1,123 | 53,759 |
| 5 MiB：`NSCountableTextRange` | 532 | 531 | 17,218 | 174,941 |
| 5 MiB：`NSCountableTextLocation` | 367 | 370 | 42,051 | 337,070 |
| 10 MiB、首次滚动前：`NSTextParagraph` | 331 | 331 | 2,005 | 319,539 |
| 10 MiB、首次滚动前：`NSCountableTextRange` | 532 | 531 | 36,800 | 990,431 |
| 10 MiB、首次滚动前：`NSCountableTextLocation` | 337 | 343 | 91,771 | 1,874,683 |

10 MiB 时间窗的 `All Heap & Anonymous VM` persistent bytes 为基线 115.1 MiB、候选 118.4 MiB，与此阶段约 116.5 MiB 的 RSS 差不成比例；**本次导出的持续分配分类尚不足以解释早期 RSS 差异**。候选源码同时增加可见性查询及有条件的第二次滚动，且转换过程本身也可能触发视口通知；本对照没有分别禁用它们，不能将临时分配归因于其中某一个 API。原始时间窗导出：[基线 5 MiB](baseline/allocations-statistics-after-5MiB-convert.xml)、[候选 5 MiB](first-rect/allocations-statistics-after-5MiB-convert.xml)、[基线 10 MiB](baseline/allocations-statistics-before-10MiB-scroll.xml)、[候选 10 MiB](first-rect/allocations-statistics-before-10MiB-scroll.xml)。

| 全 trace 统计口径的持续对象 | 现代锚点 | `firstRect` 候选 | 候选增加的分类字节 |
| --- | ---: | ---: | ---: |
| `NSTextParagraph` | 387 | 265,621 | 32.38 MiB |
| `NSCountableTextRange` | 593 | 663,666 | 30.35 MiB |
| `NSCountableTextLocation` | 373 | 398,269 | 6.07 MiB |
| `NSTextLayoutFragment` | 397 | 381 | 未增长 |

前三类增加的持续分类字节合计约 68.80 MiB，约占本次 `All Heap & Anonymous VM` 持续字节差 82.14 MiB 的 **84%**；这只是 Allocations 分类口径，不能直接换算为 RSS。`NSCoreTypesetter` 分配事件基线 22,255、候选 831,899，持续对象两者均为 1，也支持存在大量非持续排版工作。未测重复切换后的内存回落、引用链寿命和独立 API 消融，**不称为泄漏或通用 TextKit 2 缺陷**。

## 复核、留存与下一步

运行 `python3 docs/performance/2026-09-24-textkit-allocation-traces/analyze.py` 可从归档 JSON/XML 重算阶段 RSS、各窗口与全 trace 的对象数，并验证导出文件 SHA、PID、退出状态、来源提交、时间窗切点和 10 MiB 输入输出哈希。两份原始 `.trace` bundle 分别约 225／746 MB，留在本机而未加入 Git；各 `trace-summary.json` 保存文件数、总字节数及确定性树哈希。仓库为每个变体保存全部阶段 JSON 和三份 Statistics XML 导出；无法据此替代 raw trace 的调用栈复查。

复现时在上述锁定源码的独立工作树运行 `scripts/benchmark-app.py`；候选还需将 [归档源码快照](../2026-09-24-textkit-selection-candidates/raw/first-rect/ModernWorkspaceScrollKeeper.swift.txt) 放入 `Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift`：

```bash
python3 scripts/benchmark-app.py --output /path/outside/repository --packages /path/to/locked/SourcePackages --reflow --textkit2-modern-anchor --middle-composed --build-only
```

只为**复制出的诊断 App**签入调试 entitlement。按基准驱动的 `-performance-output`、`-performance-reflow`、`-performance-require-textkit2`、`-performance-middle-composed` 参数用 Launch Services 启动进程；在 `process_initialized` 写入后、reopen 事件前，运行 `xcrun xctrace record --template Allocations --attach <PID>`。结束后以 `xcrun xctrace export --xpath '/trace-toc/run/tracks/track[@name="Allocations"]/details/detail[@name="Statistics"]'` 导出，必要时用 Xcode 27 的 `--time-end <毫秒数>ms` 复核窗口。测试副本、来源、PID、签名与输入输出要逐项读回。

下一步在独立私有候选中分别量化可见性查询、锚点滚动、第二次选区滚动及异步回调，再做重复操作与 Instruments 引用链/VM 分析；同时保留 #68 的真实编辑、IME、VoiceOver、iOS 15／macOS 12 和签名包验收。#68 继续开放，正式编辑器不迁移。
