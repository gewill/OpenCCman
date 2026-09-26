# OpenCCman 应用性能历史试验 — 2026-09-14

> 已由 PR #66 review 发现测量问题：以下原始数据作为历史诊断记录保留，不能作为当前工具的回归基线。编辑器计时包含全文字符串比较，metadata 有事后补注且与当前生成格式不一致。新的协议、原始数据与结论见 [修正报告](../2026-09-14-review/README.md)。不得手动改写旧 metadata 使其通过比较器。

关联 [#18](https://github.com/gewill/OpenCCman/issues/18)。本次把已有引擎微基准扩展到真实 Mac 应用、主页模型、系统文本编辑器及窗口；不把模拟器、引擎或上游宣称的数据当成三端实际收益。

## 环境与来源

- MacBook Pro，Apple M4 Pro，48 GiB，macOS 26.6.2（25G83），Xcode 26.6（17F113），arm64 Release。
- 应用源码 `c3009c74796e8f4ff3b39c4f1c5bb8c9ed1c04cf`，对应 Cloud Build 50 的源码。这里是本地独立诊断包，bundle build 仍为源工程的 30，**不是重测已签名的 TestFlight 50**。
- 旧依赖：SwiftyOpenCC `53f200cebe40eade3ebda025b0e8980e08cf23fa` / OpenCC 1.2.0。
- 当前依赖：SwiftyOpenCC `6eded293f5c84c064f332cbc2832391165c82dda` / OpenCC 1.4.2。
- 两组各 5 个新进程；每进程 5 次热转换。所有正式样本在主页就绪后的阶段都记录为前台状态。没有并行构建、录屏、AX 查询或 profiler。
- 同一界面、同一测试入口、同一语料及其他依赖。独立标识、Pro 偏好、SDK 抑制范围、启动握手和计时边界详见 [测量协议](../README.md)。窗口请求 1200×800pt；运行截图窗口边界也记录为 1200×800pt（含标题栏）。英文、浅色、系统默认字号。
- 引擎对照的测试入口来自 `90561e0`；完整 commit 和 SHA-256 在 [来源校验](MEASURED-HARNESS-SHA256.txt)。每组 metadata 包含全部源码哈希、工程 pin 和实际 checkout SHA。

启动等待、SDK 回调覆盖测试权益、手工托管窗口初始路由/尺寸等问题在试跑阶段校准。失败和受诊断工具影响的试跑没有计入下面的 10 个正式样本；最终协议下没有按快慢选择样本。

## 引擎升级在应用中的表现

以下均为中位数。热转换先取每进程 5 次的中位数，再在 5 个进程之间取中位数；组合耗时也是先按每个进程相加，不能直接相加两个中位数。

| 指标 | OpenCC 1.2.0 | OpenCC 1.4.2 | 解释 |
|---|---:|---:|---|
| 新进程开始到主页布局就绪 | 547 ms | 651 ms | 含打开窗口握手；样本区间重叠，不判断启动收益或回归 |
| 256 KiB 首次模型转换 | 70.7 ms | 55.5 ms | 含首次转换器创建和实际模型发布 |
| 256 KiB 热模型转换 | 56.2 ms | 22.3 ms | 结果编辑器更新另计 |
| 1 MiB 模型转换 | 176.7 ms | 41.9 ms | 输出一致 |
| 5 MiB 模型转换 | 840.8 ms | 114.7 ms | 输出一致 |
| 10 MiB 模型转换 | 1,665.7 ms | 210.5 ms | 应用内测得的引擎路径收益 |
| 10 MiB 结果编辑器更新 | 631.7 ms | 651.4 ms | 包含全文比较，不能判断显示成本 |
| 10 MiB 转换到结果编辑器更新合计 | 2,299.2 ms | 863.5 ms | 不含原文读取和显示 |
| 10 MiB 读取、原文显示、转换、结果显示合计 | 3,149.3 ms | 1,732.4 ms | 不含系统文件选择、语料生成及阶段间固定等待 |
| 七组配置使用后整个应用 footprint | 209.3 MiB | 245.3 MiB | 包含 UI/SDK/字体等；不是纯转换器缓存大小 |
| 10 MiB 结果阶段应用 footprint | 252.9 MiB | 324.2 MiB | 阶段快照，不等于峰值 |
| 整个协议的进程峰值 RSS | 403.8 MiB | 457.8 MiB | 包含测试工具、两轮窗口和此前阶段 |

启动范围：旧引擎 483–1,574 ms，新引擎 495–790 ms。单次时间受环境影响较大，不能用 104 ms 的中位差宣称启动变慢，也不把这个带握手的诊断指标等同于系统启动指标。

10 MiB 在当前引擎下，温文件读取约 10.7 ms，原文编辑器更新约 855.7 ms。这些编辑器指标被计时内全文比较污染，撤回“主要成本移向文字显示”的归因。两组所有转换阶段的输入和输出哈希一致；七组有效配置的固定答案、U+0000、CRLF、空行、Emoji、组合字符、重复结果和导出快照断言通过。

原始数据：[1.2.0](opencc-1.2.0/)、[1.4.2](opencc-1.4.2/)、[逐阶段比较及范围](comparison.json)。数字仅代表这台机器、该语料和该协议，不外推 iPhone/iPad、低端设备、耗电或 FPS。

## 采样发现与窗口生命周期

独立 CPU Profiler 记录覆盖 10 MiB 转换、切换布局和 AX 查询，共 45,369 个采样记录。主线程热点包含 `NSLayoutManager` 的 `_doSomeBackgroundLayout`、填充布局空洞、字形生成和 `NSTextStorage` 属性修正。AX 查询也带来明显开销，不能把该诊断记录中的全部 CPU 成本归给日常交互。

[脱敏的 CPU 栈汇总](cpu-profile-summary.json) 保留周期权重、代表栈与源导出的 SHA-256；inclusive 栈存在重叠，不能相加当百分比。完整 Instruments 文件含启动环境信息，只保留在本机，不直接上传。

一次大文本滚动的自动化调用超时；随后 `sample` 显示主线程主要处于事件循环等待，应用 CPU 约 1.4%。因此记录为自动化超时，**不声称应用连续卡死五分钟**。后续截图确认界面和结果仍在。

手动托管窗口测试在关闭后仍可观察到模型存活，不能将其当作 WindowGroup 泄漏。随后用系统 Cmd-N 创建两个真正的 WindowGroup 窗口，弱引用计数从 1→3，Cmd-W 关闭后回到 1；持续快照保持为 1。两额外系统窗口使用默认短文本，主窗口为 1 MiB；不是三个大文稿的系统窗口内存压力测试。

[系统窗口快照](native-windowgroup.json) 与 [仅用于该诊断的计数入口源码](InteractiveAudit.swift.txt) 保存了这次区分验证。七组转换器仍按设计进程常驻，本轮没有证据要求改成 LRU 或预加载。

## 闲时排版试验：有 CPU 收益，暂不纳入应用

使用同一当前引擎，独立运行各 5 个新进程。测试入口来自 `056d56a`，增加了累计 CPU 记录；因此不与上一组不同入口的 CPU 数据混算。唯一应用差异为 [试验补丁](background-layout-trial.patch)：在 Mac 编辑器挂接时关闭 `NSLayoutManager.backgroundLayoutEnabled`。该设置停止 run loop 空闲时的主动全文排版，仍允许系统按需排版；不是把 TextKit 移到后台线程。

| 同一完整协议的中位数 | 基线（开启闲时排版） | 试验（关闭闲时排版） |
|---|---:|---:|
| 进程累计 CPU | 29,114 ms | 8,640 ms |
| 协议累计经过时间 | 34,270 ms | 15,899 ms |
| 进程峰值 RSS | 456.4 MiB | 444.1 MiB |
| 10 MiB 原文编辑器更新 | 866.0 ms | 867.7 ms |
| 10 MiB 模型转换 | 212.9 ms | 213.5 ms |
| 10 MiB 结果编辑器更新 | 643.1 ms | 646.6 ms |

历史协议累计 CPU 中位数差约 70.3%。重新按阶段复算，两次手动关窗阶段 CPU 中位数合计由 19,230.8 ms 变为 171.0 ms，约占总 CPU 中位差的 93.1%；主要差异来自该托管窗口关闭路径。编辑器计时受全文比较污染，撤回“首屏显示没有改善”的结论，亦不能归因为日常输入与闲时排版竞争。所有输出一致。原始 [基线样本](idle-layout-on/)、[试验样本](idle-layout-off/)、[比较结果](idle-layout-comparison.json) 保留完整范围及来源。

随后真实交互暴露了未通过的边界：试验版导入并转换 10 MiB，切上下、Cmd-Down 到原文末尾、再切左右，出现持续高 CPU。3 秒采样显示主线程在 SwiftUI 布局→NSTextView 尺寸变化→selection rect→TextKit 全文重排。基线版导入同样文件后切上下，也出现持续近 100% CPU，采样在 NSTextView.drawRect→布局空洞填充与字形生成；累计进程 CPU 从 40.55s 到 129.70s，结束该诊断进程。两次路径的位置不完全相同，且包含 AX 操作，**不能比较最坏延迟，也不能证明试验没有交互回归**。

因此最终 PR **只交付测量工具、回归和报告，不修改正式编辑器的排版设置**。[#65](https://github.com/gewill/OpenCCman/issues/65) 单独跟踪大文稿显示/重排，保留 [基线栈](baseline-reflow-stack.txt) 与 [试验文末栈](trial-tail-reflow-stack.txt)。约 1 MiB 的原生文末、选区、重排与组合文字回归通过，并不覆盖这个 10 MiB 最坏场景。

## 实际运行截图与视频

以下是同一当前引擎的基线与**未采用的试验**，不是本 PR 的正式 UI 修改前后。macOS 26.6.2，1200×800pt 窗口，英文、浅色、默认字号，10 MiB 固定文稿。应用来源 `c3009c7`，测试入口 `056d56a`；试验额外应用上述补丁。界面截图包含 Retina 阴影区域，不用截图像素代替窗口点尺寸。

| 基线 | 闲时排版关闭试验（未采用） |
|---|---|
| ![基线运行](https://github.com/user-attachments/assets/16bd41c0-8fc3-4014-8d3b-cb26f5709ca5) | ![试验运行](https://github.com/user-attachments/assets/72575b19-45b5-4fe0-be94-e5368909ac7c) |
| [布局与转换交互视频](https://github.com/user-attachments/assets/7e30f4a6-7142-442e-84f0-44e3ad305bb0) | [布局与转换交互视频](https://github.com/user-attachments/assets/5b2f1066-d328-45b7-b7ee-5c2e2c61c32d) |

录像单独进行，不计入正式性能样本，也没有完整记录后续文末重排长等待。媒体最初通过 `gh` 的 Git 数据接口提交进仓库；现已通过 `gh pr edit --attach` 改为附件，并从当前树删除二进制，未重写既有提交历史；[文件校验和与录制来源](media-provenance.json) 记录原始/压缩文件。完整 Instruments 包未上传。

## 验证与后续

- 两个引擎的实际 Release 应用均完成构建；没有其他依赖漂移。
- 比较器的六项测试覆盖一致样本、依赖漂移、配置缺失、语料改变、输出改变和失败运行，已接入现有 App Regression。
- 核心转换、文件、取消/替换、配额、provider 回归通过；工程静态检查和比较器 6 项测试通过。日志见 [validation](validation/)。最终应用代码未改；[编辑器回归日志](validation/editor-scroll-final.log) 对应最终源码，试验日志另存。
- 核心转换、文件和额度规则不在诊断入口内重写；测试包不触发购买或消耗正式偏好中的额度。
- 本轮仅完成 Mac 本地应用基线；系统默认启动/正式签名包与 iPhone/iPad 的实机性能仍未测，不将诊断启动握手算作完成该验收。
- 最低系统、真实购买和已签名包的文件/快捷键验收继续由既有 release issues 跟踪。本轮没有推送 `build*`，没有触发 Xcode Cloud 发布。
- [#52](https://github.com/gewill/OpenCCman/issues/52) 的大文件 Pro 功能应优先验证有限预览与完整导出分离，再测 20/50/100 MiB；不从本次 10 MiB 样本线性推算上限。
- [#20](https://github.com/gewill/OpenCCman/issues/20) 的无障碍验收应加入大文稿读取；AX 诊断开销不替代真实 VoiceOver 结论。本轮未开启 VoiceOver。

参考：[Apple 启动测量](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)、[NSLayoutManager.backgroundLayoutEnabled](https://developer.apple.com/documentation/appkit/nslayoutmanager/backgroundlayoutenabled)。
