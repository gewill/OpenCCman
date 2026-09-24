# 5 MiB 单段落的应用主线程 CPU 轨迹（#68，2026-09-24）

**结论：本次带采样开销的私有 App 运行，将三个长等待都定位在文本排版调用链，但入口不同。** 原文编辑器确认和转换结果发布期间，主线程样本几乎全部经过 `NativeWorkspaceTextEditor.updateNSView` → `NSTextView` 替换／`NSLayoutManager`；首次纵向切轴期间，样本主要经过 `NSScrollView`／`NSView` 布局 → `NSTextView` 尺寸调整／`NSLayoutManager`。三段的热点叶函数都是 CoreText `TCombiningEngine::ResolveCombiningMarks`。这比 [#172 的两段 5 秒 `sample`](../2026-09-24-textkit-content-ablation/README.md)覆盖更完整，**仍只适用于这一份高度重复的合成单段落**。正式 App 继续使用 TextKit 1；不能据此认定通用 TextKit 2 缺陷、内存泄漏或迁移收益。

## 来源与采集

从 `develop` 合并提交 `b5c0f270543d73091416efaf6abb49686bf6dece` 构建私有 Release 副本，沿用 #172 的 1／5 MiB 混合单段落、完整组合字符目标、1200×800 pt 英文浅色窗口和合成 Pro；5 MiB 实际输入／输出 SHA-256 与 #172 相同。机器为 Apple M4 Pro、macOS 27.0、Xcode 27.0。源码、依赖 checkout、构建产物哈希和诊断条件见 [`build-metadata.json`](raw/build-metadata.json)及[`build-complete.json`](raw/build-complete.json)。**构建在添加采样驱动前完成**，正式 App 源码和签名未改。

只复制隔离的 App，再为**测试副本**加入 `com.apple.security.get-task-allow` 并 `codesign --verify --deep --strict`。`xctrace` 的 CPU Profiler 与 Points of Interest 绑定私有 PID `33894`，运行上限 190 秒；应用在 reopen 后到 180 秒上限仍停于首次 5 MiB 纵向切轴，驱动确认 PID 属于该复制包后将其终止。trace 与 Launch Services 都正常退出，应用 JSON 保留 57 个阶段，除启动前记录外全程 `app_active=true`；Mac HID 空闲时间从约 698 秒增加到 887 秒。[清单](raw/manifest.json)、[应用阶段](raw/run.json)、[trace 目标摘要](raw/trace-target.json)与[签名权限](raw/debug-entitlements.plist)可核对。独立五秒 attach 探针先验证了权限和清理；探针虽未显式 reopen，窗口已自动进入 1 MiB 流程，**不能称为“无工作负载”的空白采样**。[探针清单](raw/probe-manifest.json)保存了这一点。

| 区间，以 trace signpost／应用阶段对齐 | 主线程 CPU 样本 | 栈含组合字符解析 | 栈含应用编辑器更新 | 观察 |
| --- | ---: | ---: | ---: | --- |
| 5 MiB 原文编辑器确认 | 190,805 | 83.7% | 100.0% | signpost 48.005 秒，`NSTextView` 写入触发排版 |
| 转换请求至诊断任务恢复 | 188,412 | 83.4% | 99.9% | signpost 47.457 秒，结果发布的编辑器更新占热点 |
| 首次 5 MiB 纵向切轴开始后 | 293,644 | 94.0% | 0.0% | 180 秒应用上限前无完成记录，热点在视图重排 |

第二行的 signpost 名为“Model conversion”，**不能解释成 OpenCC 引擎花了 47 秒**：模型的 `isLoading=false` 完成信号在本次约 0.102 秒出现，诊断任务恢复却在约 47.457 秒后；这段时间几乎所有主线程采样栈经过结果编辑器 `updateNSView`。原文确认的代表调用链包括 `NSTextView.replaceCharactersInRange` → `NSLayoutManager` → `NSATSTypesetter` → CoreText；切轴代表调用链包括 `NSView.layoutSubtreeIfNeeded`、`NSScrollView` 尺寸布局、`NSTextView.setFrameSize`、`NSLayoutManager` 和 CoreText。[CPU 摘要与代表栈](raw/cpu-summary.json)含 721,153 条 CPU 记录中的 718,907 条主线程样本及各阶段函数计数。

两种时钟通过原文确认和转换 signpost 分别校准，算得偏移相差约 **0.155 毫秒**，再把应用 `layout_begin_5_0_vertical` 映射到 trace 时间；[signpost 原始导出](raw/signpost-intervals.xml)和[分析脚本](../../../scripts/analyze-paragraph-cpu-trace.py)保留计算过程。三个阶段的“组合字符百分比”是**落在含该函数调用栈的主线程采样比例**，不是墙钟时间比例、自耗时或统计置信区间。CPU Profiler、signpost 与 JSON 写盘都会带来开销；本次单进程运行**不作为 #172 未采样耗时的直接对比样本**。布局区间没有完成事件，不能给出完整切轴耗时。阶段 RSS／physical footprint 也不是峰值或泄漏证据。

## 复核与后续

原始 `.trace` 包约 56.2 MB，CPU XML 导出约 176 MB，**留在本机而未加入 Git**：trace TOC 含运行环境字段，不适合直接公开。仓库只存无环境字段的[目标摘要](raw/trace-target.json)、[CPU 摘要](raw/cpu-summary.json)、signpost 导出、阶段 JSON 和 [trace 文件树 SHA-256](raw/trace-tree.json)。[校验清单](checksums.json)锁定 11 个归档文件；无本机 trace 时只能核对这些派生证据，**不能独立重算全部 CPU 样本**。本机可做更强的文件逐项校验和重新分析：

```bash
python3 docs/performance/2026-09-24-paragraph-cpu-trace/analyze.py \
  --local-trace /private/tmp/openccman-68-cpu-trace-full/paragraph-phases.trace
python3 scripts/analyze-paragraph-cpu-trace.py \
  --run-dir /private/tmp/openccman-68-cpu-trace-full
```

下一步应对同语料、同协议做独立 Allocations／VM 与对象寿命采集，区分短时分配和稳定驻留；再用真实 TXT 的段落长度、Emoji／组合字符密度、CRLF 和重复新进程样本检验普遍性。编辑/IME、VoiceOver、iOS 15／macOS 12 和签名发行包仍在 [#68](https://github.com/gewill/OpenCCman/issues/68) 中待验收。
