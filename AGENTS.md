# OpenCCman Agent Instructions

本文件是本仓库对所有 agent 的通用规则。动手前先读它。

## 本分支不是开发线

`main` 是默认分支，但应用的日常开发在 `develop` 上。当前 `main` 只承载上游同步协调器与历史发布内容，2.0 的应用代码、文档与 CI 都在 `develop`，正式发布主线的整合由 [#122](https://github.com/gewill/OpenCCman/issues/122) 跟踪。

因此：

- 功能、修复、测试与文档任务从最新 `develop` 新建 `codex/<issue>-<topic>` 分支，PR 合回 `develop`，不要从 `main` 起手。
- 只有修改上游同步协调器的维护任务从 `main` 起手并合回 `main`，同时通过 PR 把变更同步到 `develop`。
- `build` 前缀的分支会触发 Xcode Cloud 打包，日常开发不要使用。

完整规则见 `develop` 上的 [docs/BRANCHING.md](https://github.com/gewill/OpenCCman/blob/develop/docs/BRANCHING.md)。下面的链接同样指向 `develop`，因为这些文件不在本分支上。

## 跨项目规范

多语言切换、Xcode Cloud、翻译等跨项目规范的事实来源是内部规范仓库 `dev-standards`，不在本仓库维护副本。涉及这些主题时先读该仓库的对应规范；实现与规范冲突时，先判断哪一边是错的，更新规范，再改本仓库代码。

## 本分支上的内容

| 路径 | 内容 |
| --- | --- |
| [docs/upstream-sync.md](docs/upstream-sync.md) | 上游 OpenCC 同步协调器的用途、触发方式与人工复核要求 |
| [scripts/sync-upstream.py](scripts/sync-upstream.py) | 协调器实现，只读上游并产出候选，不自动合入 |

协调器改动需要真实运行证据，不能以「脚本能跑」代替对候选结果的复核。

## 验收与证据

- Issue 只在其自身「关闭标准」被满足、且有运行证据时关闭。PR 合并不代替验收，本仓库的 PR 也不使用 `Closes #N` 关键字自动关闭 Issue。
- UI 改动需要真实前后截图，交互过程需要录像。证据用 `gh issue|pr create|comment|edit --attach` 上传：正文用 markdown `![alt](/绝对路径.png)` 引用，并把**逐字相同**的绝对路径传给 `--attach`，否则 gh 会留下死链并把文件追加到正文末尾。
- 不要把本地路径当作证据留在 Issue 或 PR 正文里。
- 提交信息不写 AI 工具名、模型名、agent 模式或执行步骤。

## 应用开发的其余规则

应用代码的分支、CI、验证命令与验收记录都在 `develop`：

| 文档 | 内容 |
| --- | --- |
| [AGENTS.md](https://github.com/gewill/OpenCCman/blob/develop/AGENTS.md) | `develop` 上的完整版本，含本地验证命令 |
| [docs/CI.md](https://github.com/gewill/OpenCCman/blob/develop/docs/CI.md) | App Regression 的检查项与构建参数 |
| [docs/XCODE_CLOUD.md](https://github.com/gewill/OpenCCman/blob/develop/docs/XCODE_CLOUD.md) | 云端打包与 TestFlight 分发 |
| [docs/validation/](https://github.com/gewill/OpenCCman/tree/develop/docs/validation) | 各项验收的运行证据与边界 |
