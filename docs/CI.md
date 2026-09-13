# 持续集成与分支迁移

GitHub Actions 负责回归与依赖候选验证，Xcode Cloud 负责正式签名构建和 TestFlight。日常 PR 合入 `develop`，打包入口见 [分支规范](BRANCHING.md) 与 [Xcode Cloud 指南](XCODE_CLOUD.md)。

## 工作流

| 工作流 / 检查 | 触发条件 | 执行环境与范围 |
| --- | --- | --- |
| `App Regression` | 目标为 `main`、`develop`、`release/**`、`hotfix/**` 的 PR；这些分支的推送；手动运行 | `macos-15`，20 分钟；工程和 Swift 语法、真实转换/文件/预设、窗口布局、原生控件完整尺寸、编辑器滚动、额度、What’s New、本地化和隔离剪贴板回归 |
| `Upstream Coordinator Tests` | 上述分支中修改协调器源码、配置、测试或其 workflow 的 PR/推送；周检；手动运行 | `ubuntu-24.04`，5 分钟；临时 Git 仓库与假 GitHub API 测试，并验证公开 Checks API 的读权限 |
| 上游检测 → 准备 → 发布 | **仅 `main`** 的周一 09:17（UTC+8）或手动运行 | 检测/发布用 Ubuntu；有候选才用 `macos-15` 验证；写令牌仅位于独立发布 job |

所有 Runner 继续使用 GitHub 托管环境。原有回归脚本、部署下限与依赖 revision 不随此次 CI 迁移改变；不引入完整 Xcode 构建或模拟器矩阵。

`App Regression` 不设置路径过滤，文档 PR 也会产生检查，避免将它设置为 required check 后出现永远等待的情况。协调器检查有路径过滤，不应将它无条件设为所有 PR 必需的检查。应用合并后的 push 检查不可省略：协调器要求目标分支精确 SHA 上已有成功的 `App Regression` 才推广依赖。

PR/推送不会自动准备或发布依赖候选；在其他分支手动运行协调器也只做测试。`build*` 没有纳入新 GitHub Actions 触发范围；旧 `build` 上已有的历史 workflow 在该分支被推送时仍会生效，应停止向它合并。

## 权限和并发

- 默认 `contents: read`；checkout 使用完整 SHA 并设置 `persist-credentials: false`。
- 应用回归按 PR/分支取消旧运行；协调器按 PR/分支隔离 concurrency，同一默认分支的发布流程不相互取消。
- 发布使用短期 GitHub App 令牌，只能写入当前目标仓库；验证候选不持有写令牌。
- 失败报告与候选 artifact 保留原有 7 天策略；云端签名与购买验收仍按发布文档进行。

## 迁移 PR 的合并顺序

1. **应用 CI 迁移 → `develop`**：通过 merge commit 接回旧 `build` 的 1.3 应用历史与 `main` 的协调器历史，保留已合入的分支规范。仅解决 README 的文档冲突，应用源码、工程与依赖锁文件保持旧 `build` 的内容。更新 CI 触发分支和应用侧同步配置。
2. 等待 `develop` 合并提交的 `App Regression` 成功。配置 required check 时使用实际 job 名 `App Regression`，不绕过失败或尚未运行的检查。
3. **默认分支协调器迁移 → `main`**：仅同步协调器 workflow、配置、测试和说明，将自动依赖 PR 的基线改为 `develop`；不在此 PR 发布应用。切换前检查旧候选，确保没有待审依赖 PR 仍指向 `build`。
4. 默认分支更新后，通过只读 `check --stage app` 核对基线与状态；没有候选时不运行 macOS 准备或打包。未来发布 PR 将同一协调器内容保留在两条主线中。

两层 PR 均只准备候选，不自动合并。第一层必须选 **Create a merge commit**，不要 squash/rebase 掉历史迁移的祖先关系。默认分支配置尚未合并前，线上周检仍按旧配置运行。

## 验证与剩余事项

本地验证使用 `actionlint` 检查两个 workflow，运行协调器集成测试，并检查 diff 和应用源码/锁文件一致性。协调器新增覆盖：仓库不存在旧 `build` 引用时，准备和发布仍将 PR 指向 `develop`，不会推进基线分支。

2026-09-13 本地验证结果：30 项协调器集成测试通过（51 秒）；`actionlint 1.7.7` 检查两个 workflow 通过；触发分支矩阵、权限与 Action SHA、周检时间与发布条件、文档链接检查通过。确认候选保留 `build`、`main`、`develop` 三条历史，应用源码、工程、依赖锁文件和原有回归语料与旧 `build` 无差异；两个 PR 的协调器文件逐字节一致。

PR 与合并后真实 GitHub Actions 运行结果是线上验收依据。纯迁移无需重跑签名归档或模拟器测试；现有回归由新 PR 的 CI 执行。

以下操作需在上述 PR 按顺序合并后继续，不因候选代码已准备而视为完成：

- 给 `develop` 配置 PR 和 `App Regression` 保护；`main` 的应用回归文件要随验收后的发布 PR 进入，不能提前要求一个尚不存在的检查。
- 归档并退出旧 `build` 引用，释放 `build/*` 命名空间；先核对关联 PR、保护规则和云端构建。
- 在明确需要发布验收包时验证临时 `build/*` 的 Xcode Cloud 触发与 TestFlight 产物。

历史验收报告继续保留当时的 `build` 分支事实；新的操作按本指南执行。

## 控件尺寸回归

`check-control-sizing.sh` 在临时目录按 `Package.resolved` 的精确 SHA 读取 Neumorphic，编译原生 SwiftUI/AppKit 测量程序。覆盖上游 28/30→44 复现、应用 Mac 28/32pt 完整外框、Segment 底座、开关及多行增长；不改依赖缓存。iOS 点击和布局证据见 [三端验收记录](validation/control-sizing/README.md)，此原生 Mac 检查不能代替触屏或 VoiceOver 验收。
