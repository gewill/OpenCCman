# Mac 大文件容量候选（#269）

日期：2026-10-02。关联 [#269](https://github.com/gewill/OpenCCman/issues/269)、[#217](https://github.com/gewill/OpenCCman/issues/217)。

## 交付边界

这是 **2 / 4 / 8 GiB 开发候选**，不是公开支持 8 GiB 的发布承诺。常规 Pro 路径仍为 1 GiB；`MacLargeFileCoordinator.experimentalCapacityEnabled` 保持 `false`。只有 Debug 的精确 QA bundle `org.gewill.OpenCCman.WhatsNewUITests` 加 `-qa-mac-file-experimental-capacity` 才能验证实验入口。Pro QA 注入也只在同一隔离 bundle 生效。

[#260](https://github.com/gewill/OpenCCman/issues/260) 的真实 iPad、最低系统与相关签名验收并未因此通过。#269 保持开放；下面列出的未验收项目完成前不得打开生产实验开关。

## 实现

| 环节 | 行为 |
| --- | --- |
| 容量政策 | 编辑器 10 MiB 不变；Mac 常规 1 GiB；实验候选硬上限 8 GiB，超限先于 Pro 提示拒绝。移动端政策不变。 |
| 每任务确认 | 超过 1 GiB 时，选择保存位置前显示文件名、实际大小、空间估算和失败可能；同意仅绑定当前 Session ID。风险弹窗取消会释放任务，系统保存面板取消会清除本次同意，下次再次确认。 |
| 权益与开关 | 在选择保存位置、二次确认及真正开始转换时重新检查当前 Pro 和开关；失败关闭源文件并保留可读错误。 |
| 服务入口 | `StreamingTextFileService` 独立检查容量；默认只能处理 1 GiB，实验调用显式传入 `MacFileCapacity.experimental`，仍拒绝 8 GiB＋1 字节。 |
| 空间 | 仅实验任务预检输入的两倍＋64 MiB，乘加及 Int64 转换均检查溢出；常规任务不做两倍预检。两种任务写入时均约每 4 MiB 重查可用空间，为下一块保留 64 MiB。每次移除 URL 缓存；important-usage 为 nil／非正值时使用普通可用空间，后者明确为 0 仍拒绝。未知容量继续由实际 I/O 判断，查询错误照常返回；估算不是输出上限或成功保证。 |
| 原稿与发布 | 仍是 256 KiB 有界读取、OpenCC 流式转换、私有临时文件、同步关闭后原子替换；不把大文件文本放入编辑器。源身份／大小变化、目标竞态、取消、错误清理沿用既有机制。 |

空间查询使用 Apple 为用户主动保存数据提供的 [volumeAvailableCapacityForImportantUsage](https://developer.apple.com/documentation/foundation/checking-volume-storage-capacity)。已有隐私清单 DiskSpace `E174.1` 覆盖本地写入前容量检查；未增加上报。

PR 审查后修正了常规路径的两倍空间限制，并增加普通容量查询回退，见 [Review 修复记录](review-fixes.md)。下方 23 个大文件案例与原生截图仍对应各自记录的原始源码 SHA；不把它们改标为修复后重新跑过的证据。

## 整数与恢复审计

- `fstat.st_size` 在支持的 arm64 / x86_64 平台为 64 位；负值不会转成巨大无符号容量。`OpenedTextFile.byteCount`、累计输入／输出与进度回调使用 `UInt64`。
- `FileHandle` 顺序读写，每块不超过 256 KiB；没有把整个文件大小传给 C++ 的 32 位参数。文件身份与起始大小在读取前、完成后复核，途中增长也由 pump 的累计读取检查拒绝。
- UI 将最多 8 GiB 的输入转成 `Int64`，空间估算最多 16 GiB＋64 MiB；均在范围内。进度 `Double` 对这些整数无精度截断问题。最终 100% 只在原子提交成功后显示。
- **Mac 当前没有持久任务 journal，也没有重启续转。** 本次没有虚构或引入一份恢复授权：取消／重新导入必须重新确认；重启后的私有半成品清理仍由 #217 跟踪。
- #217 已记录 SIGKILL 后可能遗留私有临时目录。普通取消／捕获错误的清理不能代替强退、断电和外接卷断连验收，因此生产实验开关保持关闭。

## 可重现验证

```sh
python3 scripts/check-core.py --opencc-path <干净且与 Package.resolved 一致的 SwiftyOpenCC>
bash scripts/check-project.sh
python3 scripts/check-app-language.py
bash scripts/check-control-labels.sh
python3 scripts/benchmark-streaming-files.py \
  --opencc-path <同上> --output <新的证据目录> --experimental \
  --sizes-mib 1024 2048 4096 8192 --corpora single multiline \
  --configurations s2t --samples 1 --timeout 600
```

其他配置：`t2s s2tw s2hk s2twp s2t-tw-idiom s2hk-tw-idiom`。未传 `--experimental` 时，脚本仍拒绝超过 1024 MiB 的任务。每次以新进程运行，保留来源哈希、完整输出长度和 SHA-256、10 ms 服务进程内存采样及取消到清理完成时间。参考生成已预热同配置转换器，因此这不是冷启动测量；每个组合只有一个样本，不能据此宣称相对旧版提速。

参考输出使用同版本 **完整字符串转换器** 处理带独立分隔符的有界语料块，校验块连接与末尾的等价性，再计算完整文件期望哈希；不是让被测流式实现验证自己。该方法适用于本报告的固定重复语料，不代表任意文件都可无上下文切块。语料包含中文、Emoji、组合字符、IDS、U+0000、BOM、CRLF／空行、超长单行。另用 `--corpora expansion --configurations s2hk-tw-idiom` 覆盖显存／內存／互联网等扩张词组，并断言完整输出确实大于输入。

## CI 工具链修正

首次 [App Regression](https://github.com/gewill/OpenCCman/actions/runs/36896071201/job/110483273907) 在 Xcode 26.3 编译测试时，无法在时限内推断 Optional UInt64 比较右侧的容量乘加表达式。本机 Xcode 27 可以编译。已将该测试的预期容量改为显式 `UInt64` 常量 17,246,978,048（16 GiB＋64 MiB），不改变产品代码；后续检查以修正后的 PR HEAD 为准。

## 本轮结果

结果与原始 JSON 在本目录归档；服务基准是优化构建的非沙盒 harness，不等同于整 App。原生应用单独使用开发签名、沙盒、用户选择文件读写 entitlement 的 Debug QA 包；Pro 由 QA 参数注入，不是购买验收。

通过 **23 个完整文件案例**，合计处理约 58.01 GiB 输入；全部完整输出哈希一致、取消后的原目标保留、临时输出清理通过。另有核心回归的边界与故障注入，它们不计入完整大文件案例。

来源：应用实现 `f48c58548b51cfe6b420d6dad9f10372ae0e70d9`；矩阵与扩张语料各自源哈希、二进制哈希和测试提交见对应 `metadata.json`。Wrapper `564b094b2b69f2c1e907fa3d89fe6845469a4e4e`；OpenCC `025f371dc76b598d77384fbdab90c937471844d8`。

| 1 GiB 配置 | 单行耗时（秒） | CRLF/空行耗时（秒） | 两者最大采样 footprint（MiB） |
| --- | ---: | ---: | ---: |
| s2t | 13.03 | 13.10 | 42.33 |
| t2s | 9.92 | 10.91 | 22.13 |
| s2tw | 25.72 | 25.56 | 57.31 |
| s2hk | 25.78 | 25.14 | 56.41 |
| s2twp | 26.92 | 26.10 | 57.84 |
| s2t-tw-idiom | 28.86 | 28.81 | 54.74 |
| s2hk-tw-idiom | 36.10 | 36.84 | 54.95 |

| s2t 容量 | 单行耗时（秒） | CRLF/空行耗时（秒） | 两者最大采样 footprint（MiB） |
| --- | ---: | ---: | ---: |
| 2 GiB | 24.74 | 26.21 | 41.25 |
| 4 GiB | 50.32 | 52.16 | 43.03 |
| 8 GiB | 97.07 | 104.66 | 45.39 |

8 GiB 混合香港字形／台湾词汇单行：292.02 秒。8 GiB 扩张语料：输出 **10,128,430,349 字节（9.433 GiB）**，330.22 秒，采样 footprint 54.94 MiB。输入上限没有被错误用于限制输出大小。

这 23 项的服务取消探针都在首块成功写入后触发，最慢返回清理时间 0.537 ms；这不是 UI 点击响应或正在执行的 C++ 可随时抢占的证明。

原始证据：[矩阵](matrix/README.md)、[汇总](summary.json)、[UI 来源与媒体哈希](ui-evidence.json)、[自动检查](checks.json)。

### 原生 App 验收

- 开发签名＋沙盒，M4 Pro 48 GiB / macOS 27.0.1，arm64 实际运行（构建包含 arm64 与 x86_64）。主窗口 1024×768 pt，浅色，三语确认均完整显示。使用 CUA 操作真实系统打开／保存面板；视频由 ScreenCaptureKit 仅捕获 QA 应用，无音频。
- 本地 APFS 2 GiB、OpenCC 繁体实际完成，完整输出为 2,147,483,648 字节，SHA-256 `713eac9628aaa6a6ab28cfbca7d1d3aed069b96264fb6ed70c189780c1c87e3e`。原稿和旧结果在完成后保留。
- Debug 包从私有输出创建至观察到原子提交约 **201.61 秒**（100 ms 提交观察间隔，不含打开／保存面板和未单独计时的预检）；整 App 100 ms 采样 footprint 峰值 **89.55 MiB**，RSS 171.16 MiB。采样窗口包含保存前、转换与完成后。语料、优化级别与服务基准不同，不能直接比较速度。
- 从转换开始后约 34 秒采样私有输出，到原子提交；采样最大逻辑大小 2,146,697,187 字节、分配大小 2,147,745,792 字节。采样可能漏过最后一块，不能把它当作精确的全流程磁盘峰值，也未包含输入与其他 App。
- 取消系统保存 → 重新选择保存位置时再次确认；取消风险提示 → 原稿／旧结果保留。真正开始转换后点击取消，约 1.415 秒内观察到工作区（含自动化和 AX 读取耗时）；原定目标未生成，对应私有临时目录已删除。
- 实际挂载的 128 MiB HFS+ 测试磁盘映像：2 GiB 任务在空间预检安全失败，无输出文件、卷中无剩余常规文件；已卸载。它验证真实目标卷容量查询，不能代替物理外接盘断连测试。

原生原始数据在 [native](native/app-result.json)；内存／磁盘采样及取消、空间检查分别归档。`native/fixture.py create <新文件路径>` 可重建固定 2 GiB 输入，选择「OpenCC 繁体」转换后以 `native/fixture.py verify <输出路径>` 核对整个输出。该 literal oracle 仅对固定语料有效。

### 截图与交互

前后截图与两段完整交互录像见 [PR #272](https://github.com/gewill/OpenCCman/pull/272)，均经 `gh --attach` 上传；对应 URL 和原始媒体 SHA-256 见 `ui-evidence.json`。未将本地绝对路径作为 GitHub 媒体链接。

## 开放前仍需完成

- 支持范围内的低内存 Mac（本机 M4 Pro 为 48 GiB），以及 macOS 12 最低系统；最低系统承接 [#16](https://github.com/gewill/OpenCCman/issues/16)。
- #217 的真实外接卷／文件提供方断连、权限撤销、强退和重启残留恢复；不能用故障注入或磁盘映像代替物理设备／提供方验收。
- 正式签名 Release 候选的完整文件大小／配置矩阵、整 App 峰值、分阶段耗时与磁盘峰值，确认可公开的有限上限。
- 正式权益路径与最低系统购买相关继续由 [#14](https://github.com/gewill/OpenCCman/issues/14) / [#71](https://github.com/gewill/OpenCCman/issues/71) 承接。
- 明确选择生产上限、补齐剩余证据后，用独立 PR 打开开关；本次没有触发 Xcode Cloud、TestFlight 或商店发布。
