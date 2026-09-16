# 真实 OpenCCman 诊断包：同类宿主闭包的分配栈

本次补上了真实应用的分配来源证据。两个 `AppKitWindowHostingView<…Router<…RootView…>>` 的明确 strong block 入边，均由 `NSView._commonAwake` 经 `NSNotificationCenter.addObserverForName:object:queue:usingBlock:` / `_Block_copy` 分配，与最小程序一致。仍未证明 registrar 到 block 的完整所有权及清理条件，不是产品修复或已确认的系统缺陷。

## 来源与运行边界

- 复用此前 CI 的 Xcode 26.3 Release 诊断 artifact，源码 `b0addf7f7e4472fe788558b71a5637450e70b861`（#108 的编辑器修正候选）。不是当前 develop，也不是签名 Cloud 发行包。
- 正常 WindowGroup、Router、RootView、业务模型与原生编辑器；既有诊断变体禁用购买初始化、Services 和全局快捷键注册，以独立偏好和 weak 模型表采样。该变体的具体源码注入、hash 和依赖不变量见 [provenance.json](provenance.json) 中的 sourcePreparation。
- 新解压私有副本，只改可执行文件名称、显示名称及进程级 `LSEnvironment.MallocStackLogging=1`，重新 ad-hoc 签名。保留沙盒、用户选定文件读写、网络 entitlement；没有修补 SDK 或源码。
- macOS 27.0 (26A428)，PID 46071。通过 CUA 正常启动、Command-N 新建第二窗并读取 AX。保留默认合成示例文本，没有导入、转换、购买或导出，不计为 1/10 MiB 工作流验收。
- 首次连续两次 Command-W 仅关闭第二窗，首窗有延后出现的 What's New sheet；原生日志仍为一窗。按实际 UI 关闭 sheet 后点击首窗关闭按钮，工具返回 AXError.failure，但之后原生日志持续零窗。没有以按键次数或工具成功消息代替窗口计数。
- 初始有界采集 watcher 在零窗满 20 秒前超时。未重启应用；同 PID 日志证明持续零窗后继续捕获，实际在首个零窗样本后 **55.099 秒**开始。它不是固定 +20 秒捕获，原始偏离保留在 [capture.json](capture.json)。

## 原始观察

[全部捕获前样本](pre-capture-samples.jsonl)从启动开始保留；[观察摘录](observations.json)选取首次零窗、至少 +5/+20 秒和捕获前最后一条，不裁掉 sheet 等待。该诊断只记录可见窗口数，**没有 weak NSWindow/host 采样，所以零窗不能在本轮解释为 NSWindow 已释放**。宿主与模型地址由后续 heap 快照取得。

| 时点 | 可见主窗口 | 活模型身份 |
| --- | --- | --- |
| 首次零窗（100.002 秒） | 0 | 1、2 |
| 首次零窗后至少 +5 秒 | 0 | 1、2 |
| 首次零窗后至少 +20 秒 | 0 | 1、2 |
| 捕获前（155.101 秒） | 0 | 1、2 |

两份宿主均有 3 条明确 strong 入边（block、set storage、array storage），另有 conservative/weak 入边，不能将扫描总数当强持有数：

| 宿主 | 工具报告 strong / conservative / weak 等 | 原始证据 |
| --- | --- | --- |
| `0x76fe900a00` | 3 / 66 / 259 | [入边](host-a-incoming-excerpt.txt)、[block 布局](host-a-block-layout.log)、[分配栈](host-a-block-allocation.txt) |
| `0x76fe901400` | 3 / 69 / 258 | [入边](host-b-incoming-excerpt.txt)、[block 布局](host-b-block-layout.log)、[分配栈](host-b-block-allocation.txt) |

`malloc_history` 对两份 block 均成功；不是根据环境变量或类型相似推断来源。公开文件只含合成测试的数字状态、栈和限定布局摘录；memgraph、完整布局及全量分配表留本机并记录 SHA256。

## 清理和结论

捕获完成后，为退出应用再次读取 UI，日志新增第三个模型并出现一个可见窗口。保留在 [完整日志](complete-samples.jsonl)，不混入捕获前零窗结果。这再次说明 UI 重新激活不是无干扰的零窗观察方法。

已通过 CUA 退出并核对原 PID 消失；标准域偏好精确恢复并读回，沙盒偏好恢复，私有副本停用。VoiceOver 和全局设置未改，未操作 #19 人工接管中的应用。[清理记录](cleanup.json)。

本次将“最小程序中存在同类 block”的推测推进为“真实应用诊断包中也具有同一分配路径”。它没有证明所有保留模型都由该路径导致，也没有测得修复收益。下一步定位框架对象/通知存储的实际所有权和注销时机，再判断是否存在可改的应用代码。#93/#18 保持开放。
