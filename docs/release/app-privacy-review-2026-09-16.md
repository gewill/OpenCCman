# App Store 隐私标签勾选草案

关联 #17；2026-09-16 整理，**供维护者审核，未修改或发布 ASC**。源码基线 `c1efdb55aa8ab00907b7480b4e0e695b713400c5`。此前后台只读记录为 Data Not Collected；本轮未重新登录读回，不能将历史状态当作新的后台验证。

## 建议勾选

| 问卷项 | 候选答案 | 依据与条件 |
|---|---|---|
| 是否由应用或第三方收集数据 | 是 | RevenueCat 处理并保留购买记录 |
| 数据类型 | Purchases → Purchase History（购买记录） | RevenueCat 明确要求披露 |
| 购买记录用途 | App Functionality（App 功能）、Analytics（分析） | 权益验证/恢复、购买分析及销售通知 |
| 第三方广告、开发者广告或营销、产品个性化、其他用途 | 不勾选 | 已核实用途不包含这些目的；外部广告用途/数据经纪商共享仍须最后确认 |
| 购买记录是否与身份关联 | 候选：否 | SDK 默认匿名标识；维护者确认不与邮箱、真实身份或广告数据关联。依 RevenueCat 指引，前提是无法通过其他数据识别个人；匿名标识不等于数据完全不可关联 |
| 购买记录是否用于追踪 | 候选：否 | 未见广告标识或归因集成；需确认后台之外也没有广告衡量、跨应用定向广告或数据经纪商共享 |

预期标签：Data Not Linked to You → Purchases，用于 App Functionality 和 Analytics。它是上述条件成立后的预期，不是 ASC 预览截图或已发布结果。

## 其他数据类型

- **User ID / Device ID**：目前不因 RevenueCat 默认匿名标识而额外勾选；这是依据其官方配置指引作出的候选判断，不是“随机 ID 一律豁免”。Apple 的 User ID 定义较宽；若支持渠道或 Customer Center 实际将 ID 与身份结合，需重新评估 User ID 与身份关联。
- **联系信息 / Customer Support**：应用反馈入口用 mailto，默认只带应用名称和版本；没有自动附上 RevenueCat ID。主动联系支持可能产生邮箱及用户提供的内容。不能仅因“自愿”就认定豁免：发布前核对最终 Customer Center 的邮件/反馈入口及真实支持流程是否满足 Apple 全部可选披露条件，不满足时需补充对应数据类型和 App Functionality 用途。
- **Payment Info**：不因 Apple 内购而声明银行卡资料；当前无应用直接采集该资料的证据。
- **正文 / TXT / 本地偏好与额度**：本地处理不构成离机收集；不因存在编辑器就勾选 Other User Content。用户主动将正文发给支持时应另按支持流程判断。
- **位置、联系人、健康、敏感信息、浏览/搜索记录、诊断、其他使用数据**：当前审计没有要求勾选的证据；不能把 SDK 请求头中的设备型号直接等同 Device ID，或把购买分析自动等同点击行为采集。最终发布包与后台新增配置需另核。

## 已确认事实与边界

维护者确认：未把 RevenueCat 匿名 ID 与邮箱、真实身份或广告数据关联；Slack 通知仅本人查看，使用免费版默认保留设置；未实际使用 Rico 查询/处理客户数据。Slack 实际保留配置未读回，单条事件 payload 未打开，故政策写“可能包含”及“按工作区设置保存”，不承诺确切删除天数。

Slack 是购买数据的下游接收方，不是 ASC 单独的数据类型。仅向 Slack 发送购买通知不自动构成 Apple 定义的追踪；该定义关注跨来源广告用途或数据经纪商共享。政策中仍披露此处理。

此前记录的 RevenueCat 5.64.0 隐私清单声明 PurchaseHistory / AppFunctionality、非身份关联、非追踪；官方后台问卷指引额外要求 Analytics。清单不能代替完整问卷。参见 [SDK 记录](metadata-2026-09-15/sdk-manifests.json) 和 [后台观察](metadata-2026-09-15/revenuecat-observation.json)。

## 政策与发布步骤

三语政策已获维护者批准并发布到博客及独立 Pages 网站。独立域名仍在等待配置完成，既有 ASC 政策链接先保留；域名监测不授权修改 ASC 问卷。

1. 逐个确认外部广告/数据经纪商用途及支持流程剩余条件。
2. 核对最终 Customer Center 设置/数据路径，必要时补充用户标识、支持数据候选。
3. 给维护者审阅最终完整选择；本文件不授权发布。
4. 获授权后重新读取 ASC，修改、预览、发布并读回；保存时间、最终选项与证据。
5. 最终签名包隐私报告仍为发布验收项，不能由本草案或源码审查代替。

## 官方依据

均于 2026-09-16 读取：

- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)：第三方收集、数据类型、用途、身份关联、追踪及可选披露标准；标签可独立于应用版本更新。
- [RevenueCat Apple App Privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy)：购买记录必选，功能及分析用途，匿名 ID / 自定义 ID 的条件判断。
