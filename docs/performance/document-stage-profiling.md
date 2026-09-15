# 文稿阶段调用栈诊断

关联 #18、#65；依赖 [#105](https://github.com/gewill/OpenCCman/pull/105) 的完整原生窗口文稿协议。

## 问题与方法

#105 的 macOS 15 云端记录中，固定 10 MiB 文稿从导入开始到驱动确认就绪约 17 秒，原生 OpenCC 调用约 0.2 秒。这两项覆盖不同区间：前者包含 UI 和驱动检查，不能直接归为磁盘读取或 TextKit 耗时。

在同一 Release 应用、同一原生 WindowGroup / 文稿驱动外部增加系统 `sample` 调用。只采样由当前检查器 `Popen` 创建的 PID，不扫描其他应用、不通过辅助功能观察窗口，也不修改生产应用。保持五次既有文稿循环、保留窗口转换时关闭另一空闲窗口、完整输出字节检查和最终关闭观察。

| 样本 | 启动事件 | 结束事件 | 采样请求 |
|---|---|---|---|
| import | `document_10mib-a_import_started` | `document_10mib-a_imported` | 5 秒，每 10ms |
| conversion | `document_10mib-a_conversion_started` | `document_10mib-a_exported` | 5 秒，每 10ms |

事件写入后到启动采样存在延迟。采样可能跨越阶段边界；报告保留采样返回时是否已经观察到结束事件。conversion 区间包含结果呈现与驱动验证，并不等于 C++ 执行时间。`sample` 是线程栈观察，等待栈的采样数量不能直接当作 CPU 占比。

## 执行

在 App Regression 手动工作流勾选 `profile_document_stages`。它选择已有 `--documents --active-anchor` 构建，并追加检查器参数：

```sh
python3 scripts/check-native-window-lifecycle.py --app /path/to/OpenCCman.app \
  --documents --active-anchor --profile-stages --output /new/report/directory
```

`--app` 仍仅允许 GitHub Actions 的 macOS runner 和精确诊断 bundle ID。本地只能读取已生成的 JSONL；这个新增参数不能用于本地启动应用。总进程期限仍为 660 秒，采样用时包含在内，不追加期限。没有修改依赖、最低系统、发布分支或正式应用配置。

## 证据与失败

artifact 的 `automatic/profiles/` 包含两份原始 sample、工具日志和 `capture.json`（PID、事件时间、请求间隔、工具耗时、退出码、sample SHA-256）。`automatic/result.json` 分别记录 `valid_protocol` 与 `valid_profile`。采样失败后仍在原截止时间内等待完整协议，保留文稿和原始日志；采样或协议任一失败，命令返回 4。工作流无论成功失败都尝试上传 artifact。

新增单元测试使用模拟进程与模拟采样文件，只证明采样控制、身份校验、截止时间与失败处理，不证明真实性能。实际云端采集和栈分析完成前，不据此宣称优化收益或归因。采样有额外开销，本次运行不能替代未采样的延迟基线。工具变更不改变界面；既有界面与交互证据见 #105，后续产品 UI 修复仍需独立的前后媒体。

参考：[Apple 响应性诊断](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)、[忙碌与等待的分析](https://developer.apple.com/tutorials/instruments/getting-started-with-hang-analysis)。先确定调用路径，再决定是否优化；如果等待栈不能解释延迟，继续采集调度证据，不凭样本猜测根因。
