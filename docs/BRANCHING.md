# 分支管理规范

OpenCCman 采用与 Pingman 相同的精简版 Git Flow：常驻分支为 `main` 与 `develop`，开发、发布、热修复和打包使用临时分支。日常 PR 合入 `develop`；只有需要 Xcode Cloud 产物时才推送 `build` 前缀的分支。

**2026-09-16 已核实：日常开发和 CI 已迁移到 `develop`，默认分支协调器也已使用 `develop` 作为应用 PR 目标。** [#43](https://github.com/gewill/OpenCCman/pull/43) 与 [#44](https://github.com/gewill/OpenCCman/pull/44) 均于 2026-09-13 合并。默认分支仍为 `main`；main/develop 的 PR 保护与 develop 的 App Regression 门禁已启用；旧 `build` 已于 2026-09-17 归档；正式发布主线整合由 #122 跟踪，见文末账本、[CI 说明](CI.md)与 [#110](https://github.com/gewill/OpenCCman/issues/110)。

## 分支职责

| 分支 | 来源 | 合入目标 | 用途 |
| --- | --- | --- | --- |
| `main` | `release/*`、`hotfix/*` | — | 验收通过、可交付的版本；发布提交创建版本 Tag，同时承载默认分支上的上游同步协调器 |
| `develop` | `main`，迁移时接回旧 `build` 历史 | — | 下一版本的日常集成分支 |
| `codex/<issue>-<topic>` 或 `feature/<issue>-<topic>` | `develop` | `develop` | 单一功能、修复、测试或文档任务；Codex 默认使用 `codex/` |
| `release/v<version>` | `develop` | `main`、`develop` | 版本冻结、验收与发布阻断修复 |
| `hotfix/<issue>-<topic>` | `main` | `main`、`develop` | 已发布版本的紧急修复 |
| `build/<version>-<YYYYMMDD>` | 已确认的 `release/*` 或 `main` 提交 | 不合并 | 触发 Xcode Cloud 的临时打包分支 |

仅修改默认分支协调器的维护 PR，从 `main` 新建任务分支并合回 `main`；不得借此将普通应用开发绕过 `develop`。协调器变更也应通过 PR 同步到 `develop`，避免之后发布时覆盖自动化配置。

## `build` 前缀会触发 Xcode Cloud

当前工作流按分支名前缀 `build` 匹配，包括 `build`、`build-*` 和 `build/*`。向旧 `build` 合并 PR 同样会触发云端打包，因此不能继续将它作为日常集成分支。

- 日常开发、文档修改和代码审查均不使用 `build` 前缀。
- 只有明确需要生成安装包时，才从指定提交创建并推送打包分支。
- 打包分支不作为 PR 基线，不追加开发提交；需要修改时回到发布或热修复分支，再选定新的候选提交打包。
- 同一天多次打包可添加序号，例如 `build/v2.0-YYYYMMDD-02`。
- 确认构建产物及对应提交后再删除打包分支；发布版本由 Tag 长期追踪。
- 不保留名为 `build` 的常驻分支。Git 的 `build` 引用与 `build/*` 存在命名冲突，旧分支退出前不要直接创建子路径分支。

Xcode Cloud 构建、TestFlight 分发和 App Store 发布是不同步骤。推送打包分支不等于已完成测试或商店发布，也不能以 GitHub Actions 回归通过代替签名包验收。

## 日常开发

功能、普通修复和文档修改都从最新 `develop` 新建任务分支，通过 PR 合回 `develop`：

```bash
git fetch origin
git switch develop
git merge --ff-only origin/develop
git switch -c codex/<issue>-<topic>
# 修改并完成必要验证后提交
git push -u origin HEAD
gh pr create --base develop
```

没有对应 Issue 的独立文档任务可省略编号，例如 `codex/docs-branching`。一个分支只承载一项任务，不复用已合并分支，不通过 `HEAD:develop` 绕过 PR。

若现有工作区有未提交改动、正在承担其他任务，使用独立 worktree，不切换或重置开发者工作区：

```bash
git fetch origin
git worktree add -b codex/<issue>-<topic> ../openccman-<topic> origin/develop
```

**历史迁移已由 #43 完成**：普通功能从 `develop` 开始，不再从旧 `build` 派生。原迁移的祖先关系保留，不通过重置分支改写历史。

### 验证和 PR

- PR 写清问题、实现思路和实际验证结果；有对应 Issue 时引用它。
- 应用变更通过对应回归检查，并完成与风险相称的构建或运行验收。
- UI 变更附修改前后截图，保持平台、窗口尺寸、语言、主题和输入内容一致；说明未覆盖的设备或辅助功能场景。
- 纯文档变更在本地检查内容、链接和 `git diff --check`，无需额外运行 Xcode 构建或模拟器测试；PR 仍会触发统一 App Regression。
- 创建 PR 的任务在提交、推送并返回链接后完成；CI 排队时报告状态。只有明确要求等待检查、合并或发布时才继续等待，不反复查询相同状态。
- `main`、`develop` 已要求通过 PR 更新，保护同样约束管理员，禁止强制推送和删除受保护分支。`develop` 要求 GitHub Actions 提供 `App Regression` 成功；`main` 暂不要求尚不存在的应用回归。
- 单人维护不要求额外审批者，不配置机器人绕过；保留 merge commit。`strict=false` 不强制每次更新至最新基线，依赖合并后仍需核对目标、冲突和候选 SHA；发生代码整合时重新验证候选。

普通任务可使用 squash merge。发布、热修复及历史迁移采用 merge commit，保留分支祖先关系。SwiftyOpenCC 上游同步 PR 也必须保留 merge commit；不要将应用任务的 squash 策略套到 wrapper 同步上。

## 发布和热修复

1. 从已集成的 `develop` 创建 `release/v<version>`，冻结功能，仅处理版本信息、发布文案、签名配置和阻断问题。
2. 确认需要云端验收包后，从明确的发布候选 SHA 创建临时 `build/<version>-<YYYYMMDD>` 分支。记录候选 SHA、Xcode Cloud 构建号及 TestFlight 验收结果。
3. 验收通过后，通过 PR 将发布分支合入 `main`，在对应发布提交创建 `v<version>` Tag，再通过 PR 将发布期修复同步回 `develop`。
4. 如需从 `main` 重新打包，明确选定提交后另建打包分支；合并发布 PR 本身不应触发 `build` 前缀规则。
5. 确认产物和版本记录后清理临时分支。若候选期间又有代码修改，必须重新验证最终候选。

线上热修复从 `main` 创建 `hotfix/<issue>-<topic>`，验证后分别通过 PR 合入 `main` 与 `develop`，按需创建补丁版本 Tag 和打包分支。不得仅修复临时打包分支。

## 上游同步

协调器继续保留在默认分支 `main`，每周一 09:17（UTC+8）运行并支持手动触发；不另建每日调度。

```text
ddddxxx/SwiftyOpenCC + BYVoid/OpenCC 正式 Release
    → gewill/SwiftyOpenCC 同步 PR（master，人工 merge commit）
    → OpenCCman 精确依赖更新 PR（develop，人工合并）
    → release/* 验收 → 临时 build/* 触发 Xcode Cloud
```

迁移时将 `main` 上 `scripts/upstream-sync.json` 的 `app.base` 从 `build` 改为 `develop`，同步调整相关测试、工作流和说明。应用只能引用已合并且验证通过的 fork revision，继续要求 `App Regression`，不得因为换基线而跳过验证。依赖回滚同样向 `develop` 提交 PR，并记录被忽略的候选，避免自动重复更新。

## 跟踪关系与清理

- `main` 跟踪 `origin/main`，`develop` 跟踪 `origin/develop`；任务分支首次推送使用 `git push -u origin HEAD`，跟踪远端同名分支。
- PR 合并后先核对未推送提交、PR 状态及 `git worktree list`，再清理已完成的任务分支；不删除仍被工作区使用的分支。
- Squash 合并后 `git branch -d` 可能拒绝删除，须先确认 PR 已合并且无新增提交，不凭分支名称强制删除。
- 打包分支额外核对云端产物，历史分支逐一确认，不批量删除状态不明的分支。
- 分支名使用小写英文、数字、连字符及职责前缀；不用个人名称或含义不明的临时编号。

## 迁移前历史快照

以下为 **2026-09-13 文档 PR #42 合并前**的历史快照，并非迁移完成声明；后续准备情况见 [CI 迁移记录](CI.md)：

| 项目 | 当前状态 |
| --- | --- |
| 默认分支 | `main`，SHA `e28ae12b55602092e6bcce808c90f191060818c9`，承载协调器 |
| 应用集成 | 旧 `build`，SHA `9daf1539232ee668f8050dac664b78ab195e2fc9` |
| `develop` | SHA `4061dacc198d15a12127852f9ad0478896d53e28`，相对旧 `build` 独有 0 个、缺少 62 个提交 |
| `main` 与旧 `build` | 已分叉，分别独有 8 个、65 个提交，不能直接重置覆盖 |
| 分支保护 | `build` 已保护；`main`、`develop` 尚未保护 |
| 应用回归 | 旧 `build` 上的 `app-regression.yml` 只匹配目标为 `build` 的 PR 和对 `build` 的推送 |
| 自动依赖 PR | 默认分支配置中的 `app.base` 仍是 `build` |
| Xcode Cloud | `build` 前缀触发；旧 `build` 上的发布文档仍描述向它合并应用 PR |

## 2026-09-16 迁移账本（历史快照）

| 项目 | 已核实状态 | 尚需完成 |
|---|---|---|
| 应用与历史 | #43 merge commit `fbd1ac0` 已进入 develop；旧 build `9daf153` 与原 main `e28ae12` 都是当前 develop 的祖先 | 日常继续通过 PR 集成 |
| 默认协调器 | #44 merge commit `fb56ea3` 已进入 main；main 的 `scripts/upstream-sync.json` 明确为 `app.base=develop` | 保持周检与两层人工合并 |
| 应用 CI | develop 有每个 PR 都执行的 App Regression，包含堆叠 `codex/**` 目标与 macOS 验证构建 | 已要求 GitHub Actions 的 App Regression（app ID 15368）通过 |
| 保护规则 | main/develop 已配置经典 PR 保护，管理员同样受约束，禁止强推和删除；develop 要求 App Regression | main 应用工作流随发布整合后再增加检查；单人维护审批数为 0，strict=false |
| 说明 | 本文、README 与 CI 说明区分已迁移内容和历史快照 | 发布或保护变化后更新对应证据 |
| 正式发布主线 | main 仍是默认协调器分支，不能据此认定它已含验收后的 1.3 应用 | 完成 #11 发布门禁后，通过发布 PR 整合 main、Tag 与云端产物 |
| 旧 build | 仍存在，SHA `9daf153`；当前没有以它为目标的开放 PR | 先核对云端运行与外部引用，再保留归档、退出旧引用，释放 build/* 命名空间；见 #110 |
| 打包分支 | 另有 `build-v1.3-20260914`，SHA `c3009c7` | 与对应 Xcode Cloud 产物逐一核对，不批量删除；下一次明确授权打包时再验证 build/* |

首次只读核对的 API、来源 SHA 与祖先检查记录见 [历史快照](validation/branching-status-2026-09-16.json)；随后启用保护的请求及 API 回读见 [保护配置证据](validation/branch-protection-2026-09-16.json)。回读确认配置已生效，未通过破坏性推送测试拒绝行为。未删除分支或执行新的 Xcode Cloud/签名/TestFlight 验收。[维护 Issue #110](https://github.com/gewill/OpenCCman/issues/110) 跟踪保护与旧引用，其关闭不替代 #11 的完整发布验收。

本文参考 Pingman 的 `docs/BRANCHING.md`，并补充 OpenCCman 现有分支分叉、上游协调器及 Xcode Cloud 的迁移约束。

## 当前归档账本（2026-09-17）

#110 通过 GitHub 分支 rename API 完成归档，旧引用已退出远端、SHA 未改变，没有解除保护或强推。参见[GitHub 分支重命名说明](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-branches-in-your-repository/renaming-a-branch)。

| 原分支 | 归档分支 | SHA | 云端核对 |
| --- | --- | --- | --- |
| `build` | `archive/legacy-build-20260917` | `9daf1539232ee668f8050dac664b78ab195e2fc9` | Build 49，run `6da6dcac-261a-45e1-8a57-73e0d5f5c4f0`，成功，两端 VALID |
| `build-v1.3-20260914` | `archive/build-50-v1.3-20260914` | `c3009c74796e8f4ff3b39c4f1c5bb8c9ed1c04cf` | Build 50，run `9a3b158a-07ac-43a9-ac44-b950484b2f8f`，成功，两端 VALID |

Default 的全部可见运行 38–53 均 COMPLETE，无活跃运行或开放 PR 引用旧分支。main/develop 的 `.github`、`scripts` 未发现旧引用硬编码；未知外部克隆/脚本没有被全面盘点。旧保护随 rename 迁移，但回读发现检查来源 app_id 变为空值，已恢复为 15368 并验证；main/develop 保护未变。

归档只供历史查询，不继续开发，不重新推送本地旧 build。使用旧 Git/raw URL 的外部工具需要更新引用；克隆可运行 `git fetch origin --prune` 更新远端引用。本轮保留本地分支、未提交改动和所有工作区。

远端 `build/*` 命名冲突已解除。本轮没有新建 build 前缀分支；保留两个 2.0 打包分支、release 分支和全部 Cloud/TestFlight 产物。Build 53 已证明 `build-v2.0-20260916-02` 的 GIT_REF_CHANGE 自动触发及两端 VALID，不能代替带斜线分支的实际打包验证。

[精简 API 证据](validation/branch-archive-2026-09-17.json)记录运行、产物 ID、SHA 和保护配置。下一次授权打包的 `build/*` 实验与正式发布 main 整合由 [#122](https://github.com/gewill/OpenCCman/issues/122) 承接。main 应用工作流实际进入发布 PR、检查成功后，在合并前增加来源绑定的必需检查；不提前要求不存在的检查。本归档收尾不代表 #11 发布验收完成。
