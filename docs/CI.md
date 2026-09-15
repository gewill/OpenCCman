# 持续集成与分支迁移

GitHub Actions 负责回归与依赖候选验证，Xcode Cloud 负责正式签名构建和 TestFlight。日常 PR 合入 `develop`，打包入口见 [分支规范](BRANCHING.md) 与 [Xcode Cloud 指南](XCODE_CLOUD.md)。

## 工作流

下表描述已合入 develop 的工作流。main 目前还没有应用回归文件，不能仅因触发模式包含 main 就认为 main 推送已会运行 App Regression；其发布整合与保护门禁需分别完成。

| 工作流 / 检查 | 触发条件 | 执行环境与范围 |
| --- | --- | --- |
| `App Regression` | 目标为 `main`、`develop`、`codex/**`、`release/**`、`hotfix/**` 的 PR；main/develop/release/hotfix 推送；手动运行 | `macos-15`，20 分钟；工程和 Swift 语法、真实转换/文件/预设、窗口布局、原生控件完整尺寸、编辑器滚动/Introspect、Pro、StoreKit、额度、What’s New、本地化、隔离剪贴板回归及双架构 macOS Debug 验证构建 |
| `Upstream Coordinator Tests` | main/develop/release/hotfix 中修改协调器源码、配置、测试或其 workflow 的 PR/推送；周检；手动运行 | `ubuntu-24.04`，5 分钟；临时 Git 仓库与假 GitHub API 测试，并验证公开 Checks API 的读权限 |
| 上游检测 → 准备 → 发布 | **仅 `main`** 的周一 09:17（UTC+8）或手动运行 | 检测/发布用 Ubuntu；有候选才用 `macos-15` 验证；写令牌仅位于独立发布 job |

所有 Runner 继续使用 GitHub 托管环境。产品部署下限和依赖 revision 由应用工程管理。当前常规回归已包含完整 macOS 验证构建，并非最初迁移时的纯脚本检查；没有建立模拟器矩阵。

`App Regression` 不设置路径过滤，文档 PR 也会产生检查，避免将它设置为 required check 后出现永远等待的情况。协调器检查有路径过滤，不应将它无条件设为所有 PR 必需的检查。应用合并后的 push 检查不可省略：协调器要求目标分支精确 SHA 上已有成功的 `App Regression` 才推广依赖。

PR/推送不会自动准备或发布依赖候选；在其他分支手动运行协调器也只做测试。`build*` 没有纳入新 GitHub Actions 触发范围；旧 `build` 上已有的历史 workflow 在该分支被推送时仍会生效，应停止向它合并。

## 权限和并发

- 默认 `contents: read`；checkout 使用完整 SHA 并设置 `persist-credentials: false`。
- 应用回归按 PR/分支取消旧运行；协调器按 PR/分支隔离 concurrency，同一默认分支的发布流程不相互取消。
- 发布使用短期 GitHub App 令牌，只能写入当前目标仓库；验证候选不持有写令牌。
- 失败报告与候选 artifact 保留原有 7 天策略；云端签名与购买验收仍按发布文档进行。

## 已完成的迁移与历史合并顺序

2026-09-16 核对：[应用迁移 #43](https://github.com/gewill/OpenCCman/pull/43) 和 [默认协调器迁移 #44](https://github.com/gewill/OpenCCman/pull/44) 都已合并，main 上 `app.base` 已是 develop。下面保留原来的依赖顺序作为历史说明，不表示这些 PR 仍待合并。实时保护与旧引用状态见 [分支账本](BRANCHING.md#当前迁移账本2026-09-16)。

1. **应用 CI 迁移 → `develop`**：通过 merge commit 接回旧 `build` 的 1.3 应用历史与 `main` 的协调器历史，保留已合入的分支规范。仅解决 README 的文档冲突，应用源码、工程与依赖锁文件保持旧 `build` 的内容。更新 CI 触发分支和应用侧同步配置。
2. 等待 `develop` 合并提交的 `App Regression` 成功。配置 required check 时使用实际 job 名 `App Regression`，不绕过失败或尚未运行的检查。
3. **默认分支协调器迁移 → `main`**：仅同步协调器 workflow、配置、测试和说明，将自动依赖 PR 的基线改为 `develop`；不在此 PR 发布应用。切换前检查旧候选，确保没有待审依赖 PR 仍指向 `build`。
4. 默认分支更新后，通过只读 `check --stage app` 核对基线与状态；没有候选时不运行 macOS 准备或打包。未来发布 PR 将同一协调器内容保留在两条主线中。

两层 PR 均只准备候选，不自动合并。第一层必须选 **Create a merge commit**，不要 squash/rebase 掉历史迁移的祖先关系。当时要求先确认默认分支配置合并，再视为线上切换；该步骤现已由 #44 完成。

## 验证与剩余事项

本地验证使用 `actionlint` 检查两个 workflow，运行协调器集成测试，并检查 diff 和应用源码/锁文件一致性。协调器新增覆盖：仓库不存在旧 `build` 引用时，准备和发布仍将 PR 指向 `develop`，不会推进基线分支。

2026-09-13 本地验证结果：30 项协调器集成测试通过（51 秒）；`actionlint 1.7.7` 检查两个 workflow 通过；触发分支矩阵、权限与 Action SHA、周检时间与发布条件、文档链接检查通过。确认候选保留 `build`、`main`、`develop` 三条历史，应用源码、工程、依赖锁文件和原有回归语料与旧 `build` 无差异；两个 PR 的协调器文件逐字节一致。

PR 与合并后真实 GitHub Actions 运行结果是线上验收依据。纯迁移无需重跑签名归档或模拟器测试；现有回归由新 PR 的 CI 执行。

2026-09-16 已启用经典分支保护：`main`、`develop` 均要求 PR，包含管理员，禁止强推和删除；`develop` 必须通过由 GitHub Actions（app ID 15368）提供的 `App Regression`。不强制额外审批者，不允许机器人绕过；`strict=false` 保留按依赖推进的流程，不要求每次基线更新都重跑无关候选。源码整合或候选变化后仍按既定规则重新验证。

[请求与回读证据](validation/branch-protection-2026-09-16.json)记录实际配置；采用 GitHub 官方 [分支保护 API](https://docs.github.com/en/rest/branches/branch-protection#update-branch-protection) 的 `checks` 字段绑定检查来源。文档 PR #111 和堆叠 PR #108 已产生 App Regression，条件诊断 job 和路径过滤的协调器 job 不列为必需检查。

以下事项仍由 [#110](https://github.com/gewill/OpenCCman/issues/110) 跟踪：

- `main` 的应用回归文件随验收后的发布 PR 进入后再增加对应必需检查；当前只要求 PR，避免永久等待。
- 归档并退出旧 `build` 引用，释放 `build/*` 命名空间；先核对关联 PR、保护规则和云端构建。
- 在明确需要发布验收包时验证临时 `build/*` 的 Xcode Cloud 触发与 TestFlight 产物。

历史验收报告继续保留当时的 `build` 分支事实；新的操作按本指南执行。

## 控件尺寸回归

`check-control-sizing.sh` 在临时目录按 `Package.resolved` 的精确 SHA 读取 Neumorphic，编译原生 SwiftUI/AppKit 测量程序。覆盖上游 28/30→44 复现、应用 Mac 28/32pt 完整外框、Segment 底座、开关及多行增长；不改依赖缓存。iOS 点击和布局证据见 [三端验收记录](validation/control-sizing/README.md)，此原生 Mac 检查不能代替触屏或 VoiceOver 验收。


## 手动诊断与构建

当前 develop 的 `workflow_dispatch` 提供：

- `build_ios_validation`：用配置的 Xcode 26.3 构建未签名 arm64 iOS Simulator 应用，不自动运行设备验收；此选项不会关闭普通 App Regression。
- `diagnose_window_lifetime`：在 macOS 15 顺序运行两个最小 WindowGroup 变体。可配合 `observe_window_hosts` 记录弱窗口/初始宿主；后者单独勾选不启动诊断。
- `diagnose_editor_anchor`：运行固定 macOS 15 编辑器锚点诊断。

两种 diagnose 入口取代该次手动运行的普通 regression job；普通 PR/push 始终执行 App Regression。可选 job 没运行时显示 skipped，不能当作该项验收通过。诊断包和回归构建都不能代替 Xcode Cloud 的分发签名产物。

该清单以核对时 develop `b2e0e63` 为准；尚在 PR 中的真实 WindowGroup Release 构建等扩展，合并后再纳入当前入口说明，不把候选工作流写成已上线能力。

## Xcode 27 与 RevenueCat 编译诊断

[#107 的隔离复现与工具链策略](validation/toolchain-compatibility/README.md)记录 Swift 6.4 下初始化器冲突及 RevenueCat 5.78.0 的官方修复。当前 App Regression 继续使用 Xcode 26.3；本诊断不更改应用依赖、最低系统或 Xcode Cloud。独立源文件类型检查不能替代完整升级验收。
