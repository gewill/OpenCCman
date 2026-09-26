# 移除重复 NUL 扫描的定向性能验证

锁定的 SwiftyOpenCC `6eded293f5c84c064f332cbc2832391165c82dda` 已按字节长度传递输入／输出，并在 C++ 桥接层保留 NUL 分隔。应用再次执行 `text.utf8.contains(0)` 和 NUL 分段，重复了桥接层工作。本次只移除这段应用处理，缓存、异步转换、取消、额度和文件规则保持原样。

## 依据与范围

[真实 Services 定向采样](https://github.com/gewill/OpenCCman/blob/66816bedafa14cf276bdd67384a8bbb60f79e8aa/docs/performance/services/2026-09-15/provider-identity.sample.txt)中，`ChineseConversionService.convertSynchronously` 下出现大量 `Sequence.contains`、`String.UTF8View._foreignSubscript` 和 `NSString.characterAtIndex` 栈。该历史样本的应用源码为 eab5003、工具链为 Xcode 26.3；它用于定位本次扫描热点，不与下面的新计时混算。

已核对锁定 wrapper 的 [Swift 字节长度入口](https://github.com/gewill/SwiftyOpenCC/blob/6eded293f5c84c064f332cbc2832391165c82dda/Sources/OpenCC/ChineseConverter.swift)和 [C++ NUL 分隔实现](https://github.com/gewill/SwiftyOpenCC/blob/6eded293f5c84c064f332cbc2832391165c82dda/Sources/copencc/source.cpp)。Swift 官方文档说明 [isContiguousUTF8](https://developer.apple.com/documentation/swift/string/iscontiguousutf8)反映字符串是否具有连续 UTF-8 存储；[String](https://developer.apple.com/documentation/swift/string)可以使用桥接的 NSString 存储。本次不强制改变编辑器字符串表示，直接复用依赖已提供的转换能力。

**以下测量是编译了生产转换服务的 Release 处理测试，不是整套 App、NSPerformService 往返、画面显示、启动、FPS、电量或内存收益。** #18 的原生窗口生命周期和最终签名产物等剩余项不由它替代。

## 固定来源与方法

- 候选源码 `0817af608d3b9f0f1d0fc0ec3212c4e82e3a470e`，应用服务 hash 在两份 source.json 中一致；基线函数体来自 `f8f40f2b6f85d1c5fd1c3224a745aa9e7abe1df8`。基线和当前路径在同一二进制中，共用未改变的 converter cache。
- Apple M4 Pro、14 个逻辑 CPU、48 GiB RAM、macOS 27.0（26A428）、Xcode 27.0（27A266a）、Swift 6.4；[环境](environment.json)、[构建日志](build.log)、[首轮来源](run-1/source.json)。SwiftPM Release 构建使用同一锁定 OpenCC，不升级依赖。
- 固定合成短段落覆盖中文、Emoji、组合字符、CRLF、空行；以 ASCII 空格补齐到 1 MiB 和 10 MiB，不截断 Unicode。七配置，各测 native 和独立命名剪贴板返回的 String。
- 每个数据集五对调用，交替先执行基线或当前路径，每次计时前重新取得输入。实际 140 个 native 样本均为连续 UTF-8，140 个 pasteboard 样本均为非连续 UTF-8；第二进程亦如此。并未使用通用剪贴板。
- converter 初始化／预热、输入准备、读取剪贴板、输出编码、完整字节比较、hash 和日志均在计时区间之外。时间只包围对应转换函数调用。引用输出由同版本 converter 直接整稿产生；固定 NUL 期望另由 CoreChecks 验证，不能将这份基准当作独立词典质量审查。
- 首轮原生 s2t 波动较大且中位数反向，因此用同一二进制重新启动一个进程复测，保留首轮所有数据。没有剔除慢样本、跨轮合并中位数或在同一输出目录覆写样本。[复测原因及开始前热状态快照](run-2/repeat.json)；没有全程采集外部负载／热状态。

## 10 MiB 剪贴板文本结果

单位为 ms；每个数值是五个样本的中位数。两轮全部 560 次输出与各自固定参考完整匹配，28 种输入／配置条件每轮齐全。下表只对比剪贴板来源文本的转换处理。

| 配置 | 首轮基线 → 当前 | 复测基线 → 当前 |
| --- | ---: | ---: |
| s2t | 389.410 → 225.296 | 369.664 → 224.992 |
| t2s | 337.662 → 196.078 | 343.218 → 195.909 |
| s2tw | 447.800 → 305.476 | 451.394 → 307.320 |
| s2twp | 496.029 → 358.963 | 499.549 → 355.575 |
| s2hk | 452.978 → 306.722 | 454.173 → 307.698 |
| legacy-s2t-tw-idiom | 635.045 → 491.491 | 634.370 → 489.536 |
| legacy-s2hk-tw-idiom | 693.268 → 544.494 | 691.573 → 550.149 |

精确值、1 MiB、native 结果及所有最小／最大值见 [首轮摘要](run-1/summary.json)、[复测摘要](run-2/summary.json)；原始数据分别为 [run-1](run-1/samples.jsonl)、[run-2](run-2/samples.jsonl)。这两轮中 10 MiB 非连续 UTF-8 输入的中位数下降约 20%–43%，不能称为整个应用提速这个比例。

原生 s2t 首轮为 148.973 → 162.963 ms（当前中位数慢约 9.4%），基线单样本范围 121.969–414.177 ms；复测为 104.202 → 90.624 ms。反向结果未复现，但没有据此确定首轮波动原因，也不声称原生字符串在所有条件下都有稳定收益。

## 正确性与报告检查

[核心回归](core-checks.log)通过七配置 × 十一语料，包括前／中／末尾 NUL、连续 NUL、超旧分块阈值的文本以及固定 NUL＋Emoji＋组合字符＋CRLF 字节预期；同步的 Foundation 解码文本和异步路径均通过。原有取消／替换、单次回写、额度、文件和 provider 回归同时通过。

[34 项报告测试](report-checks.log)包括原有应用测量比较器及新增八项：用真实捕获重生成中位数，拒绝未完成记录、输出错误、成功标记与 hash 不符、重复 pair、顺序错误、无效时间和重复 case。[工程解析](project-check.log)通过 58 个 Swift 源文件和三份本地化文件。[执行入口负向检查](negative-checks.json)确认拒绝覆盖结果和错误依赖 revision。

完整应用构建仍由本 PR 的 App Regression 验证，以 PR 检查为准；本报告不把 SwiftPM 编译当作完整应用构建。

## 重现与依赖回滚

```bash
python3 scripts/benchmark-byte-scan.py --output /path/to/new-output
# 可选使用已经核对的精确 revision 本地 checkout：
python3 scripts/benchmark-byte-scan.py --output /path/to/another-new-output \
  --opencc-path /path/to/SwiftyOpenCC
python3 -m unittest discover -s Tests/Benchmarks -p 'test_*.py'
```

脚本保留构建、来源与输出，失败不自动重试。`summarize()` 可从原始 JSONL 重算摘要并检查完整性；测试直接读取本报告的真实捕获，不要求测量机器或启动 UI。

若回滚到缺少按长度传递／NUL 保留的旧 wrapper，应在同一个回滚 PR 恢复应用兼容处理并通过 CoreChecks，见[同步回滚说明](../../upstream-sync.md#回滚与维护)。本次没有修改依赖 pin，也没有触发 Xcode Cloud 发布。
