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
| 隐私政策 | 三语公开页均仍为笼统的“不收集/上传隐私信息”，见 [HTTP 实测](public-policy-check.json) | 与购买 SDK 数据说明不充分对齐；已准备[三语候选替换段落](privacy-policy-proposal.md)，需核实 RC 后台集成并单独发布博客后复查 |
| 隐私问卷 | `asc web privacy pull` 返回缺少 cached web session；浏览器跳到 Apple 登录页 | **未读到问卷，不推断当前答案**。等待网页登录；购买信息、用途、身份关联及追踪逐项核对后才能关闭 |
| 隐私清单 | app UserDefaults `CA92.1`；RevenueCat 声明购买记录用于功能、非身份关联、非追踪；IQKeyboardManagerSwift 声明无收集/追踪 | 见下节。SDK manifest 不代替问卷，也不能只看 app manifest 就选“无收集” |
| 权限文案遗留 | pbxproj 两配置仍含 `NSAppleEventsUsageDescription = ... execute AppleScript`；app Swift 未找到 AppleScript/Apple Events 调用，当前快捷键用 CGEvent | 记录为待清理差异，未把 Accessibility 改写成 Apple Events。后续独立移除过时 key，并检查生成的两平台 Info.plist 与实际快捷键；本 PR 不改工程 |

## 数据与权限依据

本轮读取了锁定 checkout 的 SDK 清单，核实 checkout HEAD 与 `Package.resolved` 一致；结构与 SHA-256 保存于 [sdk-manifests.json](sdk-manifests.json)。排除 SDK 的 Examples/Tests 清单，不将它们视为应用依赖。

| 数据 / 权限 | 已核实源码 | 判断及限制 |
|---|---|---|
| 原文、结果、TXT | `ChineseConversionService` 在本机调用 OpenCC；`TextFileService` 使用系统文件 API | 未发现 app 源码将转换正文发送给 SDK/服务器；这是源码审查，未进行本次发布包网络抓取 |
| 本地设置 / 额度 | `UserDefaultsKeys`、`TestNumbersPerDayManager`；app manifest `CA92.1` | 与本地偏好和额度使用一致；不由“本地设置”推导整个应用无网络 |
| 购买记录 | RevenueCat **5.64.0**，SHA `155ea739f45f54189ca83ee9088b373c1415d98b` | SDK manifest 有 PurchaseHistory / AppFunctionality。官方问卷指南还要求按实际使用声明 Analytics；不能逐字照抄 manifest 为后台答案 |
| 用户标识 / 联系信息 | `Purchases.configure(withAPIKey:)` 未传自定义 appUserID；app 未找到 `logIn`、`setAttributes`、广告标识采集调用 | 当前代码使用 SDK 匿名用户路径；RC 项目后台集成、历史身份关联及 Customer Center 配置未核实，最终“是否关联身份”仍需核对 |
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

两平台离线 schema/字符限制检查共 12 文件通过，无错误、无警告。`--check-urls` 在当前环境产生 6 个“target is not a public internet address”警告，保留原结果，未算作链接校验通过；单独对这 3 个已知公开 URL 执行 HTTP GET 均为 200，最终 URL 不变且三语隐私锚点存在（见 `public-policy-check.json`）。这只能验证链接可达，不能验证隐私内容准确。未修改网络设置或放宽 CLI 的地址检查。

复查命令（先使用 `asc ... --help` 确认当前 CLI 语义）：

```sh
asc metadata validate --dir docs/release/metadata-2026-09-15/proposed/ios
asc metadata validate --dir docs/release/metadata-2026-09-15/proposed/mac
```

确认发布版本和准确可写 AppInfo/version ID 后，重新拉取该记录，审查远端变化，将候选合并入新快照，再按平台执行 `asc metadata push ... --dry-run`。本轮因 1.3 记录不存在，**未运行 push / dry-run**；不得将本地版本目录直接改成 2.0 后上传以规避确认。隐私问卷和博客更新独立核实、执行并留证，不随元数据 PR 合并自动生效。

## #17 关闭前剩余事项

- [ ] 维护者确认 1.3 与现有两平台 2.0 草稿的处理方式，绑定最终版本和 Cloud build。
- [ ] 登录读取实际问卷，核实 RC 后台集成/身份关联，将实际答案与源代码及候选政策对齐。
- [ ] 在博客任务中发布三语隐私修订，清理同页面过宽的产品/Services 介绍，再验证原 URL 和锚点。
- [ ] 清理遗留 Apple Events 用途字符串，核查最终生成的 Info.plist；保持现有辅助功能权限流程。
- [ ] 对最终签名 Cloud 产物检查依赖清单资源与聚合隐私报告，完成文件/跨 App/购买门槛。
- [ ] 对确定版本完成最新快照、dry-run、后台文案更新及读回，记录准确 SHA/build；核对 #71 等仍待验收功能是否实际纳入该 build。

最低 iOS 14 / macOS 11 验收按用户决定保留为发布前项目；本报告不关闭这些门槛，也不关闭 #17。
