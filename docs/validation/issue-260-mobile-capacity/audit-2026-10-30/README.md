# PR #264：2026-10-30 整理与审计

## 结果与范围

本轮把 #264 从已合并的 #263 分支整理到 `develop` 基点 `a1758296b628fae076f7259265732f7209b178a0`；不修改 App、工程、依赖、容量或生产开关，不合并 PR、不关闭 #260。

运行源码提交：`23026c5ec8959c1eceeb6ad454d803b52f73cc53`，开始时工作区干净。后续只整理文档和证据；六份服务/探针源码及 runner 的哈希见 [服务报告](service-report.json)，均另对照该提交与当前工作树验证相同。Xcode 27.1（27A9275），Mac SwiftPM Release；wrapper 为独立、干净 checkout `564b094b2b69f2c1e907fa3d89fe6845469a4e4e`，未使用或修改用户原有脏 wrapper checkout。

| 本轮实际验证 | 结果 | 证据 |
| --- | --- | --- |
| 20/50/100 MiB × 四语料，重建 12 文件，共 680 MiB | 输入名称、精确字节数、完整 SHA、种子、生成器和 wrapper 均与历史清单一致 | [重建清单](regenerated-manifest.json)、[验证索引](verification.json) |
| 当前 `MobileLargeFileService`，12 × 七配置 | 84/84 完整输出长度、SHA、options、Ready 恢复和删除后空目录均匹配；独立复核无缺项/重复 | [完整报告](service-report.json)、[运行日志](service-84.log) |
| 重新编译固定 wrapper 的独立整篇 oracle | 1 MiB Unicode 输入七模式运行；BOM/NUL/CRLF/Emoji/组合字符/正文 U+FEFF 与非法 UTF-8 语义测试通过 | [本轮 oracle](oracle-1mib.json)、[语义日志](oracle-semantics.log) |
| 语料、预检、导出 CLI 小样本 | 3 + 8 + 4 = 15 项通过 | [测试日志](tool-checks.log) |
| 基准报告工具、工作流语法 | 111 项通过；Ruby YAML 解析通过（未声称 actionlint 已执行） | [测试日志](tool-checks.log) |

## 两轴审计发现与处理

1. **空/重复矩阵可能假通过。** 原 `check-mobile-capacity-outputs.py` 对空 fixtures/rows 或重复同名 fixture 与重复七行使用长度加集合比较，可能到达构建并最终生成空/重复通过报告。本轮在输出目录创建、源码复制及编译前要求输入非空、名称唯一、模式对唯一且完整。新增 8 项真实入口测试覆盖空集、重复文件/模式、缺模式、错误选项、文件篡改、路径越界及正常矩阵进入构建。负例检查不创建输出、不调用编译；正常路径的实际编译和服务运行由 84 项另证。
2. **历史证据身份不能代表当前代码。** 原 [service-report.json](../service-report.json) 绑定 `52def28102d209803152c296fbfd568100f55b40`；pump、容量策略和服务后续已变化。本轮保留历史原件，新增当前源码的完整服务矩阵，更新父目录说明和关闭条件表。#261/#262/#263 的已合并事实与各 Issue 仍开放分开记录。

[原缺陷反例记录](original-defect-reproduction.json)：用新负例测试执行固定旧提交 `44dc506` 的真实预检代码，两种输入均到达编译边界；只拦截编译调用，没有启动空矩阵的 Swift 构建。修复后同样输入在编译前拒绝。没有用镜像实现的谓词测试代替入口。

七模式在独立工具中重复定义属于低优先级维护建议，本次保留显式映射，并以各模式实际结果及 raw 值校对，未借审计扩大模块重构。

## 独立参考的复用方式

原 oracle 的转换源码、wrapper 均未变化；本轮重建 12 份输入后核对整份 fixture 元数据一致，才把原始 manifest 原样复制到本次临时输入目录，用来复用其 [84 项独立整篇参考](../oracle.json)。本轮生成的新 manifest 另存，明确绑定 `23026c5`，未改写历史 app SHA 或伪装重新运行 84 次整篇 oracle。本轮另编译并运行七模式小样本及字节语义测试；84 次重新运行的是**当前服务**。

复现时：

1. 在仓库外新目录运行 `generate-mobile-capacity-fixtures.py` 的默认 12 文件矩阵；核对其 fixtures、wrapper_sha、generator_sha256 与历史清单完全一致。保存新 manifest，再复制历史 manifest；任一不一致即停止，必须重新生成 oracle。
2. 先对 fixture 生成器传 `--sizes-mib 1 --corpora unicode`，再以这个目录调用 oracle 生成器并运行 `test-mobile-capacity-oracle.py --binary <实际 Oracle>`。精确实际命令见验证索引。
3. 对完整输入目录运行 `check-mobile-capacity-outputs.py --fixtures <12文件目录> --oracle <原84项oracle.json> --opencc-path <干净锁定wrapper> --output <新目录>`。只在全部完成后生成聚合报告。
4. 运行三个 `test-mobile-capacity-fixtures.py`、`test-mobile-capacity-preflight.py`、`test-mobile-export-verifier.py`，并用报告中的源码哈希校对来源。

运行设置 10 GiB 可用空间下限、单日志 10 MiB 上限、oracle 900 秒/服务矩阵 1200 秒截止；本轮未触发停止条件。临时输入、包和构建缓存仅清理本任务目录；必要日志、报告与哈希保留。

## 不据此验收的项目

- 本轮没有读取/操作设备、启动 Simulator、重新安装 App、测 UI、提供方保存、购买或签名候选。
- Mac 宿主服务和私有目录恢复不等于 UIKit 生命周期、受保护文件、系统保存或真实设备体验；报告中的 exportURL 不是 provider 导出。
- 没有测量物理 footprint、热状态、内存警告、jetsam/watchdog，也没有重做 1 GiB Mac/强退旧探针；旧报告保留原范围。
- #260 的签名 iPhone/iPad、完整容量/缓存/文稿/重复/故障矩阵及正式启用仍开放；最低系统 #16、真实 Pro #14/#71 不计为通过。#268/#269 扩容不在本轮范围。
