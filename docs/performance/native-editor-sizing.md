# Mac 工作区编辑器尺寸修复候选

关联 #18、#65、#68；前置诊断 [#106](https://github.com/gewill/OpenCCman/pull/106) 的两份真实主线程栈已定位到 SwiftUI TextEditor 尺寸查询调用全容器布局。候选完整文稿和同机对照已通过；真实 UI 完成首轮检查与媒体归档，完整交互验收仍未完成。

## 实现边界

Mac 的 `WorkspaceTextEditor` 以 `NSViewRepresentable` 包装系统 `NSScrollView` / `NSTextView`，视口不声明基于正文计算的 intrinsic size。原有工作区提供宽高，AppKit 排版可见文字。使用 TextKit 1，沿用 `WorkspaceScrollKeeper` 的局部布局与阅读锚点；不截断正文、不修改转换、文件、额度或窗口模型。iPhone/iPad 继续使用原有 SwiftUI TextEditor 与样式。

SwiftUI Binding 仍是正文来源，Coordinator 只桥接原生编辑事件并记录最近渲染值。无正文变化的布局/任务更新不改写 NSTextView，保留组合文字和选区。程序替换新正文时清除旧文稿的撤销操作；原文、结果各有独立 UndoManager，更新结果不清空原文撤销历史。比较使用 UTF-8 字节，不能用 Swift String 的规范等价比较跳过组合字符顺序改变。

视口和编辑器不保存在全局对象中；系统编辑器继续承担键盘、选择、撤销与查找。没有调用采样中出现的 SwiftUI 私有 API，也没有改动依赖或最低部署目标。

真实界面预检发现初稿采用 `NSFont.preferredFont(.body)` 后，Mac 原有 Helvetica 12pt 编辑字体变为 13pt 系统字体，导致换行改变。已改为 `NSFont.userFont(ofSize: 0)`，保留系统可配置的编辑字体，不写死字号。另将随应用语言解析的标签直接设置到 NSTextView；仅对 SwiftUI representable 加 accessibilityLabel 会标记滚动容器，不能保证直接导航到文本区域时仍有“原文／结果”名称。这两项已补原生回归，并在下方实际 UI 中复验。

## 已检查与待验收

- 本地使用 macOS 11 部署目标编译独立原生回归，通过全文含 U+0000/CRLF/组合字符、键入和 Binding 回写、撤销/重做、组合文字在无关更新后的保留、选区、只读/禁用、独立撤销历史与程序换稿。
- SwiftUI NSHostingView 内的固定 420×240pt 尺寸查询保留 272 万字符的远端文字未排版。这只是无窗口的布局测试，不能代替真实应用延迟或可见内容验收。
- 工程检查通过 59 个 Swift 源文件及三语资源。
- [x] macOS 15 的上述回归、完整应用构建和原生文稿/关窗协议，见下方精确来源和验证边界。
- [x] 同一机器、相同 Release 配置与语料的旧/新两版对照；初稿及修正后样本均保留并独立复核。不同云端 runner 的结果不直接作为收益比例；此项不覆盖冷启动和全部七配置。
- [x] Mac 真实界面前后截图/交互视频，记录尺寸、语言、主题和源提交，已通过 gh 上传至 [PR #108](https://github.com/gewill/OpenCCman/pull/108)。媒体齐全不代表下列完整交互清单全部通过。
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

这组结果支持全容器编辑器布局是主要等待来源，但初稿存在上文已查出的字体/标签差异，不能把这组数值直接记作修正后版本收益。`b0addf7` 的独立复测见末节。单次 baseline → candidate 顺序还含系统缓存与顺序影响；a/b 是同一进程内的两次文稿操作，不是独立冷启动样本。

## 修正后的真实 UI 检查

2026-09-16，本机 macOS 27.0 (26A428)，English / Light / 默认编辑字号。旧包源码 `1c6114efc94d769bceb63a4d637b7c828dff1874`，其 `OpenCCman` 与 `OpenCCman.xcodeproj` 相对性能基线 `cb73fc5` 无差异；新包源码 `b0addf7f7e4472fe788558b71a5637450e70b861`，由 [Xcode 26.3 云端构建](https://github.com/gewill/OpenCCman/actions/runs/35020081358)生成。两包使用相同诊断隔离与产品 entitlement，重新 ad-hoc 签名，不代替分发签名。没有更改依赖或部署目标；本机 Xcode 27 编译限制另由 [#107](https://github.com/gewill/OpenCCman/issues/107) 跟踪。

使用同一 9,599 字节、60 段合成文稿，包含中文、Emoji、组合字符。前后截图均为实际窗口捕获，900×450px；放大后的候选截图为 1302×768px，未将图像像素直接当作独立的逻辑 pt 测量。新包实际文本区域均显示 Source / Result 无障碍名称；保留原有默认编辑字号及换行。

实际键盘输入 `x`、撤销、重做、再次撤销均按完整原文核对；可跳到第 60 段文末。转换后聚焦结果再按 `x`，结果全文未变，结果仍可选择。此过程累计四次成功转换，诊断额度为 4。程序化 marked text 测试另已通过，不能代替真实输入法会话。

900×450 小窗口的上下切换存在外层滚动裁切，初始前后图片的可见段落不一致，不能据此宣称全部滚动回归通过。将候选窗口放大、外层滚动归零后，左右/上下的相同段顶行与“段落 30”选区保留；这只证明该条件。窄窗口、连续拖动分隔条和任务过程中布局切换仍保留验收，与 #57 / #65 的工作区边界一起核对。

[完整 UI 证据](native-editor-sizing/2026-09-16-ui/)保存两进程原始日志、固定文稿、键盘检查、来源、媒体校验和及恢复记录。旧版录像 54.473333 秒；候选最终完整短视频 62.435 秒，包含两轴切换、输入/撤销/重做、跳文末、转换与只读检查。另保留 340.688333 秒的中断录像：ScreenCaptureKit 报 -3822/-3808，不当作完整覆盖；一次新编译的录制器启动即 CGS 初始化失败，没有可用录像。这些是录制器结果，不是应用崩溃。完整视频使用已验证录制器补录，退出状态为 0。

两个验收应用均已退出并移为 `.app.inactive`；标准/沙盒测试偏好已恢复，VoiceOver 未启用且仍未运行。保护中的其他应用与模拟器没有操作。带 CUA/录屏的本机日志不作为性能或生产泄漏结论。

[完整 App Regression 和 iOS Simulator 构建](https://github.com/gewill/OpenCCman/actions/runs/35020997241)已通过，源码 `7958839` 与上述应用代码一致。模拟器构建成功不是 iPhone/iPad 实际交互验收；三语、深色、真实输入法、VoiceOver 全流程、签名文件访问及最低系统仍按原门槛保留。

真实媒体已上传并读回验证，完整列表及各自哈希见 [媒体记录](native-editor-sizing/2026-09-16-ui/media.json) 和 [PR #108](https://github.com/gewill/OpenCCman/pull/108)。

| 修改前：900×450 左右 | 修改后：900×450 左右 |
|---|---|
| ![旧版左右](https://github.com/user-attachments/assets/452d77b0-6e64-445b-8731-8b6862f33db5) | ![修正版左右](https://github.com/user-attachments/assets/88fb4804-1626-4385-adca-e3143a37a6aa) |

[旧版交互视频](https://github.com/user-attachments/assets/f76d8353-f36d-4387-be06-1f06e48e62b0) · [候选完整短视频](https://github.com/user-attachments/assets/8787b6e9-3e6e-4cc8-93bc-652f8df86197)

## 修正后候选同机对照

[运行 35020888552](https://github.com/gewill/OpenCCman/actions/runs/35020888552)成功，旧版 `cb73fc528b3c9d53dfc840b8ae48e1cae7426fcb`、候选 `b0addf7f7e4472fe788558b71a5637450e70b861`。同一 macOS 15.7.9 ARM64 runner、配置的 Xcode 26.3、相同 Release 双架构参数及逐字相同的依赖锁。两包先全部构建，随后各启动一个进程顺序运行，无采样/录屏/CUA。[完整数据、实际构建命令与固定文件](native-editor-sizing/2026-09-16-corrected-comparison/)已归档。

| 阶段 | 旧版 a / b | 修正后候选 a / b |
|---|---:|---:|
| 1 MiB 导入到驱动就绪 | 1,622 / 1,488 ms | 57 / 67 ms |
| 1 MiB 转换到导出验证 | 1,848 / 1,763 ms | 116 / 118 ms |
| 10 MiB 导入到驱动就绪 | 17,531 / 17,259 ms | 113 / 108 ms |
| 10 MiB 转换到导出验证 | 19,615 / 19,407 ms | 387 / 394 ms |
| 其中 10 MiB 原生转换调用 | 190 / 185 ms | 176 / 176 ms |
| 协议内采样点峰值 footprint | 430,821,376 bytes | 143,003,264 bytes |
| 内核峰值 RSS | 788,086,784 bytes | 430,620,672 bytes |

下载后分别用 checker 独立复核原始 JSONL 和实际文件：两边各五份导出完整一致，NUL/CRLF/组合文字保留、无 BOM；活动调用中关闭、保留窗口转换时关闭另一窗均通过，最终 +5/+20 秒零模型、零预约，进程正常退出。内存 API 状态全部有效。差异主要在文稿显示/排版相关等待，原生 OpenCC 调用依然约 0.18 秒；没有升级引擎或宣称其算法加速。

此结论限定于固定语料、默认转换配置、单次同机顺序对照及这些事件边界；a/b 是进程内重复操作。缓存/顺序影响保留，不等于首次屏幕呈现、冷启动、多机统计或发布版收益。#18 的冷启动/七配置/真实业务全覆盖以及 #93 持有链问题不因此关闭。UI 剩余门槛仍按上文保留，PR #108 继续 Draft。

## 生产编辑器缩放锚点补验

2026-09-16 继续验收时，直接使用 `WorkspaceTextEditorCoordinator.makeViewport()` 补了无窗口回归。原有 `EditorScrollChecks` 主要使用系统默认 NSTextView 工厂，这组新增用例同时覆盖实际生产视口、delegate、Binding 和 keeper。合成文稿实际为 1,048,356 / 10,485,396 字节，分别测试原文可编辑和结果只读。

旧 keeper 在 420→840pt 变宽时可复现失败：首次顶行字符 426,132 变成 427,161。诊断记录显示按需排版在坐标查询过程中调整了 clip origin，旧 capture 仍将 219pt 偏移与高 17pt 的行片段组合为锚点；此问题无需外层工作区 ScrollView 即可复现，但不能仅凭它解释先前小窗口截图的全部差异。

修复先请求可见区域的排版，再读取当前坐标；阻止捕获期间嵌套的 bounds 通知覆盖中间值，并最多三次确认坐标和行内偏移一致。未能解析的估算不再作为锚点恢复。使用局部 `ensureLayout(forBoundingRect:in:)`，没有全容器排版调用；Apple SDK 文档允许系统实际排版范围大于请求区域，所以是否保持收益仍需应用协议复测。

[本地原始日志、来源文件哈希及范围](native-editor-sizing/2026-09-16-anchor/)记录旧实现失败和修复后通过。原文/结果的中段变宽、变窄、连续尺寸变化、文末导航、恢复排队期间新选区优先和换稿均通过；组合文字 resize 及后续 RunLoop 后远端文字仍未全部排版也通过。只暴露编译期测试同步状态，不向正式应用添加诊断入口。这里验证的是原生视口，不是实际分隔条手势、焦点或全工作区验收。

此前 `b0addf7` 的截图、视频和同机性能结果仍是该提交的历史证据，不能直接当成本次滚动修复的验收。新候选需重新通过 macOS CI、同机文稿协议及真实 UI；#108 继续 Draft，最低系统和发布门槛不变。
