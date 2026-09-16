# Xcode Cloud 构建与发布

OpenCCman 正式构建和分发使用 Xcode Cloud。执行构建、修改 workflow 或更新 TestFlight 信息前，应先核对本文。配置核对日期：2026-09-13；以下 App 和 workflow ID 来自 App Store Connect 实际查询。

## App 与 workflow

| 项目 | 当前值 |
| --- | --- |
| App ID | `6474449401` |
| Bundle ID | `org.gewill.OpenCCman` |
| Workflow | `Default` |
| Workflow ID | `00F5435C-1C48-4750-88FA-4563D018E4B3` |
| 工程 / Scheme | `OpenCCman.xcodeproj` / `OpenCCman` |
| 归档平台 | iOS、macOS，均为必须通过的 `APP_STORE_ELIGIBLE` action |
| 自动触发 | 分支名以 `build` 开头：`pattern: build`、`isPrefix: true` |
| 其他设置 | enabled、clean、autoCancel 均为 true |

当前规则包含 `build` 本身及其他以 `build` 开头的分支，并不是仅匹配 `build/*`。向旧 `build` 合并仍会自动触发，因此日常应用 PR 改以 `develop` 为目标。`main`、`develop`、`release/*`、`hotfix/*` 和 `codex/*` 均不符合该打包规则。分支职责见 [分支规范](BRANCHING.md)，CI 迁移进度见 [CI 指南](CI.md)。不要为了补跑另建同名规则的 workflow，也不要照搬其他项目的 App ID、workflow 名称或分支模式。

## 构建顺序

1. 应用修复以 PR 合入 `develop`，从已集成代码建立 `release/*` 发布候选。引擎变更先合入 SwiftyOpenCC，通过检查后再以独立应用 PR 固定完整 revision；不从尚未合并的引擎分支发布。
2. 仅在需要云端验收包时，从明确的 `release/*` 或 `main` 提交创建并推送临时 `build/<version>-<YYYYMMDD>`，事先确认 SHA、版本与 `Package.resolved`。旧 `build` 尚未退出前与 `build/*` 有引用命名冲突，先完成归档和退出迁移；普通 PR 合并不再承担打包入口。正式发布记录使用云端 run/build 号、平台和 source commit；本地工程 build 号不能代替云端产物身份。
3. 推送后先检查是否已自动触发。只有自动触发失败且需要构建时才手动运行，避免重复归档。不要为了文档核对启动新的构建。
4. 同时核对 iOS/macOS action 和 App Store Connect processing 状态。归档成功、整个 run 成功、处理为 `VALID`、可供 TestFlight 安装是不同阶段。
5. 用本次云端产物完成购买、文件、跨 App 和旧系统验收。只有需要发布测试说明时才修改本次新 build 的 What to Test；不要误改旧 build 或顺带通知测试者。

## 查询与手动补跑

```bash
asc xcode-cloud workflows --app 6474449401 --output json
asc xcode-cloud build-runs \
  --workflow-id 00F5435C-1C48-4750-88FA-4563D018E4B3 \
  --sort=-number --limit 5 --output json
```

以下命令会真实启动构建；执行前将示例分支替换为已确认的远端打包分支，核对它指向要构建的提交，并确认没有同一提交的运行中任务：

```bash
asc xcode-cloud run \
  --app 6474449401 \
  --workflow Default \
  --branch build/v1.3-YYYYMMDD
```

用返回的 run ID 查询或诊断；只有任务明确要求等待检查、合并或发布时才持续等待。原始构建日志可能包含签名服务响应，先脱敏再附入公开 PR。

```bash
asc xcode-cloud status --run-id <RUN_ID>
asc xcode-cloud doctor --run-id <RUN_ID> --save-logs /tmp/openccman-cloud-logs
```

## 本地验证与签名

本地 Release Archive、`.ipa`、`.pkg` 只用于诊断和构建验证；不作为此项目的正式上传路径。Xcode Cloud 管理云端签名，本机 Keychain 的证书不会自动成为云端修复。不要把本地私钥或 provisioning profile 提交到仓库或塞入云端脚本。

2026-09-13 的本地导出补建了一个 Apple Distribution 身份和两个本地 App Store profiles，身份保存在登录 Keychain，生成时的明文私钥副本已删除；这不是正式发布前置步骤，不应在日常云端构建中重复执行。

## 资源签名阻塞与修复证据

**后续验证已通过**：引擎修复及应用依赖 PR #32 已合并。Xcode Cloud #44 两平台归档和内部 TestFlight 分发成功，ASC 两 build 均为 VALID；macOS 已从 TestFlight 安装并完成启动/基本转换。详见 [#44 验证记录](xcode-cloud-44-testflight-validation.md)。以下 #42 为已解决问题的历史记录。

云端 run **#42**（`2f6ea0dc-1f97-419a-a95c-c81b487712a3`，应用 SHA `c2c8581b8f1b781f5c05321f58fe484634341374`）中 macOS Archive 成功，iOS Archive 失败，两平台 TestFlight 内部测试动作被跳过。iOS 日志明确指向 `SwiftyOpenCC_OpenCC.bundle` 的 `bundle format unrecognized, invalid, or unsuitable`。

本地对同一资源 bundle 执行云端使用的 ad-hoc `codesign` 可复现失败；去除 bundle 顶层名为 `Resources` 的目录后可签名。[引擎 PR #5](https://github.com/gewill/SwiftyOpenCC/pull/5) 已调整 SwiftPM 资源布局及读取路径，保留词典字节和公开接口，并加入通过本地验证的 iOS 资源 bundle 签名检查。不得禁用云端签名来掩盖错误。

#42 不能作为发布通过证据；修复后的 #44 构建结果已补齐，但最终购买、跨 App 和旧系统等验收仍需完成。完整范围见 [1.3 收尾记录](v1.3-release-validation-2026-09-13.md) 和 [项目完整报告](project-status-and-follow-up-2026-09-13.md)。

配置结构参考维护者提供的 iPerfman `docs/XCODE_CLOUD.md`；本项目数值与规则均独立核对。workflow 配置位于 App Store Connect，任何后续调整都应同步更新本文。

## 2026-09-16 工具链兼容修复

2.0 Build 51（源码 `450c74af97532cc8e3eb62f362edc392d938722a`）在 iOS 与 macOS 归档开始时失败：云端 SDK 27 分别要求最低 iOS 15、macOS 12，与当前 iOS 14 / macOS 11 支持范围不符。

已向 Default workflow 提交固定 Xcode 26.3 (`17C529`) / macOS Tahoe 26.3 (`25D125`) 的配置更新，不提高应用部署下限、不更改依赖。Xcode 版本 ID `5061ab6a-e61b-4d8b-893d-d3b13acabeea`，macOS 版本 ID `44c68446-99a7-4ef8-adce-d90be94f22b2`，两者来自当前 Cloud API 可用组合。随后从同一打包分支手动启动 Build 52 (`aa665f62-c781-4cf9-ad60-f137424622f2`)；最终归档工具链与 TestFlight 状态必须以本次产物和日志核实，不能以更新 API 成功响应代替。
