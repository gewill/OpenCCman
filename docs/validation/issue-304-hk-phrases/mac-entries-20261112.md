# #304：Mac 各入口实测

2026-11-12，macOS 27.2。用 develop `0ac4790`（#338 合入后，App 代码与 `e33640e` 相同）构建独立的 QA 包，在 Mac 上实际运行 `s2hkp`、`hk2sp` 的编辑器、服务、全局快捷键、大文件和批量入口，18 项输出全部与预期逐字节一致。同一个包还补录了 #303 的 Mac 切换录像。

## 测试包与环境

- `git archive` 导出干净源码，Xcode 27.2（27B52），arm64 Debug，`CODE_SIGNING_ALLOWED=NO`，锁定 `Package.resolved`。
- 复制产物后改 Bundle ID 为 `org.gewill.OpenCCman.MacEntries20261112`、服务名为 `OpenCCman 304 QA Convert`／`OpenCCman 304 QA Open`、端口为 `OpenCCman 304 QA`，再用仓库的 sandbox entitlement ad-hoc 签名。这样不会和正式 App 或以前的 QA 包共用设置和服务登记。
- 版本 2.2(30)，`OpenCCman.debug.dylib` SHA-256 `0f87a1944ab63b6f9c80a8c7a61d7bc12cf8b3a821ae184daa9d5ca3db9678f3`。
- 简体中文界面，文字大小 100%，窗口 1440×880。`-isPro YES` 只用于放开大文件和批量的 Pro 资格，不代表购买。
- 转换设置都在界面上点选，写入 QA 自己的偏好。服务和全局快捷键读到的就是这份设置。
- 全局快捷键改为 ⌃⌥⇧⌘T／⌃⌥⇧⌘R，避开默认的 ⌥⌘T／⌥⌘R。辅助功能权限由维护者在系统设置中临时开启。

## 样例与预期

| 配置 | 原文 | 预期输出 |
| --- | --- | --- |
| `s2hkp`（繁体，香港标准 + 香港模式） | 鼠标里面的软件和打印机，用的是信息技术。 | 滑鼠裏面的軟件和打印機，用的是信息技術。 |
| `hk2sp`（简体，原文香港标准 + 香港模式） | 滑鼠裡面的軟體，著衣與衞生紙。 | 鼠标里面的软体，著衣与卫生纸。 |

- **短样例**：末尾带 CRLF，分别为 62、47 字节。预期由 OpenCC 1.4.2 命令行生成。
- **大文件**：把短样例分别重复 186,000、245,412 次，得到 11,532,000、11,534,364 字节，超过工作区的 10 MiB 上限。
- **批量**：每种配置两个文件，一个是样例本身，另一个是样例重复 1000 次。
- **大文件和批量的预期**：对整份输入调用一次 `opencc_convert_utf8`，再与短行结果重复拼接互相核对。命令行的文件模式在 `hk2sp` 大文件上与整篇结果差 6 字节，与 [#303 记录的 `tw2sp` 现象](../issue-303-simplified-source/mac-entry-acceptance-20261105.md)相同，所以不用它。

## 结果

| 入口 | 做法 | `s2hkp` | `hk2sp` |
| --- | --- | --- | --- |
| 编辑器 | 「粘贴文本」后转换；读结果框，再点「复制结果」读剪贴板 | 两路都一致 | 两路都一致 |
| 服务（API） | `NSPerformService("OpenCCman 304 QA Convert")` | 一致 | 一致 |
| 服务（菜单） | TextEdit 全选，TextEdit › Services › OpenCCman 304 QA Convert | 原位替换一致，⌘Z 恢复原文 | 同左 |
| 全局快捷键 | TextEdit 全选后按 ⌃⌥⇧⌘T；读 QA 结果框和「复制结果」 | 一致；QA 原文等于选中文字，TextEdit 原文不变 | 同左 |
| 大文件 | 「导入 TXT」，选择保存位置后转换并保存 | 11,532,000 字节一致 | 11,534,364 字节一致 |
| 批量 | 文件 › 批量转换 TXT 文件…，选两个文件和输出文件夹 | 成功 2 个，都一致 | 成功 2 个，都一致 |

- 大文件任务面板的摘要是「繁體中文 · 香港标准 · 香港模式」「简体中文 · 原文为香港标准 · 香港模式」，批量面板相同。
- 服务和全局快捷键调用后，QA 窗口切到前台，显示这次的原文和结果。
- 全局快捷键每次按键都有一条 `Sandbox: OpenCCman(33492) deny(1) mach-lookup com.apple.axserver`，所以只在 QA 中显示结果，不原位替换。这与 [#303 的独立 QA 复验](../issue-303-simplified-source/hotkey-isolation-20261107.md)和 #333 的说明一致。
- 全局快捷键读选中文字时借用了剪贴板，事后恢复为按键前的内容。
- 结构化结果（含完整 SHA-256）见 [mac-entries-results-20261112.json](mac-entries-results-20261112.json)。

## #303 的 Mac 切换录像

- 用同一测试包，目标选简体，依次切到 OpenCC 标准、台湾标准、台湾模式、香港标准（香港模式）、不转换，每次切换后重新转换。
- 结果依次为 `t2s`、`tw2s`、`tw2sp`、`hk2sp`、`hk2s`，都与命令行一致。
- 每次改设置后，结果上方出现「设置已更改。此结果使用上次转换时的设置。」。
- 录像见 [#303 评论](https://github.com/gewill/OpenCCman/issues/303#issuecomment-6815878576)。

## 观察

- SwiftUI 的「导入 TXT」面板只在 App 位于前台时弹出；批量和保存位置用的 AppKit 面板，在后台也会弹出。
- 有一次无效尝试，没有计入结果：
  - 当时 TextEdit 的全选没生效，选区为空，而且剪贴板约 0.5 秒前刚写入一段标记文本。
  - 按快捷键后，QA 把这段标记文本当作选中文字转换了。
  - 让剪贴板静置 5 秒后，在空选区再按一次，QA 正确提示「未选择文本」。
  - 原因未定位，可能是写入后有其他程序紧接着改动了剪贴板。

## 收尾与证据

- 前台操作约 9 分钟，每次发送按键前都核对前台 App。
- TextEdit 测试前没有运行，测试中只打开样例副本，结束后退出。剪贴板测试前整体备份，结束后恢复。
- QA 已退出。QA 包与构建产物的 LaunchServices 登记已注销，`pbs -dump_pboard` 中没有残留。
- 辅助功能权限要在系统设置中移除，QA 容器要在访达中删除。
- 原始输出、AX 快照、日志、脚本和 QA 包的压缩件，保存在本机证据目录 `~/Library/Application Support/Codex/ui-evidence/OpenCCman/304-mac-entries-20261112/`。
- 结果发在 [#304 评论](https://github.com/gewill/OpenCCman/issues/304#issuecomment-6815889796)。

## 未验证

- VoiceOver 体验未验证。
- App Store 真实升级与最终签名包没有运行；macOS 12 最低系统没有运行，转 #16。
- 没有测浏览器输入框、Electron、终端等其他宿主，也没有用物理按键或服务键盘快捷键运行这两种配置。
