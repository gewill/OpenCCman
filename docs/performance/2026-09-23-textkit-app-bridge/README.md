# 当前应用 TextKit 2 桥接与变宽归因（#68）

**结论：暂不迁移正式编辑器。** 在当前 OpenCCman 2.0 源码、Xcode 27.0 / macOS 27.0 上，TextKit 2 诊断候选确实改善了 10 MiB 文稿的中部远端滚动，但文末切换布局时稳定出现约 0.9 秒动作和额外的驻留内存。独立原生编辑器复现了“变窄后未重新定位可见末尾字符”这一触发条件；重新定位可避开本次语料的跃升，但直接滚动到光标**不能**代替对任意阅读位置的正确恢复。

## 对照范围与来源

基于 `develop` 的 `d9ecd56f80983710695e2635d65deed6d0de0d66`，使用 [benchmark-app.py](../../../scripts/benchmark-app.py) 的私有 Release 快照、诊断 bundle、独立偏好、相同锁定依赖和 1200×800 pt 可见 Mac 窗口。只改快照中的 [编辑器候选补丁](candidate.patch.gz)：用 `NSTextView(usingTextLayoutManager: true)` 替换显式 `NSLayoutManager` 网络，并**暂不挂接**旧 glyph `WorkspaceScrollKeeper`；正式应用源码和生产目标均未改。这个候选用于拆分内存来源，功能不等价于正式滚动恢复实现。Apple 的 [TextKit 迁移说明](https://developer.apple.com/videos/play/wwdc2022/10090/)要求在访问旧 `layoutManager` 前先确认现代 manager，否则会单向进入兼容模式。

三次独立前台进程按 TK2、TK1、TK2、TK1、TK2、TK1 交错运行；另一次 TK2 运行在 10 MiB 阶段失去前台焦点，[比较器](../../../scripts/compare-textkit-bridge.py)保留该 [run-02.json](raw/tk2-no-anchor/run-02.json) 并明确排除。比较器核对构建环境、依赖 SHA、应用和测试入口哈希、阶段、文本／转换输出哈希及两编辑器 TextKit 状态；可比快照中**编译和执行的源码**只有 `WorkspaceTextEditor.swift` 的候选修改，分析脚本在两个私有快照创建间新增，但未进入应用。所有有效 TK2 阶段中原文和结果编辑器均保持 `NSTextLayoutManager`，无回退。原始 [TK1](raw/tk1/)／[TK2](raw/tk2-no-anchor/) JSON、metadata、构建校验和 [完整比较](comparison.json)随报告保存。

| 同机三轮中位数 | 正式 TextKit 1 | TK2 无旧锚点候选 |
|---|---:|---:|
| 整段流程峰值 RSS | 380.4 MiB（378.5–380.6） | 549.0 MiB（546.8–552.7） |
| 10 MiB 转换模型完成 | 180.4 ms | 178.2 ms |
| 10 MiB 文中远端滚动 | 74.4 ms | 7.4 ms |
| 10 MiB 文末切换至上下布局 | 17.9 ms | 905.5 ms（877.2–907.2） |
| 随后切换至左右布局 | 24.0 ms | 207.4 ms（205.4–213.0） |

动作耗时包含主队列两次 layout/display flush，不是屏幕呈现或键盘交互时间。峰值 RSS 是进程 `rusage` 高水位，包含两个编辑器、OpenCC 转换、诊断入口和此前阶段。不能把这组新系统数据直接与[旧全应用试验](../2026-09-14-textkit/README.md)的 2.5–2.7 GiB 混合比较，也不能据此认定旧峰值不存在。

## 同阶段内存与对象

用 [profile-textkit-bridge.py](../../../scripts/profile-textkit-bridge.py)在 10 MiB 文末布局动作前暂停，分别用 `vmmap`／`heap` 采集切换前、完成后约 15 秒的状态。两版使用相同剖析入口与依赖，仅编辑器候选不同；这些**各一次**的诊断运行与上表无采样计时分开。[TK1](profile/tk1/)与[TK2](profile/tk2-no-anchor/)保留 manifest、阶段 JSON 及压缩原始报告。

| 保留的堆对象 | TK1 前→后 | TK2 前→后 |
|---|---:|---:|
| 全部 malloc 节点 | 748,849→747,522 | 735,964→2,060,133 |
| `NSTextParagraph` | 0→0 | 419→265,621 |
| `NSCountableTextRange` | 0→0 | 673→663,664 |
| `NSCountableTextLocation` | 0→0 | 437→398,262 |

TK2 的上述三类对象在切换后合计约 68.8 MiB 已分配大小；10 MiB 短段语料含 132,731 次 `CRLF CRLF` 重复，约 265,462 个段落边界，与切换后 `NSTextParagraph` 数量接近。**推断**：未重新定位时的文末变宽路径生成了近全文的段落定位对象；这不是已证明的框架泄漏，也无法从单次快照精确归属全部 RSS 差额。单独启用 `MallocStackLogging=1` 的[调用树](profile/tk2-stacks/)将大量对象与诊断入口的布局刷新关联，但系统内部帧未完整展开；栈记录本身增大内存，不能纳入上表对照。[Apple 内存分析说明](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)也区分分配、虚拟内存和实际占用。

本机 `xctrace` 的 Allocations／VM Tracker 无法附加该诊断进程；对我新编译的独立测试进程附加亦失败。失败日志在 [profile/xctrace-failure](profile/xctrace-failure/)，**无效 trace 未作为证据**。`vmmap`、`heap` 与 `malloc_history` 成功，完成了定点的保留对象取证，仍缺连续的 Allocations／VM Tracker 时间线和释放／泄漏判定。

## 原生对照缩小触发条件

扩展 [NativeTextKitMemory.swift](../../../Tests/Benchmarks/NativeTextKitMemory.swift)与[驱动](../../../scripts/measure-native-textkit.py)：一个原生 `NSTextView`，同一 10 MiB 短段语料，先定位文末，再 1200→500→1200 pt；TK1 使用与应用相同的非连续布局设置。两组以**相同源码、驱动与语料 SHA**分别构建并运行三个新进程；各构建二进制 SHA 单独记录，区别只在变宽后是否再次调用 `scrollRangeToVisible`。原始 JSON 与 SHA 见 [不重新定位](native/no-rescroll/)和[重新定位](native/rescroll/)。

| 原生编辑器：变窄动作三轮中位数 | 不重新定位 | 重新定位文末 |
|---|---:|---:|
| TK1 时间／阶段 RSS | 34.3 ms／225.5 MiB | 31.6 ms／225.4 MiB |
| TK2 时间／阶段 RSS | 877.1 ms／425.2 MiB | 25.7 ms／138.0 MiB |

两种 TK2 条件都保持现代 manager、完整文本和可见文末字符，因此“视图尺寸本身”不足以解释跃升；变宽后的定位调用改变了本次布局路径。这是**诊断线索**，不是可直接用于产品的修复：用户可能在未选中的段落阅读，强制滚到光标会丢失阅读位置。下一候选须按可见字符／行偏移恢复，保持焦点、输入法组合、选区、撤销和滚动位置，再用同机三轮及交互视频验证。

## 重跑与剩余验收

```bash
python3 scripts/measure-native-textkit.py --output /tmp/tk-native-no-rescroll --pattern short --sizes 10 --samples 3 --width-switch --narrow-width 500 --no-rescroll
python3 scripts/measure-native-textkit.py --output /tmp/tk-native-rescroll --pattern short --sizes 10 --samples 3 --width-switch --narrow-width 500

# 使用与 Package.resolved 完全匹配且干净的 SourcePackages，分别建新目录。
python3 scripts/benchmark-app.py --output /tmp/tk-app-tk1 --reflow --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/tk-app-tk2 --reflow --textkit2-no-anchor --build-only --packages /path/to/SourcePackages
# 完成两次构建后，在没有其他性能工作负载时逐次 --reuse-build --reflow --samples 1 --start-index 1/2/3。
python3 scripts/compare-textkit-bridge.py /tmp/tk-app-tk1 /tmp/tk-app-tk2
```

最低 macOS 12 真机／系统环境、iOS 15 路径、真实键盘与 VoiceOver、输入法组合、连续滚动、布局切换期间转换／取消／导入及内存回落尚未验收。正式 TextKit 1 继续保留，#68 仍开放；如后续候选不能在保持阅读位置的同时消除高内存与停顿，应以本报告为依据暂缓迁移。
