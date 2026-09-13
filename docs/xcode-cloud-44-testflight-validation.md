# Xcode Cloud #44 与 TestFlight 验证

核对日期：2026-09-13（Asia/Taipei）。本记录完成云端构建、内部测试可用性与 macOS 安装启动验证；购买、跨 App 和旧系统真机仍单独验收。

## 产物身份与结果

| 字段 | 已核对值 |
| --- | --- |
| App / Bundle ID | `6474449401` / `org.gewill.OpenCCman` |
| Workflow | `Default` / `00F5435C-1C48-4750-88FA-4563D018E4B3` |
| Cloud run | #44 / `8e1d8cff-3c58-4a11-bf30-5334894b7aca` |
| 触发 | `build` 的 `GIT_REF_CHANGE`，未重复手动触发或上传本地产物 |
| 应用 SHA | `eb43b7ccd9e5788daa8af810e59d006d28dcb7d6`（[依赖 PR #32](https://github.com/gewill/OpenCCman/pull/32)） |
| 引擎 SHA | `6eded293f5c84c064f332cbc2832391165c82dda`，OpenCC 1.4.2 |
| 云端版本 | 1.3（44），不要与本地工程 build 30 混淆 |
| 完成时间 | 2026-09-13 06:55:49 UTC |
| 整体结果 | `SUCCEEDED` |

四个 action 均为 `COMPLETE / SUCCEEDED`：Archive - iOS、Archive - macOS、TestFlight Internal Testing - iOS、TestFlight Internal Testing - macOS。仍有颜色资产生成符号冲突警告，由 [维护评估 #24](https://github.com/gewill/OpenCCman/issues/24) 跟踪；本次没有签名错误。

| 平台 | ASC build ID | 处理状态 | 内部测试状态 | 最低系统 |
| --- | --- | --- | --- | --- |
| iOS | `92e06879-486d-4bbe-87dd-7bccd547314d` | `VALID` | `IN_BETA_TESTING` | 14.0 |
| macOS | `e3b9fdd9-1a47-414e-8788-9c38a0fc9e0d` | `VALID` | `IN_BETA_TESTING` | 11.0 |

两 build 都未过期，属于 `APP_STORE_ELIGIBLE`，非豁免加密标记为 false。已通过 Cloud run → builds → preReleaseVersion 关系核对平台、营销版本和来源，没有仅凭“最新 build”推断身份。

## TestFlight 配置

两平台都已属于现有 `Internal Group`（`c375055a-0cf0-4505-84c2-4b99de010e12`）。完整 membership 查询显示 `explicit-and-all-builds`，`hasAccessToAllBuilds=true`。没有新增测试者、改变通知偏好或扩大外部测试范围。

仅更新本次两 build 已存在的 `en-US` 与 `zh-Hans` What to Test，随后回读确认一致。说明覆盖预设/高级选项、UTF-8 TXT/容量/格式/取消、迟到结果、额度/Pro 和 Sandbox 购买；macOS 增加 Services、全局快捷键、权限及全部关窗场景。测试说明是待执行指引，不代表这些完整用例已经验收。

外部测试状态为 `READY_FOR_BETA_SUBMISSION`，本轮没有提交 Beta App Review 或向 Public Test Group 分发。本文的“可测试”指现有内部组。

## macOS 安装与启动

1. TestFlight 客户端选择 OpenCCman 的 **macOS 1.3（44）**，实际显示 Install。
2. 替换提示出现后先备份现有容器 `Data`，再安装。系统管理的容器 metadata 不属于应用数据备份范围。备份为本机受限临时目录，不提交私人偏好到仓库。
3. 客户端显示 Open；通过该按钮启动 `/Applications/OpenCCman.app`。
4. 安装后 Info.plist：Bundle ID 正确，版本 1.3、build 44、最低 macOS 11.0；存在 TestFlight receipt。`codesign --verify --deep --strict` 通过，签名身份为 **TestFlight Beta Distribution**，team `RLK76T8Y89`。
5. entitlements 包含 beta reports、sandbox、用户选定文件读写和网络客户端；没有 Apple Events 自动化 entitlement。
6. 应用窗口可见。使用公开默认样本和台湾正体＋台湾词组预设执行一次转换：

```text
输入：鼠标里面的硅二极管坏了，导致光标分辨率降低。
输出：滑鼠裡面的矽二極體壞了，導致游標解析度降低。
```

UI 显示 100%，复制和导出按钮可用。这是实际安装包的启动/基本转换验证；未据此宣称购买、文件面板、跨 App 或无障碍全流程通过。

## 剩余验收与复核方式

- [#13 云端构建和内部 TestFlight](https://github.com/gewill/OpenCCman/issues/13)：本轮完成；iOS 已核对后台可用性，未在物理 iPhone/iPad 上执行安装和运行。
- [#14 购买](https://github.com/gewill/OpenCCman/issues/14)、[#15 文件/跨 App](https://github.com/gewill/OpenCCman/issues/15)、[#16 最低系统真机](https://github.com/gewill/OpenCCman/issues/16)、[#17 发布资料](https://github.com/gewill/OpenCCman/issues/17)：继续保持开放。
- 性能、全部关窗、VoiceOver/编辑器和真实 fork 来源演练仍见 [总清单 #11](https://github.com/gewill/OpenCCman/issues/11)。

可用以下只读命令复核；未来处理状态和可用期限可能变化：

```bash
asc xcode-cloud doctor --run-id 8e1d8cff-3c58-4a11-bf30-5334894b7aca --skip-logs
asc xcode-cloud build-runs builds --run-id 8e1d8cff-3c58-4a11-bf30-5334894b7aca
asc builds list --app 6474449401 --build-number 44 --include preReleaseVersion,buildBetaDetail
asc testflight groups list --build-id 92e06879-486d-4bbe-87dd-7bccd547314d --internal
asc testflight groups list --build-id e3b9fdd9-1a47-414e-8788-9c38a0fc9e0d --internal
```

本记录更新 [Xcode Cloud 指南](XCODE_CLOUD.md) 和 [此前收尾快照](v1.3-release-validation-2026-09-13.md) 中等待 #44 的状态；保留 #42/#43 失败作为历史证据。
