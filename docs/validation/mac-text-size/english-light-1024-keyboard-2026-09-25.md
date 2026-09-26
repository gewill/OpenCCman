# Mac 英语浅色大字号与键盘补验（#191 / #57）

2026-09-25 从 `develop` `fc5a901d76e88109547397704e9037a7d9cefa05` 构建 Debug Mac App，复制为独立 `org.gewill.OpenCCman.TextSizeKeyboardQA20260925`，移除副本的 `NSServices`，保留沙盒和用户选定文件读写 entitlement，再以 ad-hoc 签名。`codesign --verify --deep --strict` 通过；没有运行正式分发包。系统为 macOS 27.0，Xcode 27.0 (27A266a)，仅内建 Liquid Retina XDR 显示器。CGWindow 读回 QA 主窗口为 **1024×768 pt**。

应用内为英语、浅色。100% 时用默认示例中文成功转换；随后在同一窗口依次选择 125% 和 150%。三个档位的设置单选状态均由实际 AX 状态确认。各档返回工作区后，原文仍为 `鼠标里面的硅二极管坏了，导致光标分辨率降低。`，结果仍为 `鼠標裏面的硅二極管壞了，導致光標分辨率降低。`，复制及导出入口启用。窗口尺寸始终为 1024×768 pt。

150% 时，⌘⌥2 切到上下布局、⌘⌥1 回到左右布局；原文和结果未丢失。⌘⌥I 打开转换配置 sheet，Esc 关闭。从原文编辑器按 Control-Tab 后，AX 焦点到结果编辑器。导出和导入系统面板分别能打开并取消，返回工作区后结果仍在。导入面板没有选择真实文件；不把面板打开等同导入成功。

[Issue #57 补验评论](https://github.com/gewill/OpenCCman/issues/57#issuecomment-5826557413)附同条件真实截图和两段无音轨、仅 QA 窗口的录像。录像分别展示 100%→125% 设置操作与 150% 布局快捷键；125%→150% 由设置单选状态与 150% 截图证实，不在第一段录像内。

| 附件 | SHA-256 |
| --- | --- |
| 100% 截图 | `2a098f91d3f95c1a8d2d265f59cd6039e5fafee4e852b9be5f3739a84a4b5f1c` |
| 125% 截图 | `2d6a04498025cbfb04e6943579544975595d00bcf04a4fe3bbd00eaaf061ba56` |
| 150% 截图 | `5b652c477e25e0900640b394c0320249a31f9863073a3c9c7a0d1019c570ce21` |
| 字号操作录像 | `97c8055bcd1b445d375c0248c60fb352099f03fbabddd7cd21952cca6b8686f8` |
| 布局快捷键录像 | `26274aba389a5516bf409d175828e4ff8b11ebe2fbdc038840d111eb6248a5f1` |

同一源码的 macOS Debug 构建成功。`bash scripts/check-window-sizing.sh` 与 `scripts/check-workspace-editor.sh` 均通过；后者含 1 MiB／10 MiB 无窗口编辑器夹具，**不是**完整 App 的大文件响应时间或输入法验收。

本次补齐英语／浅色推荐窗口的一部分和明确的键盘路径，没有覆盖三语言、浅深色、推荐／最小窗口的完整组合、实际输入法标记文字、完整焦点顺序、Mac VoiceOver 或正式签名包。`system_profiler SPDisplaysDataType` 只列出内建显示器，#57 的真实外接屏断开／重连未执行；合成几何检查不代替物理拔插。#191 与 #57 均保持开放。
