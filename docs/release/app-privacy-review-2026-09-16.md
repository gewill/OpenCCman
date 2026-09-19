# App Store 隐私标签审核

关联 [#17](https://github.com/gewill/OpenCCman/issues/17)。2026-09-16 起草，**2026-09-19 按 RevenueCat 5.78.0 源码重新核对，并只读核对 RevenueCat 后台**。本文记录标签答案与证据，**尚未修改 ASC、RevenueCat 后台、网站或博客**。机器可读证据见 [evidence.json](privacy-review-2026-09-19/evidence.json)。

## 结论

- ASC 现行声明为 Data Not Collected，与实际不符，需要修改。
- RevenueCat 后台的 Customer Center **没有配置支持邮箱**，应用内工单也**关闭**。因此带 RC User ID 的支持邮件和工单在生产环境都不会出现。维护者“保留支持邮件中的 RC User ID”的决定，目前没有可达的入口。
- 按当前配置，推荐方案 A：声明购买记录（App Functionality、Analytics）和产品交互（Analytics），两者都“不关联身份”，不追踪。
- 如果以后在后台配置支持邮箱，必须先把标签改为方案 B（关联身份），再启用该入口。
- 从 5.64.0 升到 5.78.0，支持邮件正文、应用内工单和 Customer Center 事件的代码均未改变。

## 版本与方法

| 项目 | 值 |
|---|---|
| 应用源码 | develop `65e609d29c767402b71e3d184c8711e3486710fa`；最低 iOS 15 / macOS 12 |
| RevenueCat（当前） | purchases-ios-spm 5.78.0，`629a56ecef190469914b8f0914bf0446363eb09f`，与 `Package.resolved` 及 tag 一致 |
| RevenueCat（历史） | 5.64.0，`155ea739f45f54189ca83ee9088b373c1415d98b` |
| 取源方式 | 在仓库外按 SHA 浅取两个版本；未读取或修改 Xcode 依赖缓存 |
| SDK 隐私清单 | 两版逐字节相同（sha256 `76c876c7…`），只声明 Purchase History：App Functionality、未关联、不追踪。清单不能代替问卷 |
| RevenueCat 后台 | 2026-09-19 由维护者登录后只读查看，未查看客户、交易、Slack 事件记录或密钥；页面上的“Save changes”始终不可点 |
| 方法边界 | 源码追踪、官方文档与后台配置核对；未对发布包抓包，也未生成最终签名包的隐私报告 |

## RevenueCat 后台配置（2026-09-19）

| 设置 | 值 | 对应用的影响 |
|---|---|---|
| 支持邮箱 | 空 | SDK 不生成邮件草稿；不会显示“联系支持”，恢复失败时的提示框里也没有 |
| Contact support metadata（应用内工单） | 关 | 不显示工单表单 |
| Contact support visibility | 无有效订阅的用户（默认） | 支持邮箱为空，因此不起作用 |
| 有购买的用户看到的选项 | Missing Purchase；Change Plans；Manage（挂默认三选项问卷）；Refund Request（挂 Promotional Offer，退款窗口 Forever） | 终身买断不是自动续期订阅，Change Plans 和 Manage 不会显示，问卷也就到不了用户；只剩恢复购买和退款申请 |
| 无购买的用户看到的选项 | Missing Purchase | 只能恢复购买，没有问卷 |
| 其他开关 | 更新提醒开；购买历史链接关；用户详情区开（iOS） | 用户详情区会在界面上向用户显示其 App User ID 和首次购买日期，这属于本地显示，不是收集 |
| Integrations 中已启用 | 只有 Slack | 与 2026-09-15 的观察一致 |

## 平台入口

- iOS / iPadOS：“设置 → 购买支持”打开官方 RevenueCatUI `CustomerCenterView`。
- macOS：使用应用自有的 `PurchaseSupportView`（恢复、刷新、反馈），不含 RevenueCatUI，因此没有 RevenueCat 支持邮件、工单或 Customer Center 事件。
- 两端：`IAPManager.configure` 只设置代理 `api.rc-backup.com`、API key 和界面语言；没有自定义 App User ID、`logIn`、客户属性、归因、ATT 请求或诊断。

## 最终表：字段、触发条件、接收方、用途、身份关联、标签

| 数据与字段 | 触发条件 | 接收方 | 用途 | 身份关联 | 标签（方案 A） |
|---|---|---|---|---|---|
| 购买记录：交易与收据、商品、价格与币种、权益状态 | 两端的购买、恢复、StoreKit 交易更新、补传缓存交易 | RevenueCat（经 `api.rc-backup.com`）；购买事件通知转发到维护者的 Slack | 权益验证、恢复、防欺诈；RevenueCat 报表；Slack 销售通知 | 只以匿名 RC App User ID 为键；当前没有把它与邮箱等身份信息自动对应的渠道 | Purchase History：App Functionality、Analytics；不关联；不追踪 |
| RC App User ID（SDK 在本机生成的匿名 ID） | 每个 RevenueCat 请求；事件；Slack 通知 | RevenueCat；Slack | 权益与购买分析的键 | 匿名，未与身份信息对应 | 按 RevenueCat 指引不单独声明 User ID（见边界 3） |
| Customer Center 曝光事件：事件 ID、`app_user_id`、`app_session_id`、时间、语言、深色模式、沙盒标记、展示方式 | iOS 每次打开 Customer Center；先写入本地队列，App 回到前台时延迟上传，或退到后台时上传 | RevenueCat 事件接口（经代理） | Customer Center 使用分析 | 只有匿名 ID | Product Interaction：Analytics；不关联；不追踪 |
| 问卷选项事件：选项 ID、路径类型、路径 URL，以及上面的基础字段；没有自由文本 | 需要用户进入挂有问卷的路径。当前只有 Manage 挂问卷，终身买断看不到 Manage | RevenueCat | 问卷统计 | 只有匿名 ID | 当前不可达；可达时也归入 Product Interaction |
| RevenueCat 支持邮件草稿：默认正文，以及 RC User ID、App 版本、设备类型（iPhone/iPad）、系统版本、商店国家 | 需要后台配置支持邮箱。**当前为空，不可达** | 配置的支持邮箱 | 客服 | 邮箱与 RC User ID 同时出现 | 当前不适用；配置后改用方案 B |
| 应用内工单：用户输入的邮箱、问题描述（最多 250 字）、`app_user_id`，以及后台勾选的附带信息 | 需要开启 Contact support metadata 并配置支持邮箱。**当前关闭，不可达** | RevenueCat 转发到支持邮箱 | 客服 | 关联 | 当前不适用；开启后须声明 Email Address、Customer Support、User ID |
| 应用自有反馈邮件：主题，以及“OpenCCman v版本” | 两端“设置 → 反馈”，用户在自己的邮件 App 中撰写并发送 | 维护者 Gmail | 客服 | 仅有发件邮箱，不含 App 生成的标识符 | 按可选披露不声明（见边界 4） |
| 请求头：平台、系统版本、设备型号、App 版本与构建号、Bundle ID、首选语言、商店国家、沙盒与调试标记、安装方式 | 每个 RevenueCat 请求 | RevenueCat | 处理请求；后台显示最近版本、平台和商店国家 | 随请求 | 不属于 Apple 列出的数据类型，不单独勾选；在政策中说明 |
| IDFV（`X-Apple-Device-Identifier` 请求头） | iOS 每个请求；macOS 仅在沙盒环境发送（由 MAC 地址派生），正式版不发送 | RevenueCat | 用途与留存均未公开 | 随请求 | 见边界 1 |
| IP 地址，以及据此推算的国家 | 每个请求 | RevenueCat | 后台的国家维度 | RevenueCat 称确定国家后丢弃 IP | 见边界 2 |
| `$attConsentStatus` | SDK 自动同步当前的 ATT 状态；本应用从不请求 ATT 授权 | RevenueCat | 供归因集成使用的状态字段 | — | 不属于数据类型；不涉及 IDFA |
| 正文、TXT、偏好、额度、剪贴板与辅助功能 | 本机处理 | 不离开设备 | — | — | 不构成收集 |

## 推荐的 ASC 答案

### 方案 A：当前配置（推荐）

- **Data Used to Track You**：无。
- **Data Linked to You**：无。
- **Data Not Linked to You**：

| 数据类型 | 用途 |
|---|---|
| Purchases → Purchase History | App Functionality、Analytics |
| Usage Data → Product Interaction | Analytics |

### 方案 B：在后台配置支持邮箱之后

邮件会带上 RC User ID，发件邮箱即可与购买记录对应，因此改为：

- **Data Used to Track You**：无。
- **Data Linked to You**：Purchase History（App Functionality、Analytics）；User ID（App Functionality、Analytics）；Product Interaction（Analytics）；Email Address（App Functionality）；Customer Support（App Functionality）。

规则：先在 ASC 发布方案 B，再在 RevenueCat 后台填写支持邮箱。

## 边界判断

1. **IDFV 与 Device ID。** iOS 的每个 RevenueCat 请求都带 IDFV。RevenueCat 官方指引只在使用 IDFA 类集成时要求勾选 Device ID；`$idfv` 属性只在调用 `collectDeviceIdentifiers()` 或设置归因 ID 时保存，本应用两者都没有。请求头在服务器端是否留存，RevenueCat 没有公开说明。推荐按其指引不勾选，并在政策中写明请求会带 IDFV。保守的备选是勾选 Device ID（App Functionality）。
2. **按 IP 推算国家与 Coarse Location。** RevenueCat 文档说明会用最近请求的 IP 推算国家，确定后不保存 IP；它的 Apple 隐私页又写明不收集粗略位置。推荐按其指引不勾选，并在政策中说明可能按 IP 估计国家。保守的备选是勾选 Coarse Location（Analytics）。
3. **匿名 ID 算不算“关联”。** RevenueCat 指引：使用其匿名 App User ID、且没有办法识别个人时，可以答“不关联”。Apple 的定义更宽，认为适用隐私法下的“个人数据”都算关联，而 RC ID 本身也可以视为分配的用户 ID。方案 A 采用 RevenueCat 的指引；如果维护者采用 Apple 的严格读法，就使用方案 B 中的关联答案（不含邮箱与客服内容）。
4. **应用自有反馈邮件能否免于披露。** Apple 的可选披露须同时满足四项条件。这封邮件不用于追踪或营销，只在少数情况下由用户主动发起，也不是主要功能；邮件由用户自己撰写，发件地址和全部内容都显示在撰写界面上，每次都由用户决定是否发送，并且不带 App 生成的标识符。唯一的出入是撰写界面属于系统邮件 App，而不是本应用。推荐不声明，在政策中说明支持邮件的处理。保守的备选是声明 Email Address 与 Customer Support（App Functionality）。
5. **应用内隐私链接打开的网页。** 应用内的“隐私政策”“在线帮助”仍指向 gewill.org 博客。2026-09-19 实测，三种语言的博客页都加载了 Google Analytics（`www.googletagmanager.com`）和 `datapulse.app`；新网站的三个隐私页没有外部脚本。iOS 用 SFSafariViewController 打开，应用读不到其中的数据；macOS 用系统浏览器打开。本表不把它计入 App 的数据收集。建议在 2.0 中把应用内链接和 ASC 的隐私政策 URL 改为 `https://openccman.gewill.org/<语言>/privacy.html`，或移除博客这几页的统计脚本。

## 已确认的决定

- 保留 Customer Center 支持邮件中的 RC User ID。当前后台未配置支持邮箱，该路径不可达；启用前须先按方案 B 更新标签。
- 没有广告用途，不向数据经纪商共享；没有使用 Rico。
- Gmail 只有维护者本人访问，只用于支持；普通邮件没有固定的删除期限，垃圾箱的 30 天规则不代表所有支持邮件的保存期。
- Slack 购买通知只有维护者本人查看，按免费方案的默认设置保留，不写具体天数。
- 允许发布本轮隐私标签和三语政策，网站与旧博客须保持一致；正式域名 `https://openccman.gewill.org` 已验证。
- 不授权发布应用、修改价格、发送支持邮件或读取无关的客户数据。

## 相对旧草稿的更正

- 旧草稿认为购买记录“不关联”，但没有核实支持入口。现已核实后台没有支持邮箱，方案 A 维持“不关联”；同时写明启用支持邮箱后必须改为方案 B。
- 新增 Product Interaction：iOS 的 Customer Center 曝光事件已证实会上传。
- 补入旧草稿遗漏的应用内工单路径（5.64.0 已经存在，当前关闭）和 IDFV 请求头。
- 删去“是否保留 RC ID”“需再次取得发布许可”“独立域名待配置”等过时内容。
- 现行网站政策（2026-09-16 版）没有提到 Customer Center 事件、IDFV 和按 IP 估计国家，同步政策时须补上。

## 5.64.0 历史发现

2026-09-16 基于 5.64.0 得出的 Customer Center 结论依然成立：支持邮件正文包含 RC User ID 等五项；生成草稿不等于发送；事件经 `CustomerCenterPurchases` 进入 `Purchases.track`。相关文件在两个版本之间逐字节相同。与隐私有关的改动只有两处：`$attConsentStatus` 在属性同步时也会刷新；“有效订阅”的判断不再计入已过期的订阅，但终身买断在两个版本中都不算有效订阅。

## 后续步骤

1. 维护者确认采用方案 A 还是 B，以及边界 1、2、4 是否采用推荐做法。
2. 同步网站与旧博客的三语政策：写入 IDFV、Customer Center 事件、按 IP 估计国家、支持邮件的处理方式；检查三种语言是否一致、链接是否有效。
3. 登录 ASC，按最终答案修改、预览、发布并读回，保存发布后的证据。
4. 更新 #17，列出精确版本、实际核验内容、未覆盖项和发布证据。
5. 最终签名包的隐私报告仍是独立的发布验收项。
