# 分支管理规范

开工、日常验证、整合、Issue 处理、发布与热修复的通用流程见共享 [分支管理规范](https://github.com/gewill/dev-standards/blob/main/branching_guide.md)（私有仓库，2026-11-03 按 `main` `64b58f1` 核对）。本文只记录 OpenCCman 与之不同或需要落实的部分：分支模式、远端保护、CI／打包触发器和版本命名。

## 分支模式

采用 `main` + `develop` 双分支。默认分支仍为 `main`：它承载已发布版本与每周上游同步协调器；`develop` 是下一版本的日常集成分支。

| 分支 | 来源 | 合入目标 | 本项目约定 |
| --- | --- | --- | --- |
| `codex/<issue>-<topic>` 或 `feature/<issue>-<topic>` | 最新 `develop` | `develop` | 日常任务分支；没有 Issue 的独立文档任务可省略编号，如 `codex/docs-branching` |
| `release/v<version>` | 已集成的 `develop` | `main`，随后回流 `develop` | 可选，需要冻结版本同时继续开发时使用 |
| `hotfix/<issue>-<topic>` | 最新 `main` | `main`、`develop` | 已发布版本的紧急修复 |
| `build/v<version>[-<topic>]-<YYYYMMDD>[-NN]` | 明确的候选提交（`develop`、`release/*` 或 `main`） | 不合并 | 只用于触发 Xcode Cloud，见下文 |

只改默认分支协调器的维护任务从 `main` 建分支并合回 `main`，随后同步到 `develop`，避免发布时覆盖自动化配置；不得借此让普通应用开发绕过 `develop`。2026-09 的迁移、保护启用与旧 `build` 归档记录见 [历史账本](validation/branching-history-2026-09.md)。

## 远端保护（2026-11-03 只读核对）

| 项目 | `main` | `develop` |
| --- | --- | --- |
| 必须通过 PR 更新 | 是，审批数 0（单人维护） | 是，审批数 0 |
| 必需检查 | `App Regression`，绑定 GitHub Actions（app ID 15368），`strict=false` | 同左 |
| 约束管理员 | 是 | 是 |
| 强推／删除 | 禁止 | 禁止 |
| 线性历史、会话解决 | 未要求 | 未要求 |

仓库没有 ruleset；squash、merge commit、rebase 三种合并方式都允许；2026-11-03 应维护者要求开启仓库 auto-merge（仍须必需检查通过），未开启合并后自动删分支。

与共享规范的差异：

- 远端强制 PR，共享规范里“小改动直接提交到 `develop`”在本项目不适用；即使是文档或单行修改，也从任务分支通过 PR 合入 `develop`。PR 只是满足远端门槛，不因此增加全量测试、UI 自动化或截图要求。
- 每个 PR（含纯文档）都会运行 `App Regression`，合并前当前 HEAD 必须通过；不以管理员身份绕过。
- PR 不使用 `Closes #N` 等关键字自动关闭 Issue，Issue 按其自身关闭标准手动处理。
- 普通任务 PR 可 squash；发布 PR 当前 HEAD 检查通过后 Squash and merge 到 `main`。上游同步的 SwiftyOpenCC 层和历史迁移必须用 merge commit 保留祖先关系，见 [上游同步](upstream-sync.md)。

## CI 与打包触发器

- `App Regression`：目标为 `main`、`develop`、`codex/**`、`release/**`、`hotfix/**` 的 PR，以及 `main`、`develop`、`release/**`、`hotfix/**` 的推送，另可手动运行。检查项与构建参数见 [CI 指南](CI.md)。
- 上游同步协调器只在 `main` 上每周一 09:17（UTC+8）或手动运行时准备、发布候选，见 [上游同步](upstream-sync.md)。
- Xcode Cloud `Default` workflow 自动匹配**以 `build` 开头**的分支名，包括 `build`、`build-*` 和 `build/*`，见 [Xcode Cloud 指南](XCODE_CLOUD.md)。因此：
  - 日常开发、文档修改和审查不使用 `build` 前缀；`codex/`、`release/`、`hotfix/`、`main`、`develop` 都不会触发打包。
  - 不保留名为 `build` 的常驻分支，避免与 `build/*` 引用冲突。
  - 同一天重复打包追加序号，例如 `build/v2.2-20261031-02`；确认产物、SHA 与构建号已记录后再删除。
- Xcode Cloud 构建、TestFlight 分发和 App Store 发布是不同步骤；GitHub Actions 回归通过不能代替签名包验收。

## 版本命名

- Marketing 版本为 `主.次`（如 `2.2`），构建号以 Xcode Cloud 的 build 号为准，记作 `2.2(63)` 这类形式；本地工程 build 号不能代替云端产物身份。
- 发布 Tag 为带注释的 `v<version>`（如 `v2.2`），指向发布 PR squash 后的 `main` 提交；推送时点按共享 [Release 规范](https://github.com/gewill/dev-standards/blob/main/github_release_guide.md)。`v1.0-macOS`、`v1.1-macOS` 是早期仅 macOS 的历史 Tag，不再沿用。
- README 以英文 `README.md` 为主，日常改动只改英文版。每次发版（App Store 公开）后，按当时的英文 README 同步更新 `README.zh-Hans.md`、`README.zh-Hant.md`，繁体用词遵循 dev-standards 的 `zh_hant_terminology_guide.md`；两次发版之间中文版可以落后于英文版。
- 每次上架记录写在 `docs/release/launch-<version>-<YYYYMMDD>.md`，Store 素材与元数据分别放在 `docs/release/store-assets-*`、`docs/release/metadata-*`。
