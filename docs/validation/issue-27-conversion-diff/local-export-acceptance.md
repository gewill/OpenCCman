# #27 导出、分享与最小 Mac 窗口补验

日期：2026-11-01。#27 保持打开；本记录没有扩大容量、默认开关或快捷键范围，没有修改 App 实现。

## 合并与来源

- #312 squash `8ec39b3e971c3efed9976525f52a9e330c683902` 的原 push CI 被取消；重跑同一 SHA 的 [41255740534 / attempt 2](https://github.com/gewill/OpenCCman/actions/runs/41255740534) 后 App Regression 与 App icon 均成功。取消不计为通过。
- #316 HEAD `6abf99236f2894bd62a58694dfec48b3173bebcd` 的检查成功，复用该 HEAD 的需求／规范双路审核（各 0 项）；Squash 到 develop：`8ac87c596abe8d5fb7d15245408908655cf8de4a`。
- #316 合并后同一 SHA 的 [push CI 41260802482](https://github.com/gewill/OpenCCman/actions/runs/41260802482) 已完成，App Regression 与 App icon 均成功。
- 首次双端构建 `build-01` 来自干净的 `6abf992`；后续 `build-02-payload-report` 来自 `8ac87c5` 加本文工具修复的未提交 diff。两个提交之间 App 与 Xcode 工程内容相同。后续构建的主可执行文件及相邻 dylib 哈希逐项与实际运行构建一致。
- Apple M4 Pro / Mac16,7 / 48 GiB，macOS 27.2（26B123）；Xcode 27.1（27A9275），进程级 `/Applications/Xcode.app/Contents/Developer`。隔离 Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`，Debug、英语、台湾标准＋台湾词组。
- Mac 原生 Debug arm64+x86_64、iOS Simulator Debug arm64 两次均构建成功。命令、构建设置、来源 diff 与依赖锁保存在报告；未以工具层修复后的基线 SHA 冒充干净构建。

## 实际操作与逐字节核对

原始 110 字节 UTF-8 夹具（转义写法）：

```text
\ufeff鼠标里面的硅二极管坏了，导致光标分辨率降低。\r\n👩🏽‍💻 e\u0301\x00\rLine\u2028Next\u2029End\n
```

真实 OpenCC 输出首句为 `滑鼠裡面的矽二極體壞了，導致游標解析度降低。`。Mac 既有 `TextFileService` 导入逻辑移除开头 UTF-8 BOM；导出比较对象是导入后文本对应的转换结果，107 字节。iPhone 的模拟器剪贴板准备与 App 粘贴后也未保留开头 BOM，本轮不作为 BOM 保留路径证明。算法对 BOM 的既有独立回归与此导入边界分开记录。

| 场景 | 实际结果 |
| --- | --- |
| Mac 常用宽窗 100% | 导入夹具→转换→显示 3 处差异→导航→原生 Export TXT 保存面板→读回磁盘文件；全部 107 字节等于预期 |
| iPhone SE3 / iOS 18.6 / 375×667，默认字号 | 转换→差异导航→Export TXT→On My iPhone 保存→读回 File Provider Storage 实际文件；全部 107 字节等于预期 |
| iPhone Copy Result | 点击 App 复制按钮；只读 LLDB 将原生 UIPasteboard.string 编码为 UTF-8，完整 107 字节等于预期，包括 NUL 后内容 |
| iPhone 原生选择分享 | 长按结果的高亮替换词“滑鼠”→Share→系统 Copy，剪贴板为这两个字的 6 字节 UTF-8；无差异标记，没有发送到第三方 |
| Mac 最小 300×412 pt，150%／100% | 用户手动缩窗后，通过仅 QA 窗口录制器读取真实 frame；外层滚动到导航行，两档均 1/3→下一处 2/3→上一处 1/3；稿件未丢失 |

Mac/iPhone 导出与 iPhone 完整复制的统一 SHA-256：`f76f6f6d21a681b1ad311b8770dcb7a8ea0b96b0380ef65cda4af4737ad2549e`。比较覆盖 CRLF、CR、U+2028/2029、NUL、Emoji 与组合字符，不能只凭截图得出这些字节结论。

完成导航、导出／复制／分享后，只读读取原生编辑器内容并编码为 base64，分别与原文和结果字节比较。iPhone 两侧均匹配；Mac 完成两档最小窗口导航后两侧均匹配，选区均为 `{0, 3}`，对应第一处。最小窗口通过滚动分别查看两侧，不声称能同时显示完整两面板。

两个工具边界保留：`simctl pbpaste` 遇 NUL 截断，不能将其输出当作 App 剪贴板丢失；Mac CUA 点击虽返回 `AXError.failure`，后续计数及原生选区已改变，不盲目重放。最小窗口真实录像保留了动作与结果。

## 构建报告缺口与修复

本机旧 iPad Debug 04 与本轮新 iOS 构建的启动可执行文件哈希相同，`OpenCCman.debug.dylib` 哈希却不同。旧报告只记录启动文件不足以唯一绑定实际 App 代码。[Apple 的构建布局说明](https://developer.apple.com/documentation/xcode/understanding-build-product-layout-changes) 说明 Debug 可执行文件可作为加载 `.debug.dylib` 的启动壳。

`build-duo-validation.py` 现保留原有字段，新增 `app_code_sha256`：记录主可执行文件及同目录所有 `.dylib`，以 App 相对路径为键。这不是包含资源和所有嵌入 framework 的完整 bundle 清单，也不替代 source/diff/依赖锁记录。两种平台目录布局、相同启动壳但代码改变、无拆分 Release 文件与缺少可执行文件均有回归检查，并接入 App Regression。

实际运行代码载荷 SHA-256：

| 平台 | OpenCCman.debug.dylib |
| --- | --- |
| Mac | `f352db40b16e3bf0334cbde821f92c1cb6892be9fa6cc4d815dadb11caf9139f` |
| iOS Simulator | `efcb18d63df12f8222474c54490a98481d545d29d9c226225df259070b1cb23d` |

实际检查：`python3 Tests/Regression/DuoBuildChecks.py`：8 tests / OK；`bash scripts/check-project.sh`：`PASS: parsed 80 Swift sources and 6 localization files`；Ruby YAML parse：PASS；`git diff --check`：通过。App 源码未改变，没有将历史整套功能检查冒充本轮重跑。

## 证据与未验边界

外部证据根：`~/Library/Application Support/Codex/ui-evidence/OpenCCman/27-local-acceptance/6abf992/`，仅作为开发机索引，不作为远程图片链接。

- `build-01/report.json`、`build-02-payload-report/report.json`、`runtime-payload-sha256.json`、`stub-vs-code-evidence.json`：双端构建及代码载荷。
- `mac/export-verification.json`、`iphone/export-verification.json`、实际导出 TXT：磁盘内容证明。
- `iphone/native-copy-result.txt`、`native-editor-state.json`、`share-highlight-copy.txt`：原生完整复制、编辑器文本和选中词分享。
- `mac/minimum-*-record.log`、`minimum-native-state.json`、`minimum-100/150.mp4`、`minimum-100/150-result.png`：真实窗口尺寸、两档导航、原生正文与选区。
- 本轮只从 Shutdown 启动 iPhone QA `42C71610-575F-482E-A329-7637CD51D10F`，完成后停止录制与调试，终止 QA App，已读回 Shutdown；其余模拟器未启动。

本轮没有重测性能矩阵；没有验证 iCloud／第三方文件提供方、所有分享服务、iPad 的分享导出、iOS 实际输入法 marked text、VoiceOver 体验、最低系统、真机性能或签名分发包。分享选中词验证不能外推整篇分享。#27 继续打开，由这些独立验收补齐关闭标准。

远程证据已补至 [#27 本轮评论](https://github.com/gewill/OpenCCman/issues/27#issuecomment-6551867539)，PR 复用链接，没有重复上传。五个压缩副本全部完整解码；Mac 导出与 iPhone 分享在 QuickTime 完整播放，其余三段在隔离本地浏览器播放器从头播放到 ended，已检查画面可读性。15fps 副本只用于动作展示，不作为帧时证据；原件保留。附件下载 SHA-256 与本地副本逐项一致。

| 录像 | 上传副本 SHA-256 |
| --- | --- |
| [mac-export.mp4](https://github.com/user-attachments/assets/3bed291a-a901-45a2-bc05-d2237efd240e) | `734a78682ccae7ef0ed16f10acd7395cdc6567befe9d514c2d7201b403103836` |
| [iphone-export.mp4](https://github.com/user-attachments/assets/732bed6f-39c6-43da-a1ca-d041504954c6) | `de7ef1e0fc48d95783bac53360752357e333eb44af738e287cad462f94a14658` |
| [iphone-share.mp4](https://github.com/user-attachments/assets/75276cd9-5010-4ac5-a565-4a331171efb2) | `f7e7a4aff7ba287ff669a372981d94bfb0c914f922337e9bcd23bc6c4857ad7e` |
| [mac-minimum-100.mp4](https://github.com/user-attachments/assets/9dcbad35-ca3b-4899-a06a-6ff08c49b8f6) | `5e0c48498c11fd139e84df850d85f1c0b137a90447aee6c669d28101946a6b3c` |
| [mac-minimum-150.mp4](https://github.com/user-attachments/assets/c3b8ade5-4560-471e-9845-8ff6bd016df2) | `4b581e7e806821947a3ec2778475af7e5399475570f6b05e228623a307e6498d` |
