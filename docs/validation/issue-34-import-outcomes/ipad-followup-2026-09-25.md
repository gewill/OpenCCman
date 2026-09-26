# #34 iPad Files 选择补验（2026-09-25）

此记录是对 [先前未完成的 iPad 选择](ios-qa-2026-09-25.md) 的补验，不推断先前失败的原因。应用源码为 `develop` merge commit `059402962263e85f31d9ae00bd2caeccaa0aa011`。本轮只移除 XCUITest 的 iPad 跳过条件，未修改应用导入、What’s New 或文件权限代码。

## 环境与方法

- Xcode 27.0（27A266a）；专用 iPad Air 11-inch (M4) / iPadOS 26.5 Simulator `F3A87B05-3191-443D-8795-71C962563A59`；英语、浅色、普通文字大小、全屏竖屏。
- 隔离 Debug QA bundle `org.gewill.OpenCCman.WhatsNewUITests`，重装后只为它启用 Files 共享并在 Documents 放入 `success.txt`（UTF-8，CRLF、Emoji、组合字符）与 `bad-encoding.txt`（非法 UTF-8）。不修改正式 App 的 Info.plist 或已安装商店包。
- 诊断用例先确认 Files 中 `success.txt` 可点，单击后选择器消失、App 原文变为测试内容。随后删除临时诊断用例及两条测试的 iPad 跳过条件。
- 两条导入专项 2/2 通过；在**全新 DerivedData、关闭并行测试**后，完整 What’s New UI 套件执行 13 项：12 通过、0 失败、1 项仅支持 iOS 27 的 VoiceOver 用例跳过。再录制两条专项，2/2 通过。重用旧测试 Runner 的一次完整运行仍显示历史跳过条件，不计为新代码通过证据。

## 实际结果

成功导入：系统 Files 面板关闭后，导入任务期间卡片未覆盖工作区；任务完成后原稿替换为含 `測試導入` 和 Emoji 的文稿，先前结果清空，再显示一次 2.0 卡片。非法编码：已有草稿在系统面板及错误提示期间保留；卡片不覆盖错误提示，点击 OK 后显示一次。两个路径均由 XCUITest 的实际 UI 与 App 文本值断言，不把只看到文件项当作导入完成。

完整运行的 `.xcresult` 保留导入运行中、错误提示及随后卡片的真实 1640×2360 PNG；约 57 秒的连续 Simulator 录像覆盖两条专项。原始录制 SHA-256 为 `b850ecdabfcd9b729acd31905d12834bd7041e4f8cb9f57ef367886004472e40`，供 PR 上传的 820 px 宽 H.264 压缩副本为 `90a180273fc26fec89095efd1ed53260385133ee1ff71b82e009a62a51f5fca3`。截图和录像经 `gh` 上传至实现 PR，PR 记录对应源提交与运行日志。

## 边界

这证明所述隔离 Simulator 环境的当前 App 与测试用例通过；此前 Files 面板未关闭的原因未确定，不能推出系统选择器在所有 iPad 环境都可靠。尝试启动本机已有 iOS 15.5 Simulator 时，CoreSimulator 返回 `The iOS 15.5 simulator runtime is not supported on macOS 27.0`，故最低 iOS 15 运行验收未完成。真机、真实前台首次展示、VoiceOver 朗读顺序和签名 Xcode Cloud / TestFlight 包仍按 #34 及相关发布 Issue 验收。两秒 QA 延迟只用于观察状态顺序，不是导入吞吐量测量。
