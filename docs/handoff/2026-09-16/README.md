# OpenCCman 工作交接 — 2026-09-16

> 这是接手工作快照，不是发布完成报告。目标仍是按依赖完成 1.3 开发与验收；自动推进已停在人工确认节点。创建本交接 PR 前，14 个开放 PR 的最新 App Regression 全部成功，7 个为 Draft；可选 job 的 skipped 不计作通过。精确查询时间、完整 SHA、CI 链接、开放 Issue 和最近合并记录见 [GitHub 快照](github-state.json)。后续操作须重新查询，不能将本快照当作永久状态。

## 1. 接手后先做什么

1. 读本页的人工待办及现场保护事项；不要先清理 worktree、模拟器或旧 build 分支。
2. 核对 GitHub 最新 PR head/base、必需检查和维护者新回复。本文基线为远端 `develop@10a29785ccaafe38cc2451cbbb1693b264c60a4a`（#114 merge commit），默认分支仍为 `main`。
3. 最优先取得 **#90 是否按诊断工具范围先合并**的明确答复。收到答复前保持 Draft；不能将“继续”“梳理进度”或本次保存 handoff 解释成接受范围变更。
4. 若允许 #90 单独合并，检查候选和验收范围后，按 #90 → #101 → #102 → #103 → #104 → #105 → #106 顺序处理；每次保留 merge commit、核对祖先关系，父 PR 合入后调整子 PR 目标到 develop。#108 的产品 UI 验收独立保留，不因前置测试合并而自动放行。
5. UI 链为 #74 → #76 → {#77, #78}；#81、#96 独立。未完成的真实交互和发布验收继续留在对应 Issue。
6. 若没有人工回复或外部状态变化，停在明确阻塞处；不反复重建、修改验收口径或复制相同状态报告来代替进展。

## 2. 仍然有效的约束

- 日常任务新建 `codex/` 分支和隔离 worktree，最终 PR → `develop`；不修改有未提交改动的主工作区。遵循 [分支规范](../../BRANCHING.md)。
- 必需 CI、父依赖和已约定的实际验收全部通过才合并；不使用 admin bypass，不强推。堆叠依赖采用 merge commit。
- UI Issue/PR 展示界面时附真实截图，展示交互时附视频，使用 `gh` 上传；优先前后并排表，注明平台、窗口尺寸、主题、语言、字号、输入与来源 SHA。设计稿、AX 标签、发出点击请求均不等于实际验收。
- 保留 iOS 14/macOS 11、精确依赖、商品/价格/付费入口、每窗口业务模型、每日 12 次主页额度及文件规则。导入/导出/切布局不扣次；取消只保证停止接收迟到结果，不声称中断正在运行的 C++。
- 10 MiB 仍为当前单 TXT 容量边界，Pro 也受限。超过 10 MiB 的 Pro 工作流由 #52 跟踪，尚未实现；批量/Shortcuts/OCR 等后续事项不纳入本轮完成声明。
- 正式打包使用 Xcode Cloud，`build*` 推送会触发打包。本轮不推 `build*`、不发布/提审、不接入 ci-config；上游协调器仍每周一 09:17（UTC+8），用户已取消新增每日调度。
- 实际购买、最低系统、发行签名、TestFlight 与 App Review 是独立门槛。本地 StoreKit、ad-hoc 包或 CI 通过不能替代。
- 测试前记录、测试后精确恢复设置，尤其 VoiceOver。UI 操作使用当前允许的 CUA 入口；不要绕过失效的 UI 工具去用未授权外部输入驱动。

## 3. 已交付与本次新增成果

| 工作 | 当前结论与证据 |
| --- | --- |
| 1.3 预设、单 TXT、跨窗口额度、三端工作区 | 实现已进入此前开发主线；完整 UI/发布矩阵仍由 #11、#45 和各子 Issue 跟踪，不能按“有代码”全部勾选。入口见 [工作区验证](../../validation/adaptive-workspace/README.md)。 |
| 用户中心基础与 StoreKit | #72/#73 已合并；iOS 15+ 使用官方 RevenueCatUI，原生 macOS/iOS 14 使用兼容入口。#71 仍有运行时验收，#14 保留真实交易验收。 |
| macOS 27 适配 | #99 已合并，恢复旧 Introspect 版本列表跳过的编辑器/窗口回调；#98 的更广泛验收仍开放。 |
| 生命周期证据 | #94/#100/#109/#114 已合并，分开观察模型、窗口和宿主，并补充分配栈。它们是诊断证据，不是 #93 已修复。 |
| 隐私和权限说明 | #87/#89/#91 已合并审计/候选文案及无用 AppleScript 用途字符串清理；未发布博客政策或修改 ASC 问卷。 |
| 分支和工具链 | #111/#112 已记录迁移和 main/develop 分支保护；#113 提供 Xcode 27/RevenueCat 兼容复现。#107/#110 尚未闭环。 |
| 最新 #77 回归 | `609bdade4a416af369875c5361723587513f18fe` 增加真实 HomeViewModel 的窗口定向通知回归，完整 App Regression 35042881145（含 StoreKit、macOS 构建）成功。见 [#19 验证评论](https://github.com/gewill/OpenCCman/issues/19#issuecomment-5690562753)。 |

#77 新测试覆盖两个明确窗口目标、未绑定模型拒收、Services/快捷键结果隔离、NUL/CRLF/组合字符、导出快照、仅原文替换、缺字段保护和额度不变。测试直接绑定两个不显示的 NSWindow 并投递通知，**不覆盖** AppDelegate 选窗/等待队列、MainWindowReader 自动绑定、NSPerformService 或系统菜单。它已纳入该分支的 `python3 scripts/check-core.py`；develop 尚未包含本测试。

旧 `eab5003` Services 实测虽返回正确字节，但已有窗口未更新；旧 RootView 只列 macOS 11–26，本机 27 会跳过窗口绑定。当前候选已继承 MainWindowReader，需重新实测，不能把旧结果当当前版本通过或失败。

## 4. 待合并 PR 与依赖

下表状态来自本次快照；“非 Draft”也不等于依赖与验收已满足。完整 head SHA/分支名在 JSON 与后面的本机工作区表中。

| PR | 状态 | HEAD | 当前目标 | App Regression | 剩余门槛/用途 |
| --- | --- | --- | --- | --- | --- |
| [#74](https://github.com/gewill/OpenCCman/pull/74) | Draft | `919e0e6` | `develop` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35037722257/job/104610476783) | 真实大字号、连续缩放录像、多显示器；#57 |
| [#76](https://github.com/gewill/OpenCCman/pull/76) | 非 Draft | `b48e0de` | `codex/mac-window-sizing` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35037859477/job/104610901402) | 等待 #74；#75 |
| [#77](https://github.com/gewill/OpenCCman/pull/77) | Draft | `609bdad` | `codex/settings-sheet-locale` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35042881145/job/104626331971) | 等待 #76；真实 Services/快捷键/状态栏入口；#19 |
| [#78](https://github.com/gewill/OpenCCman/pull/78) | Draft | `8ec94df` | `codex/settings-sheet-locale` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35038043011/job/104611465475) | 等待 #76；iPhone 最大辅助字号设置面板；#49/#50 |
| [#81](https://github.com/gewill/OpenCCman/pull/81) | Draft | `9d9b629` | `develop` | [通过](https://github.com/gewill/OpenCCman/actions/runs/34960015426/job/104351105674) | 真实 Services 菜单与应用回写；#22/#19 |
| [#90](https://github.com/gewill/OpenCCman/pull/90) | Draft | `397eaf8` | `develop` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35032158249/job/104592893464) | 诊断工具单独合并的范围确认；#18/#93 |
| [#101](https://github.com/gewill/OpenCCman/pull/101) | 非 Draft | `cd18ad7` | `codex/native-window-lifecycle` | [通过](https://github.com/gewill/OpenCCman/actions/runs/34995909429/job/104472399347) | 等待 #90；观察方法对照 |
| [#102](https://github.com/gewill/OpenCCman/pull/102) | 非 Draft | `da6b30b` | `codex/native-window-ax-control` | [通过](https://github.com/gewill/OpenCCman/actions/runs/34999487090/job/104484039505) | 等待 #101；三轮模型身份验证 |
| [#103](https://github.com/gewill/OpenCCman/pull/103) | 非 Draft | `09e61b2` | `codex/native-window-three-cycles` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35005389513/job/104503728225) | 等待 #102；文稿与活动关窗 |
| [#104](https://github.com/gewill/OpenCCman/pull/104) | 非 Draft | `66f0dd8` | `codex/native-document-lifecycle` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35008756321/job/104515825046) | 等待 #103；系统文件面板证据，非分发签名 |
| [#105](https://github.com/gewill/OpenCCman/pull/105) | 非 Draft | `77b2083` | `codex/native-file-panel-validation` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35012456266/job/104527522861) | 等待 #104；保留窗口转换中关闭另一窗 |
| [#106](https://github.com/gewill/OpenCCman/pull/106) | 非 Draft | `cb73fc5` | `codex/retained-active-window` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35015868592/job/104539007621) | 等待 #105；实际主线程阶段栈 |
| [#108](https://github.com/gewill/OpenCCman/pull/108) | Draft | `c8cd2f3` | `codex/profile-document-stages` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35029843807/job/104585510384) | 等待 #106；输入法/VO/任务中布局等实际验收 |
| [#96](https://github.com/gewill/OpenCCman/pull/96) | Draft | `7eae4db` | `develop` | [通过](https://github.com/gewill/OpenCCman/actions/runs/35039166994/job/104614932234) | iOS 官方组件三语、跨窗口、加载/恢复/表单；#71 |

#90 的原始交付是诊断基础，后续 PR 描述扩大为等待 #93 根因和发布验收后才解除 Draft。当前已有明确的范围确认问题待答复；不要默默删除条件。若范围获批，#18/#19/#93 和最低系统/签名门槛仍开放。

## 5. 性能进度：收益、来源和不能推导的结论

### 5.1 原生编辑器候选 #108（未合并）

真实主线程栈将长等待定位到 SwiftUI TextEditor 尺寸查询引发全文排版。候选用 NSViewRepresentable 包装系统 NSScrollView/NSTextView，由工作区决定视口，沿用 TextKit 1 局部排版。后续修复变宽时阅读锚点；不重写引擎。

最新产品源码 `d8bcb5c7c08e86347f739aa9f8a4791caf965164`；PR HEAD `c8cd2f3` 的后续提交补文档/证据。固定 10 MiB、同一 runner 顺序对照 `cb73fc5` → `d8bcb5c`，来源 [35025165546](https://github.com/gewill/OpenCCman/actions/runs/35025165546)：

| 指标 | 旧版两次操作 | 候选两次操作 |
| --- | ---: | ---: |
| 导入到驱动就绪 | 20,977–22,829 ms | 175–181 ms |
| 转换到导出验证 | 23,177–24,074 ms | 472–478 ms |
| 原生转换调用 | 209–258 ms | 213–226 ms |
| 采样峰值 footprint | 441,815,040 bytes | 169,250,368 bytes |
| 内核峰值 RSS | 771,588,096 bytes | 309,673,984 bytes |

两版各五份输出下载后逐字节复核；BOM 去除、NUL/CRLF/组合字符保留；活动关窗场景通过，CI 最终 +5/+20 秒零模型、零预约。它是一组固定配置/语料的顺序实验，含缓存/顺序影响，**不是**冷启动、像素呈现、七配置、所有文稿或发行包收益。不要混用首轮 `b0addf7` 的 108–113 ms 数值与最新候选比较额外成本。

[完整报告（固定证据提交）](https://github.com/gewill/OpenCCman/blob/eb2dd51/docs/performance/native-editor-sizing.md)、[#108 真实前后截图/视频](https://github.com/gewill/OpenCCman/pull/108)。真实键盘输入、撤销/重做、结果只读、转换/导出、非法编码保稿已有记录；中文输入只得到 ASCII，不能算 IME 成功；VoiceOver 导航/朗读/激活未可靠完成。设置返回回到顶部，也没有被记作阅读位置保留通过。录屏 ScreenCaptureKit -3822 失败保留，不是应用崩溃证明。

### 5.2 关窗后的宿主持有 #93（未闭环）

- 旧多窗口观察出现 3/5/7 活模型，不能脱离 AX 查询/录制条件推广为生产无界泄漏。#101/#102/#103 的观察方法对照中，无额外 AX/录屏路径可释放新增模型；实际任务/文稿测试与纯空窗测试分开记录。
- #114 的同二进制最小程序对照：查询两窗，最终 2 模型/0 weak 窗口/2 weak 宿主；只查询首窗，第二窗释放，最终 1/0/1。每条件一次，不是统计性因果结论。
- 明确 strong capture 的闭包分配栈追到 `NSView._commonAwake` → `NSNotificationCenter.addObserverForName` → `_Block_copy`；发生于视图创建，不能称为 AX 创建了闭包。registrar 至 block 的完整强边和系统清理时机尚未证明。
- 实际应用诊断源码 `b0addf7` 也见同一栈，零可见窗后 55.099 秒捕获；它没有 weak NSWindow 采样，不能说窗口对象已释放，也不是当前 develop 全量验收。
- [已合并原始证据](../../performance/weak-window-hosts/README.md)。不通过清空文稿、伪造 deinit 或隐藏指标作为性能修复。

## 6. 人工待办与恢复条件

| 项目 | 具体需要什么 | 答复后怎么继续 |
| --- | --- | --- |
| #90 合并范围 | 是否允许仅按诊断工具交付先合并，完整产品/发布门槛继续留 Issue | 重新核对候选、检查与依赖，按第 1 节顺序处理；#108 继续独立验收 |
| #93 Apple Feedback | 是否授权将已准备的最小源码、合成日志和分配栈发送 Apple | 仅发送批准范围，保留提交 ID；无授权不提交，不附原始 memgraph/sysdiagnose |
| #78 模拟器接力 | 在 DeviceHub 选择 “OpenCCman Inspector QA 20260916”，打开 Inspector After，点 Conversion settings 后告知已打开 | 继续最大辅助字号设置面板/Segment 验收，结束后恢复该设备 large/light 并清理自有资源 |
| #20/#71 输入法/VO | 物理键盘完成中文组合输入、VoiceOver 顺序/朗读/激活对照 | 记录真实行为、截图/视频；VO 和键盘/输入法恢复原值 |
| #19/#81 系统入口 | 在已保留基线完成 Services 菜单启用/选项及零窗入口的实际操作 | 同条件候选对照，核对目标窗口、结果、重复请求；不重新激活基线来“观察零窗” |
| #110 ASC | 在保留的 OpenCCman ASC 登录页完成重新登录 | 只读核对 Cloud 构建/source/artifact 映射，之后再处理历史 build 引用；当前不删除 build |
| #17 隐私/版本 | 外部身份/广告关联；Slack 保留/访问及 Rico 实际使用；源码 1.3 与 ASC 草稿 2.0 的版本决定；政策发布/后台更新确认 | 依据实际用途修正文案/问卷并读回，最终签名包聚合报告；不能把 RevenueCat 已登录当作这些问题的答复 |
| #14/#15/#16 发布验收 | 真实 Sandbox/TestFlight 购买恢复/退款撤销、分发签名文件与跨 App 权限；最低系统环境 | iOS 14/macOS 11 用户明确暂无环境，保留发布前门槛；本地 StoreKit/ad-hoc 不代替 |

已核实的 RevenueCat 配置是 Active 仅 Slack，未见启用的分析/归因集成；源码匿名 ID 不证明历史或后台外没有身份关联。ASC 实际问卷是 Data Not Collected，与 RevenueCat 购买数据不一致；三语政策候选已入库但未发布。见 [隐私审计](../../release/metadata-2026-09-15/README.md) 和 [#17](https://github.com/gewill/OpenCCman/issues/17)。保留浏览器中的 RevenueCat 登录，不访问/公开客户交易或密钥。

## 7. 本机工作区和证据位置

以下目录均与主仓 `OpenCCman` 同处 `MyApps/`；实际根目录请接手者自行定位。不要复制整个 `.build` 到仓库或公开附件。

| PR | 分支 | 同级 worktree 目录 |
| --- | --- | --- |
| #74 | `codex/mac-window-sizing` | `OpenCCman-window-sizing` |
| #76 | `codex/settings-sheet-locale` | `OpenCCman-settings-locale` |
| #77 | `codex/closed-window-entries` | `OpenCCman-window-entries` |
| #78 | `codex/inspector-label-layout` | `OpenCCman-inspector-layout` |
| #81 | `codex/services-wait-benchmark` | `OpenCCman-services-benchmark` |
| #90 | `codex/native-window-lifecycle` | `OpenCCman-native-window-lifecycle` |
| #101 | `codex/native-window-ax-control` | `OpenCCman-native-window-ax-control` |
| #102 | `codex/native-window-three-cycles` | `OpenCCman-native-window-three-cycles` |
| #103 | `codex/native-document-lifecycle` | `OpenCCman-native-document-lifecycle` |
| #104 | `codex/native-file-panel-validation` | `OpenCCman-native-file-panel-validation` |
| #105 | `codex/retained-active-window` | `OpenCCman-retained-active-window` |
| #106 | `codex/profile-document-stages` | `OpenCCman-profile-document-stages` |
| #108 | `codex/native-editor-sizing` | `OpenCCman-native-editor-sizing` |
| #96 | `codex/customer-center-locale` | `OpenCCman-customer-center-locale` |

| 其他本机材料 | 位置/注意事项 |
| --- | --- |
| #114 已合并证据与反馈草稿 | `OpenCCman-host-allocation-stacks`，HEAD `2bc2f6c`；不要复用已合并分支做新修改 |
| Apple 报告 | `OpenCCman-host-allocation-stacks/.build/apple-feedback-draft/REPORT.md` |
| Apple ZIP | `OpenCCman-host-allocation-stacks/.build/OpenCCman-93-Apple-feedback-draft.zip`，20,587 bytes / 17 files；SHA256 `56e050f6836eae69756f1f32772d2ff3f1c41dbed9e56f4931d743bbd71bd9ea`（本次重新核对） |
| 私有真实应用内存图/采样 | `OpenCCman-host-allocation-stacks/.build/native-stack-runtime`；原始 memgraph 不公开 |
| 私有最小程序配对 | `OpenCCman-retention-reference-analysis/.build/host-stack-origin`、`.build/host-stack-control` |
| #78 接力协议/设备/输入失败记录 | `OpenCCman-inspector-layout/.build/inspector-phone-runtime` |
| #77 最新本地/CI 原日志 | `OpenCCman-window-entries/.build/window-notifications`；公开精简验证记录在该 PR 的 `docs/validation/window-entries/2026-09-16-notifications/` |
| #108 运行/录屏/失败与清理 | `OpenCCman-native-editor-sizing/.build/`；公开证据从 #108 报告和媒体链接进入 |

Apple ZIP 只包含最小源码、构建脚本、合成日志、选定分配栈及校验信息，没有真实文稿、客户数据、二进制、原始 memgraph 或 sysdiagnose。构建/签名验证成功，但保留源码原有两条 actor isolation warning；新打包 helper 未运行复现，不能称新 bundle 已验证。没有 Apple Feedback ID，尚未提交。

主工作区停在本地 `develop@03d687c`，有未提交的 `project.pbxproj`、`Package.resolved` 和未跟踪 `xcshareddata/`。本次只 fetch 和创建隔离工作区，不 stash/reset/切分支；不应直接拿主工作区构建当作最新远端候选。`git worktree list` 含失效的历史临时路径，**不要批量 prune/remove**，须另行确认材料归属与备份。

## 8. 保留现场：避免接手时破坏

### 应用和系统设置

- `org.gewill.OpenCCman.PRValidation` 是等待 #19 人工验收的零窗口基线；不要 `getApp`、AX 查询、重启或退出，它们可能重新激活/重开窗口，破坏观察条件。
- 用户 Applications 下的 `OpenCCman Services Probe eab5003.app` 保留原状，不移动/注销/修改。
- #93/#114 新诊断应用此前已退出、偏好恢复、改名 `.app.inactive`；不要为检查状态而重新打开。
- VoiceOver 最后清理读回为关闭；键盘导航/输入法已恢复。本次交接未修改它们，接手后不要凭旧值覆盖用户的新设置。
- DeviceHub 不重启、不强杀；不操作其他项目的设备或 ASC 页面。

### 模拟器与镜像（本次只读重新核对）

| 设备 | UDID | 快照状态/所有权 |
| --- | --- | --- |
| OpenCCman Inspector QA 20260916，iPhone 15 Pro Max / iOS 18.6 | `C82FB756-F651-4D2E-BB1B-2A08F6B148D7` | Booted；本任务临时设备，待手工打开设置 |
| OpenCCman Phone UI acceptance | `587CD82A-2F47-4638-9B45-CAEF56409616` | Booted；先前人工验收现场，不操作 |
| OpenCCman Sizing iPad | `B5A3C81A-D1BF-4F70-AEB3-F7DEB8122C43` | Shutdown；先核对归属再用 |
| Relationship Layout Resizable | `FF115909-042D-49AE-B9D8-711808946622` | Shutdown；其他项目，不操作 |

Inspector QA 的字号为 `accessibility-extra-extra-extra-large`、浅色；原值为 large/light。`serve-sim 0.1.46` 镜像在 `http://localhost:3200/`，本次监听进程 PID 5935。PID/工具会话是临时标识，清理前必须重查所有者和设备绑定，禁止按旧 PID 盲杀或全局 killall。

镜像 Event Log 记录过触摸，但应用按钮和 SpringBoard 图标均未响应；Home 指令能工作。08:49 的最后重试仍未打开设置。因此是尚未解决的输入路径问题，不能归因 #78，也不继续重复同一点击。镜像字号滑杆曾显示 3，但实际 simctl 和画面为最大辅助字号，不能用滑杆读数替代实机状态。

保留浏览器页：OpenCCman RevenueCat Integrations（已登录）、OpenCCman ASC（上次为登录页）、localhost 模拟器镜像；另一 ASC 页属于 Relationship-SwiftUI，不导航/编辑它。跨任务不要假定 tab ID/REPL 变量可复用，重新枚举匹配页面。临时页面若由工具管理，结束当前轮时按该工具规则保留接力标记。

完成接力后，仅对本任务拥有的 Inspector QA 设备恢复 large/light、停止对应镜像 helper、清理本任务 bundle/临时设备并关闭镜像页；其余页面/设备保持原状。清理前确认不再承担人工接力，记录实际恢复结果。

## 9. 接手验证与交付方法

先只读刷新，避免操作过时的 head：

```bash
gh pr list --repo gewill/OpenCCman --state open --limit 100
gh pr view 90 --repo gewill/OpenCCman --json headRefOid,baseRefName,isDraft,statusCheckRollup,body
gh pr checks 77 --repo gewill/OpenCCman
git worktree list --porcelain
git -C ../OpenCCman-window-entries status --short
```

有代码改动时在对应候选上运行相关检查，而不是修改后复用旧日志。例如 #77 的 `python3 scripts/check-core.py`、`bash scripts/check-window-reopen.sh`；UI/编辑器变更还要实际运行并补同条件媒体。合并父 PR 后重新核对 base、diff、冲突与实际 HEAD；集成产生新代码必须重新验证。CI 排队时可做无依赖事项；不因等待而重复触发同一构建。

本 handoff 是纯文档任务：[本地验证记录](validation.json)包含 JSON、PR 行与来源、相对链接、附件 ZIP 校验和；另已运行 `git diff --check`。无需为此本地重跑 Xcode 或启动模拟器。创建文档 PR 后报告 CI 状态，不把创建 handoff PR 当作 #90 授权或发布许可。

仍未结束的范围以 [#11](https://github.com/gewill/OpenCCman/issues/11)、[#45](https://github.com/gewill/OpenCCman/issues/45)、各 PR/Issue 最新验收清单为准。不要因为文档已保存、候选 CI 绿色或已有截图就自动关闭跟踪 Issue。
