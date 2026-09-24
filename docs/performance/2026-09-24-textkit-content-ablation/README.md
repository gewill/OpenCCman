# TextKit 1 单段落内容与视口观察器消融（#68，2026-09-24）

**结论：在本次 5 MiB 合成、无换行单段落诊断中，移除视口观察器并未解除超时；内容中的组合字符与耗时高度相关。** 没有组合字符的中文语料完成了全部布局流程，加入 Emoji 后也完成但更慢；含重复组合重音的两种语料均在首次 5 MiB 切轴时达到 180 秒上限。两段进程采样把混合语料的主线程定位到 `NSTextView`／`NSLayoutManager`／CoreText 排版调用链，不能据此推断所有用户文稿的瓶颈，也不能证明 TextKit 2 更合适。正式 App 代码与 TextKit 1 选择均未修改。

## 受控条件与证据边界

所有样本使用同一 Apple M4 Pro、macOS 27.0、Xcode 27.0、1200×800 pt 英文浅色窗口、Release 私有诊断副本、锁定依赖、合成 Pro、完整组合字符目标和 1／5 MiB 逐次切轴协议；每种配置一个新进程。输入均恰好为 5,242,880 个 UTF-8 字节、**没有 CR/LF**，但重复单元的字节数和个数不同，因此结果只回答本次内容消融，不能外推普通多段文稿或跨设备的绝对耗时。每种配置只有一次有效运行，没有统计显著性或稳定中位数；没有清理系统缓存。

视口观察器配对来自同一 `049bf62`，同一混合输入、构建条件和输出；私有源码哈希只在 `WorkspaceTextEditor.swift` 不同，去掉的仅是 `scrollKeeper.attach(editor)`。内容配对分别来自同一 `255eca7`（混合／纯中文）和同一 `bbdde9b`（Emoji／组合重音），各对的源码哈希、依赖、机器与协议相同，仅输入 profile 不同。**四种内容没有全部使用同一个提交**，不能把跨对差值当成严格配对比较。所有运行都完成 1 MiB 阶段，5 MiB 转换输入／输出哈希、编辑器与导出结果一致性也通过校验；`timeout` 表示后续 5 MiB 布局没有完成。

| 有效样本，每项一次 | 5 MiB 原文编辑器确认 | 转换请求至诊断任务恢复 | 5 MiB 布局终态 |
| --- | ---: | ---: | --- |
| 混合输入，保留观察器，`049bf62` | 46.863 s | 46.414 s | 首次纵向切轴超时 |
| 混合输入，移除观察器，`049bf62` | 46.262 s | 50.913 s | 首次纵向切轴超时 |
| 混合输入，`255eca7` | 46.397 s | 46.947 s | 首次纵向切轴超时 |
| 纯中文，`255eca7` | 0.319 s | 0.444 s | 完成，启动至退出 6.706 s |
| 中文＋家庭 Emoji，`bbdde9b` | 5.375 s | 5.580 s | 完成，启动至退出 66.972 s |
| 中文＋`e` 组合重音，`bbdde9b` | 77.373 s | 76.683 s | 首次纵向切轴超时 |

“转换请求至诊断任务恢复”包含 UI 调度等待，不是 OpenCC 引擎独占耗时，也不能与“原文编辑器确认”相加。移除观察器的一次运行在原文确认**之后**执行了两段各约五秒的 `sample`；因此它的后续阶段时间不用于精细的观察器配对比较。两端的原文确认都约 46 秒且整个 5 MiB 流程都超时，只支持“单独移除观察器未解除本次病态输入”这一有限结论。

在移除观察器的私有副本中，结果发布时采到的主线程调用链为 `NativeWorkspaceTextEditor.updateNSView` → `NSTextView.replaceCharactersInRange` → `NSTextStorage` → `NSLayoutManager` → `NSATSTypesetter` → CoreText `TCombiningEngine::ResolveCombiningMarks`；首次切轴的另一次采样也经过 CoreText 的组合字符处理。样本只覆盖各约五秒，显示的是采样窗口中的热点，不等于整个 180 秒的时间归因、峰值内存或泄漏证据。纯中文与 Emoji 全流程完成，支持继续针对长单段落的组合字符排版做更细定位。

首次组合重音运行在原文确认结束前失去前台焦点，其 `75.385 s` 被归档于 [`raw/content-combining-excluded/`](raw/content-combining-excluded/) 并**完全排除比较**；表中使用同一已验证构建的 `run-02.json`，该次所有测量阶段均保持前台。超时后脚本返回非零属预期的实验终态，不是构建或转换失败。

## 后续

下一轮应按段落长度和组合字符密度构造更接近真实 TXT 的语料，做重复新进程样本；用 Time Profiler、Allocations 和 VM 轨迹分开量化 `NSTextView` 替换、可见区域布局、切轴与驻留内存。若提出编辑器改动，仍需检查滚动／焦点／IME／撤销、VoiceOver、iOS 15／macOS 12 和签名构建。[#68](https://github.com/gewill/OpenCCman/issues/68) 继续开放。

[`raw/`](raw/) 保存六次有效运行、一份失焦运行、两段采样及构建／源码清单；[`checksums.json`](checksums.json) 记录全部 23 个原始文件的 SHA-256。复核命令：

```bash
python3 docs/performance/2026-09-24-textkit-content-ablation/analyze.py
```
