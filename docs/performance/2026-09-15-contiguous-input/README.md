# 未采用：提前整理连续 UTF-8 存储

#84 已移除应用重复扫描，[真实 Services 采样](https://github.com/gewill/OpenCCman/blob/9d9b629/docs/performance/services/2026-09-15/optimized-s2t/provider-identity.sample.txt)仍显示 wrapper 的 `String._slowUTF8CString()` 成本。本次评估在局部 String 副本上先调用 `makeContiguousUTF8()`，再进入现有转换服务。

**结论：本轮没有速度收益，不接入生产代码。** 280 次输出完整字节校验通过；10 MiB 剪贴板来源文本的七配置中位数均略慢。没有为了得到正向结果修改算法或剔除样本。

## 候选及来源

```swift
var contiguous = text
contiguous.makeContiguousUTF8()
return try ChineseConversionService.convertSynchronously(contiguous, options: options)
```

[Apple API 文档](https://developer.apple.com/documentation/swift/string/makecontiguousutf8())说明该操作在连续存储时为 O(1)，否则为 O(n)，并可能使既有索引失效。因此实验只使用局部副本，不把编辑器索引带入这条路径；没有更改任何编辑器或业务模型。

基线源码 `f51b6fd4ea1e922ca83b67440537f554d6ba1619`（#84 已合并），SwiftyOpenCC 保持 `6eded293f5c84c064f332cbc2832391165c82dda`。应用服务和实验源码 hash、二进制 hash、Swift 版本见 [source.json](source.json)。这是独立 SwiftPM Release 处理实验，不是应用构建、启动、Services 往返或画面呈现测量。

[完整实验源码](ContiguousInputBenchmark.swift)由 #84 的定向基准改写两个比较入口；基线调用实际生产服务，候选在调用前整理存储，操作本身包含在计时中。其余语料、准备方式、交替顺序和输出验证保持一致。构建见 [build.log](build.log)。

## 测量

同机 Apple M4 Pro、48 GiB、macOS 27.0（26A428）、Swift 6.4 / Xcode 27。七配置，1/10 MiB，native 与独立命名剪贴板来源两种表示，每例五对、交替先执行基线／候选。实际 native 样本均为连续 UTF-8，剪贴板样本均非连续；没有使用通用剪贴板。输入准备、converter 预热、输出编码及 hash 比較在计时之外。

下表为 10 MiB 剪贴板来源文本，每项五个样本的中位数。

| 配置 | 现有实现 ms | 整理存储后 ms | 中位数变化 |
| --- | ---: | ---: | ---: |
| s2t | 218.805 | 228.712 | 慢 4.53% |
| t2s | 194.638 | 201.392 | 慢 3.47% |
| s2tw | 298.301 | 307.929 | 慢 3.23% |
| s2twp | 346.957 | 351.982 | 慢 1.45% |
| s2hk | 301.707 | 310.481 | 慢 2.91% |
| legacy-s2t-tw-idiom | 482.989 | 493.096 | 慢 2.09% |
| legacy-s2hk-tw-idiom | 530.974 | 543.567 | 慢 2.37% |

[全部 280 个原始样本](samples.jsonl)、[所有条件的中位数及范围](summary.json)保留 native 和 1 MiB 结果，没有只归档目标表格。输出参考由同版本 converter 生成，完整字节相等；这不是独立词典质量验收或 NUL 专项回归。

## 决策与边界

这个候选未展现收益，因此停止该方向的实现，不追加其内存、完整应用或设备验收。没有测量这次候选的峰值内存，不能仅凭局部副本写法声称增加或减少了具体内存。单轮、每项五对结果也不足以确定所有小差异的来源；未全程控制系统外部负载和热状态。

生产服务、依赖和设置均未修改，运行结束后独立剪贴板按测试代码释放。后续若选择其他编码路径，应重新测量其自身的输出、耗时和内存；本实验不替代 #18／#22 的剩余验收。

## 重现

在完整仓库 checkout 的根目录执行；需 macOS 登录会话及 Swift 工具链。使用新的临时目录、历史生产服务和本页原型；远端依赖仍锁定同一 revision。原始测量使用本地、已校验的该 revision checkout，二者源码版本相同。

```bash
probe_dir="$(mktemp -d /tmp/openccman-contiguous.XXXXXX)"
mkdir -p "$probe_dir/Sources/ContiguousInputBenchmark"
git show f51b6fd4ea1e922ca83b67440537f554d6ba1619:OpenCCman/Services/ChineseConversionService.swift > "$probe_dir/Sources/ContiguousInputBenchmark/ChineseConversionService.swift"
cp docs/performance/2026-09-15-contiguous-input/ContiguousInputBenchmark.swift "$probe_dir/Sources/ContiguousInputBenchmark/"
cp docs/performance/2026-09-15-contiguous-input/Package.swift "$probe_dir/"
swift run -c release --package-path "$probe_dir" > "$probe_dir/samples.jsonl" 2> "$probe_dir/build-and-stderr.log"
```

应返回 0，最后一行为 `run_completed`、280 个样本。保留完整新日志；不要覆盖本页的历史记录。`scripts/benchmark-byte-scan.py` 的 `summarize()` 可用于重新检查数据完整性和计算摘要。
