# #27 iPad 全文分享复制补验

2026-11-06。补齐此前未完成的原生结果全文 Share → Copy 路径；不修改 App 代码。
**#27 保持打开，本记录不代替真机、性能、VoiceOver 或签名分发包验收。**

## 实际来源

- 源码 `fdb3798843469a7a3af538f17507c232fa36806d`，版本 2.2 (30)。
  复用 11 月 5 日构建的隔离包 `org.gewill.OpenCCman.TextActionQA20261105`。
  Xcode 27.1 (27A9275)、Debug、arm64、iOS Simulator SDK 27.1。
- 实际安装 App 的启动程序 SHA-256：
  `e5a2a24adb751d44a6f7b18a26597dff56a51cdde33eb00e32d8f118a940d1b6`；
  `OpenCCman.debug.dylib`：
  `0525bf9ccdf597d0f72bfa5e218766e892964b71b1bd4afc2fe3ba439762b603`。
- iPad A16 / iPadOS 27.0，UDID `737A20AC-4B6E-4B43-9C2D-0306F6266B6C`，
  820×1180 pt、英语、默认字号、左右布局。窗口大小由 UI 树确认。
- 本轮操作工具为 Xcode 27.2 (27B52) 的进程级工具链、AXe 1.8.0、
  sim-use 0.16.0。用户明确授权原生模拟器输入；没有改变全局 Xcode 选择。

## 操作与最终结果

原文：`鼠标里面的硅二极管坏了，导致光标分辨率降低。`

台湾标准＋台湾词组结果：`滑鼠裡面的矽二極體壞了，導致游標解析度降低。`
独立 OpenCC CLI `s2twp.json` 的结果与该预期逐字节一致。

1. 用 `sim-use paste --via-menu --replace` 经原生粘贴菜单写入原文；
   UI 树确认 Source 完整匹配。选台湾标准＋台湾词组，转换，打开差异。
   UI 树显示 `3 differences`，两侧预期文字一致。
2. 长按结果文字，用原生选区手柄拖到开头与结尾，再点编辑菜单的下一页、
   `Share…`。系统分享预览的完整 AX 文字与结果相同，截图显示选区覆盖全文。
   仅发送 ⌘A 未扩大选区，不作为全选通过证据。
3. 分享前用 `devicectl device pasteboard copy --device <UDID> --file <input.txt>`
   写入简体原文，再用 `simctl pbpaste` 读回，确认剪贴板是原文且不同于结果。
4. 在系统分享面板点 **Copy**，读回 **66 字节 UTF-8**，与完整结果逐字节相同。
   SHA-256：`a313a6e84253bdbb4db560280902af5ea80d9152ebe2bd23d44ea9f897b5f8c4`。
   没有差异标记，未发送给第三方。此夹具不含 NUL，不能外推 NUL 的分享行为。
5. 分享后重读两侧原生 TextArea：Source 与原文相同，Result 与转换预期相同。
6. 经原生粘贴菜单将原文替换为原文加“测试”：UI 树确认新原文、空 Result、
   Copy Result／Export TXT 禁用，显示
   `Convert again to view differences for the current text and settings.`。
   旧差异导航和计数不再显示。

## 输入与证据边界

本机 Device Hub 下，`simctl pbcopy` 曾退出 0 却未改变剪贴板，最初 App 粘贴按钮
读到的是上一项验收的台湾结果。这次准备不计入成功路径；改用会校验读回的
`sim-use paste` 后，UI 树确认了正确原文。分享前的哨兵则用上述 devicectl 写入并
独立读回，不能仅凭退出码判断写入成功。

证据在仓库外本机目录标识 `OpenCCman/27-full-share-20261106`，没有上传媒体：

- `installed-artifact.json`：实际安装包代码载荷及版本。
- `input.txt`、`expected.txt`、`share-before.txt`、`share-after.txt`、
  `full-share-verification.json`：原文、预期、分享前后字节与哈希。
- `pasted-ui.json`、`diff-ui.json`、`post-share-ui.json`、`invalidated-ui.json`：
  正确输入、三处差异、分享后正文不变和编辑失效。
- `full-result-share.png`：原生全文选区及系统分享面板。
- `cleanup-native.json`：恢复默认字号，终止 QA App 与本任务 sim-use daemon，
  指定 iPad 已读回 Shutdown；其他任务的两个 Booted 模拟器保留。

文档变更仅执行内容／链接核对和 `git diff --check`。本轮没有重新构建或跑历史
全套回归；没有重测 Mac、iPhone、窄窗导航矩阵、性能、输入法、最低系统、
VoiceOver、真机、签名分发包、iCloud／第三方文件提供方及其他分享服务。
这些项目仍以各自证据和未验清单为准，不能从这次短文全文分享通过外推。
