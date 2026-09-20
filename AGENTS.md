# OpenCCman Agent Instructions

本文件是本仓库对所有 agent 的通用规则。动手前先读它，再读与任务相关的 `docs/` 文档。

## 跨项目规范

多语言切换、Xcode Cloud、翻译等跨项目规范的事实来源是内部规范仓库 `dev-standards`，不在本仓库维护副本。涉及这些主题时先读该仓库的对应规范；实现与规范冲突时，先判断哪一边是错的，更新规范，再改本仓库代码。

本仓库 `docs/` 只保留本项目自己的记录：分支与 CI 约定、验收证据、发布流程。

## 分支与提交

- 日常开发从最新 `develop` 新建 `codex/<issue>-<topic>` 分支，通过 PR 合回 `develop`。完整规则见 [docs/BRANCHING.md](docs/BRANCHING.md)。
- `build` 前缀的分支会触发 Xcode Cloud 打包，日常开发不要使用。
- 一个分支只承载一项任务。工作区有未提交改动时使用独立 worktree，不切换或重置他人的工作区。
- 提交信息不写 AI 工具名、模型名、agent 模式或执行步骤。

## 验收与关闭 Issue

- Issue 只在其自身「关闭标准」被满足、且有运行证据时关闭。PR 合并不代替验收，本仓库的 PR 也不使用 `Closes #N` 关键字自动关闭 Issue。
- 某项验收因环境缺失无法完成时，在 Issue 中明确转出到承接它的 Issue，不计为通过。最低系统相关留 #16，购买与 RevenueCatUI 相关留 #14 / #71。
- UI 改动需要真实前后截图，交互过程需要录像。证据用 `gh issue|pr create|comment|edit --attach` 上传：正文用 markdown `![alt](/绝对路径.png)` 引用，并把**逐字相同**的绝对路径传给 `--attach`，否则 gh 会留下死链并把文件追加到正文末尾。
- 不要把本地路径当作证据留在 Issue 或 PR 正文里。

## 验证

App Regression 是 `develop` 的必需检查。本地可单独运行 `scripts/` 下的检查脚本，常用的有：

```bash
bash scripts/check-project.sh
python3 scripts/check-app-language.py
bash scripts/check-control-labels.sh
```

预期：各脚本输出以 `PASS:` 开头的结论。

改动影响构建时，本地按 [docs/CI.md](docs/CI.md) 记录的参数构建 macOS 与 iOS Simulator 两端；只构建一端不代表另一端通过。

## 相关文档

| 文档 | 内容 |
| --- | --- |
| [docs/BRANCHING.md](docs/BRANCHING.md) | 分支职责、打包分支触发规则与日常开发流程 |
| [docs/CI.md](docs/CI.md) | App Regression 的检查项与构建参数 |
| [docs/XCODE_CLOUD.md](docs/XCODE_CLOUD.md) | 云端打包与 TestFlight 分发 |
| [docs/validation/](docs/validation/) | 各项验收的运行证据与边界 |
