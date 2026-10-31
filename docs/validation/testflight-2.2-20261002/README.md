# 2.2 TestFlight 候选更新（2026-10-02）

本轮按维护者“发新的 TestFlight”指示更新候选。通过 PR 同步到 `release/v2.2` 后，才从其确切合并提交推送新的 `build/v2.2-20261002` 触发 Xcode Cloud。实际 run ID、云端 build 号、两端 build ID、处理与分发状态在本次候选 PR 的构建完成评论中归档；本页不是已分发的声明。

## 来源与合并

- 当前集成源码：`a6158a7ef89278381a72302772feb9ab179c1817`，包含 #271 与 #272，精确 develop 提交的 App Regression 已通过。
- 上一验收候选：`aad2b09931e34dbfab3e8218be22e94cd604fbb6`，Xcode Cloud 61、2.2(61)，由 #267 开启移动端 100 MiB 入口。
- 唯一代码冲突在 `MobileFileRuntime` 的入口开关。采用最新 develop 实现，保留 release 的 `productionEnabled = true` 和 develop 的 `experimentalCapacityEnabled = false`。
- 相对最新 develop，产品差异仅为已有候选的版本 2.2 与移动端 100 MiB 入口。iOS 15／macOS 12、依赖锁、权益与额度规则不变。

## 可验收范围

| 平台 | 范围 |
| --- | --- |
| iPhone／iPad | Pro TXT 文件工作流最高 100 MiB：转换、取消、保存取消／重试、完成结果重新保存与恢复。编辑器仍为 10 MiB。1 GiB 实验入口关闭。 |
| Mac | Pro TXT 文件工作流最高 1 GiB，包含空间查询回退和常规任务取消两倍空间预检的修复。8 GiB 实验入口关闭。 |

UI 与交互证据归档在 [#271](https://github.com/gewill/OpenCCman/pull/271) 和 [#272](https://github.com/gewill/OpenCCman/pull/272)。本次只同步已合并实现并保留旧候选入口，没有新增界面设计；旧证据保持原始 SHA，不改标为新签名包已验收。

## 本地验证

- 核心回归 17 组通过；工程／Swift 语法、语言与控件标签检查通过。
- Xcode 27.0 下 macOS Debug arm64／x86_64 和 iOS Simulator Debug arm64 构建均成功；构建均为未签名本地验证包。
- `git diff --check` 通过，锁文件与 develop 完全一致；确认两端更高容量实验开关都为 false。
- PR 的当前 HEAD 必须通过 App Regression，并完成冲突和候选差异复核后才合并／打包。

三语、双平台测试说明见 [test-notes.json](test-notes.json)。后续只写入本轮新 build，不修改旧 build 的说明，沿用 Build 61 的 Internal Group；不提交外部 Beta 审核、不改价格或正式 App Store 版本。

签名包验收仍按 #260 / #268 / #269 的关闭标准分别追踪；云端成功和 TestFlight 可安装不等于上述项目全部通过。
