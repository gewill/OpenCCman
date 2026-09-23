# TextKit 2 组合字符几何与布局恢复（#68，2026-09-24）

**结论：先前 10 MiB 文中滚动的“0/3 不可见”是诊断检查的假阴性；现代锚点候选的布局恢复仍有独立缺陷。**旧检查只把家庭 Emoji 的首个 UTF-16 单位传给 `firstRect(forCharacterRange:)`，即使 `scrollRangeToVisible` 收到的是完整组合字符。改为检查完整的 11 单位组合范围后，TextKit 1、TextKit 2 无锚点、TextKit 2 现代锚点三种候选首次滚动均为 3/3 可见。切为上下布局时三者都暂时离开可视区；切回左右后，前两者恢复为 3/3，现代锚点仍为 0/3。**正式 App 继续使用 TextKit 1。**

## 对照与来源

基于已合并的 [文中目标对照 PR #154](https://github.com/gewill/OpenCCman/pull/154)，应用源码提交 `17e6d6b63c0f436f7b3bcc18fc5e5177796156f4`。本轮只修改私有 `AppPerformanceAudit.swift` 的诊断目标/几何检查与 `benchmark-app.py` 的运行参数；应用目标、依赖锁、正式编辑器及用户偏好不变。三个私有 Release 快照的应用源码差异仅为原有的 TextKit 2 编辑器与现代锚点注入；每组 `metadata.json` 保存完整源码哈希、锁定依赖和构建命令，`build-complete.json` 保存产物哈希。三组依赖修订完全一致。

环境：Apple M4 Pro（`Mac16,7`）、macOS 27.0（26A428）、Xcode 27.0（27A266a），英文、浅色、1200×800 pt 前台隔离窗口，ad-hoc 签名。1/5/10 MiB 的固定短段文稿和转换流程相同；每组分别跑三个新进程，未交错运行或清除系统文件缓存。九次均 `status=complete`，两个编辑器内容与模型逐字节一致，没有 TextKit 2 回退；10 MiB 输入/输出 SHA-256 分别为 `30dd4e4c696b7d1fb2deb5c4d4b5fd261d962f484c6fcd85744ec36a3853dcab` / `324edfbb081f9819ff7a517978ecd6ce09c9c067c757294b466c3bb91c747f29`。

10 MiB 源文的 UTF-16 中点 `2,256,432` 位于 `👨‍👩‍👧‍👦`，完整组合范围从 `2,256,426` 开始、长度 11。滚动仍调用 `scrollRangeToVisible` 且选区仍在 `2,256,426`；本次只是把 `firstRect` 的测量范围从长度 1 改为完整 11。原始 [#154 数据](../2026-09-24-textkit-midpoint/README.md)在单单位检查下报告 0/3；本次现代锚点同目标、完整范围下首次滚动为 3/3。因此**仅首次滚动的不可见结论被纠正**，不把后续布局切换也说成误判。

| 10 MiB 家庭 Emoji 目标，三次新进程 | TextKit 1 | TextKit 2 无锚点 | TextKit 2 现代锚点 |
| --- | ---: | ---: | ---: |
| 首次文中滚动后可见 | 3/3 | 3/3 | 3/3 |
| 切为上下布局后可见 | 0/3 | 0/3 | 0/3 |
| 切回左右布局后可见 | **3/3** | **3/3** | **0/3** |
| 切回左右后目标相对可视区底缘 Y | 206.5 pt | 209.4 pt | −181 pt |
| 文末 10 MiB 切为上下布局动作中位数 | 18.9 ms | 890.8 ms | 14.0 ms |
| 同流程峰值 RSS 中位数 | 380.4 MiB | 546.0 MiB | 291.5 MiB |

表中的时间包含主队列动作及两轮 display flush，**不是用户看到画面的端到端时间**；三组顺序执行，数字只描述本机诊断。流程峰值 RSS 含转换、两编辑器、语料和诊断，不是单个锚点对象的成本。无锚点候选的中部恢复正确，但文末变宽仍复现约 891 ms 的慢等待与较高内存，因此不能把“移除锚点”直接当生产修复。现代锚点的中部恢复失败也不能归因为 TextKit 2 基础编辑器：无锚点版本同条件恢复可见。

## 可重复执行

使用锁定修订且干净的 `SourcePackages` 副本；三个变体各用新的 `/tmp` 目录。`--middle-composed` 仅在建包时设置，`--reuse-build` 从已验证的 metadata 读取条件并复核源码/依赖/产物哈希。

```bash
python3 scripts/benchmark-app.py --output /tmp/textkit-full-tk1 --reflow --middle-composed --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/textkit-full-tk1 --reuse-build --reflow --samples 3

python3 scripts/benchmark-app.py --output /tmp/textkit-full-tk2-no-anchor --reflow --textkit2-no-anchor --middle-composed --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/textkit-full-tk2-no-anchor --reuse-build --reflow --samples 3

python3 scripts/benchmark-app.py --output /tmp/textkit-full-tk2-anchor --reflow --textkit2-modern-anchor --middle-composed --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/textkit-full-tk2-anchor --reuse-build --reflow --samples 3
```

每次完整 JSON、三份摘要与来源/构建清单位于 [raw/](raw/)；`checksums.json` 校验归档文件。`scroll_end_10_2256432` 和 `layout_end_10_2256432_{vertical,horizontal}` 中保留实际选区可见性、相对 Y、来源与输出哈希；新滚动行还记录字符位置、组合范围长度和几何范围长度。

## 后续判断

下一步对私有 `ModernWorkspaceScrollKeeper` 在文中切轴前后记录锚点字符、选区、可视区与异步恢复顺序，找出为何切回左右时落在目标下方 181 pt；修复候选必须同时保持顶部阅读位置、选择/输入法状态，以及已观察到的文末性能和内存边界。Apple 的 [TextKit 2 迁移说明](https://developer.apple.com/videos/play/wwdc2022/10090/)允许 `NSTextView` 继续使用 `NSRange`，但与现代布局 API 的位置须按内容管理器换算。

本轮没有对连续手动滚动、真实键盘/IME、撤销、VoiceOver、iOS 15、macOS 12 或最终签名包作验收；#68 不关闭，也不替换正式 TextKit 1。
