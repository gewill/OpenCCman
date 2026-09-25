# #34：2.0 卡片的双向 VoiceOver 导航

2026-09-25 基于 `develop` 应用源码 `40a4e33b72976bf2e42860a5d9c8fe007e110825` 补验。此 PR 只修改隔离 XCUITest、测试后的 VoiceOver 恢复脚本和记录，不改应用视图。环境是 Xcode 27.0（27A266a）、专用 iPhone 18 Pro / iOS 27.0 Simulator `89BB5D03-693E-447F-B614-B27952EADE06`、英语、浅色、标准字号、隔离 Debug bundle `org.gewill.OpenCCman.WhatsNewUITests`。正式应用与物理手机未安装或修改。

`bash scripts/check-whats-new-ui.sh 89BB5D03-693E-447F-B614-B27952EADE06 /tmp/openccman-34-voiceover-bidirectional-fixed-20260925` 在当前源码上完成：14 项中 13 项通过、1 项 iPad 专项按平台跳过、0 失败。测试从标题、版本、四张卡片依次到达 Done，再逐项反向返回标题。反向移动后 `currentSpeech()` 与该次移动的朗读一致。正向标题为 “OpenCCman What’s New Heading”，反向标题为 “What’s New Heading”；因此分别检查对应朗读，不把系统省略应用名前缀误判成阅读顺序缺陷。Apple 的 [`XCUIVoiceOverService`](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice) 提供了本次使用的正反向移动与当前朗读接口。

一次更严格的标题前缀断言失败时，XCTest 完成失败记录后，模拟器 VoiceOver 仍为开启状态。已立即关闭并读回。测试现于 teardown 恢复原状态；运行脚本另在退出时独立读回和恢复，恢复失败会使脚本失败。修正后的完整运行记录 `voiceover-before.json`、`voiceover-after-test.json` 和 `voiceover-restored.json` 均为 `enabled: false`，末次 `devicectl device info voiceover` 也读回关闭。此前失败日志保留在 `/tmp/openccman-34-voiceover-bidirectional-20260925/`，不计作通过。

[Issue #34 证据评论](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5828365977) 附同一 `.xcresult` 导出的 [正向 Done 焦点截图](https://github.com/user-attachments/assets/43eba948-9069-4842-99e2-02610e86e940)、[反向标题焦点截图](https://github.com/user-attachments/assets/f63c33aa-404c-47bb-918c-2800b142a6ed)及[19.49 秒无声交互录像](https://github.com/user-attachments/assets/7b47fd66-a8a1-4635-a6d0-898023537121)。截图为 1206×2622 像素；录像 SHA-256 为 `a56dcc317b5d33a6d83ac8a2688c4ad4b7ab1a55887a0716`。录像显示焦点移动，朗读文本以 `ui-tests.log` 中 `VOICEOVER_UTTERANCES` / `VOICEOVER_REVERSE_UTTERANCES` 和测试断言为准。完整 `.xcresult`、构建日志和原始媒体留在上述 `/tmp` 目录。

这证明当前源码在该模拟器上的双向元素顺序；不证明卡片正文被完整朗读、其他语言／系统、真机或签名 TestFlight 包。物理 iPhone 本次显示已配对且隔离 QA 包仍在，但 iPhone Mirroring 两次超时，`devicectl` 截图在连接后断开，未取得新的真机结果。#34 保持开放，其他弹窗和发布前条件按 Issue 原清单继续验收。
