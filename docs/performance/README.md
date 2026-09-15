> 当前基线使用协议 2，见 [review 修正报告](2026-09-14-review/README.md)。2026-09-14 旧样本仅作历史记录，不能与新工具比较；更换入口后必须在新目录重新构建、采集两组样本，禁止手改 metadata。

# 应用性能基线

[保留窗口活动转换验收](retained-active-window.md)验证关闭另一窗口不会取消保留窗任务，并分别记录无录屏和录制时段的模型存活。

[macOS 沙盒系统文件面板验收](native-file-panels.md)补充实际导入、保存、错误和取消的文件完整性证据；该手动录屏运行不作为性能基线。

本目录跟踪 [#18](https://github.com/gewill/OpenCCman/issues/18)。[2026-09-14 完整结果](2026-09-14/README.md) 保存同机对照和原始数据。先在固定环境测量，再决定优化；引擎微基准不能替代真实编辑器、窗口和应用进程的结果。

## 重复测量

需要 macOS、Xcode、已解锁的图形登录会话和可用的 SwiftPM 依赖。输出目录必须是仓库外的新目录。脚本会复制源码和依赖到该目录，注入独立测试入口，构建 Release。原始工程、依赖缓存、正式应用和 `build*` 分支均不会修改。

```bash
python3 scripts/benchmark-app.py --output /tmp/openccman-new --build-only \
  --packages /path/to/DerivedData/OpenCCman/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/openccman-old --build-only \
  --packages /path/to/DerivedData/OpenCCman/SourcePackages \
  --engine-revision 53f200cebe40eade3ebda025b0e8980e08cf23fa

# 等待所有构建结束；测量期间不并行编译、分析、录屏或操作此应用。
python3 scripts/benchmark-app.py --output /tmp/openccman-new --reuse-build --samples 5
python3 scripts/benchmark-app.py --output /tmp/openccman-old --reuse-build --samples 5
python3 scripts/compare-app-performance.py /tmp/openccman-old /tmp/openccman-new > comparison.json
python3 -m unittest discover -s Tests/Benchmarks -p 'test_*.py'
```

不要同时启动两个测量进程，它们共用测试 bundle ID。`--reuse-build` 使用已记录的源码快照；修改工作区不会暗中改变已构建样本。`--start-index` 可追加样本，已有样本不会覆盖。失败、超时的 JSON 留在输出目录，比较器拒绝不完整样本。先将诊断样本移到独立目录，再进行正式比较；不要只挑选较快样本。

`Tests/Benchmarks/AppPerformanceAudit.swift` **不在正式 Xcode target 中**。它仅由脚本加入临时项目，因此不会给正式版本增加购买绕过入口、自动转换或测试窗口。测试包使用独立 `org.gewill.OpenCCman.PerformanceAudit` 标识、独立偏好、临时 Pro 权益、ad-hoc 签名和关闭的 sandbox。RevenueCat 初始化保留；权益刷新、delegate 回写、评分和 What's New 弹窗在快照中屏蔽。此配置不验证购买、签名文件权限或正式 TestFlight 启动。

## 指标的含义

- `process_start_to_root_layout_ms`：内核进程开始时间到主页首次布局 flush；包括启动成本，但不是重启机器后的冷启动，也不是屏幕首帧时间。OS/file cache 不清除。测试入口在 `didFinishLaunching` 后主动激活应用；驱动器等待初始化 JSON（20 ms 轮询）后发送一次 `open -a` reopen 事件。该打开窗口握手包含在指标内，不能当作系统默认启动时间。测试进程持有临时 activity，避免 App Nap 干扰。
- `app_init_to_root_layout_ms`：测试入口初始化后到相同终点；不包含该入口之前的 SwiftUI 初始化与 dyld 阶段。
- `model_completion_ms`：调用真实 `HomeViewModel.translate()` 到其完成发布，包含引擎调度、转换、结果发布和模型收尾。
- `result_layout_flush_ms`：随后按编辑器角色和预先计算的 UTF-16 长度等待，并执行 layout/display flush。停表后才逐字节验证内容；包含 SwiftUI 更新和本机文本视图工作，不等于显示器呈现时间。模型与布局两项之和仅为选定阶段合计，排除了长度预计算和正确性验证，不能称为端到端等待。
- `read_decode_ms`：同进程生成的固定 UTF-8 文件经实际 `TextFileService.read` 读取与解码。是温文件缓存测试，排除用户选文件时间。
- `source_layout_flush_ms`：替换原文到真实源编辑器收到内容并 flush。10 MiB 限额未改变。
- `physical_footprint_bytes`、`rss_bytes` 是阶段快照；`process_peak_rss_bytes` 是**整个进程到当时为止**的 RSS 高水位，不能当成单阶段独占内存。测试语料生成、正确性哈希和 JSON 记录也在进程内，峰值包含其开销。
- `process_cpu_ms`：进程累计 user + system CPU 时间（`getrusage`），不是墙钟时间或单阶段耗时。对照必须包含同一组操作，固定等待也保持一致。
- `maximum_main_timer_gap_ms`：从主页就绪起累计的 20 ms 主线程 timer 最大间隔，包含调度、测试工具、哈希和文件生成；仅作定位线索，不是 FPS 或纯应用卡顿指标。
- 多窗口阶段为同进程主窗口加两个独立 `NSWindow`/`NSHostingView<Router<RootView>>`，使用真实模型与编辑器；关闭窗口和移除 content view 后用弱引用观察模型。**不等价于系统 WindowGroup 的关闭/恢复验收**；存活对象不能直接称为泄漏。

每个进程依次运行：256 KiB 首次与五次热转换、七组有效配置、1/5/10 MiB 读取与显示、两轮额外窗口创建/关闭。每项结果附输入/输出 SHA-256、字节数和选项。七组配置另有中文、CRLF、空行、Emoji、组合字符、U+0000 的固定答案断言；热转换和导出快照必须一致。不同引擎的输出哈希变化显式列出，需要按词典语义审查。

## 如何判断回归

固定机器、OS、Xcode、窗口尺寸、主题、语言、语料和测量工具；升级引擎时仅允许 wrapper pin 改变。比较器拒绝其他依赖漂移、不同工具、输入变化、不完整配置或失败样本。保留所有原始运行，不仅保留中位数。

默认把超过 `max(20%, 10 ms)` 的耗时增量、超过 `max(10%, 16 MiB)` 的内存增量标为待调查。这是排查用阈值，**不是统计显著性、用户体验承诺或 CI 发布门禁**。先看样本范围、输出、系统负载和 profiler，再决定是否优化；必要时同机交错重跑。不要在共享 CI 机器上把一次墙钟结果设为硬性性能检查。

分析与计时分开。可在独立诊断运行上使用：

```bash
xcrun xctrace record --instrument 'CPU Profiler' --attach <owned-pid> \
  --time-limit 30s --output /tmp/openccman-cpu.trace
xcrun xctrace export --input /tmp/openccman-cpu.trace --toc
```

录屏/交互验证另开测试进程，在正常参数后附 `-performance-interactive`；它填入并转换 1 MiB，写入 `interactive_ready` 后保留窗口，供检查布局切换与滚动。该运行不计入基准。涉及交互的 PR 证据使用实际视频，按仓库要求通过 `gh` 上传。

## 参考

- [Apple：Reducing your app’s launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)：用户感知的完成点与系统启动指标可能不同。
- [Apple：Improving your app’s performance](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance/)：结合测量与 Instruments 定位问题。
- [已有项目审计](../project-status-and-follow-up-2026-09-13.md)：早期转换路径和引擎微基准，适用范围与本报告不同。

## TextKit 重排回归（#65）

同一份诊断入口可额外运行实际工作区的滚动与菜单命令。仅运行这套协议时使用独立目录，不能与默认转换协议的 `run-*.json` 混放：

```bash
python3 scripts/benchmark-app.py --output /tmp/openccman-reflow --reflow --build-only --packages /path/to/SourcePackages
python3 scripts/benchmark-app.py --output /tmp/openccman-reflow --reuse-build --reflow --samples 3 --timeout 180
```

`--reflow` 使用 1/5/10 MiB，分别定位段首、文中、文末，发送生产代码的上下/左右布局命令。记录阶段开始/结束、动作耗时、进程 CPU/内存和 TextKit 2 是否保留，并断言原生编辑器身份、选区和完整文本/结果哈希未改变。动作耗时包含两个主队列 layout/display flush，不包含截图或 AX 查询，也不是显示器呈现时间。它不等价于拖动/VoiceOver 手工验收。

`--timeout` 到期只终止拥有的诊断进程，保留未完成 JSON；缺少结束事件表示截断，不能当成耗时为零，也不能将进程总超时当成最后动作耗时。此协议的阶段集合与默认转换基线不同，不使用七配置比较器。可比性由同一源码入口哈希、环境、pin、语料和完整阶段判断；超时样本单独报告，不能混成完整样本中位数。

## 协议 2 的验证边界

- 编辑器计时只轮询编辑器角色和预先计算的 UTF-16 长度，再请求布局/显示刷新；停表后逐字节验证 UTF-8 内容，不符则整次运行失败。同长度不代表内容正确，因此不能省略停表后的校验。这是长度应答与刷新耗时，不是屏幕呈现时间。
- 模型转换计时与编辑器计时分开；长度预计算、全文正确性检查不在编辑器计时内。进程 CPU 和内存仍包含测试工具开销，不能当成纯应用开销。
- 构建全部成功并完成 pin 校验后才写出 metadata 和 build-complete.json；复用时检查完成标记、metadata 校验和、源码、应用文件、依赖 checkout、OS 构建号、架构、Xcode 和驱动一致性。
- metadata 自动生成且保持不变；每个运行绑定其 SHA-256。OS 条件由 sw_vers 和架构组成，避免 Python 版本格式漂移。
- 比较器拒绝缺失/不匹配的依赖证明、metadata 改写、后台/无可见窗口样本以及不同测量入口。启动记录允许尚未激活；从 root_layout_ready 起必须保持前台。
- 七组配置使用可区分台湾词组、台湾字形和香港字形的固定答案。官方模式的文字部分核对 OpenCC 1.4.2 CLI；U+0000 的保留由 wrapper/app 固定答案验证，不能用会截断 NUL 的 CLI 输出作为预期。
- 手动托管窗口关闭前、close 返回后和等待后分别记录；分析 CPU 时先算各运行的阶段增量，不能把整段协议差异推广为输入收益。
- 隔离闲时布局试验使用 `--disable-background-layout --build-only`，由脚本应用变更并记录 application_variant；复用时不重复传入覆盖选项。它仍不等同 WindowGroup 关闭行为。

## 文稿阶段调用栈

[云端文稿阶段采样](document-stage-profiling.md)复用完整原生窗口文稿协议，区分调用栈诊断和无采样延迟基线。
