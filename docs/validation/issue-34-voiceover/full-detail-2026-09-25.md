# What’s New 卡片正文辅助功能补验（#34、#20；2026-09-25）

在产品源码 `cd8d00556b6b1134deafb0ea39f5a099c44f277a` 的隔离 Debug QA 包中，只增强 `testVoiceOverCardReadingOrder` 的断言，没有改应用 UI。环境为 Xcode 27.0（27A266a）、iPhone 18 Pro / iOS 27.0 专用 Simulator `89BB5D03-693E-447F-B614-B27952EADE06`、英语／浅色／常规字号。完整套件 14 项中 13 通过、1 项 iPad 专项跳过、0 失败，运行 239.950 秒；日志与 `.xcresult` 保存在 `/tmp/openccman-34-full-detail-20260925/`。

测试在界面辅助功能树中分别找到四张卡片的正文结尾：工作区的 “iPhone keeps a focused stacked layout.”、预设的 “Advanced options are still available.”、文件的 “to a location you choose.”、可靠性的 “unfinished conversions do not use your daily allowance.”。这些断言保证内容没有只暴露标题或前半段。既有 `XCUIVoiceOverService` 测试同时验证正反向导航顺序、标题前缀和反向移动后的 `currentSpeech()` 一致性。

本机该 API 对四张合并卡片返回的 `utterance` 长度均为 **64 字符**，短于原文段落；[Apple 文档](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice/output/utterance)只定义该属性为聚焦元素的语音输出，没有承诺可据此取得全文。本轮因此**没有**把辅助功能树完整等同于实际全文朗读。完整段落的声音验收、其他语言与系统、真机和最终签名包继续留在 #34／#20。

下列原始截图由同一 `.xcresult` 导出，再用 `gh issue comment --attach` 上传至 [#34 运行评论](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5828828685)。截图只能展示可见内容与焦点，不代表声音证据。

| 卡片页面 | 正向导航至 Done |
| --- | --- |
| ![卡片页面](https://github.com/user-attachments/assets/df00c570-b67f-4076-a021-a9b4d78c0cae) | ![Done 焦点](https://github.com/user-attachments/assets/7a1178f6-0526-431c-b6b5-ea53ae833f4b) |

同一候选在该专用模拟器上另行只跑 `testVoiceOverCardReadingOrder`，1/1 通过；[24.58 秒无音频的真实屏幕录像](https://github.com/user-attachments/assets/28c9fe0e-552e-451b-ad78-0abb1279913e)经 `gh` 上传至 [#34 交互评论](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5828859556)，SHA-256 为 `221afce37d023ce789f9b5cf2eaef10baf71dfb9ee5399bd094a0e54ed5ee1e0`。视频展示焦点移动，实际语音文字仍以测试日志为准。

测试脚本记录的运行前、测试后、恢复校验和最终设备读回均显示 VoiceOver **关闭**。本轮仅使用专用 QA bundle；正式安装版、用户文件和系统辅助功能状态均未修改。`git diff --check`、回归脚本检查也通过。
