# NSServices 调用等待与容量测量（#22）

本项尚未完成容量结论。现有引擎／应用诊断不代表 TextEdit 等调用方从选择服务到重新可编辑的等待；不得以本工具成功替代目标 App 的实际验收。

## 测量工具

`Tests/Benchmarks/ServicesWaitProbe.swift` 使用正式 `NSPerformService` API 和独立命名剪贴板，调用明确指定的服务菜单名；不访问或改写用户的通用剪贴板。它不模拟或直接调用 OpenCCman 的服务方法，也不会修改应用的同步服务协议。

```bash
mkdir -p /tmp/openccman-services-probe
xcrun swiftc -O Tests/Benchmarks/ServicesWaitProbe.swift \
  -o /tmp/openccman-services-probe/services-wait-probe
/tmp/openccman-services-probe/services-wait-probe \
  'EXACT UNIQUE REGISTERED TEST SERVICE NAME' \
  /path/to/input.txt /path/to/expected.txt 5 > /path/to/new-samples.jsonl
```

只使用专用测试安装、合成语料和新输出文件。服务可能启动应用并显示文稿；先确认服务名只指向待验收产物，避免调用同名的正式或其他候选应用。`NSPerformService` 本身不返回提供者身份，因此源码 SHA、构建类型、bundle ID、实际二进制 hash、注册与进程状态必须在伴随 manifest 中另外核实。不要把命令行填入的名称当作验证后的提供者身份。

每次先写入输入并输出 `sample_started`，仅在 API 调用前后使用单调时钟。随后单独计时剪贴板读取／UTF-8 编码，再做完整字节比较和 SHA-256；输出不包含正文。成功需要服务返回 true 且结果完全匹配。服务返回失败或结果不同即退出 4，参数／文件错误退出 2，全部通过退出 0；不自动重试失败，也不把失败折算成有效样本。

外部进程期限只用于结束拥有的测试调用方并保留 JSONL。只有 `sample_started`、没有 `sample_completed` 表示截断，不能用该期限报告单次服务耗时。终止调用方不保证终止服务提供者中的转换，不宣称可取消 C++ 或同步 Services。工具不主动停止提供者。

## 实际验收矩阵与关闭条件

- 固定同机 Release 签名候选、完整源码 SHA、依赖 pin、七组配置、UTF-8 字节数和期望输出 hash。先测 1 KiB、1／5／10 MiB 多短段落，再增加长段落；超过 10 MiB 的输入须单列，不能改变主页文件限制。
- CLI 调用测 API 同步往返时间；首个样本不能自动称为冷启动。提供者已关闭／已启动、有窗口／无窗口的状态要独立记录。
- TextEdit 和另一种真实可编辑目标 App 分别通过 Services 菜单运行，确认选区替换、完整输出、可继续输入、失败原稿保留。交互用录像举证；录像／AX 查询延迟不能直接当作转换计时。
- 若等待异常，用 Time Profiler／System Trace 区分服务计算、IPC 等待及目标 App 应用结果或排版成本；不要将整个进程期限归因给某一次 UI 动作。
- 有完整样本后再提出容量边界或引导文件工作流的产品决定。没有数据时不新增限制，不改主页每日额度，也不把阻塞等待异步任务包装成可取消服务。

## 官方依据

- [Apple：提供 Services](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/providing.html)：服务读取传入剪贴板、处理并写回，在错误参数中报告失败；文档中的 `pbs` 仅作诊断，不作为程序稳定依赖。
- [Apple：NSPerformService](https://developer.apple.com/documentation/appkit/nsperformservice(_:_:))；当前 SDK `NSApplication.h` 声明同步 BOOL 返回接口。

本工具不是无障碍或窗口显示测试，没有因此关闭 #19／#20／#22。完整目标 App 记录和容量决定仍待执行。

## 工具初验（2026-09-15）

本机 macOS 27.0（26A428）、Xcode 27 的 `swiftc -O` 编译成功。[三项负向检查](negative-checks.json)通过：缺参数退出 2；非法 UTF-8 退出 2；随机未注册服务返回失败，退出 4，只记录一次尝试，剪贴板仍为输入，没有 `run_completed`。测试输入含中文、Emoji、CRLF、U+0000；这里只验证失败记录和原稿校验，**不代表这些字符的真实 Services 转换已通过**。

尚未运行成功服务样本、TextEdit 或第二目标 App，也没有据此给出容量限制或延迟指标。提供者身份、Release 产物及固定语料的正式测量仍是下一步。
