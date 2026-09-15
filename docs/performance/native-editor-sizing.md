# Mac 工作区编辑器尺寸修复候选

关联 #18、#65、#68；前置诊断 [#106](https://github.com/gewill/OpenCCman/pull/106) 的两份真实主线程栈已定位到 SwiftUI TextEditor 尺寸查询调用全容器布局。候选完整文稿协议已通过，同机前后性能和真实 UI 媒体验收尚未完成。

## 实现边界

Mac 的 `WorkspaceTextEditor` 以 `NSViewRepresentable` 包装系统 `NSScrollView` / `NSTextView`，视口不声明基于正文计算的 intrinsic size。原有工作区提供宽高，AppKit 排版可见文字。使用 TextKit 1，沿用 `WorkspaceScrollKeeper` 的局部布局与阅读锚点；不截断正文、不修改转换、文件、额度或窗口模型。iPhone/iPad 继续使用原有 SwiftUI TextEditor 与样式。

SwiftUI Binding 仍是正文来源，Coordinator 只桥接原生编辑事件并记录最近渲染值。无正文变化的布局/任务更新不改写 NSTextView，保留组合文字和选区。程序替换新正文时清除旧文稿的撤销操作；原文、结果各有独立 UndoManager，更新结果不清空原文撤销历史。比较使用 UTF-8 字节，不能用 Swift String 的规范等价比较跳过组合字符顺序改变。

视口和编辑器不保存在全局对象中；系统编辑器继续承担键盘、选择、撤销与查找。没有调用采样中出现的 SwiftUI 私有 API，也没有改动依赖或最低部署目标。

真实界面预检发现初稿采用 `NSFont.preferredFont(.body)` 后，Mac 原有 Helvetica 12pt 编辑字体变为 13pt 系统字体，导致换行改变。已改为 `NSFont.userFont(ofSize: 0)`，保留系统可配置的编辑字体，不写死字号。另将随应用语言解析的标签直接设置到 NSTextView；仅对 SwiftUI representable 加 accessibilityLabel 会标记滚动容器，不能保证直接导航到文本区域时仍有“原文／结果”名称。这两项已补原生回归，修改后的实际 UI 仍待复验。

## 已检查与待验收

- 本地使用 macOS 11 部署目标编译独立原生回归，通过全文含 U+0000/CRLF/组合字符、键入和 Binding 回写、撤销/重做、组合文字在无关更新后的保留、选区、只读/禁用、独立撤销历史与程序换稿。
- SwiftUI NSHostingView 内的固定 420×240pt 尺寸查询保留 272 万字符的远端文字未排版。这只是无窗口的布局测试，不能代替真实应用延迟或可见内容验收。
- 工程检查通过 59 个 Swift 源文件及三语资源。
- [x] macOS 15 的上述回归、完整应用构建和原生文稿/关窗协议，见下方精确来源和验证边界。
- [ ] 同一机器、相同 Release 配置与语料的旧/新两版对照；原始样本和正确性检查保留。不同云端 runner 的结果不直接作为收益比例。
- [ ] Mac 真实界面前后截图/交互视频，记录尺寸、语言、主题和源提交；未附这些证据前不作为完成的 UI PR。
- [ ] 真实键盘、输入法、焦点、两轴切换、分隔条与滚动位置，转换/取消/导入导出时切换，以及浅深色/三语/大字号/VoiceOver。
- [ ] iPhone/iPad 回归；iOS 14/macOS 11 按用户要求保留为发布前验收，不能把编译目标当成系统运行验证。

参考：[Apple NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)、[尺寸测量接口](https://developer.apple.com/documentation/swiftui/nsviewrepresentable/sizethatfits(_:nsview:context:))。桥接只管理内部文稿视图，SwiftUI 管理顶层视口的 frame/bounds。

## 同机对照入口

App Regression 手动运行 `compare_workspace_editor=true`，固定旧版为 `cb73fc528b3c9d53dfc840b8ae48e1cae7426fcb`，候选为该次工作流完整 SHA。仅在 macOS CI runner 执行，两份隔离 checkout 先各自构建相同 Release / 双架构参数，再按 baseline → candidate 顺序运行同一完整 `--documents --active-anchor` 协议。依赖锁必须逐字相同；不采样、不录屏、不调用 CUA。使用临时 checkout，不切换开发工作区。

artifact `workspace-editor-comparison` 包含两份 app、构建日志、来源清单、原始 JSONL、固定导出文件及 `comparison.json`。分别列出 1/10 MiB 导入到驱动确认、转换到导出验证、原生引擎耗时、采样点峰值 footprint 和内核峰值 RSS。命令超时清理自有进程组，失败保留已有报告。

这是一组同 runner 的顺序对照，不是多机统计，也不是冷启动测量；顺序和系统缓存影响仍需保留说明。最终视觉呈现时间不由这些事件表示。成功运行后才补结果，不把入口创建或测试通过当作收益证明。

## 候选完整文稿协议

[云端运行 35016893287](https://github.com/gewill/OpenCCman/actions/runs/35016893287) 使用 `e66adcfd444824d5ad9f16a3e05cd2ab31a2790b`、Xcode 26.3、macOS 15.7.9 (24G830)、Release 双架构产物。macOS 11 部署目标构建与原生编辑器回归通过；应用按 `--documents --active-anchor` 协议运行，没有 CUA、采样或录屏。它不包含普通 App Regression job 的全部项目。

下载 artifact 后用独立 checker 重验：1 MiB 两次、10 MiB 两次及保留窗口活动转换的五份导出均与固定预期逐字节一致，BOM 移除，NUL、CRLF 及组合文字保留。活动转换窗口关闭后没有旧结果回写；保留窗口自身转换时关闭另一窗口仍成功。最终 +5/+20 秒均为零业务模型、零额度预约，成功扣次共 6 次，进程正常退出。

[原始证据](native-editor-sizing/2026-09-16-candidate/)包含源码/依赖锁、构建工具版本、原生测试日志、JSONL、协议结果、固定输入输出 ZIP 和校验和。此运行仅证明候选在该条件下的正确性；不能将其耗时与另一 runner 的历史结果直接相除宣称提速，也不代替真实 UI、签名文件面板、购买或最低系统验收。

## 初稿同机对照（非最终验收）

[运行 35018211749](https://github.com/gewill/OpenCCman/actions/runs/35018211749) 在同一 macOS 15.7.9 ARM64 runner 顺序比较 `cb73fc5` 与初稿 `2e625a2`，两份 Release 双架构产物先全部构建，再无采样、无录屏运行。两边完整协议均成功，独立复核五份导出逐字节正确，最终业务模型均为零。[原始数据及固定文件](native-editor-sizing/2026-09-16-initial-comparison/)原样保留。

| 阶段 | 旧版 a / b | 初稿 a / b |
|---|---:|---:|
| 10 MiB 导入到驱动就绪 | 18,611 / 21,122 ms | 131 / 114 ms |
| 10 MiB 转换到导出验证 | 19,693 / 23,540 ms | 356 / 385 ms |
| 其中原生转换调用 | 189 / 361 ms | 170 / 175 ms |
| 协议内采样点峰值 footprint | 429,150,144 bytes | 155,700,800 bytes |
| 内核峰值 RSS | 766,623,744 bytes | 414,859,264 bytes |

这组结果支持全容器编辑器布局是主要等待来源，但初稿存在上文已查出的字体/标签差异。修正后的 `b0addf7` 必须重新构建、同机比较和进行 UI 复验，不能把这组数值直接记作最终版本收益。单次 baseline → candidate 顺序还含系统缓存与顺序影响；a/b 是同一进程内的两次文稿操作，不是独立冷启动样本。
