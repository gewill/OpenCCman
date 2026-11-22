# 持续集成与分支迁移

GitHub Actions 负责回归与依赖候选验证，Xcode Cloud 负责正式签名构建和 TestFlight。日常 PR 合入 `develop`，打包入口见 [分支规范](BRANCHING.md) 与 [Xcode Cloud 指南](XCODE_CLOUD.md)。

## 工作流

下表描述已合入 `develop`、并由发布 PR #210 带入 `main` 的工作流。2026-09-28 已读回：`main` 精确合并提交 `c7734f5a6f4ac3f5f9b5786d78ab1c49268364f3` 的推送 `App Regression` 成功（run `36229902055`）；`main` 继续要求来源绑定 GitHub Actions（app ID 15368）的检查。通过回归不等于 App Store 已公开发布，见[上架准备记录](release/launch-2.0-20260928.md)。

| 工作流 / 检查 | 触发条件 | 执行环境与范围 |
| --- | --- | --- |
| `App Regression` | 目标为 `main`、`develop`、`codex/**`、`release/**`、`hotfix/**` 的 PR；main/develop/release/hotfix 推送；手动运行 | `macos-15`，20 分钟；工程和 Swift 语法、真实转换/文件/预设（文件导出另在 300 MB 的 exFAT、FAT32 映像上检查新建、覆盖与批量提交）、窗口布局、原生控件完整尺寸、编辑器滚动/Introspect、Pro、StoreKit、额度、What’s New、开屏转场、本地化、隔离剪贴板回归、双架构 macOS Debug 验证构建，以及 arm64 iOS Simulator Debug 构建（含分享扩展 `OpenCCmanTextAction`，iOS 专用源码只在这一步编译；两次构建在 macOS 15 上都不含 App 图标，见下文） |
| `App icon` | 与 `App Regression` 相同的 PR 与推送 | `macos-26`，10 分钟；`scripts/check-app-icon.sh` 用 actool 为 macOS 12+ 与 iOS 15+ 编译 `AppIcon.icon`，检查浅色、深色、着色分层图标与旧系统回退图；目前不是必需检查 |
| `Upstream Coordinator Tests` | main/develop/release/hotfix 中修改协调器源码、配置、测试或其 workflow 的 PR/推送；周检；手动运行 | `ubuntu-24.04`，5 分钟；临时 Git 仓库与假 GitHub API 测试，并验证公开 Checks API 的读权限 |
| 上游检测 → 准备 → 发布 | **仅 `main`** 的周一 09:17（UTC+8）或手动运行 | 检测/发布用 Ubuntu；有候选才用 `macos-15` 验证；写令牌仅位于独立发布 job |

所有 Runner 继续使用 GitHub 托管环境。产品部署下限和依赖 revision 由应用工程管理。当前常规回归已包含完整 macOS 验证构建与 iOS Simulator 编译（含分享扩展，#353），并非最初迁移时的纯脚本检查；iOS 只编译、不安装或运行，没有建立模拟器矩阵。

App 图标是 Icon Composer 文件 `OpenCCman/AppIcon.icon`（见 [App 图标](APP_ICON.md)）。Xcode 26.3 的 actool 只能在 macOS 26 及以上的主机上编译它，在 macOS 15 上渲染进程会崩溃（`AssetCatalogAgent-AssetRuntime` 关闭连接）。因此所有构建完整 App 的任务在 checkout 后检查主机版本，低于 26 时通过 `XCODE_XCCONFIG_FILE` 加载 `scripts/without-app-icon.xcconfig`，在不含图标的情况下构建：`App Regression` 的验证构建、iOS Simulator 验证构建、窗口生命周期、编辑器对比、Services 验证与性能基线。这些产物没有 App 图标，其余行为不变；图标本身由 `App icon` 任务在 macOS 26 上检查。普通 PR 仍在 macOS 15 上运行。

`App Regression` 不设置路径过滤，文档 PR 也会产生检查，避免将它设置为 required check 后出现永远等待的情况。协调器检查有路径过滤，不应将它无条件设为所有 PR 必需的检查。应用合并后的 push 检查不可省略：协调器要求目标分支精确 SHA 上已有成功的 `App Regression` 才推广依赖。

PR/推送不会自动准备或发布依赖候选；在其他分支手动运行协调器也只做测试。`build*` 没有纳入新 GitHub Actions 触发范围；旧 `build` 上已有的历史 workflow 在该分支被推送时仍会生效，应停止向它合并。

## 权限和并发

- 默认 `contents: read`；checkout 使用完整 SHA 并设置 `persist-credentials: false`。
- 应用回归按 PR/分支取消旧运行；协调器按 PR/分支隔离 concurrency，同一默认分支的发布流程不相互取消。
- 发布使用短期 GitHub App 令牌，只能写入当前目标仓库；验证候选不持有写令牌。
- 失败报告与候选 artifact 保留原有 7 天策略；云端签名与购买验收仍按发布文档进行。

## 已完成的迁移与历史合并顺序

2026-09-16 核对：[应用迁移 #43](https://github.com/gewill/OpenCCman/pull/43) 和 [默认协调器迁移 #44](https://github.com/gewill/OpenCCman/pull/44) 都已合并，main 上 `app.base` 已是 develop。下面保留原来的依赖顺序作为历史说明，不表示这些 PR 仍待合并。实时保护与旧引用状态见 [分支账本](validation/branching-history-2026-09.md#当前归档账本2026-09-17)。

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

以下发布事项改由 [#122](https://github.com/gewill/OpenCCman/issues/122) 跟踪：

- `main` 的应用回归文件随发布 PR #210 进入；PR 检查已成功且必需检查已配置。合并后仍需核对精确 main SHA 上的推送检查。
- 旧 `build` 与 1.3 打包分支已归档，命名空间已释放，Build 49/50 两端 VALID；见[归档证据](validation/branch-archive-2026-09-17.json)。
- 在明确需要发布验收包时验证临时 `build/*` 的 Xcode Cloud 触发与 TestFlight 产物。

历史验收报告继续保留当时的 `build` 分支事实；新的操作按本指南执行。

## 移动大文件证据工具回归（#260 候选）

本候选在 App Regression 中增加 `test-mobile-capacity-fixtures.py`、`test-mobile-capacity-preflight.py` 与 `test-mobile-export-verifier.py`，检查有界语料生成、UTF-8 边界、导出全文哈希、截断/篡改、错误参考、空集/重复/缺项矩阵的编译前拒绝、拒绝覆盖和非普通文件。合并后才作为默认分支工作流能力；这些小样本工具测试不会生成整套 680 MiB 语料，不安装或操作真机，不代表 100 MiB 容量、内存或系统提供方验收。独立整篇 oracle 及完整容量矩阵继续按 #260 手动验证。

## 控件尺寸回归

`check-control-sizing.sh` 在临时目录按 `Package.resolved` 的精确 SHA 读取 Neumorphic，编译原生 SwiftUI/AppKit 测量程序。覆盖上游 28/30→44 复现、应用 Mac 28/32pt 完整外框、Segment 底座、开关及多行增长；不改依赖缓存。iOS 点击和布局证据见 [三端验收记录](validation/control-sizing/README.md)，此原生 Mac 检查不能代替触屏或 VoiceOver 验收。


## QA 构建的 Bundle ID

App 和 iOS 分享扩展（`OpenCCmanTextAction`，#29）的 Bundle ID 都由项目级设置 `OPENCCMAN_BUNDLE_ID` 派生，扩展为 `$(OPENCCMAN_BUNDLE_ID).TextAction`。QA 和 CI 构建要换 Bundle ID 时，在命令行覆盖 `OPENCCMAN_BUNDLE_ID=…`，不要覆盖 `PRODUCT_BUNDLE_IDENTIFIER`：后者会让扩展和 App 用同一个 ID，iOS 构建虽然成功，模拟器安装时会报 “Mismatched bundle IDs”。`check-text-action.sh` 会拒绝脚本和工作流里的 `PRODUCT_BUNDLE_IDENTIFIER=` 覆盖。

## 手动诊断与构建

`App Regression` 可以手动运行（`workflow_dispatch`），命令是 `gh workflow run app-regression.yml --repo gewill/OpenCCman --ref <分支> -f <输入>=true`。`regression_system` 填系统名，例如 `-f regression_system=macos-26`。下列 job 都在 macOS 15 上运行，只有 `build_ios_validation` 的系统随 `regression_system`。

以下三项不关闭普通回归，该次手动运行仍会执行 `App Regression` job：

- `regression_system`：选择该次手动运行的 `App Regression` 与 `build_ios_validation` 用 `macos-15`（默认）还是 `macos-26`。PR 与推送始终用 macOS 15。见 [macOS 26 单次回归](validation/macos26-regression.md)。
- `build_ios_validation`：job「Build iOS Simulator validation app」，20 分钟。
  - 用配置的 Xcode 26.3 构建未签名的 arm64 iOS Simulator 应用，上传 artifact `ios-simulator-validation-app`，不自动运行设备验收。
  - 普通 App Regression 已用相同参数编译 iOS 目标，只有需要可安装的模拟器包时才用这一项。
- `build_services_validation`：job「Build Release Services validation app」，20 分钟。构建未签名的 universal Mac Release 包，上传 `services-release-validation-app`，供手动测量 Services。见 [可追溯 Release 包](performance/services/README.md#可追溯-release-包)。

以下各项会取代普通回归：勾选任意一项，该次手动运行就不再执行 `App Regression` job。

- `measure_app_baseline`：job「Release application performance baseline」，35 分钟。用 5 个新进程测量 Release 应用的性能基线，上传 `app-performance-baseline`。见 [合并后应用性能基线](performance/integrated-baseline.md)。
- `compare_workspace_editor`：job「Same-runner Release editor comparison」，45 分钟。在同一个 runner 上依次运行固定旧版 `cb73fc5` 和候选版本的 Release 文稿流程并对照，上传 `workspace-editor-comparison`。见 [同机对照入口](performance/native-editor-sizing.md#同机对照入口)。
- `diagnose_editor_anchor`：job「Bounded macOS 15 anchor trace」，10 分钟。原版与追踪版交替运行固定次数，再做一组首轮恢复延迟 120 ms 的对照，上传 `editor-anchor-diagnostic`。见 [编辑器锚点诊断](validation/editor-anchor-diagnosis/README.md)。
- `diagnose_window_lifetime`：job「Native WindowGroup lifetime comparison」，8 分钟。依次运行 EnvironmentObject 与 ObservedObject 两个最小 WindowGroup 变体，上传 `window-lifetime-diagnostic`。见 [模型传递与观察工具对照](performance/window-environment-lifetime/2026-09-15/README.md)。
  - `observe_window_hosts`：在这项诊断里加上对窗口和内容视图的弱引用观察，见 [区分关窗后的窗口、宿主与模型](performance/weak-window-hosts/README.md)。单独勾选时，既不启动诊断，也不关闭普通回归。
- 原生窗口生命周期系列：共用 job「Build native window lifecycle diagnostic app」，20 分钟，构建隔离的 universal Release 诊断包，上传 `native-window-lifecycle-app`。
  - `build_window_lifecycle`：只构建，不在 CI 上测量。见 [原生 WindowGroup 生命周期诊断](performance/native-window-lifecycle/README.md)。
  - `automatic_window_lifecycle`：构建后运行真实 WindowGroup 的自驱动协议。诊断包的最低系统是 macOS 13。见 [真实应用的窗口观察方式对照](performance/native-window-ax-control.md)。
  - `cycle_window_lifecycle`：从菜单新建并关闭窗口，共三轮。见 [三轮原生窗口生命周期验收](performance/native-window-three-cycles.md)。
  - `document_window_lifecycle`：用固定的 1 MiB 和 10 MiB 文稿，通过原生调用主动关闭窗口。见 [原生窗口文稿生命周期验收](performance/native-window-documents.md)。
  - `active_anchor_window_lifecycle`：在文稿协议基础上，于保留窗口转换期间关闭另一个原生窗口。见 [保留窗口活动转换时关闭其他窗口](performance/retained-active-window.md)。
  - `profile_document_stages`：沿用上一项的协议，采样导入和转换时的调用栈，结果只作观察。见 [文稿阶段调用栈诊断](performance/document-stage-profiling.md)。

  同时勾选多项时只运行一种协议，优先级从高到低：
  1. `active_anchor_window_lifecycle` 或 `profile_document_stages`
  2. `document_window_lifecycle`
  3. `cycle_window_lifecycle`
  4. `automatic_window_lifecycle`

  勾选了 `profile_document_stages` 时，测量不要求模型已释放；其余协议都要求。

其他规则：

- 手动运行不执行 `App icon`。普通 PR 和推送始终执行 `App Regression` 与 `App icon`。
- 可选 job 没有运行时显示 skipped，不能当作该项验收已通过。
- 诊断包和回归构建都不能代替 Xcode Cloud 的分发签名产物。

本节以 develop `fbe32ca` 的工作流为准。增删手动入口时同步更新本节，不要把候选工作流写成已上线的能力。

## Xcode 27 与 RevenueCat 编译诊断

### iPhone Duo 的本地 27.1 构建入口

`scripts/build-duo-validation.py` 使用显式选择的 Xcode 27.1+，顺序构建 arm64
iOS Simulator 和 arm64/x86_64 macOS QA 应用。它不替换必需的 App Regression，
不更改 Xcode Cloud，也不触发分发。当前 GitHub 工作流仍为 Xcode 26.3；没有
将本地通过写成 CI 已覆盖 27.1。

```bash
python3 Tests/Regression/DuoBuildChecks.py
python3 scripts/build-duo-validation.py \
  --developer-dir /Applications/Xcode-27.1.0.app/Contents/Developer \
  --output "$HOME/Library/Application Support/Codex/ui-evidence/OpenCCman/277-duo/<source-sha>/<new-run>" \
  --derived-data "$HOME/Library/Caches/Codex/OpenCCman-duo/<candidate>"
```

可用 `--platform ios|mac` 定向运行，`--configuration Release` 构建 Release，或
以 `--build-wrapper /absolute/path/to/axbuild` 使用已验证的构建诊断工具。
证据和 DerivedData 必须在仓库外，证据目录不可覆盖已有结果。脚本在调用
Xcode 前检查正在运行的 xcodebuild，发现其他构建则停止，不杀进程。

`report.json` 绑定 source SHA、工作区 diff／未跟踪文件哈希及依赖锁哈希，并
保存有效 build settings、原生命令、系统／工具链、生成 plist 和二进制哈希。
校验依据是产物的 DTSDKName、Mach-O SDK、最低系统、iPhone/iPad 设备族、
scene manifest、LaunchScreen、indirect input 与方向，不以源 plist 代替生成结果。
iOS SDK 至少为 27.1；macOS SDK 与所选 Xcode 实际附带版本核对（本机 Xcode
27.1 附带 macOS 27.0 SDK），不要求两个平台的 SDK 小版本相同。最低系统仍为
iOS 15／macOS 12。脚本失败返回非零；
检查具体日志和 report 的失败原因，不反复覆盖旧证据。

QA Bundle ID 为 `org.gewill.OpenCCman.WhatsNewUITests`，不会替换正式安装。
该入口仅对已确认的 iOS 27.1+ SDK 添加 `OPENCCMAN_DUO_SDK` 编译条件；Debug QA
包再显式传 `-qa-duo-trace` 才输出容器／safe area／真实 division reserved region、
scene／模型及原生编辑器身份、选区、焦点和滚动位置。日志不含稿件文字；Release、
正式 Bundle ID 和没有该参数的运行均不输出。常规 Xcode 26.3／27.0 构建不引用
27.1 专属类型，运行时的 27.1 probe 也有 availability 检查。
构建通过不证明 Duo 姿态、输入、真机、签名包、购买或最低系统运行通过；
这些结果分别记录在 #277–#282 及既有验收 Issues。

[#107 的隔离复现与工具链策略](validation/toolchain-compatibility/README.md)记录 Swift 6.4 下初始化器冲突及 RevenueCat 5.78.0 的官方修复。当前 App Regression 继续使用 Xcode 26.3；本诊断不更改应用依赖、最低系统或 Xcode Cloud。独立源文件类型检查不能替代完整升级验收。


## 2026-09-17 更新

#120/#118 已将应用升级为 RevenueCat 5.78.0、iOS 15/macOS 12；Xcode 27 Cloud Build 53 两端成功且 VALID，见 [Build 53](validation/build-53/README.md)。上文独立编译诊断保留为历史证据，不表示升级尚未发生。

本次仅归档旧分支并更新文档，没有调整 CI 工作流。main/develop 保护读回未变，旧 build 的管理员、PR、禁止强推/删除及来源绑定检查在归档分支保留。main 尚无应用回归，继续仅要求 PR；#122 在发布 PR 带入工作流并取得真实成功检查后、合并前增加必需检查。带斜线打包验证仍需下一次明确授权；归档没有启动新的 Cloud 构建。
