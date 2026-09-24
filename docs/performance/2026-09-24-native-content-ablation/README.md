# 与应用语料逐字节匹配的原生 TextKit 对照（#68，2026-09-24）

**结论：5 MiB 无换行单段落的长等待在单个原生 `NSTextView` 中也能出现，且强烈依赖字符组成。** 本次原生 TextKit 1 的混合语料首次显示为 47.016 秒、组合重音为 70.920 秒；应用私有诊断中，同字节语料的原文编辑器确认分别为 46.397 秒、77.373 秒。纯中文原生首次显示仅 0.372 秒，家庭 Emoji 为 2.880 秒。原生 TextKit 2 的首次显示在这四组单次样本中接近或快于 TextKit 1，但中部滚动更慢，末阶段 RSS 也更高；尤其 Emoji 组为 4.487 秒、约 1.58 GiB。**计时边界和进程构成不同，不能以这些差值计算应用桥接开销或决定迁移。** 正式 App 仍使用 TextKit 1。

## 方法

在 `3c0618214372c313214e4e7d72694c288688dcf3` 的隔离分支中扩展既有[原生基准](../../../Tests/Benchmarks/NativeTextKitMemory.swift)和[驱动](../../../scripts/measure-native-textkit.py)。四组输入都恰好为 5 MiB UTF-8、没有换行，SHA-256 **逐组与 [#172 应用私有诊断](../2026-09-24-textkit-content-ablation/README.md)的实际转换输入一致**。每组在同一 Apple M4 Pro、macOS 27.0、Xcode 27.0 上分别运行一个 TextKit 1 与一个 TextKit 2 新进程；窗口 1200×800 pt，可见，运行阶段 `app_active=true`。两种模式的文中及文末目标均通过 `firstRect` 确认进入视口；TextKit 2 的 `textLayoutManager` 非空，未收到回退到 TextKit 1 的通知。另有组合重音 1 MiB 的两端控制样本。

驱动使用 `swiftc -O -g -target arm64-apple-macos12.0` 编译**独立诊断程序**，装入临时 `.app`、做 ad hoc 签名和验证，再经 Launch Services 启动。此前三次直接运行命令行二进制的试跑虽有可见窗口，所有阶段 `NSApp.isActive=false`，已存入 [`raw/excluded-launch-probes/`](raw/excluded-launch-probes/) 并完全排除。Apple 说明 `finishLaunching()` 通常由 `run()` 调用，而且激活可能延迟；本诊断显式完成启动并等候激活，同时继续逐阶段记录状态。[Apple `finishLaunching`](https://developer.apple.com/documentation/appkit/nsapplication/finishlaunching())、[Apple 激活说明](https://developer.apple.com/documentation/appkit/nsapplication/activate%28ignoringotherapps%3A%29)。这只验证当前 macOS 上的运行，**不证明 macOS 12 真机兼容**。

测量后驱动补上 `open -W` 超时的自有进程终止保护：一个独立的 5 秒有界试验停在 `empty_ready`，失败记录确认只向匹配当前诊断包路径的 PID 发出终止请求，随后 `ps` 不再能找到该进程。该试验不参与上表性能比较；有效样本仍来自上述锁定源码提交。

| 5 MiB 单段落，每端一次 | 原生 TextKit 1：首显 / 中部滚动 / 末阶段 RSS | 原生 TextKit 2：首显 / 中部滚动 / 末阶段 RSS |
| --- | ---: | ---: |
| 纯中文 | 0.372 s / 0.074 s / 177.3 MiB | 0.347 s / 0.248 s / 297.2 MiB |
| 中文＋家庭 Emoji | 2.880 s / 0.079 s / 441.5 MiB | 1.713 s / 4.487 s / 1583.4 MiB |
| 中文＋`e` 组合重音 | 70.920 s / 0.078 s / 425.7 MiB | 68.166 s / 1.525 s / 868.7 MiB |
| 中文＋Emoji＋组合重音 | 47.016 s / 0.078 s / 485.4 MiB | 45.482 s / 1.763 s / 1295.4 MiB |

“首显”从设置 `editor.string` 至两轮原生窗口布局/显示刷新结束；它不是像素呈现时间。中部滚动包含选区、`scrollRangeToVisible`、`firstRect` 和确认可见；不同于应用的布局切轴。RSS 为文末滚动阶段的**单次采样**，不是峰值、稳定驻留、泄漏或 Allocations 分类结果。各配置仅一次有效样本，运行未交错、未清系统缓存；不能把小差值或版本优劣作统计结论。本次原生程序只有一个编辑器，没有 SwiftUI、转换模型、结果编辑器或布局切换；原生两端全部完成，不与应用 #172 的 5 MiB 切轴超时矛盾。

同字节混合语料的应用原文确认和原生 TextKit 1 首显都约 47 秒，加上 [#172 的两段调用栈](../2026-09-24-textkit-content-ablation/README.md)位于 `NSTextView`／`NSLayoutManager`／CoreText 组合字符排版链，**支持排版是该阶段的重要成本**。但两套协议在窗口树、第二编辑器、结果发布和布局切换上不同，尚不能断定是否另有应用桥接开销。家庭 Emoji 的原生 TextKit 2 在一次样本中比 TextKit 1 末阶段 RSS 多约 1.14 GiB，需要 Allocations／VM 与对象寿命证据再定位；不称为泄漏。

[`raw/`](raw/) 保存四组有效元数据、构建日志、汇总、十次阶段 JSON 及三次被排除的启动试跑。[`checksums.json`](checksums.json) 锁定 31 份原始文件；[复核脚本](analyze.py)核对源提交/哈希、工具链、完整阶段、前台与可见性、TextKit 模式、输入 UTF-16 长度、每组输入 SHA 与应用 #172 的原始记录。输出目录中的临时二进制未纳入 Git，`metadata.json` 保留其 SHA-256；源码、构建命令与签名条件可重跑：

```bash
python3 docs/performance/2026-09-24-native-content-ablation/analyze.py
python3 scripts/measure-native-textkit.py --output /path/outside/repo --pattern app-mixed --sizes 5 --samples 1 --modes tk1 tk2 --timeout 180
```

下一步应对相同 profile 交错重复新进程，单独对应用的**结果编辑器发布与布局切轴**取 Time Profiler、Allocations、VM 和对象引用证据，并补真实文稿、编辑/IME、VoiceOver、iOS 15／macOS 12 与签名包验收。[#68](https://github.com/gewill/OpenCCman/issues/68) 保持开放。
