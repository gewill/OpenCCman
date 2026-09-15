# Mac 工作区编辑器尺寸修复候选

关联 #18、#65、#68；前置诊断 [#106](https://github.com/gewill/OpenCCman/pull/106) 的两份真实主线程栈已定位到 SwiftUI TextEditor 尺寸查询调用全容器布局。候选尚未通过完整应用、同机前后性能和真实 UI 媒体验收。

## 实现边界

Mac 的 `WorkspaceTextEditor` 以 `NSViewRepresentable` 包装系统 `NSScrollView` / `NSTextView`，视口不声明基于正文计算的 intrinsic size。原有工作区提供宽高，AppKit 排版可见文字。使用 TextKit 1，沿用 `WorkspaceScrollKeeper` 的局部布局与阅读锚点；不截断正文、不修改转换、文件、额度或窗口模型。iPhone/iPad 继续使用原有 SwiftUI TextEditor 与样式。

SwiftUI Binding 仍是正文来源，Coordinator 只桥接原生编辑事件并记录最近渲染值。无正文变化的布局/任务更新不改写 NSTextView，保留组合文字和选区。程序替换新正文时清除旧文稿的撤销操作；原文、结果各有独立 UndoManager，更新结果不清空原文撤销历史。比较使用 UTF-8 字节，不能用 Swift String 的规范等价比较跳过组合字符顺序改变。

视口和编辑器不保存在全局对象中；系统编辑器继续承担键盘、选择、撤销与查找。没有调用采样中出现的 SwiftUI 私有 API，也没有改动依赖或最低部署目标。

## 已检查与待验收

- 本地使用 macOS 11 部署目标编译独立原生回归，通过全文含 U+0000/CRLF/组合字符、键入和 Binding 回写、撤销/重做、组合文字在无关更新后的保留、选区、只读/禁用、独立撤销历史与程序换稿。
- SwiftUI NSHostingView 内的固定 420×240pt 尺寸查询保留 272 万字符的远端文字未排版。这只是无窗口的布局测试，不能代替真实应用延迟或可见内容验收。
- 工程检查通过 59 个 Swift 源文件及三语资源。
- [ ] macOS 15 的上述回归、完整应用构建和原生文稿/关窗协议。
- [ ] 同一机器、相同 Release 配置与语料的旧/新两版对照；原始样本和正确性检查保留。不同云端 runner 的结果不直接作为收益比例。
- [ ] Mac 真实界面前后截图/交互视频，记录尺寸、语言、主题和源提交；未附这些证据前不作为完成的 UI PR。
- [ ] 真实键盘、输入法、焦点、两轴切换、分隔条与滚动位置，转换/取消/导入导出时切换，以及浅深色/三语/大字号/VoiceOver。
- [ ] iPhone/iPad 回归；iOS 14/macOS 11 按用户要求保留为发布前验收，不能把编译目标当成系统运行验证。

参考：[Apple NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)、[尺寸测量接口](https://developer.apple.com/documentation/swiftui/nsviewrepresentable/sizethatfits(_:nsview:context:))。桥接只管理内部文稿视图，SwiftUI 管理顶层视口的 frame/bounds。

## 同机对照入口

App Regression 手动运行 `compare_workspace_editor=true`，固定旧版为 `cb73fc528b3c9d53dfc840b8ae48e1cae7426fcb`，候选为该次工作流完整 SHA。仅在 macOS CI runner 执行，两份隔离 checkout 先各自构建相同 Release / 双架构参数，再按 baseline → candidate 顺序运行同一完整 `--documents --active-anchor` 协议。依赖锁必须逐字相同；不采样、不录屏、不调用 CUA。使用临时 checkout，不切换开发工作区。

artifact `workspace-editor-comparison` 包含两份 app、构建日志、来源清单、原始 JSONL、固定导出文件及 `comparison.json`。分别列出 1/10 MiB 导入到驱动确认、转换到导出验证、原生引擎耗时、采样点峰值 footprint 和内核峰值 RSS。命令超时清理自有进程组，失败保留已有报告。

这是一组同 runner 的顺序对照，不是多机统计，也不是冷启动测量；顺序和系统缓存影响仍需保留说明。最终视觉呈现时间不由这些事件表示。成功运行后才补结果，不把入口创建或测试通过当作收益证明。
