# #18：七配置后的内存来源诊断（2026-09-23）

[同机五轮引擎对照](../2026-09-23-engine-comparison/README.md)发现，七配置使用后 OpenCC 1.4.2 比 1.2.0 的 RSS 中位数高 35.81 MiB。本报告只定位这一阶段的来源，不处理 [#68](https://github.com/gewill/OpenCCman/issues/68) 中 TextKit 2 试验的大文稿内存。Apple 建议用 Allocations 观察堆与匿名 VM 分配、用 VM 信息区分分配和实际物理占用；本轮使用本机 `vmmap`、`heap` 和 `malloc_history` 做定点取证。[Apple 内存分析说明](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)

## 可复现场景

源码基线为 `develop` 的 `7d48cd7246c1beff6f555b37e47c5575e84c5c89`。两份原版隔离 Release 诊断包仅有 `SwiftyOpenCC` revision 差异：旧 `53f200cebe40eade3ebda025b0e8980e08cf23fa`，新 `6eded293f5c84c064f332cbc2832391165c82dda`；其他依赖 pin 与所有 Swift/Python 源码哈希相同，工程文件仅 revision 不同。环境为 Apple M4 Pro / 48 GiB、macOS 27.0 (26A428)、Xcode 27.0 (27A266a)、arm64。两版均用 PR #142 的显式无 NUL 共同语料，七组配置的输入、输出 SHA-256 逐项相同；默认含 NUL 回归未改变。

为便于取样，独立诊断入口新增 `-performance-hold-after-configurations`：记录 `seven_configurations_resident` 后保存 `profiling_hold`，保持窗口和模型存活。正式 App target 不包含这个入口。先用 `scripts/benchmark-app.py --build-only --comparison-no-nul` 在仓库外构建，旧版额外加 `--engine-revision <旧 SHA>`，然后对各包依次运行：

```bash
open -n -a /path/to/diagnostic/OpenCCman.app --args \
  -performance-output /path/to/hold.json \
  -performance-comparison-no-nul -performance-hold-after-configurations \
  -skip-whats-new -AppleLanguages '(en)' -AppleInterfaceStyle Light
open -a /path/to/diagnostic/OpenCCman.app  # 与正式基线相同的窗口 reopen 握手
vmmap -summary <owned-pid> > vmmap-summary.txt
heap -sH <owned-pid> > heap-summary.txt
```

`heap`／`vmmap` 均在同一个暂停点、按相同顺序运行，结束后仅终止各自诊断进程。单独启动 `MallocStackLogging=1` 的同版诊断进程，再用 `malloc_history <pid> -callTree -chargeSystemLibraries` 取分配栈；启用栈记录本身增加内存，而且工具提示记录并非从进程最早阶段开始，**栈数据只用于识别路径，不能拿它的金额与无采样数据计算差值**。构建、取样、栈追踪不并行。

## 定点结果

下表是每种实现的**一个**无栈记录新进程，不把它伪装成五轮统计结论。RSS 与 footprint 来自暂停点 JSON；dirty 与 malloc 类别来自紧接着的 `vmmap`／`heap`，时间点略有差异，不能精确相减。MiB 按 2²⁰ 字节换算。

| 指标 | 旧 1.2.0 | 新 1.4.2 | 新版＋两项缓存候选 |
|---|---:|---:|---:|
| 暂停点 RSS | 142.13 | 174.38 | 176.83 |
| 暂停点物理占用 | 69.35 | 100.56 | 79.47 |
| `vmmap` dirty total（约） | 68.9 | 100.0 | 93.2 |
| `heap` malloc 节点总量 | 26.2 | 60.8 | 58.2 |
| `opencc::StrSingleValueDictEntry` 数量 | 57,754 | 119,172 | 110,040 |
| 上述对象自身大小（约） | 3.53 | 7.27 | 6.72 |

旧→新在同暂停点的 malloc 节点多约 34.6 MiB，与五轮基线的 RSS 增量数量级一致。OpenCC 字典条目增加约 61,400 个；对象本身只解释其中约 3.7 MiB，剩余的非对象分配、字符串及索引结构也须计入。新版的 [分配栈](new/malloc-calltree.txt.gz)明确经过 `HomeViewModel.translate → ChineseConversionService.ConverterCache.converter → ChineseConverter → CCConverterCreateWithConfig → opencc::Config::NewFromFile`；其中 `opencc::PrefixMatch::PrefixMatch`／`BuildMatcher`／`LeafMatcher::AddEntry` 是重要分配路径。此证据支持**引擎配置与词典构建是主要来源**，并不证明某个具体对象泄漏，也不说明整个峰值都是 OpenCC 独占。

`ConverterCache` 默认长期保留七种转换器。为验证简单容量上限的效果，另用[两项 LRU 候选补丁](cap2-experiment.patch.gz)构建第三份诊断包，其他源码和依赖保持一致；七配置输出 SHA 与原版一致。一次暂停点取样的 malloc 节点仅少 2.6 MiB、dirty 少约 6.8 MiB，RSS 反而高 2.45 MiB；物理占用读数较低，但单次值不够稳定，也未量化重新选择已淘汰配置的加载延迟。**本次不采用容量为 2 的应用修改。**候选源码已撤回，正式缓存仍保留全部七项。

## 原始证据与边界

- [旧版](old/)／[新版](new/)／[两项缓存候选](cap2/)各保留 `metadata.json`、`build-complete.json`、`hold.json`，以及 gzip 压缩的完整 `vmmap-summary.txt` 与 `heap-summary.txt`；旧／新另保留完整 `malloc-calltree.txt`。解压命令示例：`gzip -dc heap-summary.txt.gz`。候选补丁可用 `gzip -dc cap2-experiment.patch.gz | git apply` 在相同基线源码中复现。metadata 与 build marker 的 SHA 对应，记录了来源、工程哈希、依赖 checkout 和机器环境。
- 单次暂停点只能辅助归因；五轮未经剖析的时间与 RSS 分布仍以[前一份报告](../2026-09-23-engine-comparison/README.md)为准。`vmmap` 的 resident 包含共享/干净页，dirty、RSS、physical footprint 不是同一指标。
- 本次没有完成 Allocations/VM Tracker 时间线、泄漏判断、实际签名产物、iOS/iPadOS 或 TextKit 2 分析。不能因为堆节点增加就判定泄漏；也不能用大文稿阶段的高水位反推七配置阶段的单独内存。
- 下一步如需进一步压低驻留，应对词典资源和 PrefixMatch 的共享／缓存生命周期做多轮剖析，并测配置往返的加载时延，再决定是否改应用或上游。#18 保持开放；#68 独立推进 TextKit 2 最小示例与完整布局回归。
