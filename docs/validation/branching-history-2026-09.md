# 分支迁移与归档账本（2026-09）

本文从 [分支说明](../BRANCHING.md) 移出，原文保留 2026-09 迁移、保护启用和旧 `build` 归档时的历史事实，不代表当前流程。当前分支模式与远端保护见 [BRANCHING.md](../BRANCHING.md)。

## 2.0 发布时的状态（2026-09-28）

**2026-09-28 已核实：日常开发和 CI 在 `develop`；发布 PR #210 已合入 `main`，`main` 精确合并提交 `c7734f5` 的 App Regression 成功，并已创建指向它的注释 Tag `v2.0`。** 两端 2.0(56) 已手动发布，价格、网站和 GitHub Release 已切换；美国、英国、台湾店面的 Apple Lookup API 已返回 2.0，实际购买页仍待复测，见[上架记录](../release/launch-2.0-20260928.md)。[#43](https://github.com/gewill/OpenCCman/pull/43) 与 [#44](https://github.com/gewill/OpenCCman/pull/44) 于 2026-09-13 完成早期迁移；默认分支仍为 `main`。旧 `build` 于 2026-09-17 归档；下方保留历史账本。

## 迁移前历史快照

以下为 **2026-09-13 文档 PR #42 合并前**的历史快照，并非迁移完成声明；后续准备情况见 [CI 迁移记录](../CI.md)：

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

首次只读核对的 API、来源 SHA 与祖先检查记录见 [历史快照](branching-status-2026-09-16.json)；随后启用保护的请求及 API 回读见 [保护配置证据](branch-protection-2026-09-16.json)。回读确认配置已生效，未通过破坏性推送测试拒绝行为。未删除分支或执行新的 Xcode Cloud/签名/TestFlight 验收。[维护 Issue #110](https://github.com/gewill/OpenCCman/issues/110) 跟踪保护与旧引用，其关闭不替代 #11 的完整发布验收。

当时的分支说明参考 Pingman 的 `docs/BRANCHING.md`，并补充 OpenCCman 现有分支分叉、上游协调器及 Xcode Cloud 的迁移约束。

## 当前归档账本（2026-09-17）

#110 通过 GitHub 分支 rename API 完成归档，旧引用已退出远端、SHA 未改变，没有解除保护或强推。参见[GitHub 分支重命名说明](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-branches-in-your-repository/renaming-a-branch)。

| 原分支 | 归档分支 | SHA | 云端核对 |
| --- | --- | --- | --- |
| `build` | `archive/legacy-build-20260917` | `9daf1539232ee668f8050dac664b78ab195e2fc9` | Build 49，run `6da6dcac-261a-45e1-8a57-73e0d5f5c4f0`，成功，两端 VALID |
| `build-v1.3-20260914` | `archive/build-50-v1.3-20260914` | `c3009c74796e8f4ff3b39c4f1c5bb8c9ed1c04cf` | Build 50，run `9a3b158a-07ac-43a9-ac44-b950484b2f8f`，成功，两端 VALID |

Default 的全部可见运行 38–53 均 COMPLETE，无活跃运行或开放 PR 引用旧分支。main/develop 的 `.github`、`scripts` 未发现旧引用硬编码；未知外部克隆/脚本没有被全面盘点。旧保护随 rename 迁移，但回读发现检查来源 app_id 变为空值，已恢复为 15368 并验证；main/develop 保护未变。

归档只供历史查询，不继续开发，不重新推送本地旧 build。使用旧 Git/raw URL 的外部工具需要更新引用；克隆可运行 `git fetch origin --prune` 更新远端引用。本轮保留本地分支、未提交改动和所有工作区。

远端 `build/*` 命名冲突已解除。本轮没有新建 build 前缀分支；保留两个 2.0 打包分支、release 分支和全部 Cloud/TestFlight 产物。Build 53 已证明 `build-v2.0-20260916-02` 的 GIT_REF_CHANGE 自动触发及两端 VALID，不能代替带斜线分支的实际打包验证。

[精简 API 证据](branch-archive-2026-09-17.json)记录运行、产物 ID、SHA 和保护配置。下一次授权打包的 `build/*` 实验与正式发布 main 整合由 [#122](https://github.com/gewill/OpenCCman/issues/122) 承接。main 应用工作流实际进入发布 PR、检查成功后，在合并前增加来源绑定的必需检查；不提前要求不存在的检查。本归档收尾不代表 #11 发布验收完成。
