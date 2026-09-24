# 5 MiB 单段落的私有 App 内存轨迹（#68，2026-09-24）

**结论：本次 TextKit 1 前台诊断呈现大量与排版同时发生的分配事件，但还不能判断哪些对象是泄漏、哪些内存可回落，也不能据此比较 TextKit 2。** 同一份混合中文／Emoji／组合字符的无换行 5 MiB 输入，在原文确认、结果发布和首次纵向切轴期间分别产生新的分配。最后一个阶段在 180 秒应用上限前未结束。正式 App 仍用 TextKit 1。

## 来源和有效性

使用 [CPU 轨迹报告](../2026-09-24-paragraph-cpu-trace/README.md)相同的私有 Release 构建：源码 `b5c0f270543d73091416efaf6abb49686bf6dece`，相同锁定依赖、输入和输出 SHA-256、1200×800 pt 英文浅色窗口及合成 Pro。只在复制出的诊断 App 加入 `get-task-allow`；原构建和发行签名未改。主机为 Apple M4 Pro、macOS 27.0、Xcode/Instruments 27.0。驱动在自有 PID `43300` 上同时记录 Allocations、VM Tracker 和 Points of Interest，并在 180 秒边界终止自有 App；trace 正常结束。全部 57 个应用阶段记录均为前台，HID 空闲时间从 106.9 秒增加到 302.9 秒。应用在 5 MiB 首次纵向切轴开始后没有完成记录，**不能把最后阶段称为完整耗时或峰值**。

较早一次同协议记录在结果发布阶段失去前台焦点，HID 空闲时间重置，故**从比较中排除**；[排除记录](raw/excluded-run.json)仅保留判定字段。独立五秒探针确认 Allocations/VM 可附加；首个探针因驱动先终止 App 导致附加失败，改为等待 xctrace 结束后重试成功。以上不计为有效重复样本。[运行清单](raw/manifest.json)、[应用阶段](raw/run.json)、[目标摘要](raw/trace-target.json)和[源输入对照校验](analyze.py)记录有效样本身份。

| 有效运行阶段 | RSS | physical footprint | 说明 |
| --- | ---: | ---: | --- |
| 5 MiB 原文编辑器确认开始 | 334.9 MiB | 360.9 MiB | 源稿已交给模型，编辑器确认开始 |
| 原文编辑器确认结束 | 630.0 MiB | 508.1 MiB | 约 50 秒确认／显示刷新后 |
| 转换诊断任务恢复 | 680.4 MiB | 521.2 MiB | 约 50.6 秒 signpost **包含结果发布等待** |
| 首次纵向切轴开始 | 701.0 MiB | 541.8 MiB | 随后仍在排版，进程达到上限 |

这些是带 Allocations 录制的**阶段采样**，并非未采样用户时延、最后阶段峰值或内存稳定值。CPU 报告已表明第二行长 signpost 不能全算作 OpenCC 引擎耗时。

## 分配和 VM 证据

通过原文确认及转换 signpost 双点对齐应用时钟，两次偏移相差不到 5 毫秒；在原文确认开始前、结束后、转换结束后、切轴开始后分别导出 Allocations Statistics。下表是导出窗口**累计事件数**，最后一列为整段 trace，不是每阶段新增对象数：

| 分类 | 原文确认前 | 原文确认后 | 转换结束后 | 切轴开始后 | trace 结束 |
| --- | ---: | ---: | ---: | ---: | ---: |
| All Heap & Anonymous VM | 11,171,093 | 16,464,861 | 22,016,953 | 22,370,289 | 27,345,222 |
| CTRun | 2,349,091 | 3,332,447 | 4,315,796 | 4,315,800 | 5,453,840 |

从切轴开始后到 trace 结束，新增约 **114 万次 CTRun 事件**；和 [#174 的 CPU 栈](../2026-09-24-paragraph-cpu-trace/README.md)一起，支持首次切轴期间仍有大量文字排版工作。整段导出的 `CTRun` 为 215,466 个 persistent 分类对象、约 92.1 MiB；**这不是对象引用链或进程退出后的存活证明**。Xcode 27 对中间 `--time-end` 导出的 `All Heap & Anonymous VM` 给出负的 `count-persistent`，因此报告只比较这些窗口的累计 `count-events`，不把中间窗口当作存活对象快照。[五份 Statistics XML](raw/allocations-statistics.xml)和[复核脚本](analyze.py)保留该异常以供复查。

VM Tracker 的默认 `Regions Map` 导出有 11,406 行；去掉每行地址和文件路径后的[类型汇总](raw/vm-region-types.json)显示 `Malloc Small` resident 470.2 MiB、`Malloc Large` resident 109.9 MiB。命令行导出未明确标出每行对应的快照时点；这个表也包含大量映射文件及共享映像。**各区域 resident 数不可简单相加当作 App RSS**，更不能仅凭类型总量指出泄漏对象。相同输入下的 TextKit 2 成对 trace、重复切换后回落和引用链寿命，本次均未采集。

## 复核边界

仓库保存阶段 JSON、signpost、五份 Statistics XML、去路径后的 VM 类型汇总、[13 个归档文件的 SHA-256](checksums.json)及 [174 个本机 trace 文件的树哈希](raw/trace-tree.json)。原始约 1.64 GB `.trace`、带环境字段的 TOC 和含映射路径的 VM Regions XML **只留本机**。无原始 trace 时可以复算归档数字与时钟对齐，不能重新做对象引用链或 VM 逐行归因。

```bash
python3 docs/performance/2026-09-24-paragraph-memory-trace/analyze.py
python3 docs/performance/2026-09-24-paragraph-memory-trace/analyze.py \
  --local-trace /private/tmp/openccman-68-memory-full-2/paragraph-phases.trace
```

下一步要在同一语料下记录 TextKit 2 私有候选、增加独立新进程重复样本和对象引用链／内存回落，随后用真实 TXT 文稿检验段落长度和组合字符密度的代表性。真实编辑、IME、VoiceOver、iOS 15／macOS 12 与签名发行包仍在 [#68](https://github.com/gewill/OpenCCman/issues/68) 待验收；本报告不改变正式编辑器。
