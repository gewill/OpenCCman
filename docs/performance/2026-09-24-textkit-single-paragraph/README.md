# 单个无换行长段落的编辑器诊断（#68，2026-09-24）

**结论：短段落的 TextKit 2 单次目标候选不能直接扩展为大文稿迁移结论。** 在相同 1 MiB 单段落、相同中部组合字符目标的三个交错新进程中，TextKit 1 与私有 TextKit 2 候选均完成流程，但布局切换都需约 1.5–2.0 秒；候选的中部与文末远端滚动约 0.36 秒，而 TextKit 1 为数毫秒，流程末峰值 RSS 中位数约 643 对 301 MiB。另用 1／5／10 MiB 全流程各试一次，两者都在 5 MiB 首次纵向布局切换期间到达 **120 秒进程上限**，没有进入 10 MiB；最后记录的 RSS 分别约 698 MiB 与 2.19 GiB。这是当前隔离诊断、特定语料和上限的观察，**不能称为泄漏、正式签名包结果或完整 5/10 MiB 成绩**。正式 App 保持 TextKit 1；#68 的迁移门槛未满足。

## 语料与配对条件

新增 `scripts/benchmark-app.py --reflow --single-paragraph`，由私有 `AppPerformanceAudit.fixture(bytes:)` 生成准确字节数的中文、繁体、家庭 Emoji 与组合字符重复单元，**无 CR/LF**。1 MiB 输入 SHA-256 为 `3589430ad438ead1803658c8c0d77d32d30f5694b0b1787ffc512d4e32f8b239`；[分析脚本](analyze.py)从独立 Python 生成相同字节、验证恰为 1 MiB 且无换行，再与实际输入哈希比较。输出哈希在所有配对样本中一致。

`--reflow-max-mib 1` 把运行限制为完整 1 MiB 协议；默认仍跑 1／5／10 MiB。输入类型、最大尺寸和中部目标记录于构建元数据，`--reuse-build` 从元数据恢复参数，不接受新的源码/输入配置。超时后驱动会保留已记录阶段，并写入 `status=timeout`、截止秒数与最后记录阶段；本报告的两份**较早**全流程超时文件来自添加该标记之前的提交，原始 JSON 仍为 `running`，另附人工核对的 `attempt.json` 说明终态，不改写原始记录。

配对构建均来自 `9cf7879`，Apple M4 Pro、macOS 27.0、Xcode 27.0，Release 诊断 App、1200×800 pt 英文浅色窗口、同一锁定依赖与实际 checkout；源码差异仅为私有 TextKit 2 编辑器/锚点注入文件。TextKit 2 使用 [#169 单次目标候选](../2026-09-24-textkit-scroll-ablation/README.md)的原始源码快照。两端均选择**中部组合字符及完整组合范围**，按 TextKit 1、TextKit 2 交错运行三对新进程；未清系统缓存。此前一次 TextKit 1 构建选的是附近普通汉字，已排除在下面的配对表之外。六次均 `status=complete`、21 个阶段、编辑器与模型内容一致；布局阶段分别报告真实的 TextKit 1 / `NSTextLayoutManager`。源、构建、语料、阶段与顺序可用 [analyze.py](analyze.py)复核。

| 1 MiB 单段落，三次新进程中位数（范围） | TextKit 1 | TextKit 2 单次目标候选 |
| --- | ---: | ---: |
| 转换结束 RSS | 283.3（281.8–283.9）MiB | 422.2（338.1–422.6）MiB |
| 整个流程末峰值 RSS | **300.7（299.1–303.8）MiB** | **642.7（596.9–650.1）MiB** |
| 流程末 physical footprint | 324.4（322.3–335.3）MiB | 538.9（536.0–563.3）MiB |
| 中部远端滚动 | **3.6（2.7–6.7）ms** | **357.4（354.4–368.1）ms** |
| 文末远端滚动 | **6.4（1.1–7.3）ms** | **363.2（353.0–365.3）ms** |
| 中部切上下 | 1573（1512–1582）ms | 1861（1845–1902）ms |
| 中部切回左右 | 1853（1827–1858）ms | 1942（1934–1999）ms |

动作计时包括基准驱动触发后的主队列动作和两轮 display flush，**不是最终屏幕呈现时延**。流程末高水位包含此前所有转换与滚动；RSS 与 physical footprint 是不同口径。两端在当前单段落语料的布局切换都已达到秒级，这也是正式发布体验需要单独改善的问题；不能只把它归因为 TextKit 2。

## 5 MiB 上限证据与不能下的结论

[TextKit 1 部分记录](raw/tk1-max10-timeout/run-01.json)及[TextKit 2 部分记录](raw/tk2-max10-timeout/run-01.json)来自各一个较早的完整 1／5／10 MiB 协议尝试，来源提交 `2e6e079`。两者的 1 MiB 阶段完成，5 MiB `reflow_convert_5MiB` 已写出，再进入 `layout_begin_5_0_vertical`，但 **120 秒内没有 `layout_end_5_0_vertical`**。最后记录阶段的 RSS 是 697.7 / 2192.9 MiB，physical footprint 为 472.5 / 1464.7 MiB；这是最后一次采样，不是峰值，也不证明内存泄漏。驱动终止自己的隔离进程并以 `TimeoutExpired` 退出；终态和最后阶段见各自 [TextKit 1 attempt](raw/tk1-max10-timeout/attempt.json)与[TextKit 2 attempt](raw/tk2-max10-timeout/attempt.json)。未触碰正式 App。

5 MiB 转换记录出现在进程约 107.5 / 99.7 秒；其中记录的模型转换时间只有约 0.1 / 1.8 秒。大部分前段耗时位于源稿替换、编辑器长度确认或其连锁布局之间，**现有阶段没有进一步分隔，不能精确归因**。开始 5 MiB 纵向切轴后又超时，说明该动作也未在剩余截止时间内完成；不能从此推定其最终耗时。由于完整协议已在 5 MiB 停止，本次没有 10 MiB 单段落运行数据，也不能据此说 App 的 10 MiB 功能完全不可用。

## 原始文件与后续门槛

[raw/tk1-max1/](raw/tk1-max1/)与[raw/tk2-max1/](raw/tk2-max1/)保存配对的三份完整 JSON、`metadata.json` 和构建哈希；两个 `max10-timeout` 目录保存原始部分 JSON、元数据与外部终态说明。另有一次**故意设置 2 秒上限**的[驱动冒烟记录](raw/timeout-smoke/run-04.json)，验证新版驱动将状态写成 `timeout`、保存 `root_layout_ready` 最后阶段并退出隔离进程；它不计入性能表。[checksums.json](checksums.json)覆盖 19 份原始文件，[run-order.json](run-order.json)保存交错样本的 JSON 写入时间（近似运行结束时间）。运行：

```bash
python3 docs/performance/2026-09-24-textkit-single-paragraph/analyze.py
```

下一步给私有诊断的“替换源稿完成”和“原文编辑器确认完成”分别加时间戳，再对单段落的首次展示、远端滚动与切轴取 Time Profiler/Allocations 栈；明确 TextKit 1 的生产风险和 TextKit 2 候选额外开销。仍须在多种长段长度、组合输入、撤销、用户主动滚动、内存回落、iOS 15／macOS 12 及签名包上验收。#68 保持开放；性能测量不能替代实际界面、键盘与 VoiceOver 验收。
