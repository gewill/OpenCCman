# 真实核心来源的上游同步演练（2026-09-15）

关联 [#21](https://github.com/gewill/OpenCCman/issues/21)。本次使用真实 OpenCC 源码、锁定 CMake、实际编译器和官方 CLI；GitHub 状态接口与发布权限拒绝使用隔离 fixture。没有创建生产引擎更新、移动正式 tag、回退应用依赖或触发 Xcode Cloud。

## 来源与演练范围

- 应用集成基线：`714f6bf`，应用依赖仍由原来的精确 pin 决定。
- 协调器来源：`OpenCCman/main` 的 `fb56ea3de2427d07405d43f5400977d6167fbca6`。实际下载源码与本分支协调器逐字节相同，未修改生产协调器及工作流。
- fork：`gewill/SwiftyOpenCC` 的 `6eded293f5c84c064f332cbc2832391165c82dda`。
- wrapper 上游：`ddddxxx/SwiftyOpenCC` 的 `1d8105a0f7199c90af722bff62728050c858e777`，已在 fork 祖先中；本次不声称覆盖了新的真实 wrapper merge。
- 旧核心：[正式 1.4.1](https://github.com/BYVoid/OpenCC/releases/tag/ver.1.4.1)，`81223ed87ae53283ef518e2deac34b7971f8a39e`。
- 新核心：[正式 1.4.2](https://github.com/BYVoid/OpenCC/releases/tag/ver.1.4.2)，`025f371dc76b598d77384fbdab90c937471844d8`。

实时 `check --stage fork` 返回 `noop`。为演练有变化路径，在独立 clone 中把核心选到真实 1.4.1，并运行真实生成器，得到 42 项资源及通过的清单检查，随后提交为仅供演练的基线 `c400ac932b960904ea1903715cb22dd572c2886b`。它不是过去已发布的 fork 版本；没有声称这个旧核心与当前桥接通过了完整 Swift 兼容测试。

从此基线执行正常协调器 `prepare`，选择真实 1.4.2 源码。仅 GitHub 查询由本地 fixture 提供、Git transport 指向隔离仓库；没有替换 `validate_candidate`、资源生成器、编译器、`swift test` 或官方 CLI。测试程序不属于每周工作流，也不自动运行高成本构建。

## 可复现方法

先在独立 clone 中检出上述 fork，初始化 OpenCC 子模块，检出 1.4.1、运行生成器并提交演练基线。保留原始 checkout；不要在开发者工作区或生产分支执行回退。

```sh
python3 Tests/manual/real_upstream_replay.py \
  --fork-source /absolute/path/to/isolated-committed-baseline \
  --upstream-sha 1d8105a0f7199c90af722bff62728050c858e777 \
  --coordinator /absolute/path/to/reviewed-main/scripts/sync-upstream.py \
  --output /absolute/path/to/new-replay-output
```

协调器旁须有同来源的 `upstream-sync.json`。输出路径必须不存在。脚本创建三个本地 bare 仓库，不配置远端推送；核心子模块传输仅通过命令环境重定向，不修改全局 Git 配置。首次运行按 fork 的 `BuildTools/cmake.json` 下载并校验官方 CMake，不安装全局工具。

## 验证结果

生成失败演练使用不存在的 `CXX` 路径，让实际 CMake 配置失败。协调器返回退出码 4，并保留 `failure.json`、`report.md`、`prepare.log` 和补丁；补丁只有核心 gitlink 变化，原有生成资源未被覆盖，没有 `candidate.json` 或 `candidate.bundle`。

正常编译器恢复后的两轮 `prepare` 均返回 0，并得到相同候选 `c75671b112ae7ff8cc08` 和提交 `c723c347ce178cceb2e4d94ba0ca96479fb79912`。

| 检查 | 实际结果 |
| --- | --- |
| 真实资源生成 + manifest 检查 | 每轮 42 项；四份兼容配置源与生成副本校验和保持相同 |
| Swift XCTest | 每轮 7/7；覆盖 32 种 flags、14 模式、兼容配置、NUL／Unicode、并发及 native handle 释放；后面的 Swift Testing “0 tests” 不重复计数 |
| 官方 CLI 对照 | 每轮 565 次逐字节相同：495 官方样例 + 70 边界；独立固定 NUL 预期通过，不计作 CLI 原生 NUL 对照 |
| 同来源重复准备 | 相同 candidate ID、相同完整提交 SHA |
| 本地 API fixture 待审／人工关闭 | 均返回 `waiting` / 0，不重新构建或创建候选 |
| 本地 API fixture 忽略候选 | 返回 `noop` |
| 真实本地 Git 拒绝写入 | `pre-receive` 拒绝 push，退出码 5；未创建候选分支，GitHub PR 创建接口调用数 0 |
| 既有轻量回归 | 30 项通过；包含实际临时 Git merge／推广／revert／忽略／新来源继续，生成器仍为替身，与上述真实构建分开记录 |
| 生产两层只读检查 | fork、app 均为 `noop`；app 保持 pin `6eded293f5c84c064f332cbc2832391165c82dda` |

环境：macOS 27.0 arm64、Xcode 27.0 (`27A266a`)、Swift 6.4、AppleClang `21.0.0.21000334`、锁定 CMake 4.4.3。没有临时提高部署下限或修改依赖缓存；这里的 SwiftPM 构建不替代应用 macOS 11 最低系统验收。

## 证据归档

- [独立 clone 恢复 bundle 的记录](bundle-verification.log)。
- [完整结果摘要](summary.json)、[演练来源](sources.json)、[最终资源清单](generated-manifest.json)。
- [日志、完整 CLI 对照、失败报告、补丁与 Git bundle](opencc-real-source-replay-2026-09-15.zip)（2.8 MB）。ZIP SHA-256：`dcb2548cb6502b9b6e7110396fde6abf4a86aa8da3b92fd0a0720c33b44b3000`。内部 `SHA256SUMS.json` 为每份归档文件提供校验和。

归档将本机 HOME 与随机临时根路径替换成 `<HOME>`／`<TEMP>`；其余日志内容保留，bundle 保持原始字节。归档中的 `replay-baseline.bundle` 包含演练基线，`run-1/recovered/candidate.bundle` 包含验证候选。它们仅供恢复审计，不应推送到生产分支。`production-sources.json` 与 `source/` 保存协调器和配置来源。两份完整 `official-cli-report.json` 含 565 行输入／输出校验和，而非只有通过标志。

可在另一个独立 fork clone 中先 `git fetch /path/to/replay-baseline.bundle refs/heads/replay-baseline`，检出 `c400ac9`，再 fetch 候选 bundle 复原 `c723c34`。随后初始化官方 OpenCC 子模块即可查看对应核心。不能直接用候选 bundle 代替基线：它要求已有 `c400ac9` 前置提交。

## 认证与验收边界

默认分支工作流经过源码核对：准备 job 不包含 GitHub App 私钥／写令牌；发布 job 才生成目标仓库范围的短期 App token。准备进程显式移除 token 环境变量已有自动测试覆盖；本地开发者钥匙串不是凭证沙箱。

本地拒绝写入使用 Git `pre-receive` hook，不是对生产 GitHub App 权限不足的现场试验。人工关闭／待审状态来自本地 GitHub fixture，不伪造线上 PR。生产 App 安装权限、未来新核心／wrapper 提交、正式应用推广和分发不由这次隔离演练证明。
