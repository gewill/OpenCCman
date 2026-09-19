# App Store 隐私标签审核

关联 [#17](https://github.com/gewill/OpenCCman/issues/17)。2026-09-16 起草，**2026-09-19 按 RevenueCat 5.78.0 重新核对**。本文记录标签答案与证据，**尚未修改 ASC、RevenueCat 后台、网站或博客**。机器可读证据见 [evidence.json](privacy-review-2026-09-19/evidence.json)。

## 结论

- ASC 现行声明为 Data Not Collected，需要改为下文的推荐答案。
- 购买记录不能再答“未关联身份”：维护者决定保留 Customer Center 支持邮件中的 RC User ID，用户发信后，发件邮箱即可与 RevenueCat 购买记录对应。
- 从 5.64.0 升到 5.78.0，支持邮件正文、应用内工单和 Customer Center 事件的代码均未改变，5.64.0 的历史发现仍然成立。
- 推荐答案还取决于 RevenueCat 后台的 Customer Center 支持设置，见“待核对”。读回之前不发布。

## 版本与方法

| 项目 | 值 |
|---|---|
| 应用源码 | develop `65e609d29c767402b71e3d184c8711e3486710fa`；最低 iOS 15 / macOS 12 |
| RevenueCat（当前） | purchases-ios-spm 5.78.0，`629a56ecef190469914b8f0914bf0446363eb09f`，与 `Package.resolved` 及 tag 一致 |
| RevenueCat（历史） | 5.64.0，`155ea739f45f54189ca83ee9088b373c1415d98b` |
| 取源方式 | 在仓库外按 SHA 浅取两个版本；未读取或修改 Xcode 依赖缓存 |
| SDK 隐私清单 | 两版逐字节相同（sha256 `76c876c7…`），只声明 Purchase History：App Functionality、未关联、不追踪。清单不能代替问卷 |
| 方法边界 | 源码追踪加官方文档核对；未对发布包抓包，也未生成最终签名包的隐私报告 |

## 平台入口

- iOS / iPadOS：“设置 → 购买支持”打开官方 RevenueCatUI `CustomerCenterView`。
- macOS：使用应用自有的 `PurchaseSupportView`（恢复、刷新、反馈），不含 RevenueCatUI，因此没有 RevenueCat 支持邮件、工单或 Customer Center 事件。
- 两端：`IAPManager.configure` 只设置代理 `api.rc-backup.com`、API key 和界面语言；没有自定义 App User ID、`logIn`、客户属性、归因、ATT 请求或诊断。

## 最终表：字段、触发条件、接收方、用途、身份关联、标签

| 数据与字段 | 触发条件 | 接收方 | 用途 | 身份关联 | 标签 |
|---|---|---|---|---|---|
| 购买记录：交易与收据、商品、价格与币种、权益状态 | 两端的购买、恢复、StoreKit 交易更新、补传缓存交易 | RevenueCat（经 `api.rc-backup.com`）；购买事件通知转发到维护者的 Slack | 权益验证、恢复、防欺诈；RevenueCat 报表；Slack 销售通知 | 以 RC App User ID 为键；支持邮件可将它与邮箱对应 | Purchase History：App Functionality、Analytics；关联；不追踪 |
| RC App User ID（SDK 在本机生成的匿名 ID） | 每个 RevenueCat 请求；支持邮件正文；工单；事件；Slack 通知 | RevenueCat；维护者 Gmail（用户发信后）；Slack | 权益与客服定位；购买分析 | 与发件邮箱一同出现 | User ID：App Functionality、Analytics；关联；不追踪 |
| Customer Center 曝光事件：事件 ID、`app_user_id`、`app_session_id`、时间、语言、深色模式、沙盒标记、展示方式 | iOS 每次打开 Customer Center；先写入本地队列，App 回到前台时延迟上传，或退到后台时上传 | RevenueCat 事件接口（经代理） | Customer Center 使用分析 | 含 `app_user_id` | Product Interaction：Analytics；关联；不追踪 |
| 问卷选项事件：选项 ID、路径类型、路径 URL，以及上面的基础字段；没有自由文本 | 仅当后台给可达路径配置了问卷，且用户选择了选项。终身买断不会显示取消路径 | RevenueCat | 问卷统计 | 含 `app_user_id` | 归入 Product Interaction，不新增类型 |
| 支持邮件草稿：默认正文，以及 RC User ID、App 版本、设备类型（iPhone/iPad）、系统版本、商店国家 | iOS，且后台配置了支持邮箱：(1) 无购买用户的 Customer Center 页面点“联系支持”；(2) 恢复购买未找到时，提示框里的“联系支持”。用户须在邮件 App 中自行发送 | 后台配置的支持邮箱（应为维护者 Gmail，待读回） | 客服 | 邮箱与 RC User ID 同时出现 | Email Address、Customer Support：App Functionality；关联；不追踪。见边界 3 |
| 应用内工单：用户输入的邮箱、问题描述（最多 250 字）、`app_user_id`；RevenueCat 转发时可附带后台勾选的客户信息（选项包括 IDFV、IP 等） | 仅当后台开启 “Contact support metadata”。默认只对“无有效订阅”的用户可见，终身买断也属于这一类 | RevenueCat 转发到支持邮箱 | 客服 | 关联 | 一旦开启，必须声明 Email Address、Customer Support、User ID；附带的元数据另行评估 |
| 应用自有反馈邮件：主题，以及“OpenCCman v版本” | 两端“设置 → 反馈” | 维护者 Gmail（用户发信后） | 客服 | 仅有发件邮箱 | 已由 Email Address、Customer Support 覆盖 |
| 请求头：平台、系统版本、设备型号、App 版本与构建号、Bundle ID、首选语言、商店国家、沙盒与调试标记、安装方式 | 每个 RevenueCat 请求 | RevenueCat | 处理请求；后台显示最近版本、平台和商店国家 | 随请求 | 不属于 Apple 列出的数据类型，不单独勾选；在政策中说明 |
| IDFV（`X-Apple-Device-Identifier` 请求头） | iOS 每个请求；macOS 仅在沙盒环境发送（由 MAC 地址派生），正式版不发送 | RevenueCat | 用途与留存均未公开 | 随请求 | 见边界 1 |
| IP 地址，以及据此推算的国家 | 每个请求 | RevenueCat | 后台的国家维度 | RevenueCat 称确定国家后丢弃 IP | 见边界 2 |
| `$attConsentStatus` | SDK 自动同步当前的 ATT 状态；本应用从不请求 ATT 授权 | RevenueCat | 供归因集成使用的状态字段 | — | 不属于数据类型；不涉及 IDFA |
| 正文、TXT、偏好、额度、剪贴板与辅助功能 | 本机处理 | 不离开设备 | — | — | 不构成收集 |

## 推荐的 ASC 答案

**Data Used to Track You**：无。

**Data Linked to You**：

| 数据类型 | 用途 |
|---|---|
| Purchases → Purchase History | App Functionality、Analytics |
| Identifiers → User ID | App Functionality、Analytics |
| Usage Data → Product Interaction | Analytics |
| Contact Info → Email Address | App Functionality |
| User Content → Customer Support | App Functionality |

**Data Not Linked to You**：无。

不勾选 Device ID、位置、诊断、支付信息、Other User Content 及其余类型，理由见下节。

## 边界判断

1. **IDFV 与 Device ID。** iOS 的每个 RevenueCat 请求都带 IDFV。RevenueCat 官方指引只在使用 IDFA 类集成时要求勾选 Device ID；`$idfv` 属性只在调用 `collectDeviceIdentifiers()` 或设置归因 ID 时保存，本应用两者都没有。请求头在服务器端是否留存，RevenueCat 没有公开说明。推荐按其指引不勾选，并在政策中写明请求会带 IDFV。保守的备选是勾选 Device ID（App Functionality，关联）。
2. **按 IP 推算国家与 Coarse Location。** RevenueCat 文档说明会用最近请求的 IP 推算国家，确定后不保存 IP；它的 Apple 隐私页又写明不收集粗略位置。推荐按其指引不勾选，并在政策中说明可能按 IP 估计国家。保守的备选是勾选 Coarse Location（Analytics，关联）。
3. **支持邮件能否免于披露。** Apple 的可选披露须同时满足四项条件。邮件草稿满足前三项，但填写发生在系统邮件 App 中，不在本应用界面内；工单会附带用户看不到的 `app_user_id` 和元数据，不满足第四项。而且邮件里的 RC User ID 已经让购买记录可以关联到具体用户。推荐直接声明，不依赖可选披露。
4. **应用内隐私链接打开的网页。** 应用内的“隐私政策”“在线帮助”仍指向 gewill.org 博客。2026-09-19 实测，三种语言的博客页都加载了 Google Analytics（`www.googletagmanager.com`）和 `datapulse.app`；新网站的三个隐私页没有外部脚本。iOS 用 SFSafariViewController 打开，应用读不到其中的数据；macOS 用系统浏览器打开。本表不把它计入 App 的数据收集。建议在 2.0 中把应用内链接和 ASC 的隐私政策 URL 改为 `https://openccman.gewill.org/<语言>/privacy.html`，或移除博客这几页的统计脚本。

## 待核对（发布前必须完成）

在 RevenueCat 后台只读核对，不查看客户和交易：

- [ ] Customer Center → Lifecycle → Support：支持邮箱、Contact support visibility、Contact support metadata（应用内工单）和 Embedded metadata。
- [ ] Customer Center 的页面配置：管理选项、无购买页面及问卷。
- [ ] Integrations：Active 列表和 Slack 的沙盒设置（2026-09-15 观察到只有 Slack）。

如果支持邮箱为空且工单关闭，RevenueCat 的支持路径就不可达，购买记录的身份关联和边界 3 都要重新评估。如果工单开启并勾选了 IDFV 或 IP 元数据，边界 1、2 也要重新评估。

## 已确认的决定

- 保留 Customer Center 支持邮件中的 RC User ID。
- 没有广告用途，不向数据经纪商共享；没有使用 Rico。
- Gmail 只有维护者本人访问，只用于支持；普通邮件没有固定的删除期限，垃圾箱的 30 天规则不代表所有支持邮件的保存期。
- Slack 购买通知只有维护者本人查看，按免费方案的默认设置保留，不写具体天数。
- 允许发布本轮隐私标签和三语政策，网站与旧博客须保持一致；正式域名 `https://openccman.gewill.org` 已验证。
- 不授权发布应用、修改价格、发送支持邮件或读取无关的客户数据。

## 相对旧草稿的更正

- 购买记录由“未关联”改为**关联**；User ID 由“不勾选”改为**勾选**；Product Interaction 由“待定”改为**勾选**，因为 iOS 事件路径已证实可达。
- 补入旧草稿遗漏的应用内工单路径（5.64.0 已经存在）和 IDFV 请求头。
- 删去“是否保留 RC ID”“需再次取得发布许可”“独立域名待配置”等过时内容。
- 现行网站政策（2026-09-16 版）写着不会把这些标识符与姓名或邮箱关联，与保留 RC User ID 的决定冲突，同步政策时必须修订。

## 5.64.0 历史发现

2026-09-16 基于 5.64.0 得出的 Customer Center 结论依然成立：支持邮件正文包含 RC User ID 等五项；生成草稿不等于发送；事件经 `CustomerCenterPurchases` 进入 `Purchases.track`。相关文件在两个版本之间逐字节相同。与隐私有关的改动只有两处：`$attConsentStatus` 在属性同步时也会刷新；“有效订阅”的判断不再计入已过期的订阅，但终身买断在两个版本中都不算有效订阅。

## 后续步骤

1. 登录 RevenueCat，完成上面的只读核对，确定最终答案。
2. 同步网站与旧博客的三语政策：写入 IDFV、Customer Center 事件、支持邮件含 RC User ID、按 IP 估计国家；检查三种语言是否一致、链接是否有效。
3. 登录 ASC，按最终答案修改、预览、发布并读回，保存发布后的证据。
4. 更新 #17，列出精确版本、实际核验内容、未覆盖项和发布证据。
5. 最终签名包的隐私报告仍是独立的发布验收项。
