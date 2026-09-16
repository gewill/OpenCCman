# Services 失败时原稿保留与错误回传对照

## 实际结果

在独立 Release 测试副本中移出 `s2t.json` 后，1 KiB、10 MiB 和含 U+0000 的 27 字节输入均完整保留，实际期望转换未发生。**但本机 macOS 27.0（26A428）的 `NSPerformService` 三次均返回 true，不能仅以这个返回值判定转换已完成或错误已经展示。**

使用正确的 s2t 输出作为期望后，现有测量工具三次均因完整字节不匹配退出 4；每次虽请求五个样本，只执行第一个样本即停止，没有 `run_completed`。见 [summary.json](summary.json) 及对应 JSONL。这验证了工具会识别“API 报告成功但文稿未转换”的结果，也验证了这些故障输入的剪贴板正文未被清空；尚未验证 TextEdit 等实际调用方如何向用户显示错误。

## 故障隔离与来源

- 从 `eab5003bfdd938f08b936826225d7ab482d6f703` 的已验证 Release 副本另复制 `org.gewill.OpenCCman.ServicesFailureValidation`，使用独立服务名和端口，仅移出该副本的 `SwiftyOpenCC_OpenCC.bundle/Contents/Resources/Official/s2t.json`，然后重新 ad-hoc 签名。
- 正常测试包的实际二进制和 `s2t.json` 保持原样；没有修改源码、包缓存或正式安装。缺配置时 wrapper 初始化的 `fileNotFound` 抛错分支已在锁定源码中核对；未声称捕获了应用错误处理分支的运行栈。
- [setup.json](setup.json)保留资源 hash、签后故障二进制 hash 和精确注册信息；[provider-process.json](provider-process.json)确认系统启动的独立故障进程 PID 93062。测试偏好中三个配置键均未设置，使用默认 s2t。

初次探测误把“原稿不变”直接作为 expected，并断言 API 应返回 false；[该次原始记录](short-1KiB.jsonl)实际返回 true 且执行了五个请求，外层断言失败。该记录完整保留，不算转换成功或错误回传通过；没有重写它来匹配后续预期。后续使用真正的转换输出，在三个明确不同的语料场景检查“不符即停止”。

## 最小原生对照：不是已定位的 Swift 实现缺陷

为区分应用实现与系统 Services 路径，另外编译了一个没有 OpenCC、Swift 或应用业务代码的 Objective-C 对照服务，使用 `NSRegisterServicesProvider` 和官方形式的 `NSString **error` 参数。处理方法只写入固定错误字符串，不改剪贴板。

- [源代码](control/FailureControl.m)与[注册／二进制 hash](control/setup.json)。
- [提供者记录](control/provider.stderr)确认真实处理方法执行且收到非空错误指针。
- [调用结果](control/result.jsonl)仍返回 `service_succeeded: true`，剪贴板保持不变；调用方标准错误为空。

这排除了“必须经过 OpenCCman 的 Swift 方法才能出现该现象”的假设，但未确定系统、调用方式或其他运行环境的最终根因，也没有据此修改应用错误签名。Apple 的 [NSPerformService 文档](https://developer.apple.com/documentation/appkit/nsperformservice(_:_:))说明返回值表示服务是否成功执行，[服务实现说明](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/providing.html)要求失败时设置错误字符串；本机观测与直接按这两点推断返回 false 不一致，需在实际调用方及发布支持系统上复核。

## 对既有成功样本的影响

此前 56 组成功语料全部满足 `inputSHA256 != expectedSHA256`，280 次调用均匹配真实期望输出。因此返回原稿不变不能通过那些成功用例。本项不撤回完整输出已正确的结论，也不把这些失败／对照调用加入成功耗时统计。错误回传、目标 App 原稿保留及错误提示仍未全部验收，#22／#81 保持开放。

## 清理与 UI 保留项

[清理记录](cleanup.json)：故障 App 与无界面对照进程已退出，两项注册已移除，故障偏好恢复为不存在，VoiceOver 保持关闭。可复验的副本和移出的配置保留在 `.build/services-probe/failure-injection/`。

正常的 `OpenCCman Probe eab5003 Convert` 服务仍暂留，供维护者核对它为何未在 TextEdit 菜单中显示；尚未改动系统服务勾选或快捷键。TextEdit 只创建并移动了合成文稿到隔离目录，选区设置和存盘字节核对通过，尚未选择执行任何原有同名 OpenCCman 服务，不能计为目标 App 转换验收通过。第二目标 App 仍未开始。

[TextEdit 诊断尝试与清理](ui-attempt.json)：直接执行系统 App 二进制退出 137，改用 LaunchServices 启动后确认诊断参数生效，但菜单仍无专用服务；可用日志将 NSDebugServices 内容隐藏为 private，未从日志取得排除原因。未降低日志隐私保护或改动系统开关。诊断会话已退出，合成文稿存盘内容仍为原稿；保持菜单可见性检查待人工确认。
