# #68: 双原生编辑器的清空后 heap／VM 对象快照

在一个只有两个原生 `NSTextView` 的 TextKit 2 进程中，两个编辑器清空 30 秒后仍有 **96,776 个 `CTRun`** 和 **13,616 个 `NSTextLineFragment`**。数量与[应用 TextKit 2 高状态](../2026-09-24-recovery-retention/README.md)的一次快照（96,807／13,613）非常接近；应用低状态的一次快照约为一半（48,422／6,807）。这表明**高状态所见规模的布局对象不需要 SwiftUI、转换模型或应用滚动保持器即可出现**。本轮原生快照未建立每个对象到具体编辑器的直接引用链，且应用与原生的进程结构不同，因此数量接近不等于已定位全部物理内存差额，也不证明泄漏。

## 限时采集

私有诊断包由提交 `7ff9e1a3c8c5be1621f818c90a53336493755402` 的源码构建，使用与[双原生编辑器运行对照](../2026-09-24-native-paired-recovery/README.md)相同的 1 MiB 输入、两个各 440pt 宽的编辑器、开头／中部／文末滚动及清空流程。环境为 Apple M4 Pro / 48 GiB、macOS 27.0、Xcode 27.0；目标参数设为 macOS 12 并做 ad hoc 签名验证，但没有在 macOS 12 实机运行。每种 TextKit 模式各用一个新前台进程；清空 30 秒后记录状态并保持最多 60 秒，采集 `heap -s -H -q` 与 `vmmap -summary`，然后只终止匹配该诊断包路径的 PID。

| 清空后单次快照 | 原生 TextKit 1 | 原生 TextKit 2 | 应用 TextKit 2 高状态 | 应用 TextKit 2 低状态 |
| --- | ---: | ---: | ---: | ---: |
| 物理内存占用 | 74.5 MiB | 267.5 MiB | 384.4 MiB | 188.8 MiB |
| `CTRun` | 8 | 96,776 | 96,807 | 48,422 |
| `CTLine` | 8 | 13,618 | 13,649 | 6,843 |
| `NSTextLineFragment` | 0 | 13,616 | 13,613 | 6,807 |
| `NSTextLayoutManager` | 0 | 2 | 未在该报告计数 | 未在该报告计数 |

两份原生快照都来自完整、前台、同语料的恢复阶段：两个编辑器的 `string` 与 `textStorage` 为零长度，滚动目标此前可见，TextKit 2 没有兼容模式回退通知。`vmmap` 显示的原生 TextKit 2 物理内存占用为 267.5 MiB，与阶段记录一致。heap 类别统计是某一时点的存活数量，不是所有对象的引用归属；类别字节数、malloc 区分类和进程物理占用也不能简单相加。应用高／低对象数据同样各只是一份保持进程快照，不代表分布。应用高状态已有两条 `NSTextView → NSTextLayoutManager → NSTextLayoutFragment → NSTextLineFragment → CTLine → CTRun` 引用树；本轮不把相近的原生类别数量冒充相同的直接引用路径。

## 复核与下一步

[`raw/`](raw/) 包含构建元数据、两个限时保持过程的逐阶段记录、原始 heap／VM 输出的无损压缩、输入及校验和。校验脚本复查提交、工具链、输入、前台与双编辑器状态、原始输出哈希、对象数量，并重新验证前两份原生及应用报告：

```bash
python3 docs/performance/2026-09-24-native-heap-control/analyze.py
python3 scripts/measure-native-textkit.py --output /path/outside/repo/build --pattern app-mixed --sizes 1 --samples 1 --modes tk1 tk2 --recovery --second-editor --activate-process --content-width 440 --build-only
python3 scripts/profile-native-recovery.py --build /path/outside/repo/build --output /path/outside/repo/capture --modes tk1 tk2 --hold-seconds 60
```

原生双编辑器的 30 秒占用在先前各三个独立进程中为 TextKit 1 的 73.8–75.1 MiB 和 TextKit 2 的 267.9–269.4 MiB；本轮 heap／VM 每模式各取其中一个新的保持进程，不将单次对象计数写成统计范围。下一步需要在应用高、低状态对两个编辑器分别记录布局片段与调用路径，加入真实转换结果和同等布局动作，继续验证普通 TXT、5/10 MiB、编辑／IME、iOS 15／macOS 12、VoiceOver 和签名包。#68 保持开放，正式应用仍使用 TextKit 1。
