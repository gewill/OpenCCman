# macOS 沙盒文件面板验收

关联 #18、#93，接续 #103 的业务接口验收。本次通过真实系统 Open/Export 面板处理沙盒外文件，未修改产品代码、依赖、部署下限或发布分支。

## 产物与边界

2026-09-16，本机 macOS 27.0 (26A428)，Xcode 26.3 Release 诊断产物，源码 `1c6114efc94d769bceb63a4d637b7c828dff1874`。与父提交 `09e61b2dcbd0b836f5221651f7cba8e516cdabee` 的 `OpenCCman` / `OpenCCman.xcodeproj` diff 为空。使用真实 RootView、编辑器、转换、导入和导出实现；私有诊断 bundle 跳过购买 SDK、Services 和全局快捷键初始化，记录每秒弱模型状态。首次操作前关闭版本介绍卡。

复制现有产物后，以仓库 `OpenCCman.entitlements` 重新 ad-hoc 签名。提取出的权限字典与产品文件完全相等：App Sandbox、用户选定文件读写、网络客户端均为 true；`codesign --verify --deep --strict` 通过。**没有 Developer ID / App Store 分发签名或公证，不替代 TestFlight 文件权限验收。**

输入和输出位于独立工作区 `.build/file-panel/fixtures` / `exports`，均在诊断沙盒外。系统面板选择这些文件；没有通过诊断入口直接给应用写入文稿。输出通过独立 Python 读取后逐字节比较。

## 实际结果

固定语料沿用[历史清单](native-window-lifecycle/2026-09-15-documents/preparation.json)，显式 OpenCC 繁体预期，包含 BOM、CRLF、空行、中文、Emoji、组合字符和 NUL。

| 实际操作 | 结果 |
|---|---|
| Open 选择 1 MiB TXT → Convert → Export | `input-1mib-converted.txt`，1,048,573 字节，与固定预期完整一致，无 BOM |
| Open 选择 10 MiB TXT | 新原稿及文件名就绪，旧结果清空、导出禁用；转换后重新启用 |
| 10 MiB 转换后取消 Export | 没有新建文件，原稿和结果保留，额度为 2 |
| 再次 Export 到指定目录 | `input-10mib-converted.txt`，10,485,757 字节，完整一致；139,810 个 NUL、419,430 个 CRLF，无 BOM |
| Open 选择非法 UTF-8（5 字节） | 提示 “This file is not valid UTF-8. Save it as UTF-8 and try again.”；确认后保留 10 MiB 文件名和非空结果 |
| Open 选择 10 MiB + 1 字节文件 | 提示 “This text exceeds the 10 MiB import limit.”；确认后保留原稿和结果 |
| 取消 Open，再导出保留结果 | `input-10mib-preserved.txt` 与 10 MiB 固定预期完整一致，验证错误及取消后输出没有被替换 |
| 再次使用已有导出名称 | 系统显示同名 Replace 提示；取消覆盖、再取消 Export，原输出仍完整一致 |
| 最终独立读取隔离额度 | `2026-09-16: 2`；只有两次成功转换扣次 |

文件名扩展名由系统面板隐藏显示，但磁盘文件确实带 `.txt`。未测试点击 Replace 后实际覆盖；本次只验证系统重名提示及取消路径。`file-checks.jsonl` 中保留结果检查的 `quota_fields: {}` 是该次按名称筛选未取到额度，不代表额度为零；最终检查读取实际 `testNumbersPerDay` 并得到 2。

## 证据与复核

[2026-09-16 完整证据](native-file-panels/2026-09-16/)保存产物来源、签名信息、实际 entitlement、文件检查、完整合成输入/输出 ZIP、1,122 行原始诊断日志及恢复记录。日志不记录全文，也没有全部面板事件；面板动作由实际 UI 观察与视频证明。它包含 UI 自动化、录屏和人工等待开销，**不用于性能基线或泄漏结论**。

```bash
python3 docs/performance/native-file-panels/verify.py
```

复核器在 ZIP 内读取文件，不解压或写入用户目录；以历史固定 SHA 校验输入及预期，逐字节对照全部三份实际导出，并验证非法编码、超限样本及最终额度记录。校验通过不等于重新操作系统面板。

### 媒体

English / Light / 默认字号；主窗口图像约 900×450px，录制画布 1496×968px，仅目标应用，无音频、麦克风或鼠标指针。截图均来自实际视频帧，是同一源码的操作前后状态，不是 UI 设计变更对比。

- `import-1mib.mp4`：35.475 秒，从自有 fixtures 目录中选中输入开始，包含 Open、转换；不包含首次导航。
- `export-and-10mib.mp4`：450.160 秒，包含 1 MiB 保存、10 MiB 导入/转换、取消保存、再次保存和错误文件操作；含等待时间，到时自动结束，不表示全部后续动作已录完。
- `errors-cancel-and-preserved-export.mp4`：103.352 秒，从错误提示已关闭后的保留结果开始，包含取消 Open、另名导出保留结果、同名提示及取消。
- `10mib-imported.png` / `10mib-converted.png` 分别取第二段 90s / 150s，展示新稿清空旧结果及转换后系统保存面板；`system-replace.png` 取第三段 80s。

媒体已通过 `gh --attach` 上传至 [PR #104](https://github.com/gewill/OpenCCman/pull/104#issuecomment-5685972056)；[校验和与媒体参数](native-file-panels/2026-09-16/media.json)用于核对原文件。首次导航预检录像不发布，公开视频从自有合成文件目录开始。

| 导入后，旧结果清空 | 转换后，系统保存面板 |
|---|---|
| ![导入后](https://github.com/user-attachments/assets/f709ae51-b6bb-40ad-9dca-6fc221e70654) | ![转换后](https://github.com/user-attachments/assets/b0d4bf70-fdbf-4d2b-b0c5-5ac5f8486da5) |

[系统同名提示截图](https://github.com/user-attachments/assets/dda1b707-2e42-4d2f-b777-5944699bc0ee) · [1 MiB 导入视频](https://github.com/user-attachments/assets/5aa856f9-2f36-48fc-9bb8-81c16c8bfd16) · [保存及 10 MiB 视频](https://github.com/user-attachments/assets/0a0ba02e-8e72-441d-ae36-8f8ed91bdc4a) · [取消和保留结果视频](https://github.com/user-attachments/assets/208d5d6a-6ab8-4f48-9f3c-48343c047131)

### 恢复与剩余验收

PID 4355 已退出；原标准偏好逐键恢复一致。新建沙盒偏好域已清空，新增空 plist 已移除；保留 OS 创建的容器元数据和诊断 cache，未声称删除全部系统历史。应用已注销并移为 `.app.inactive`。VoiceOver 前后均关闭，未操作其他待验收应用或设备。

本次没有新增功能缺陷。仍需保留：分发签名/TestFlight 的系统文件访问，最低 iOS 14/macOS 11，iOS/iPadOS 文件面板，拖放及配对权限释放的独立证据，保留窗口自身正在转换时关闭另一窗口，Pro/跨日/临界额度，#19 实际系统入口，以及 #18 同条件性能定位。#93 不因本次文件面板通过而关闭。
