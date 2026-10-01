# #268：移动端 1 GiB 实验性转换候选

日期：2026-10-01。关联 [#268](https://github.com/gewill/OpenCCman/issues/268)、
[#260](https://github.com/gewill/OpenCCman/issues/260)、[#256](https://github.com/gewill/OpenCCman/issues/256)。

维护者要求“开始268”，本轮先交付独立开发候选。**#260 的 100 MiB 完整验收尚未完成，真实 iPad 当前不可用；本记录不将其计为通过。**
`MobileFileRuntime.productionEnabled` 和 `experimentalCapacityEnabled` 均为 `false`。
没有推送 `build*`、生成 TestFlight 包、启用正式入口或调整价格。Mac 扩容仍由 #269 独立跟踪。

实现源码提交：`0bd20fff08b29b1226005440cafa5fe720b053f6`。
对比基线：`fbd03f79b18a1d8b35c248914e8490cc2d931da5`。
初次交付的逐文件 SHA-256 见 [source.json](source.json)。评审后修复默认容量查询缓存、非 Pro 文案和
journal 格式校验，最新源码与补充证据见 [评审修复记录](review-fix/README.md)；下方初次交付日志保留其原来源 SHA。
SwiftyOpenCC 固定 `564b094b2b69f2c1e907fa3d89fe6845469a4e4e`，未修改依赖或缓存。

## 实现边界

| 输入 | 候选行为 |
| --- | --- |
| ≤10 MiB | 原编辑器与拖放规则 |
| >10 MiB、≤100 MiB | 原移动端 Pro 文件任务，仍受 #260 生产开关约束 |
| >100 MiB、≤1 GiB | 额外实验开关开启时可选择；普通转换确认之后，再逐任务确认 |
| >1 GiB | 明确拒绝，二次确认不能绕过 |

1 GiB 为 **1,073,741,824 字节**，BOM 计入输入大小。界面文件大小沿用系统十进制格式，
因此 1 GiB 显示为 1.07 GB；限制和拒绝信息明确使用 GiB 与字节。

- 每个任务冻结文件身份、大小、配置及场景归属。首次点击转换只进入 `capacityConfirmation`，
  不创建作业、不申请运行资源。确认动作携带 session ID，旧弹窗不能授权新文件。
- 没有持久化“以后不再提示”。取消第二次确认关闭源句柄并释放任务；关闭所属窗口也会取消。
  开始实际处理时重新核对 Pro、实验开关、文件指纹和大小，文件增长不能沿用旧授权。
- `MobileFileCapacity` 将容量贯穿快照、转换及恢复记录。生产路径继续使用同一个 OpenCC stream，
  256 KiB 读取并落盘，正文不进入编辑器；没有整篇 `String`/`Data` 回退。
- 输出可能大于输入，**1 GiB 只限制输入**。输出由实际写入、同步、哈希及导出空间检查约束，
  不能因为输出膨胀而截断或误报成功。恢复时拒绝无法安全进行导出容量运算的异常计数。
- 源快照开始前要求约 `4 × 输入大小 + 64 MiB` 可用空间；复制、转换第一次写入及之后约每
  4 MiB 写入前再次检查，预留至少下一写入与 64 MiB 余量。该估算不保证能完成：可用空间会变化，
  文件提供方/系统导出还可能复制，实际 write/sync 错误始终按失败处理。
  容量查询返回未知不会被当作零空间。
- 继续沿用完整结果提交点、取消/提交竞争规则、安全域释放、失败清理、后台/锁屏中止及保存取消可重试。
  本轮不承诺后台续跑，也不以免责声明代替容量验收。
- 英语、简体、繁体均更新确认、容量错误、输入区提示及帮助；描述为实验性尝试，不宣传必定成功。

### 完成记录与回退

普通任务继续写 `schema: 1`，不增加 `capacity` 字段，旧版仍能恢复这类 ≤100 MiB 结果。
实验性任务写 `schema: 2, capacity: experimental`；新代码兼容合法旧记录，并按记录的容量恢复。
缺失/未知策略、超限输入、计数溢出、哈希不符均失败且保留未验证的完成文件，供明确恢复或删除。
关闭实验开关不应使已经完成的实验性结果无法保存；恢复策略不授权开始下一次任务。

**旧版不能读取 schema 2。** 回退旧版前先保存或删除实验性待保存结果，不能把完成记录降级为
schema 1、删除记录或静默丢弃完整结果。

## 本轮实际验证

| 验证 | 结果及边界 |
| --- | --- |
| 项目/三语/控件检查、`git diff --check` | PASS |
| macOS Debug arm64 + x86_64 完整构建 | PASS，unsigned 验证包 |
| iOS Simulator Debug arm64 完整构建 | PASS，隔离 QA bundle |
| 核心回归 | PASS，七配置 × 11 语料、共享流、Mac、Shortcuts、配额及模型回归 |
| 移动服务/协调器 native Release | 2 个 XCTest suite case 通过；5 个真实 SIGKILL 后的新进程恢复通过 |
| iOS Simulator Release 服务回归 | 3 个 case 通过，包含生命周期适配器；不代表真实锁屏或后台执行 |
| 容量准入 | 100 MiB、+1、256/512 MiB、1 GiB；1 GiB+1 在读取前拒绝。这组边界探针在开始读取时刻意停止，不冒充整篇转换 |
| 100 MiB+1 实际服务转换 | 完整输出对照整篇参考通过；完成记录、重启恢复、导出 URL、删除通过 |
| 二次确认状态机 | 开关关闭、无作业提前启动、取消/场景释放、旧 session、Pro/开关变化、源增长通过 |
| 空间与恢复故障 | 写入前空间丢失注入、旧/新记录、缺失/未知策略、超限/溢出记录通过；不是物理磁盘耗尽测试 |
| 实际 App 模拟器 UI | 1 GiB 英语 iPhone、512 MiB 繁体 iPhone、256 MiB 简体 iPad：确认→取消→重启→再次确认→完成，通过 |
| 新 App 关闭实验开关 | iPad 实际 UI 仍拒绝 100 MiB+1，源文件前后哈希一致 |
| 上述三个完整输出 | 同版本独立整篇 oracle 的长度和 SHA-256 均一致；语料含中文、Emoji ZWJ、组合字符、CRLF、空行及 U+0000 |

日志/清单：[native-results.txt](native-results.txt)、[job-regression.json](job-regression.json)、
[core-results.txt](core-results.txt)、[builds.json](builds.json)、[ui-results.json](ui-results.json)、
[ios-summary.json](ios-summary.json)。核心完整回归先于普通记录格式兼容收尾；收尾之后重跑移动服务、
协调器、iOS 生命周期及双端构建。未声称消除项目已有编译警告。

### 截图和录像

UI 是实际 QA App，采用 XCUITest 点击和 `simctl io recordVideo` 录制，非设计稿。
视频保留真实等待过程，无加速。英文 iPhone 和简体 iPad 各有同条件基线对照。
截图、录像通过 `gh --attach` 上传后的链接记录在 [media.md](media.md)。

| 条件 | iPhone | iPad |
| --- | --- | --- |
| 机型 | iPhone 16 Pro Simulator | iPad Pro 13-inch (M4) Simulator |
| 系统 | iOS 18.6 (22G86) | iPadOS 18.6 (22G86) |
| 竖屏大小 | 402 × 874 pt / 1206 × 2622 px | 1032 × 1376 pt / 2064 × 2752 px |
| 主题/字号 | 浅色、默认字号 | 浅色、默认字号 |
| 语言/容量 | 英语 1 GiB、繁体 512 MiB | 简体 256 MiB |
| 配置 | OpenCC 繁体，raw 1 | OpenCC 繁体，raw 1 |

文件由专用 QA 启动参数注入 HomeViewModel 的导入路径，Pro 同样为 QA 注入；**不是系统选择器、
真实文件提供方或真实购买验收**。测试不显示全文，不代表系统已保存导出副本。
测试总耗时包含启动、断言、取消和重启，不能当成单次转换性能。未测 iPhone 的整 App physical footprint、
存储峰值或热状态，不据此宣称真机可稳定转换 1 GiB。
仅使用新建专用模拟器，未改 VoiceOver 或用户设备设置。

## 复现

从对应源码按 [CI 参数](../../CI.md) 构建 macOS 与 iOS Simulator；UI App 使用
`PRODUCT_BUNDLE_IDENTIFIER=org.gewill.OpenCCman.WhatsNewUITests`、Debug、禁止签名及锁定依赖。
在专用模拟器安装此 QA 包，并对 `Tests/UI/WhatsNewPresentation` 工程执行 `build-for-testing`。
运行新的容量 UI case 时使用生成的 `.xctestrun`：

```bash
python3 docs/validation/issue-268-mobile-gib/run-ui.py \
  --device "$SIMULATOR_UDID" --mode candidate --language en \
  --bytes 1073741824 --xctestrun "$XCTESTRUN" --output "$NEW_OUTPUT_DIRECTORY"
```

输出目录必须不存在；脚本仅在隔离 QA Documents 新建唯一测试目录，不替换用户稿件。模拟器需无上次未保存
QA 任务，重复运行前保存/删除 QA 结果或只重装该专用模拟器的 QA bundle。
`baseline` 使用基线 App；`disabled` 使用新 App 但不开实验开关，均验证 100 MiB 拒绝边界。
脚本记录视频、XCTest 结果、源文件前后哈希；输出正确性仍须单独运行整篇 oracle。

QA 仅在 Debug 且精确 QA bundle ID 时可使用以下参数；正式包无此绕过入口：

```text
-qa-enable-mobile-large-files
-qa-mobile-file-pro
-qa-mobile-file-experimental-capacity
```

服务回归（干净的 SwiftyOpenCC checkout 必须等于 Package.resolved 锁定 SHA）：

```bash
python3 scripts/check-mobile-file-jobs.py --output "$NEW_JOB_OUTPUT" \
  --opencc-path "$PINNED_OPENCC_CHECKOUT" \
  --destination "platform=iOS Simulator,id=$SIMULATOR_UDID"
python3 scripts/check-core.py --opencc-path "$PINNED_OPENCC_CHECKOUT"
```

## 仍阻止正式启用和关闭 Issue 的项目

1. #260 完整 100 MiB 验收，特别是真实 iPad；当前无设备，不计通过。
2. #268 低内存 iPhone 与真实 iPad 的签名候选，全部容量档、七配置、无换行/词组跨块/输出膨胀语料。
   每个完整输出对照整篇 oracle；记录构建、source/wrapper SHA 和重复测量。
3. 整 App physical footprint、存储峰值、阶段耗时、热状态、系统终止诊断。没有固定可用内存或稳定成功承诺。
4. >100 MiB 真实系统选择/保存：本机、iCloud 与目标第三方提供方，取消、同名保存、权限/断连、空间不足、失败重试。
5. 签名包上的后台/锁屏、强退重启、取消/提交边界、未保存结果恢复、Pro 失效和场景关闭；大字号、深色和 VoiceOver。
6. 最低系统独立留 #16，真实权益留 #14 / #71。未来开启实验入口需独立 PR 与上述证据，不能由本候选的合并自动开启。
