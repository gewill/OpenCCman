# 重复扫描修复后的 Services 默认配置补测

PR #84 合入后，默认 s2t 的 10 MiB Services 往返中位数从约 419 ms 降到约 314 ms（约 25%）；1 KiB、1 MiB 和 5 MiB 的结果接近，没有明确收益。这里测量 `NSPerformService` 调用，不包含调用方读取／编码输出，也不是目标 App 可编辑时间或整个 UI 的提速。

## 来源与方法

- 基线源码 `eab5003bfdd938f08b936826225d7ab482d6f703`，当前源码 `6de377c3f8f1973ba06b04fc489b7125caa613ea`。`git diff` 确认应用／工程仅 `ChineseConversionService.swift` 中移除重复扫描的九行 diff；项目与依赖锁文件相同。[产物及签名 hash](provider-manifest.json)。
- 两个应用均为 Xcode 26.3（17C529）构建的 Release universal，使用同一台 Apple M4 Pro、48 GiB、macOS 27.0（26A428）。新产物的 [构建及整套回归](https://github.com/gewill/OpenCCman/actions/runs/34958289040)均通过。应用为本地 ad-hoc 重签副本，不代替分发签名验收。
- 每个副本使用独立 bundle ID／Services 名称。已核对[唯一注册](registration-excerpt.txt)、实际进程与二进制；[定向采样](provider-identity.sample.txt)命中当前副本的 `TextConversionService` 和 OpenCC 转换链。20 次身份诊断调用不计入表格。
- CUA 逐项确认 Traditional Chinese／OpenCC Standard／Not convert，设置面板关闭；English、默认字体，主窗口 900×450pt。[第二轮状态](run-2/runtime.json)、[实际窗口几何](run-2/window-geometry.json)。编辑器保留默认短文与空结果，文稿通过独立 Services 剪贴板传输。
- 复用历史同版本官方 CLI 生成的八份语料及完整预期字节，覆盖短／长段落和 1 KiB、1/5/10 MiB。每轮新提供者进程启动、已开窗后先做一次 1 KiB 预热，再按表格顺序每例五次连续调用；不将样本 1 称为冷启动。计时区间内没有输出读取、hash 或日志。
- 首轮跟进工具误用 `swiftc` 默认参数，历史工具记录为 `swiftc -O`。首轮 40 次及其[原始摘要](first-run-comparison.json)完整保留，仅作诊断和正确性证据；发现后恢复环境，使用同一应用二进制、新进程和匹配的 `-O` 工具重测。[复测原因与工具 hash](run-2/repeat.json)。下面只使用第二轮；未混合或挑选两轮样本。

## 正式对照

单位 ms，每例五个样本。基线为[历史记录](../README.md)，当前为[第二轮原始数据](run-2/s2t-series)。两轮跟进的 80 次固定语料调用全部匹配预期；表格使用其中参数匹配的 40 次。

| 语料 | 大小 | 基线中位数（范围） | 修复后中位数（范围） |
| --- | ---: | ---: | ---: |
| short-paragraphs | 1 KiB | 106.175（105.086–152.955） | 106.301（105.963–128.020） |
| short-paragraphs | 1 MiB | 105.490（101.563–150.663） | 105.499（105.237–133.218） |
| short-paragraphs | 5 MiB | 211.002（208.438–259.015） | 210.559（209.392–230.300） |
| short-paragraphs | 10 MiB | 419.349（418.234–444.881） | 314.321（309.636–336.841） |
| long-paragraphs | 1 KiB | 106.237（101.340–153.284） | 105.975（104.980–131.747） |
| long-paragraphs | 1 MiB | 106.546（101.404–142.953） | 105.725（105.345–136.627） |
| long-paragraphs | 5 MiB | 210.299（206.029–254.637） | 210.474（209.247–231.233） |
| long-paragraphs | 10 MiB | 419.394（417.431–2189.534） | 314.089（311.220–342.305） |

[机器可读对照](comparison.json)、[验证日志](verification.log)、[第二轮执行记录脚本](run-2/run-s2t-series.py)。历史长段落 10 MiB 的 2189.534 ms 慢样本仍包含在范围中，未剔除。

这是同机、同工具链、相同语料的分时段历史对照，并非随机交替配对实验；没有全程采集外部负载或热状态，不能把所有差异都归因于修复，也不能外推其他六配置、iOS、内存或画面呈现。小文件调用聚集在约 106 ms、5 MiB 约 210 ms 的现象只作观察，未确定等待来源。

## 正确性、后续与清理

额外的 [27 字节 NUL／Emoji／组合字符／CRLF 契约](nul-service.jsonl)通过，前中后及连续 NUL 保留。它和身份诊断、预热都不混入性能表。生产代码的七配置 NUL 回归已在 #84 完成；本次真实 Services 补测仅默认 s2t。

新采样中仍能看到 wrapper 的 `String._slowUTF8CString()` 编码成本；下一步若评估这条路径，应再测输出一致性、复制及内存，不能直接从采样占比推算收益。本轮不再修改代码或依赖。

CUA 在调用后仍显示默认原文及空结果，因此结果回写到目标 App／应用编辑器、关窗和快捷键路径继续由 #19／#22 验收。此报告没有将 Services API 成功等同于实际编辑器交互通过，也不改变容量边界。

[第一轮清理](cleanup.json)、[第二轮清理](run-2/cleanup.json)均确认进程退出、临时服务注销、应用移出 Applications、临时偏好恢复为不存在；VoiceOver 未开启。旧 `OpenCCman Probe eab5003 Convert` 仍保留给待办的人工菜单检查。
