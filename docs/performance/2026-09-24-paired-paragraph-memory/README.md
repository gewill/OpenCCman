# 1 MiB 单段落 TextKit 1／2 成对内存轨迹（#68，2026-09-24）

**结论：在相同私有 App 源码、语料和采样协议下，旧 `textkit2-modern-anchor` 诊断候选仍明显更占内存，并且本次选区可见性失败；不应迁移正式编辑器。** 这只是一对带 Allocations／VM Tracker 开销的新进程记录，不是 TextKit 2 框架的普遍性能结论，也不是 #169 单目标滚动候选的测试。正式 App 保持 TextKit 1。

## 配对条件

两个隔离 Release 构建都来自提交 `ea76273ff1fe9af61cb685fb5771d8aa0c30d9b1`，锁定相同依赖、Apple M4 Pro、macOS 27.0 和 Xcode 27.0。测试副本的共同改动是在私有 `AppPerformanceAudit` 启动前等待文件闸门；只有 TextKit 2 副本再替换为 `NSTextView(usingTextLayoutManager: true)` 与旧 `ModernWorkspaceScrollKeeper`。两者使用 1200×800 pt 英文浅色窗口、合成 Pro、同一份 **1 MiB 无换行混合中文／Emoji／组合字符**输入、完整组合字符中点目标。输入／输出 SHA-256 和字节数相同，实际布局记录分别证明为 TextKit 1 和 TextKit 2，未把工具选项当作引擎身份。

驱动通过 Launch Services 打开 App，核对自有 PID，发送一次 reopen 使窗口就绪，附加 Allocations、VM Tracker 与 Points of Interest，**确认闸门释放前仅有 `process_initialized` 记录**，再放行工作负载。仅对复制出的 App 加 `get-task-allow`，正式签名未改。两次应用均完整结束、38 个阶段全程前台、trace 正常结束、HID 空闲时间单调增加；目标均为对应的 OpenCCman PID，退出为 `exit(0)`。来源、参数、签名、阶段与目标见各自的[原始归档](raw/)。

| 带采样开销的阶段 | TextKit 1 RSS | TextKit 2 旧候选 RSS |
| --- | ---: | ---: |
| 1 MiB 原文编辑器确认结束 | 226.3 MiB | 296.8 MiB |
| 转换及结果发布诊断任务完成 | 295.7 MiB | 518.3 MiB |
| 中部选区切上下完成 | 361.4 MiB | 646.4 MiB |
| 中部选区切回左右完成 | **361.5 MiB** | **680.0 MiB** |

| trace 结束时的分类 | TextKit 1 | TextKit 2 旧候选 |
| --- | ---: | ---: |
| Allocations `All Heap & Anonymous VM` persistent bytes | 183.7 MiB | 323.6 MiB |
| `CG::DisplayListEntryGlyphs` persistent bytes／对象 | 0.1 MiB／304 | 65.7 MiB／269,165 |
| `CTRun` persistent bytes／对象 | 约 0 MiB／4 | 41.3 MiB／96,772 |
| VM Tracker `Malloc Small` region resident 汇总 | 216.7 MiB | 504.3 MiB |
| 中部选区切上下／切回左右后可见 | 是／是 | **否／否** |

`CG::DisplayListEntryGlyphs`、`CTRun` 与 `Malloc Small` 的差异指向文字显示／排版相关分配，是后续引用链调查的优先线索；**不能把分类字节相加解释 RSS 差值，也不能据此证明泄漏或某一个 API 的因果责任**。Xcode 命令行默认 `Regions Map` 导出没有明确每行快照时点，区域 resident 与应用 `task_info` RSS 的口径不同。Allocations 的 persistent 分类是 trace 截止时的工具口径，不代表进程退出后仍存活。这里没有重复操作后的内存回落或对象引用链。TextKit 2 trace 包约 4.26 GB、TextKit 1 约 0.82 GB，尺寸本身也不能直接推算用户内存。

选区回归仅对本次 **旧 modern-anchor** 成立。[#169](https://github.com/gewill/OpenCCman/pull/169) 在私有单目标滚动候选上有 10 MiB 的 6/6 可见记录，本报告没有重测它，不能反推它也失效。1 MiB 单段落依旧是高度重复的合成边界输入；一个采样进程／变体不足以估计普通文稿的分布或稳定收益。计时同时受 Instruments、UI 刷新和窗口调度影响，不用作未采样交互时延。

首次 TextKit 2 采集虽有完整的前台应用 JSON，`xctrace` 保存约 4.2 GB 包时磁盘耗尽并以 `-6` 退出，**明确排除其 trace**；保留[排除记录](raw/excluded-trace-save.json)。清理该失败包后重新录制，表中 TextKit 2 数据只来自成功重试。有效原始 `.trace`、含环境字段的 TOC 及含映射路径的 VM Regions XML 留在本机；仓库保存完整应用阶段 JSON、Allocations Statistics、signpost、去路径 VM 类型汇总、[23 个归档文件校验和](checksums.json)以及两份 trace 文件树哈希。无原始 trace 时可复算上述归档分类，但不能独立重新导出调用栈、逐行 VM 或对象寿命。

```bash
python3 docs/performance/2026-09-24-paired-paragraph-memory/analyze.py
python3 docs/performance/2026-09-24-paired-paragraph-memory/analyze.py \
  --tk1-trace /private/tmp/openccman-68-paired-trace-tk1/paired-memory.trace \
  --tk2-trace /private/tmp/openccman-68-paired-trace-tk2-retry/paired-memory.trace
```

后续应在 **#169 单目标滚动候选**上重复同样的闸门与内存协议，增加多次新进程、真实 TXT 段落分布、主动滚离光标与编辑／IME 测试，并用 Instruments 引用链／内存回落区别缓存和泄漏。VoiceOver、iOS 15／macOS 12 和签名发行包仍属于 [#68](https://github.com/gewill/OpenCCman/issues/68) 的未完成验收。
