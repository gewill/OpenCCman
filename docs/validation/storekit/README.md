# 本地 StoreKit 验收（#70／#14）

2026-09-14，基于 develop `30eef4d`。本地测试已通过 **7 项**：[日志](results.log)。Apple M4 Pro，macOS 26.6.2，Xcode 26.6；测试专用 host／bundle，ad-hoc 签名，无 RevenueCat 网络或真实交易。

## 两个独立入口

1. `bash scripts/check-storekit.sh /tmp/openccman-storekit-new-run`：运行测试专用 Xcode 工程及 SKTestSession。使用全新输出目录，日志和 xcresult 成功／失败均保留。CI 执行同入口，失败上传 artifact。测试工具要求 macOS 14+，仅用于错误注入 API；应用仍支持 iOS 14／macOS 11。
2. Xcode 中选择 **OpenCCman-StoreKit** Scheme 和 iOS 模拟器，可启用测试目录的 `.storekit`。此 Scheme 仅 Debug，不参与 Archive。它运行实际应用，但 RevenueCat 后台集成仍需相应测试配置；本轮未将其记为 RevenueCat 全链路通过。原 OpenCCman Scheme、应用资源和 Xcode Cloud 不变。

自动测试工程的生成源为 `Tests/StoreKit/project.json`，使用 XcodeGen 2.46.0；生成工程已提交，执行测试不要求安装 XcodeGen。修改后可运行：

```bash
xcodegen generate --spec Tests/StoreKit/project.json --project Tests/StoreKit
```

## 商品与断言

ASC 只读查询 `asc iap list --app 6474449401 --paginate --output json` 确认：`ios_openccman_pro_lifetime_3`，`NON_CONSUMABLE`，`APPROVED`（2026-09-14）。本地 `0.99` 是故意固定的测试价格，**不是线上价格**；没有创建商品、改变价格或新增订阅。

| 用例 | 实际断言 |
|---|---|
| 商品获取 | ID、非消耗型类型、非空标题／价格、无订阅信息 |
| 购买 | 验证成功交易、无到期日、StoreKit 当前权益存在 |
| 用户取消 | 返回 userCancelled，未授予权益 |
| 购买失败 | 注入 StoreKit 错误并实际抛出，未授予权益 |
| 显式恢复 | 完成购买后执行 AppStore.sync，再查询权益仍有效；不是重装／跨设备恢复 |
| 重复购买 | 当前终身权益只有一项 |
| 退款 | 先确认购买权益有效，注入退款，再确认当前权益移除 |

StoreKit 状态异步传播，测试按预期状态轮询，最多 5 秒；超时真实失败，不跳过断言。每项开始清除**测试 host**交易并确认无权益，结束清理。测试不操作正式应用交易。

首次无 host 试验出现 `SKInternalErrorDomain Code=3`，商品为空；增加独立 host 后恢复。初版购买后立即查权益有传播竞态，改为上述有界等待，并确保退款前已获得权益，避免“从未授权也算撤销通过”。最终 7 项均通过。

## 不替代的验收

这些验证的是固定商品的 Apple 本地 StoreKit 合约，**不运行生产 IAPManager 或 RevenueCat 后端**。生产权益回写／取消错误展示的定向回归随 #71 接入；#14 继续验收真实商品、RevenueCat entitlement 映射、Sandbox／TestFlight 购买恢复、撤销、离线与最终云端包。

RevenueCat 的本地测试需核对 SDK 模式和测试证书；其文档列出 macOS 本地配置及部分退款事件的限制。本自动套件不依赖该组合，不冒充原生 Mac RevenueCat 链路通过。真实旧系统、线上价格展示、重装／跨设备恢复仍未验收。

参考：[Apple 本地测试](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)、[RevenueCat 测试条件](https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store)。

CI 初次执行的 xcodebuild 已成功，但日志摘要依赖 runner 没有的 `rg`，导致退出 127；已改用现有 Python 输出摘要，不改变交易测试、断言或通过标准。
