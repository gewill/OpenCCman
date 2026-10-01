# #260：iPhone X 用户返回文件完整输出核验

日期：2026-10-01。后续补测见 [iPhone 16 Pro TestFlight 实测](IPHONE16-TESTFLIGHT.md)。对应 [#260](https://github.com/gewill/OpenCCman/issues/260)，总跟踪 [#256](https://github.com/gewill/OpenCCman/issues/256)。

## 结论

用户返回的三份文件，使用 **OpenCC 繁体**（`traditional`，`Options.rawValue = 1`）与候选包锁定 wrapper 的独立整篇转换参考比较，**完整长度和 SHA-256 全部一致**。不是抽样比较，也不是用相同流式实现自校验。

本次只通过三份实际文件的输出正确性检查。尚未完成 #260 的整 App 容量／资源／异常恢复矩阵，不关闭 #260，不扩大移动端上限。

| 用户返回文件 | 输入／输出字节数 | 完整输出 SHA-256 | 结果 |
| --- | ---: | --- | --- |
| `openccman-boundary-10MiB-plus-1byte-converted.txt` | 10,485,761 | `11225af00bc4ae3cb6c763c7da66325c5df659663ae38661c44b55da2d517634` | 一致 |
| `openccman-test-50MiB-converted.txt` | 52,428,800 | `d2ec075e0adcaa760586f81e6453bafb5d39427f5d63b9706f72b01ba3aff5ea` | 一致 |
| `openccman-stress-100MiB-converted.txt` | 104,857,600 | `f93543cbc7db3afd13cde3fb84adbbe9c1b43193a0c90bbac33a37b73d8ffa67` | 一致 |

输入哈希见 [input-manifest.json](input-manifest.json)，完整参考、实际哈希及换行统计见 [output-verification.json](output-verification.json)。三份输出均通过严格 UTF-8 解码，无 BOM，LF／CRLF 数与输入一致。正文包含中文、Emoji、组合字符和空行；本组语料不包含 U+0000、初始 BOM、巨型单行或全部七种配置，因此不代表这些项目已通过真机验收。

## 证据来源与待确认事项

| 信息 | 来源／状态 |
| --- | --- |
| iPhone X、iOS 16.7.15、OpenCC 繁体 | 维护者直接反馈 |
| 100 MiB 约 3 秒 | 维护者观察值；未记录计时起止点、重复次数或仪器数据，不作为端到端性能基线 |
| 三份结果文件 | 维护者提供；核验其完整内容哈希，不将设备信息嵌入文件视为可信证明 |
| 实际安装的 App 版本／build | 已请求确认，当前未确认；JSON 保留 null |
| 文件选择、保存提供方和是否有中间处理 | 待确认，当前未记录 |
| 实际操作截图／录像 | 本轮未取得；没有用设计稿、Simulator 或 QA 截图代替 |
| 设备内存、热状态、watchdog／jetsam | 未测量；成功返回文件不能证明这些指标通过 |

待关联的云端候选为 `release/v2.2` 的 `aad2b09931e34dbfab3e8218be22e94cd604fbb6`、TestFlight **2.2 (61)**。这是候选信息，不代表已确认 iPhone X 安装的就是此构建。独立读取到已连接 iPhone 16 Pro 安装 `org.gewill.OpenCCman` **2.2 (61)**，也不能代替 iPhone X 的构建确认。初始截图确认其锁屏；随后维护者解锁并配合 Mirroring，已补做实际交互，详见 [独立补测记录](IPHONE16-TESTFLIGHT.md)。此结果不替代 iPhone X 的构建关联。

本机 Xcode 27.0（27A266a）的 `devicectl list devices` 仅列出 iPhone X 的 `iPhone10,3`／ECID 信息，没有可交互设备状态；本次未通过 Xcode 操作这台 iPhone X。Device Hub 原生 UI 自动化读取超时，不把读取失败记为 App 故障。

## 独立参考的来源与方法

- wrapper：`564b094b2b69f2c1e907fa3d89fe6845469a4e4e`；隔离 checkout 的 `HEAD` 匹配且 `git status --porcelain` 为空。与候选工程及 `Package.resolved` 的精确 revision 一致。
- 程序：[#264 源提交](https://github.com/gewill/OpenCCman/blob/74dadb7b0d82161515d57a7bc756efabc0d921ff/Tests/Benchmarks/MobileCapacityOracle.swift)；本次留存 [源文件副本](oracle-source.swift.txt)，SHA-256 `4e5111bbbc0bbc03e6d7f50eb58e9bda1b40bdc7721697c737663d985f72495a`。
- Mac SwiftPM Release 可执行程序，只链接同版本 OpenCC 库；每个输入在独立进程执行一次 `ChineseConverter.convert`，不使用 App 的 streaming pump/service。
- 在原隔离 package 执行 `swift build -c release` 成功，日志见 [oracle-rebuild.log](oracle-rebuild.log)。二进制 SHA-256 `121b16c988c8e5de8e5a87f3ff7cd6630d8bf81c970d09b9d311c9468eda4d16`，与先前独立参考记录一致。
- 程序调用格式：`Oracle <original-input.txt> traditional <new-report.json>`。参考包含完整输入和输出长度、SHA-256；再对维护者返回的整个输出文件计算 SHA-256，并比较长度与哈希。
- 外部核验按 65,537 字节分块严格解码，跨块累计 CRLF；验证输出的 BOM／换行计数。读取的是独立的输入与结果文件，不改变其内容。

以上 Mac 程序只用来验证结果正确性，不能用其耗时、RSS 或 Mac 服务结果冒充 iOS 整 App physical footprint。

## 当前 100 MiB 验收下一步

以下仍按 #260 原有标准执行；本轮没有缩小范围或把缺失项目视为通过。

| 顺序 | 项目 | 当前状态／取证方式 |
| --- | --- | --- |
| 1 | 关联正式候选、输入与保存提供方 | iPhone X 构建与提供方待维护者确认；已有输出全哈希匹配 |
| 2 | 保存取消 → 保留 Ready → 再次保存 → 完整读回 | iPhone 16 Pro / 2.2 (61) 已完成一轮并完整读回；iPhone X 与其他矩阵仍待补 |
| 3 | Ready 状态退出／重开后恢复；处理中取消、锁屏、后台、强退 | iPhone 16 Pro 已验证 Ready 进程重启恢复、一次转换中取消和一次后台中止；锁屏／转换中强退、私有临时文件清理与完整循环次数仍待补 |
| 4 | 20/50/100 MiB × 七配置 × 无换行/ASCII/复杂 Unicode/扩张语料 | #264 有 Mac 独立参考和服务结果；iPhone／iPad 签名候选完整矩阵待补 |
| 5 | 低内存 iPhone 与 iPad 整 App 资源 | 同条件 100−20 MiB peak physical footprint 增量目标 ≤16 MiB；冷/热/七配置缓存、空白/近10 MiB文稿、每样本三轮，待实际测量 |
| 6 | 本机、未下载 iCloud、第三方提供方；磁盘满／断连／权限变化 | iPhone 16 Pro 的未下载 iCloud 输入及 iCloud 系统保存已通过；本机／第三方／故障矩阵仍待补，禁止拿无沙盒服务探针替代 |
| 7 | Mac 1 GiB／同文件／覆盖竞态／取消／强退回归 | 需按最终候选关联已有探针证据与签名 App 差异，残余恢复问题继续 #217 |
| 8 | 最低系统与真实 Pro | 分别由 #16、#14／#71 承接；缺失证据明确保留，不能标已通过 |

维护者确认目前没有可用的真实 iPad，相关标准保留未完成，不按 Simulator 结果替代。本轮已完成 iPhone 16 Pro 的保存取消／重启恢复／重试保存；待补 iPhone X 构建关联及余下完整矩阵。

## 容量扩展另行推进

维护者已确定先完成 #260：

- [#268：iOS/iPadOS 1 GiB 与二次确认](https://github.com/gewill/OpenCCman/issues/268)。
- [#269：Mac 超过 1 GiB 的独立容量评估](https://github.com/gewill/OpenCCman/issues/269)。

两项都在 #260 完成后推进；没有承诺版本／发布日期。当前仍为移动文件 100 MiB、Mac 文件 1 GiB、编辑器 10 MiB。本证据提交不修改代码、容量、依赖或发布开关，不触发 Xcode Cloud。
