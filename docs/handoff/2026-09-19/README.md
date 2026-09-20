# OpenCCman 工作交接 — 2026-09-19

> **2026-09-20 更新：本文的隐私主线已完成。** 隐私审核（RevenueCat 5.78.0 源码、官方文档、后台只读核对）、三语政策发布与 ASC 隐私标签发布读回见 [PR #125](https://github.com/gewill/OpenCCman/pull/125) 与 [#17 评论](https://github.com/gewill/OpenCCman/issues/17#issuecomment-5742739504)；结论与证据见 [审核文档](../../release/app-privacy-review-2026-09-16.md)。RevenueCat 后台未配置支持邮箱，带 RC User ID 的支持邮件不可达，最终采用“不关联身份”的标签；启用该邮箱前须先改标签。下文其余未完成项（最终签名包隐私报告、应用内链接改指新网站、#119、#122、#14/#16/#20）仍然有效。

## 接手目标

优先完成 #17 的隐私审核、三语政策及 App Store Connect（ASC）隐私标签发布与读回。用户已经明确授权这些发布，不需要重复确认。尚未完成，不得把草稿或源码分析记为线上验收通过。

本文件结合本任务历史和 2026-09-19 的 GitHub、依赖锁文件及本地状态检查编写；注明历史的运行证据未在本次重跑。

## 当前状态

| 项目 | 状态与证据 |
| --- | --- |
| 隐私审核 #17 | OPEN；尚未完成最终标签及发布读回 |
| ASC | 9 月 18 日实际读取到登录表单；9 月 19 日浏览器仍停留在带 `authResult=FAILED` 的登录 URL。已通知用户登录，未收到完成回复 |
| 当前依赖 | 9 月 19 日通过 GitHub API 读取 develop 的 Package.resolved：RevenueCat 5.78.0，`629a56ecef190469914b8f0914bf0446363eb09f` |
| 旧审核基线 | RevenueCat 5.64.0，`155ea739f45f54189ca83ee9088b373c1415d98b`；自动化提示尚引用此旧版本，不能直接当作当前版本结论 |
| PR #124 / #93 | PR 已 MERGED，merge SHA `efd591ddcd24d97522784d7652ed4eb0c4281e62`；历史记录：#93 已关闭 |
| PR #123 / #110 | PR 已 MERGED，merge SHA `65e609d29c767402b71e3d184c8711e3486710fa`；历史记录：#110 已关闭，后续发布分支验收归 #122 |
| #119 登录启动 | 9 月 19 日仍 OPEN；用户确认“可以开关正确的触发”，尚未回答是否覆盖退出并重新登录 |
| 开放 PR | 9 月 19 日查询为空；后续接手须刷新 |

## 工作区与证据入口

- 应用主工作区：`/Users/rxwill/git/MyApps/OpenCCman`，develop；存在用户未提交的 `OpenCCman.xcodeproj/project.pbxproj`，不得覆盖、重置或顺带提交。
- 隐私专用工作区：`/Users/rxwill/git/MyApps/OpenCCman-privacy-label-review`，`codex/privacy-label-review`；本次检查干净，HEAD `d809cbe`。这是旧基线，继续编辑前先核对与最新 develop 的差异。
- 审核草稿：上述隐私工作区的 `docs/release/app-privacy-review-2026-09-16.md`。
- 已有证据：`docs/release/metadata-2026-09-15/{revenuecat-observation.json,sdk-manifests.json,privacy-policy-proposal.md}`。
- 网站：`/Users/rxwill/git/MyApps/OpenCCman-website`；正式域名 `https://openccman.gewill.org`，三语 `site/{en,zh-Hans,zh-Hant}/privacy.html`，检查 `scripts/check.py`，部署 `deploy.sh`。
- 旧博客：`/Users/rxwill/git/blog`；先定位 OpenCCman 三语政策文件并读取该仓库规则，不猜测文件名。
- 本交接工作区：`/Users/rxwill/git/MyApps/OpenCCman-handoff-20260919`，`codex/docs-handoff-20260919`。

本地旧 SDK checkout 的 Git 对象不可用：`OpenCCman-gctycldcxbefvvbjuryxawbduslm/SourcePackages/checkouts/purchases-ios-spm` 在 9 月 19 日报告 alternate object path 缺失、bad object HEAD。源码文件仍在，但不能以此证明版本。使用独立临时 checkout 获取精确 SHA，不修复或修改依赖缓存。

## 已确认的产品与数据处理决定

- 保留 Customer Center 支持邮件中的 RC User ID。
- 无广告用途、无数据经纪商共享；未使用 Rico。
- Gmail 仅维护者本人访问，只用于支持，无固定普通邮件删除期限；不能把垃圾箱期限说成所有邮件保存期限。
- Slack 购买通知仅本人查看，免费方案默认保留；不推测具体天数或读取无关客户事件。
- 允许发布本轮隐私标签及三语政策；网站和旧博客必须一致。
- 域名已经验证，不再监测或修改 DNS。
- 此任务不授权应用发布、价格修改、发送支持邮件或读取无关客户数据。

## 审核尚需完成的事实链

1. 同时保留 5.64.0 历史发现和核实 5.78.0 最终行为，记录精确源码 SHA。
2. Customer Center 邮件：旧版 `ContactSupportUtilities.swift` 默认正文含 RC User ID、App Version、Device、OS Version、StoreFront Country Code；`CustomerCenterConfigDataSupport+URL.swift` 组装草稿，相关入口包括 SubscriptionDetailView、RestorePurchasesAlert。创建草稿不等于发送；还需证明本应用配置、永久购买场景下入口的实际启用条件。
3. 事件路径：追踪 `CustomerCenterViewModel.trackImpression`、`FeedbackSurveyViewModel.trackSurveyAnswerSubmitted` → CustomerCenterPurchases → Purchases.track，再核实队列、请求、字段、开关与生产启用条件。不能只因 SDK 存在事件代码就声明实际收集。
4. 区分随机 App User ID、Device ID 和设备型号；支持邮件可能把 RC ID 与发件地址关联，因此不能沿用旧草稿“匿名，所以不关联用户”的结论。
5. 结合官方定义决定购买历史、用户标识符、产品交互、支持邮件内容/联系信息等类别、用途和关联关系；可选支持信息是否可不披露，须逐条核对 Apple 的条件。
6. 只读核对 RevenueCat 项目配置，不查看客户列表或个别交易。2026-09-15 历史观察只有 Slack 活跃集成，有生产发送记录；这不是当前配置或具体字段的重新验证。

官方依据（继续审核时重新读取）：

- https://developer.apple.com/app-store/app-privacy-details/
- https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy
- https://www.revenuecat.com/docs/integrations/third-party-integrations/slack

## 建议接续顺序与完成条件

1. 在隔离工作区完成源码追踪及正式文档核对，形成“字段—触发条件—接收方—用途—身份关联—标签”的最终表；纠正草稿中重复询问发布许可、是否保留 RC ID、域名待验证的旧内容。
2. 检查 ASC 登录；未登录时等待已经提出的登录请求，不重复通知同一阻碍。若 RevenueCat 登录也失效，再明确请求该服务登录。
3. 同步网站及旧博客三语政策，检查翻译一致、链接有效、描述与实际配置一致；按各仓库规则分支、检查和提交。使用网站既有 deploy.sh，核实其参数和副作用。
4. 按已授权范围发布 ASC 隐私标签并读回；分别保存网站公开页面及 ASC 的发布后证据，不把“已保存草稿”写成已发布。
5. 更新 #17 和审核文档，列出精确版本、实际核验、未覆盖项与发布证据。只在验收满足后关闭相关 issue。
6. 更新自动化旧 SDK 基线；全部完成后停止该自动化，不留下重复巡检。

当前自动化 `openccman`（名称“完成 OpenCCman 隐私审核与发布”）仍 ACTIVE，每日 09:17。配置在 `~/.codex/automations/openccman/automation.toml`；通过 Codex automation 工具修改，不手写配置。状态未变保持安静，只通知完成、新实质故障或新人工操作需求。

## 其他未完成事项与验收边界

- #119：用户开关验证已记录在 https://github.com/gewill/OpenCCman/issues/119#issuecomment-5711341838 。待确认开启后重新登录自动启动、关闭后不启动；不得补造构建号或系统版本。历史还有外部系统设置状态回显验收项。
- #122：正式发布主线整合、真实 build 分支流程仍独立跟踪。禁止因交接或隐私任务推送 build 前缀分支。
- 历史签名 TestFlight 2.0(53)、CI、本地自动化通过，不等于 App Store 正式发布、真实新购买、最低系统或所有真机验收通过。
- 最低系统目前为 iOS 15 / macOS 12，产品版本 2.0。旧 1.3 / iOS 14 / macOS 11 文字不得作为新验收标准。
- #14 购买、#16 最低系统、#20 辅助功能/输入法等遗留验收须逐项读 issue；不能因相关 PR 已关闭就一并关闭。

日常 PR 目标 develop；每项新工作使用独立 codex/ 分支与工作区，遵循 docs/BRANCHING.md。UI 变化需真实前后截图，交互过程需视频；纯交接文档无需 Xcode 构建。本轮不运行或改变 VoiceOver 等系统测试设置。
