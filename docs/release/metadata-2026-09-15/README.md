# 1.3 发布资料与隐私核对（2026-09-15）

关联 [#17](https://github.com/gewill/OpenCCman/issues/17)。这是源码、API 与公开页面的核对记录及候选文案，**不是发布验收完成记录，也未更新 ASC 或博客**。

## 来源与版本边界

- 源码：`8dffd48326d01e8d77b151e5bda627d24b14ebcf`，`develop`。工程 marketing version 为 `1.3`、本地 build 为 `30`；本地数字不能代替 Xcode Cloud build 身份。
- ASC App：`6474449401` / `org.gewill.OpenCCman`。API 读取成功，完整相关 ID 与商品状态见 [source.json](source.json)。
- iOS 待提交版本：`2.0`，`17a9e553-7399-4e0c-97be-e1695f06b7d0`。
- macOS 待提交版本：`2.0`，`ca370499-5c15-4510-8a7e-36ef7ebff15d`。
- 两平台均为 `PREPARE_FOR_SUBMISSION`，没有 `1.3` 版本记录。保留现有草稿，需维护者确定 1.3/2.0 的处理方式；不得默认改名或覆盖。
- 本轮未选择、触发、关联或修改任何云端 build / TestFlight What to Test，也未提审、发布或通知测试者。最终发布仍须按 [Xcode Cloud 指南](../../XCODE_CLOUD.md) 绑定准确 source SHA、平台和 build。

[原始本地化快照](snapshot/)只保留应用公开字段，不包含鉴权、价格、审核联系人或私密审核说明。[候选文案](proposed/)按平台分开，沿用现有三语名称、副标题、支持及隐私链接；版本目录 `1.3` 表示计划版本，不代表后台已存在。

## 对照结果与具体修改

| 项目 | 实际证据 | 处理 / 剩余门槛 |
|---|---|---|
| 产品范围 | 两平台三语描述沿用 OpenCC 核心介绍，包含日本新字体；`ConversionConfiguration.options` 仅暴露七种中文组合 | 候选改为应用四预设及高级选项，不将引擎其他能力当成应用入口；明确简体不保证完整台湾词汇反向转换 |
| Mac 关键词 | 简、繁关键词都包含“拼音生成” | 候选删除无对应入口的关键词，改用中文转换及 TXT 等已有能力 |
| 文件工作流 | `TextFileService.maximumBytes = 10 * 1024 * 1024`；严格 UTF-8，去输入 BOM，导出无 BOM；大小限制没有 Pro 例外 | 三语写明单文件、10 MiB、BOM、Big5/GBK 需先转 UTF-8；不预告 #52 已可用 |
| Mac 跨 App | `GlobalShortcutService` 通过 Accessibility / 键盘复制粘贴处理文本，Services 依赖来源应用支持 | 改掉“任何应用均可”的绝对承诺；写清权限及只读/受保护字段限制。真实跨 App 验收继续在 #19/#22 |
| Pro 商品 | ASC SKU 与 `IAPManager.Sku` 都是 `ios_openccman_pro_lifetime_3`，`NON_CONSUMABLE` / `APPROVED`；三语均说明一次购买、终身使用 | 商品原文与类型一致，保持不变。应用文案具体说明解除每日主页额度及隐藏推荐；不承诺大文件。真实购买/恢复与 RC Offering 映射仍由 #14/#70/#71 验收 |
| 日额度 | `FreeFeature.maxTestNumber = 12`；`TestNumbersPerDayManager` 跨窗口预约、成功计次 | 候选仅描述主页额度，导入/导出/切换配置不计次；不改变 Services/快捷键规则 |
| Customer Center | iOS 15+ 用 RevenueCatUI；iOS 14 / 原生 macOS 用购买支持页 | 统一用户文案为“购买支持”，不把三端都宣传为 RevenueCatUI；#71 实际 UI 与购买路径验收未完成 |
| 隐私政策 | 三语公开页均仍为笼统的“不收集/上传隐私信息”，见 [HTTP 实测](public-policy-check.json) | 与购买 SDK 数据说明不充分对齐；已准备[三语候选替换段落](privacy-policy-proposal.md)，已核实 Slack 集成并补入候选；最终身份/用途确认后单独发布博客并复查 |
| 隐私问卷 | 首轮 CLI 无会话；后续网页登录成功，App Privacy 与详情都显示 **Data Not Collected**，Data Types 为 **Data is not collected from this app.** | [只读观察记录](questionnaire-observation.json)确认已发布声明与当前 1.3 候选的 RevenueCat 购买记录清单不一致。尚未修改问卷；最终用途、身份关联、追踪须结合 RC 后台核对 |
| 隐私清单 | app UserDefaults `CA92.1`；RevenueCat 声明购买记录用于功能、非身份关联、非追踪；IQKeyboardManagerSwift 声明无收集/追踪 | 见下节。SDK manifest 不代替问卷，也不能只看 app manifest 就选“无收集” |
| 权限文案遗留 | 初始审计在两配置发现 AppleScript 用途字符串，但当前快捷键用 CGEvent | 已由 [#88 / PR #89](https://github.com/gewill/OpenCCman/pull/89) 修正并合并。CI macOS Debug 实际 plist 逐字段比较仅删除该 key；[日志](https://github.com/gewill/OpenCCman/pull/89#issuecomment-5679485853)。最终 iOS Release / Cloud 产物仍待核对 |

## 数据与权限依据

本轮读取了锁定 checkout 的 SDK 清单，核实 checkout HEAD 与 `Package.resolved` 一致；结构与 SHA-256 保存于 [sdk-manifests.json](sdk-manifests.json)。排除 SDK 的 Examples/Tests 清单，不将它们视为应用依赖。

| 数据 / 权限 | 已核实源码 | 判断及限制 |
|---|---|---|
| 原文、结果、TXT | `ChineseConversionService` 在本机调用 OpenCC；`TextFileService` 使用系统文件 API | 未发现 app 源码将转换正文发送给 SDK/服务器；这是源码审查，未进行本次发布包网络抓取 |
| 本地设置 / 额度 | `UserDefaultsKeys`、`TestNumbersPerDayManager`；app manifest `CA92.1` | 与本地偏好和额度使用一致；不由“本地设置”推导整个应用无网络 |
| 购买记录 | RevenueCat **5.64.0**，SHA `155ea739f45f54189ca83ee9088b373c1415d98b` | SDK manifest 有 PurchaseHistory / AppFunctionality。官方问卷指南还要求按实际使用声明 Analytics；不能逐字照抄 manifest 为后台答案 |
| 用户标识 / 联系信息 | `Purchases.configure(withAPIKey:)` 未传自定义 appUserID；app 未找到 `logIn`、`setAttributes`、广告标识采集调用 | 当前代码使用 SDK 匿名用户路径；已核实当前 Active 集成仅 Slack，Auth 为申请开通页；这不能排除历史或外部身份关联，最终答案仍需维护者确认 |
| SDK 请求信息 | 锁定 RevenueCat 的 `HTTPClient.defaultHeaders` 发送平台、设备及应用版本等头；`IdentityManager` 生成匿名 ID | 候选政策补充购买服务技术信息。请求字段不等于全部后台留存类型，需继续核实后台实践 |
| 网络 | macOS `network.client = true`；RevenueCat proxy 在 configure 前设为 `https://api.rc-backup.com/` | 用于购买服务；不宣称整个 app 离线。RC 后台数据实践不能从 app entitlement 反推 |
| 文件 | macOS `app-sandbox` 与 `files.user-selected.read-write`；`TextFileService.OpenFile` 成对开始/结束 security-scoped 访问 | 用户选择的文件读写用途一致；最终签名 Cloud 产物的实际打开/保存仍为发布门槛 |
| 辅助功能 / 剪贴板 | `GlobalShortcutService` 检查 AXIsProcessTrusted、复制/替换选文并有剪贴板归属保护 | 解释为用户主动快捷键操作；不声称是 AppleScript 权限，也不承诺所有来源 App 可用 |

官方依据（2026-09-15 查阅）：[Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) 要求涵盖集成的第三方实践；[RevenueCat Apple App Privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy) 说明购买记录披露及使用匿名 ID、后台集成时的判断边界。应用清单、SDK 清单、ASC 问卷和公开政策是四项不同证据。**本次未生成最终签名包的 Xcode 聚合隐私报告**，不得以 checkout 清单代替资源打包验收。

## 文件用途与应用流程

- `snapshot/{ios,mac}`：2026-09-15 读取的 2.0 草稿三语 app-info/version 元数据。
- `proposed/{ios,mac}`：三语 1.3 候选 description、keywords、whatsNew；app-info 与 URL 不变。
- `privacy-policy-proposal.md`：供博客维护任务采用的三语替换段落，尚未部署。
- `validation.json`：本地 schema、字数、链接校验与保留字段检查；不是后台已写入或发布验证。
- `revenuecat-observation.json`：登录后的集成、Auth、恢复和 Rico 访问设置观察，仅保留配置事实；不保存 Webhook、客户记录或交易数据。
- `questionnaire-observation.json`：后续登录后的 App Privacy 只读观察，包含原始标签文字。`source.json` 保留首轮 CLI/登录失败状态以说明取证顺序；不将旧“未读”状态当作当前结论。

两平台离线 schema/字符限制检查共 12 文件通过，无错误、无警告。`--check-urls` 在当前环境产生 6 个“target is not a public internet address”警告，保留原结果，未算作链接校验通过；单独对这 3 个已知公开 URL 执行 HTTP GET 均为 200，最终 URL 不变且三语隐私锚点存在（见 `public-policy-check.json`）。这只能验证链接可达，不能验证隐私内容准确。未修改网络设置或放宽 CLI 的地址检查。

复查命令（先使用 `asc ... --help` 确认当前 CLI 语义）：

```sh
asc metadata validate --dir docs/release/metadata-2026-09-15/proposed/ios
asc metadata validate --dir docs/release/metadata-2026-09-15/proposed/mac
```

确认发布版本和准确可写 AppInfo/version ID 后，重新拉取该记录，审查远端变化，将候选合并入新快照，再按平台执行 `asc metadata push ... --dry-run`。本轮因 1.3 记录不存在，**未运行 push / dry-run**；不得将本地版本目录直接改成 2.0 后上传以规避确认。隐私问卷和博客更新独立核实、执行并留证，不随元数据 PR 合并自动生效。

## #17 关闭前剩余事项

- [ ] 维护者确认 1.3 与现有两平台 2.0 草稿的处理方式，绑定最终版本和 Cloud build。
- [x] 登录读取实际问卷：已确认发布标签为 Data Not Collected，尚未修改。
- [x] 只读核实 RC 当前集成、Auth、恢复行为及 Rico 访问设置，补充 Slack 三语候选披露。
- [ ] 确认后台之外的身份关联/广告用途、Slack 保留与访问范围、Rico 实际使用，将最终问卷与政策对齐。
- [ ] 在博客任务中发布三语隐私修订，清理同页面过宽的产品/Services 介绍，再验证原 URL 和锚点。
- [x] 清理遗留 Apple Events 用途字符串并核查 CI macOS Debug 生成 Info.plist（#89）；保持现有辅助功能权限流程。最终 iOS Release / Cloud 核查仍在下一项。
- [ ] 对最终签名 Cloud 产物检查依赖清单资源与聚合隐私报告，完成文件/跨 App/购买门槛。
- [ ] 对确定版本完成最新快照、dry-run、后台文案更新及读回，记录准确 SHA/build；核对 #71 等仍待验收功能是否实际纳入该 build。

最低 iOS 14 / macOS 11 验收按用户决定保留为发布前项目；本报告不关闭这些门槛，也不关闭 #17。

## 登录后的问卷修正候选（尚未发布）

| 问卷项 | 当前发布值 | 候选与证据边界 |
|---|---|---|
| 是否收集数据 | 否 | 应包含购买记录；当前 1.3 候选的 RevenueCat SDK 明确声明 PurchaseHistory |
| 购买记录用途 | 无 | App Functionality（权益验证）与 Analytics（已可用的 RC 分析、Slack 销售通知）纳入候选；不推定额外广告用途 |
| 与身份关联 | 无对应数据项 | app 使用匿名 ID，Auth 无已配置提供方；如维护者确认不与联系信息或其他来源关联，可按 RC 指南选“否”，否则须重新评估标识符 |
| 用于追踪 | 无对应数据项 | app 源码未发现广告标识采集，当前 Active 集成仅 Slack；待确认不存在外部广告追踪用途后确定答案 |

隐私声明是 App 层级资料，与当前 2.0 草稿是否改为 1.3 是两个问题。登录成功不等于授权发布尚未核实的答案；本轮只读取预览/详情，没有点 Edit、Save 或 Publish。后续需完成后台核对，将准确答案和政策段落作为具体结果确认，再执行发布与读回。

## RevenueCat 登录后补充核对

当前 Active 区仅列出 Slack；详情中沙盒事件未启用，生产事件存在 Sent 记录。依据 [RevenueCat Slack 官方说明](https://www.revenuecat.com/docs/integrations/third-party-integrations/slack)，通知可包含购买事件、应用用户标识、商品和收入，因此三语政策已补充开发者 Slack 销售通知。没有发送测试事件，也没有修改集成。

Auth 显示 Beta 申请开通页。项目恢复行为为 Transfer to new App User ID，沙盒沿用同一行为，测试权益允许 Anybody；这为 #14/#70 的恢复测试提供配置背景，不能代替购买验收。Rico 访问设置为 Read & write with permission，仅表示允许的权限，不证明实际发送过客户数据；本轮没有使用 Rico。

[配置观察](revenuecat-observation.json)有意排除 Webhook、客户 ID、事件内容、交易数值和工作区信息；无需将这些私密数据上传 GitHub 来证明当前配置。没有查阅客户详情，不能把“当前代码匿名”扩大成“所有历史用户均无法关联”。最终披露仍待维护者确认外部实践，博客及 ASC 均未改动。
