# OpenCCman 2.0 上架记录（2026-09-28）

## 执行与读回（UTC 2026-09-28 00:36–00:41）

- 发布文档 [PR #222](https://github.com/gewill/OpenCCman/pull/222) 在 `App Regression` 成功后合入 `develop`（`6b85871`）。应用源码和 `v2.0` Tag 未因此改变。
- iOS `17a9e553-7399-4e0c-97be-e1695f06b7d0` 和 macOS `ca370499-5c15-4510-8a7e-36ef7ebff15d` 均已执行手动发布；ASC 各自读回 2.0(56) `READY_FOR_DISTRIBUTION`、`downloadable: true`。
- 唯一终身 Pro IAP `6474501747` 的美国基准价在 2026-09-28 生效为 **US$5.99**；ASC 读回英国 £5.99、台湾 NT$190、中国大陆 ¥38。原 US$2.99 区间的结束日及新价区间的开始日均为 2026-09-28。既有永久权益没有迁移或重置。
- [网站 PR #4](https://github.com/gewill/OpenCCman-website/pull/4) 已合并（`8ea7249`），该提交经 `./deploy.sh` 部署到 Cloudflare Pages。正式域名的简体、繁体、英文首页已读回 2.0 文案，下载、隐私和支持入口均存在。
- [GitHub Release `v2.0`](https://github.com/gewill/OpenCCman/releases/tag/v2.0) 于 UTC 00:40:35 公开，Tag 仍指向 `main` 发布提交 `c7734f5`。

**传播与验收未完成：**截至本次读回，Apple Lookup API 的美国、英国、台湾店面仍返回 1.2；ASC `READY_FOR_DISTRIBUTION` 不证明各店面用户已经看到 2.0。真实购买页和系统确认面板的新价格／币种一致性、旧 Pro 权益及恢复购买，也尚未在公开 2.0 产物上重测；[#212](https://github.com/gewill/OpenCCman/issues/212) 保持打开。此次按维护者“现在就发布网站 APP 以及 GitHub”的指令执行了同窗口公开，未等待 Lookup API 传播结束。后续必须继续读回商店与完成购买页核对；若币种仍不一致，按 #212 处理。

以下保留**执行前快照与计划**，供审计当时的来源和取舍；其中“尚未发布／尚未调价”的状态已经过时，以本节执行读回为准。

## 已核实状态

| 项目 | 事实 | 发布动作 |
| --- | --- | --- |
| iOS / macOS | App Store Connect 2.0(56) 均为 `PENDING_DEVELOPER_RELEASE`；审核提交分别为 `dbf4cccf-83e4-4bb5-b833-8a600a2e62d0` 与 `2ca043a7-0d5f-4c00-870e-5791294e2c05`，读回 `COMPLETE`。 | 两个平台均设置手动发布，尚未执行。Apple 要求逐平台操作。 |
| 公开商店 | Apple Lookup API 在美国、英国、台湾店面仍返回公开版本 **1.2**。 | 不把过审视为用户可下载；发布后再次逐店面核对。 |
| 构建来源 | Xcode Cloud Build 56 的应用源码为 `2f782714103d68b4972bee93e47bda8cafee1959`；`main` 发布合并提交 `c7734f5a6f4ac3f5f9b5786d78ab1c49268364f3` 的应用源码与其一致，精确提交的 `App Regression` 成功。 | 无需重新打包；不要推送 `build*`。 |
| GitHub 来源发布 | 注释 Tag `v2.0` 指向上述 `main` 合并提交；GitHub Release 已建**草稿**，未公开。 | 等商店两端 2.0 可下载再发布 Release。 |
| 网站 | 正式站点仍显示 2.0「即将推出」；[网站草稿 PR #4](https://github.com/gewill/OpenCCman-website/pull/4) 已准备三语公开文案与前后截图，尚未合并／部署。 | 等商店两端上线和价格读回，再合并并按网站 `deploy.sh` 部署、检查正式域名。 |

## Pro 价格

唯一的非消耗型商品是 `ios_openccman_pro_lifetime_3`，ASC IAP ID `6474501747`，美国为基准地区。2026-09-28 只读查询：当前美国 **US$2.99**；已授权的 2.0 目标为 **US$5.99**，保留既有永久权益。可用的美国目标 price point ID 为 `eyJzIjoiNjQ3NDUwMTc0NyIsInQiOiJVU0EiLCJwIjoiMTAwNzUifQ`。Apple 的全球自动等价价点为其他 174 个店面提供价格，不是把每个地区的数字机械乘以二。

| 地区 | 当前读回 | US$5.99 基准价点的 Apple 等价价 |
| --- | ---: | ---: |
| 美国 | US$2.99 | US$5.99 |
| 英国 | £2.99 | £5.99 |
| 中国大陆 | ¥22 | ¥38 |
| 台湾 | NT$90 | NT$190 |

**尚未建立调价日程，也未改变现价。** [Apple 的 IAP 调价说明](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/schedule-price-changes-for-in-app-purchases/)允许选择生效**日期**，并由 Apple 计算其他店面价；两端手动发布及商店传播不保证同一时刻完成。[Apple 的手动发布说明](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option)明确需要分别发布 iOS、macOS，且商店显示可能延迟最多 24 小时。因此“2.0 同步涨价”应按同一发布窗口操作、记录实际时间并读回，不宣称全球秒级同步。网站和应用没有硬编码美元价。

## 执行顺序与闸门

1. 保留用户已接受延期到 v2.1 的 #14、#15、#16、#18、#19、#20 的未完成验收。**[#212](https://github.com/gewill/OpenCCman/issues/212) 仍是发布观察项**：Build 55 的英国 Sandbox 商品卡片显示美元，而 Apple 确认面板显示英镑；根因尚未归属。公开发布前用 Build 56 重新核对购买页与系统确认价，记录其适用的测试店面；若仍不一致，先评估是否必须修复并重新提审。公开后的正式店面仍需单独读回，不能把 Sandbox 结果写成正式店面已通过。
2. 确定手动发布窗口与价格生效日期；在 ASC 核对唯一商品、当前价格、目标价点与全球等价价。CLI 的 `asc iap pricing schedules create` 没有 dry-run，创建前以只读查询和本表复核实际值。价格计划按日期生效，不能保证与手动发布同秒；操作时记录实际起效时间，避免在旧版公开期间提前提价。
3. 分别手动发布 iOS 与 macOS 2.0(56)，并在约定窗口建立价格计划。读回版本状态，逐店面确认公开版本已是 2.0；并核对实际商品卡片与 Apple 系统确认价格、旧永久权益和恢复购买。任何实际收费确认由维护者本人完成。
4. 调价生效后，读回美国及代表性地区金额、IAP 生效记录；在真实购买页核对本地化货币。随后合并并部署网站 PR #4，检查三语正式域名首页、视频、下载、隐私和支持链接。
5. 确认两端可下载、价格和网站无误后，将 GitHub Release 草稿公开，并在 #11、#17、#122 记录时间、来源 SHA 与未完成的 v2.1 项。公开 Tag 已创建；公开 Release、网站部署与 App Store 发布仍是独立动作。

这份记录只基于 2026-09-28 的 ASC、Apple Lookup API、GitHub 和网站仓库读回。它不代表用户已购买验证新价格，也不代表 2.0 已公开上架。
