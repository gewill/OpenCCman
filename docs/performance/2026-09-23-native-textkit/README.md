# 原生 NSTextView 的 TextKit 1／2 大文稿对照（#68）

本次只比较**隔离的一个原生 AppKit 编辑器**。Xcode 27.0（27A266a）、macOS 27.0（26A428）、Apple M4 Pro / 48 GiB，同机新进程交错运行；`swiftc -O` 编译目标为 `arm64-apple-macos12.0`。这证明当前系统上的构建和运行，不证明 macOS 12 真机运行。没有改动正式应用、编辑器桥接或 TextKit 选择。

入口：[NativeTextKitMemory.swift](../../../Tests/Benchmarks/NativeTextKitMemory.swift)、[measure-native-textkit.py](../../../scripts/measure-native-textkit.py)。每次构建一个 1200×800 pt 的可见窗口，在单个 `NSTextView` 中设置文本，刷新两轮布局和显示；定位段首、中部、文末，调用 `scrollRangeToVisible` 并用 `firstRect` 核实目标字位于视口内。记录动作耗时、阶段 RSS、physical footprint、完整 UTF-16 长度及 `NSTextLayoutManager`／回退通知状态。每类 1／5／10 MiB 各运行三个新进程，次序为尺寸、样本、TextKit 1、TextKit 2。短段落含 CRLF 空行；长段落每行约 180 次文字模式；单段没有换行。文字均含中文、家庭 Emoji、组合字符。精确语料生成式和 SHA-256 见脚本及各组 [raw](raw/) metadata。**动作耗时不是屏幕像素呈现时间；阶段 RSS 不是整个进程的瞬时峰值。**

| 输入 | MiB | TextKit 1 首显 / 中部滚动 / 文末滚动 | TextKit 2 首显 / 中部滚动 / 文末滚动 | 末阶段 RSS，TK1 / TK2 |
|---|---:|---:|---:|---:|
| 短段落 | 1 | 45.5 / 225.3 / 207.1 ms | 28.8 / 30.4 / 24.4 ms | 115.9 / 113.9 MiB |
| 短段落 | 5 | 45.5 / 1062.2 / 1011.2 ms | 31.3 / 29.0 / 24.4 ms | 216.6 / 126.4 MiB |
| 短段落 | 10 | 48.4 / 2117.6 / 2036.8 ms | 34.6 / 29.3 / 24.9 ms | 338.3 / 141.3 MiB |
| 长段落 | 1 | 56.1 / 201.3 / 84.8 ms | 48.9 / 34.9 / 25.0 ms | 114.8 / 114.2 MiB |
| 长段落 | 5 | 58.5 / 1249.9 / 324.6 ms | 49.4 / 35.2 / 26.9 ms | 209.5 / 127.5 MiB |
| 长段落 | 10 | 60.8 / 2606.6 / 616.3 ms | 53.2 / 35.1 / 26.6 ms | 319.4 / 142.0 MiB |
| 无换行单段 | 1 | 1114.7 / 33.9 / 22.3 ms | 1159.0 / 331.5 / 315.9 ms | 182.8 / 309.4 MiB |
| 无换行单段 | 5 | 53060.3 / 78.5 / 22.3 ms | 50892.8 / 1984.4 / 1894.0 ms | 517.2 / 1185.2 MiB |

表中为三次**完整运行**的中位数；范围及每阶段记录保存在 [raw/short](raw/short/)、[raw/long](raw/long/)、[raw/single](raw/single/) 的 JSON。全部完整样本的窗口可见、输入 UTF-16 长度完整，滚动目标字实际进入视口；TextKit 2 样本均保持 `textLayoutManager != nil`，且无兼容切换通知。单段 10 MiB 不列完成耗时：TextKit 1 在 180 秒限时内未完成 `first_display`，旧驱动保留了只有 `empty_ready` 的[部分记录](raw/single/tk1-single-10MiB-01.json)；TextKit 2 的独立运行在 120 秒限时内也未完成该阶段，[失败记录](raw/single-10-tk2/summary.json)和部分 JSON 已保存。限时只能说明其耗时**大于限时**，不能当作动作耗时或合格样本。没有为这两种引擎继续运行三次单段 10 MiB，以免把持续高 CPU 的未完成样本混入中位数。

短、长段落中，原生 TextKit 2 的远端滚动在此入口较快且阶段 RSS 较低；无换行单段的 5 MiB 样本却有约 1.1 GiB 末阶段 RSS，且两种引擎的首显都约 50 秒。**输入结构改变结论，不能据前两类样本决定迁移。**此前[应用试验](../2026-09-14-textkit/README.md)中 TextKit 2 流程峰值 RSS 为 2.5–2.7 GiB，本次单原生编辑器、不同工具链及阶段采样没有重现该峰值；既不能说旧试验错误，也不能把差额直接归因于桥接、第二编辑器、OpenCC 或缓存。

可重跑：

```bash
python3 scripts/measure-native-textkit.py --output /tmp/textkit-short-new --pattern short --sizes 1 5 10 --samples 3
python3 scripts/measure-native-textkit.py --output /tmp/textkit-long-new --pattern long --sizes 1 5 10 --samples 3
python3 scripts/measure-native-textkit.py --output /tmp/textkit-single-new --pattern single --sizes 1 5 --samples 3
```

输出目录必须是仓库外的新目录；超时或运行错误会写 `.incomplete.json` 和总览，并以退出码 4 结束，保留已完成样本。不要并行跑其他基准、构建或录屏。下一步在**同一当前应用版本**引入隔离的 TextKit 2 桥接候选，测两个编辑器、转换、布局切换、连续滚动及换稿；用 Instruments Allocations／VM Tracker 分别看峰值、稳定驻留和对象引用，并完成焦点、输入法、选区、撤销、键盘与 VoiceOver 验收。在这些证据到齐前保持正式 TextKit 1 实现，#68 继续开放。
