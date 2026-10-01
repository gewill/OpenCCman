# #272 空间检查 Review 修复

日期：2026-10-02。被审查基线 `01f601a668f348b7fbf850c1409d7c96df4df520`。

## 两项修正

| Review | 根因与修复 |
| --- | --- |
| [容量查询的零值](https://github.com/gewill/OpenCCman/pull/272#discussion_r4158573083) | 原实现把 important-usage 的 0 直接作为无空间。现在同时读取普通可用容量：important-usage 为正时优先使用，否则采用非负普通容量。普通容量为 0 仍判空间不足；两个值缺失／无效时保留未知，由实际写入处理。查询异常不被吞掉，每次仍清除 URL 资源缓存。 |
| [常规路径两倍预检](https://github.com/gewill/OpenCCman/pull/272#discussion_r4158573109) | 原实现给所有任务施加 2×输入＋64 MiB 预检。现在仅 `.experimental` 执行整任务预检；`.standard` 不再要求两倍空间。两者都保留写入前、约每 4 MiB 重查的安全余量与实际 I/O 错误处理。 |

普通路径的逐写 64 MiB 余量仍是本 PR 新增的保护，并不宣称与修改前在所有极低空间条件下完全相同。此次不调整上限、Pro、确认弹窗、UI 或流式转换器。生产实验开关仍为 `false`。

Apple [空间查询说明](https://developer.apple.com/documentation/foundation/checking-volume-storage-capacity)没有将 important-usage 限定为启动卷或 APFS。本次修复是针对非正值的防御性回退，没有把“exFAT／SMB 一定返回假 0”记录为事实。普通容量查询属于现有 DiskSpace 隐私清单原因 `E174.1` 覆盖的本地存储检查。

## 针对性回归

`Tests/Regression/StreamingFileChecks.swift` 已覆盖：

- important-usage 正值优先；0／nil／负值回退到普通容量；普通 0 仍拒绝；缺失／无效值保留未知。
- 1 GiB 稀疏输入、注入 1.5 GiB 可用空间：常规任务进入读取；实验任务被保守预检拒绝。该项在首次读取前停止，不算完整 1 GiB 转换。
- 6 MiB 完整文件、注入 73 MiB（1.5×输入＋64 MiB）容量：假 0 回退后常规转换成功，逐字节及长度一致；相同容量的实验任务仍拒绝。
- 两种任务的未知空间可继续写入；明确满卷、首次写入和中途空间不足均失败且保留原目标、清理临时目录；权限查询异常继续抛出。
- 既有实际 URL 缓存刷新、七配置转换、取消、源变更、容量越界、确认状态及 Pro 回归一并运行。

测试的容量值与故障由 hook 注入，不冒充真实满盘、USB 或 SMB 验收。上次尝试创建临时 exFAT 映像时系统返回 `Operation not permitted`，未完成外接卷复现；真实设备／提供方、异常中断和重启验收继续留在 #217 / #269。

## 验证日志

本次检查输出、工具链及所测源文件哈希记录在 [review-checks.json](review-checks.json)。macOS 构建覆盖 arm64／x86_64，iOS Simulator 构建覆盖 arm64；二者都是本地验证构建，不是分发签名包。

原报告的 23 个大文件案例、开发签名原生 App 测量、截图与视频保留其原始来源 SHA。本次只重跑受空间政策影响的功能回归与双端构建；没有将历史 UI 或性能证据改标为新提交实测。
