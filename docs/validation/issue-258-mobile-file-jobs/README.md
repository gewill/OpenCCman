# #258 移动端大文件作业服务

2026-09-30，基于 #261 候选 `6dca9d3991a17753db6b44393dcd377b81bd539e`。属于 v2.2 的 [100 MiB 方案](../../IOS_LARGE_FILES.md)，不改变 2.1 或移动端当前 10 MiB 生产入口。源码校验和见 `report.json`。

## 本次实现

`MobileLargeFileService` 将准备、转换、状态记录及恢复放在同一个串行文件 worker，统一拥有文件和取消令牌，避免 store 与准备服务各自清理正在使用的句柄。全 App 协调器须复用同一个实例；调用层不能为每个窗口创建实例或并行使用同一根目录的不同实例。

- 用户选择 TXT 后，在安全域和 `NSFileCoordinator` 读协调范围内取得私有快照；读取前后检查描述符及路径指纹。容量按实际字节计算，100 MiB + 1 在复制前拒绝，复制期间增长/截断失败。
- 单块 256 KiB，调用同一个共享 OpenCC stream；快照完成即释放外部文件及安全域。没有全文 String/Data、外部书签、编辑器内容或额度改动。
- 完整输出和小型 journal 分别同步关闭，取消令牌锁内按顺序原子 rename。`ready.json` 是唯一完成标记。只有输出没有 journal 的作业仍属未完成。
- journal 保存 UUID、schema、输入/输出长度、原始配置 flags、保存名和 SHA-256。结果实际文件名就是 `<原名>-converted.txt`；极长原名截短到 220 个 UTF-8 字节以内，再附后缀，避免超过单个文件名上限。
- 完成后删除输入；失败时返回 `cleanupPending`，保留有效结果并由恢复重试，不能把已提交的结果报告为转换失败。
- 待保存结果占唯一任务槽，保存取消不调用删除；系统导出成功或用户明确删除才按 UUID 删除，迟到/重复回调返回 staleJob。
- 所有目录/文件位于调用方指定的私有 Application Support 根目录，目录排除备份；iOS 写入采用 Complete protection。`LargeFileProtectionGate` 接收未来主线程协调器的保护数据状态，worker 不读 UIApplication。
- 保护数据不可用时延后恢复/清理；I/O 错误不解释为损坏并删除。恢复对完整结果重新核对全文件 SHA-256；损坏 journal/结果返回显式错误并保留文件，不自动抹除。
- 只处理 `job-<UUID>` 命名空间和允许的平面文件名。拒绝根目录/作业目录符号链接、不递归进入未知目录；清理文件符号链接只 unlink 链接本身。
- 开始时检查 `4 × 输入 + 64 MiB`，导出前检查 `输出 + 64 MiB`。空间查询 nil 不当成零，已知不足拒绝；查询异常和实际读写/同步异常继续抛出。预算不声称覆盖所有输出扩张或提供方缓存。

## 运行证据

复现命令（提供一个干净、精确锁定的 SwiftyOpenCC checkout 和专用 Simulator）：

```bash
python3 scripts/check-mobile-file-jobs.py --output /tmp/openccman-job-checks \
  --opencc-path /path/to/clean-pinned-SwiftyOpenCC \
  --destination 'platform=iOS Simulator,id=<dedicated-UDID>'
python3 scripts/check-core.py --opencc-path /path/to/clean-pinned-SwiftyOpenCC
```

| 验证 | 结果与范围 |
| --- | --- |
| Release 原生 XCTest | 作业测试集通过；准备/读写/同步/两次 rename 之间等九个故障边界、取消胜出/提交胜出、恢复、空间、源变化、清理失败、保护数据 gate、容量上界、并发起两次只成功一次、损坏同长度输出、符号链接边界 |
| 新进程强退恢复 | 五个子进程分别在快照写、转换写、同步前、输出 rename 后、ready 完成后 SIGKILL；前四清理不完整作业，最后恢复 SHA-256 验证的完整结果；源始终未变，恢复/删除后无拥有的作业文件残留 |
| iOS 18.6 (22G86) Simulator | iPhone 15 Pro，Release XCTest 执行同一实际服务和测试集，1 个套件通过；不是设备文件保护、UIKit scene 或文件提供方验收 |
| 整体核心回归 | `check-core.py` 包含本测试，保留七配置、共享流、Mac 文件服务、窗口/额度、Shortcuts 等既有检查 |
| 完整 App 构建 | macOS arm64/x86_64 和 iOS Simulator arm64 Debug 未签名构建；详见 `builds.json` |
| 依赖与最低系统 | 锁文件无改动；应用继续 iOS 15 / macOS 12；未推送 build 分支、安装正式 App 或触发 Xcode Cloud |

强退探针发送 SIGKILL 后停在原断点，避免跨线程信号投递的短暂延迟使后续 rename 偷跑。它测试普通进程终止，不承诺断电后的文件系统持久性。

`report.json` 为精确候选源文件哈希和强退结果；`ios-summary.json` 为原生 XCTest 摘要；`core-pass.log` 为完整核心回归 PASS；`builds.json` 为完整构建、产物与内嵌隐私清单读回。完整原始日志和 xcresult 保留在本机 `/tmp/openccman-258-final-validated`；仓库仅保存精简证据。

## 隐私清单

App 自身新增 `DiskSpace / E174.1` 用于写文件空间检查，`FileTimestamp / C617.1` 用于私有作业文件，`3B52.1` 用于用户选择的源文件 metadata。没有空间展示，因此不添加 85F4.1；信息不发送出设备。依据 [Apple Required Reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)。Complete protection 及不可访问时的处理依据 [FileProtectionType.complete](https://developer.apple.com/documentation/foundation/fileprotectiontype/complete) 和 [isProtectedDataAvailable](https://developer.apple.com/documentation/uikit/uiapplication/isprotecteddataavailable)。本轮读回未签名双端产物；签名包读回仍属 #260。

## 尚未验收，不关闭 #258

- #259 接入唯一 App 协调器、Pro 和配置快照、系统选择/保存、数值进度节流、所有 scene 后台/窗口关闭、内存警告、保护数据通知与 begin/endBackgroundTask、idleTimer 恢复。服务层测试的 gate 注入不计为这些真实交互通过。
- #259 需为损坏 journal、清理失败及未知目录提供可理解的错误与明确删除/重试路径；当前服务宁可停止，也不自动删除不能确认的完整结果。
- #260 承接真实 Files/iCloud/第三方提供方、真实锁屏保护数据、真实低空间、签名包权限和 20/50/100 MiB 全 App 内存矩阵。#257 的 Simulator 100 MiB 核心正确性不能代替这些验收。
- 最低 iOS 15 实际运行仍留 #16；实际 Pro 资格/购买链路留 #14/#71。当前没有开放移动端 100 MiB 功能。
