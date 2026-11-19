# #350 AppKit 只读选文转换回退

2026-11-19 在 macOS 27.2.1（26B131）、Xcode 27.2 上对照 develop 基线 f4674a67 与本提交。实测使用开发签名、开启 App Sandbox 的独立 QA 包（org.gewill.OpenCCman.AppKit350Validation，2.3 build 30），宿主为独立进程内的 AppKit NSTextView。

## 复现与回归

在只读宿主选中带场景标识的「鼠标」，触发 QA 专用转换快捷键。基线宿主收到两次复制、一次粘贴，仍选中原文，主窗口的原文与结果均为空。独立的事务对照中，让宿主忽略粘贴，另一个读取方取得转换文本，旧实现即返回 pasted。剪贴板提供方无法识别读取者，无法据此确定历史现场具体是哪一进程读取。

修复后，在允许自动粘贴且仍可安全检查时，恢复原剪贴板并再复制一次。仍能复制到原选文时，将本次原文和结果送入主窗口。整次只发送一次粘贴。用户中途输入、切换应用或另行复制时，沿用已有保护。

| 场景 | 实际结果 |
| --- | --- |
| 主窗口已打开 | 两个面板分别读回本次标识和「鼠标」「鼠標」 |
| 主窗口已最小化 | 解除最小化，两个面板读回本次原文和结果 |
| 应用已隐藏 | 解除隐藏，两个面板读回本次原文和结果 |
| 主窗口已关闭 | 从零个工作区窗口恢复为一个可见窗口，两个面板读回本次原文和结果 |
| 宿主可编辑 | 宿主文本变为「AppKit350-editable 鼠標」，选区长度变为零，焦点留在宿主，QA 面板保留上一组内容 |

四组只读场景均记录到复制、复制、粘贴、复制，最后一次复制仍有原选区。可编辑宿主成功粘贴后，末次复制可能触发系统提示音，按本轮产品决定接受。本次未采集声音，也未在 TextEdit、浏览器、最低支持系统或发行签名包上重新点验。

## 可重跑的检查与证据

- `bash scripts/check-shortcut-transaction.sh` 通过，覆盖独立读取方掩盖拒绝粘贴、可编辑宿主替换、剪贴板恢复及中途输入取消。
- `bash scripts/check-control-labels.sh`、`python3 scripts/check-app-language.py` 均输出 PASS。
- 按 docs/CI.md 参数构建 macOS Debug 与 iOS Simulator Debug，两端均输出 BUILD SUCCEEDED。iOS 本轮仅构建。
- 本机原始证据目录为 `~/Library/Application Support/Codex/ui-evidence/OpenCCman/350-appkit-20261119-193327/`。baseline-transaction.log 与 baseline-ui.log 为基线，fixed-*.log 记录五组修复后结果，SelectionFixture.swift 是隔离宿主源码。revocation.txt 记录撤权成功，系统设置中已复核 QA 项消失。
