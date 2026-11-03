# OpenCCman Agent Instructions

本文件是本仓库对所有 agent 的通用规则。动手前先读它，再读与任务相关的 `docs/` 文档。

## 跨项目规范

多语言切换、Xcode Cloud、翻译等跨项目规范的事实来源是内部规范仓库 `dev-standards`，不在本仓库维护副本。涉及这些主题时先读该仓库的对应规范；实现与规范冲突时，先判断哪一边是错的，更新规范，再改本仓库代码。

分支、日常开发与验证、Issue 处理、发布和 UI 留证遵循共享规则，本仓库不复制：[分支管理规范](https://github.com/gewill/dev-standards/blob/main/branching_guide.md)（本机 `~/git/dev-standards/branching_guide.md`）与全局 [AGENTS.md](https://github.com/gewill/skills/blob/main/codex/AGENTS.md)（本机 `~/git/skills/codex/AGENTS.md`）的「日常快速开发」「分支与集成」「Issue 处理」「统一发布流程」「UI 证据与流量优化」。两者均为私有仓库。

本仓库 `docs/` 只保留本项目自己的记录：分支模式、远端保护、CI／打包触发器、版本命名、验收证据与发布记录。

## 分支与提交

- 本项目的差异见 [docs/BRANCHING.md](docs/BRANCHING.md)。要点：`main`、`develop` 都由远端强制 PR 且要求 `App Regression`，所以日常改动也从最新 `develop` 建 `codex/<issue>-<topic>` 分支，通过 PR 合回 `develop`，不直接提交常驻分支。
- `build` 前缀的分支会触发 Xcode Cloud 打包，日常开发不要使用。
- README 日常只改英文 `README.md`；简体、繁体两份在每次发版后同步，见 [docs/BRANCHING.md](docs/BRANCHING.md#版本命名)。
- 提交信息不写 AI 工具名、模型名、agent 模式或执行步骤。

## Issue 与留证

- 本仓库的 PR 不使用 `Closes #N` 等关键字自动关闭 Issue；Issue 按其自身「关闭标准」与共享规范的 Issue 处理规则手动关闭，PR 合并不代替验收。
- 某项验收因环境缺失无法完成时，在 Issue 中明确转出到承接它的 Issue，不计为通过。最低系统相关留 #16，购买与 RevenueCatUI 相关留 #14 / #71。
- Issue 正文或维护者已明确的专项验收（如指定设备、截图或录像）照做。默认不要求前后截图、录屏或上传；RevenueCat 购买／恢复、系统权限与隐私等高风险流程仍须保留最少必要证据。

## 验证

日常验证范围按共享规范的「日常验证与集中检查」，不默认跑全量测试或 UI 自动化。`App Regression` 是 `main`、`develop` 的必需检查，PR 上自动运行。本地可单独运行 `scripts/` 下的检查脚本，常用的有：

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
| [docs/BRANCHING.md](docs/BRANCHING.md) | 分支模式、远端保护、CI／打包触发器与版本命名 |
| [docs/CI.md](docs/CI.md) | App Regression 的检查项与构建参数 |
| [docs/XCODE_CLOUD.md](docs/XCODE_CLOUD.md) | 云端打包与 TestFlight 分发 |
| [docs/validation/](docs/validation/) | 各项验收的运行证据与边界，含 [2026-09 分支迁移账本](docs/validation/branching-history-2026-09.md) |
