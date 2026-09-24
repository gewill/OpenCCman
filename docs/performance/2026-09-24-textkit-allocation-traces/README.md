# TextKit 2 选区恢复的 Allocations 对照（#68，进行中）

本报告先归档 [#155 现代锚点候选](../2026-09-24-textkit-composed-geometry/README.md) 的一份实际应用 trace；[两个选区恢复候选](../2026-09-24-textkit-selection-candidates/README.md) 尚待同法录制。**正式应用仍使用 TextKit 1；这份单样本不能解释候选在 5 MiB 转换阶段已经出现的 RSS 差异，也不能证明泄漏。**

## 来源与采集范围

基线来自提交 `17e6d6b63c0f436f7b3bcc18fc5e5177796156f4`、锁定的依赖和归档的 `textkit2-modern-anchor` Release 诊断构建。构建的源码、依赖 checkout、元数据和产物哈希均通过 `scripts/benchmark-app.py` 的 `verify_build` 复核。仅将构建产物复制为独立测试 App，在该副本签入 `com.apple.security.get-task-allow`，`codesign --verify --deep --strict` 通过；原构建和发行签名未修改。Apple [公证说明](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)明确要求发行包移除该调试 entitlement。

环境为 Apple M4 Pro、macOS 27.0、Xcode/Instruments 27.0。采集器用 `Allocations` 模板附加到隔离进程，然后沿原基准的 Launch Services reopen 握手开始 1／5／10 MiB 转换、滚动与布局切换。trace 目标 PID 与应用 JSON 一致，目标 `exit(0)`；5.929 秒录制包含 Allocations 和 VM Tracker 轨道。应用记录 59 个阶段、`status=complete`，三个转换阶段均 `app_active=true`。来源、签名与 trace 摘要见 [trace-summary.json](baseline/trace-summary.json)，逐阶段数据见 [run-01.json](baseline/run-01.json)。

| 本次带录制开销的单次应用样本 | 1 MiB 转换完成 | 5 MiB 转换完成 | 10 MiB 转换完成 | 文末切为上下布局后 |
| --- | ---: | ---: | ---: | ---: |
| RSS（MiB） | 195.8 | 241.8 | 317.6 | 324.2 |
| 截至该阶段峰值 RSS（MiB） | 195.8 | 241.8 | 317.6 | 329.3 |
| physical footprint（MiB） | 130.3 | 175.8 | 251.7 | 255.8 |

这些数值来自正在运行的**同一进程**，不能与先前未录制的三次中位数直接相减。`xctrace export` 的 [Allocations Statistics 原始 XML](baseline/allocations-statistics.xml)报告全录制期间 `NSTextParagraph` 2,061 次分配、387 个持续对象，`NSTextLayoutFragment` 1,651 次、397 个持续对象，`NSCountableTextRange` 49,269 次、593 个持续对象，`NSCountableTextLocation` 128,801 次、373 个持续对象。这里的“持续”是该 trace 统计口径，**不是泄漏判定**；Allocations 总量也不等于进程 RSS。VM Tracker 轨道存在，但本次命令行 `Regions Map` 导出没有行，尚未给出 VM 分类归因。

## 对照与复核边界

`firstRect` 候选已从归档提交 `be827fc6bbc010d8a1aec7874991c11a6a72c31e` 重建。新构建的 `source_commit`、应用变体、源码哈希、依赖锁、实际 checkout 修订和测试条件与 [原候选元数据](../2026-09-24-textkit-selection-candidates/raw/first-rect/metadata.json) 逐项一致；其独立测试副本签名已验证，**尚未运行 trace**。须等桌面空闲，附加录制后再比较同类对象、时间窗和分配栈，尤其区分转换阶段的选区可见性查询与切轴后的第二次滚动。

原始 `.trace` bundle 约 225 MB，保存在本机而未加入 Git；`trace-summary.json` 记录其文件数、总字节数和确定性树哈希。仓库保留应用阶段 JSON 和 Instruments 的完整 Statistics 导出供审查。复现时在上述锁定源码的独立工作树运行：

```bash
python3 scripts/benchmark-app.py --output /path/outside/repository --packages /path/to/locked/SourcePackages --reflow --textkit2-modern-anchor --middle-composed --build-only
```

仅复制生成的诊断 App，为**副本**签入 `com.apple.security.get-task-allow=true` 并复核签名。按 `benchmark-app.py` 的 `-performance-output`、`-performance-reflow`、`-performance-require-textkit2`、`-performance-middle-composed` 参数用 Launch Services 启动独立进程；进程写入 `process_initialized` 后、发送 reopen 事件前，运行 `xcrun xctrace record --template Allocations --attach <PID>`。结束后用 `xcrun xctrace export --xpath '/trace-toc/run/tracks/track[@name="Allocations"]/details/detail[@name="Statistics"]'` 导出，并核对 trace 目标 PID 与应用 JSON。测试副本、产物、权限和来源要逐项读回，不能把本次 trace 当作正式应用或签名发行包验收。
