# 原生窗口文稿生命周期验收

关联 #18、#93，依赖 #90 → #101 → #102。此变体延续 #102 的原生 New Window 菜单驱动，保留实际 WindowGroup / RootView / Router / 编辑器和业务模型。没有产品生命周期修复或依赖升级。

## 固定协议

1. 隔离诊断 bundle `org.gewill.OpenCCman.NativeWindowLifecycleAuditAutoDocuments`，免费偏好；不初始化购买 SDK、Services 或全局快捷键，不自动展示 What's New。
2. 从[历史固定清单](native-window-lifecycle/2026-09-15-documents/preparation.json)重建 1 MiB、10 MiB 输入及预期文件。预期是显式字符映射，不由被测转换器生成。验证输入、输出完整 SHA-256。
3. 首窗等待至少 10 秒，转换固定 75 字节短文并保留非空结果。后续持续检查原文、结果、导出快照、配置和任务状态的摘要。
4. 逐一创建四个实际窗口：1 MiB 两次、10 MiB 两次。调用真实 `importFile` / `translate`；导入剥离 BOM 后逐字节一致，结果及导出文件必须与固定 oracle 完整一致。覆盖 CRLF、空行、中文、Emoji、组合字符、NUL；每次成功只扣一次。
5. 导出成功后展示至少 10 秒，关闭文稿窗口，在 +5/+20 秒记录模型身份、物理占用、额度与保留窗口状态。驱动跨 tick 只保存标识、时间戳、路径和短摘要，不保存模型、窗口、正文或结果。
6. 第五个文稿窗口导入 10 MiB，在实际原生转换调用区间内关闭。诊断只给 `converter.convert(text)` 前后增加锁保护的标量时间戳，不延迟或阻塞工作线程。同步 `NSWindow.willCloseNotification` 时间必须严格位于 begin/end 内，且关窗前 `isLoading` 为 true。若错过区间，失败并保留日志，不用 UI 标签代替。
7. +5/+20 秒不得出现取消结果回写，预约归零，总扣次保持 5（首窗 1 + 正常文稿 4）。仍存活的取消模型必须没有结果或导出快照；记录存活本身，不把它自动判作泄漏。
8. 最终关闭首窗，零窗口持续观察 +5/+20 秒，自行退出；最长 420 秒。无需再次通过 UI 工具激活应用。

## 导出和测量边界

SwiftUI 的 `FileDocumentWriteConfiguration` 没有公开初始化方法。准备器仅在私有源码副本中提取原有 `fileWrapper` 的完整函数体为诊断入口，原协议入口转调同一函数体；驱动使用实际导出快照及此编码入口写入自身 cache。**这覆盖文件内容编码，不覆盖系统保存面板、重名或签名文件权限**，这些入口仍须单独验收。[Apple 写入配置](https://developer.apple.com/documentation/swiftui/filedocumentwriteconfiguration)

原生调用区间包含 wrapper 的输入输出处理，不等于采样到了某条 C++ 指令，也不宣称能中断 C++。[Apple 关窗通知](https://developer.apple.com/documentation/appkit/nswindow/willclosenotification)

主测量不额外查询窗口、不录屏。演示视频单独运行并保留独立原始记录，因为 #101/#102 已观察到额外查询和录屏会改变对象存活。20ms 驱动 timer、每秒内存记录、文件比较及诊断日志有开销，此协议不用于宣称转换延迟或峰值内存改善。

## 复验

```bash
python3 scripts/prepare-window-lifecycle.py --documents --output .build/documents-candidate
# 只构建准备器生成的 source；沿用锁定依赖和 macOS 11 下限。
# 本机通过正常 UI 启动专用 bundle，进程自动执行并退出。
python3 scripts/check-native-window-lifecycle.py --documents \
  --raw /absolute/path/to/lifecycle-PID-UUID.jsonl --output .build/documents-result
python3 -m unittest discover -s Tests/Benchmarks -p 'test_*.py'
```

手动 App Regression 输入 `document_window_lifecycle=true` 构建并测量同一协议。CI 的 launcher 只接受该专用 bundle，失败上传原始 artifact；本地 validator 默认只读取日志；可用 `--document-files` 指定生成的文件目录，独立复核四份导出并归档固定文件。CI 在进程退出后必须执行此字节复核。不同模式同时选择时，文稿优先于三轮、双窗模式。

## 结果

首轮 [CI 35001420643](https://github.com/gewill/OpenCCman/actions/runs/35001420643)，源码 `4ad96d994a0300d5124e243b1a10a5c3ea77f90f`，Release 构建通过，但完整协议未通过。四份正常导出均与固定 oracle 字节一致，关闭后的新增模型均已释放；第五窗导入时达到 240 秒上限，未完成活动关窗和最终零窗观察。[原始失败记录](native-window-documents/2026-09-16/initial-ci-timeout/)

10 MiB 的两个原生调用区间约 0.204 / 0.212 秒，但从界面触发到观测导入/结果就绪相隔约 18–22 秒。后者包含主线程展示和诊断工作，不是文件 I/O 或引擎的单独耗时，不能直接据此归因。已把驱动上限增至 420 秒、CI 进程上限增至 450 秒，保持每次 +5/+20 秒与全部样本；首轮失败不删除。复跑和本机验收仍待完成。

合成协议测试仅校验拒绝条件，不算实际验收。后续补独立截图/视频、偏好恢复和剩余结果。系统保存面板、真实入口、Pro/跨日/临界额度、最低系统及签名 Cloud 发布门槛不由本协议替代。
