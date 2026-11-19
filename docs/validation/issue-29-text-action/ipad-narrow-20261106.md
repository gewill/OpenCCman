# #29 iPad 窄窗口补验

2026-11-06。本轮补齐 11 月 5 日因输入工具受阻的窄窗路径；未修改 App 代码。
#29 保持打开，模拟器验证不替代真机与最终分发包验收。

## 来源与环境

- 源码：`fdb3798843469a7a3af538f17507c232fa36806d`，2.2 (30)。沿用前一记录的
  Xcode 27.1 (27A9275)、Debug arm64、SDK 27.1 模拟器构建，没有重新构建。
- 运行：iPad A16 / iPadOS 27.0，UDID `737A20AC-4B6E-4B43-9C2D-0306F6266B6C`。
  本轮工具通过进程级 `DEVELOPER_DIR` 使用 Xcode 27.2 (27B52)，不改全局选择。
- QA App：`org.gewill.OpenCCman.TextActionQA20261105`；扩展追加 `.TextAction`。
  实际安装的 App `.debug.dylib` SHA-256：
  `0525bf9ccdf597d0f72bfa5e218766e892964b71b1bd4afc2fe3ba439762b603`；
  扩展：`cd7bd40e8d07db5f32377b04723c65dba6a96169ce674981937f27f507e170b1`。
- 英语；系统字号 `large` 和 `extra-extra-extra-large`（XXXL，非无障碍字号）。
- Files 宿主窗口由 820×1180 缩到 **375×514 pt**，AX frame 和截图均确认。

## 输入工具边界

经用户批准退出 27.1 Device Hub GUI，保留 27.2 GUI及其他任务的模拟器。
单 GUI 下 CUA 点击／拖动仍未使内容响应。用户随后明确授权 AXe／sim-use。
AXe 1.8.0 的拖动成功缩窗及滚动；sim-use 0.16.0 的 native 坐标点按加
`--duration 0.1` 成功触发控件。AXe 的一次 physical Share 点按未生效，不能
将工具发送成功作为操作通过，更不能据此归因于 App。

窄窗 AX 坐标相对窗口；sim-use 提示无法确定 scene 原点，因此本轮用截图确认
屏幕位置后使用 native 坐标。扩展 UI 树有缺失，以截图与最终复制数据交叉核对。

## 实际步骤与结果

在 Files 分享以下 115 字节 UTF-8 测试文件，打开 Convert Chinese Text：

```text
鼠标里面的硅二极管坏了，导致光标分辨率降低。\r\n滑鼠裡面的軟體，著衣與衞生紙。\r\n
```

独立预期由本机 OpenCC CLI 的 `t2s.json`、`s2t.json`、`s2twp.json`、
`s2hk.json` 分别生成。通过实际点按切换预设、滚动 Form、点 Copy Result，
再用 `simctl pbpaste` 读回；此夹具不含 NUL，未使用该命令证明 NUL 保留。

| 场景 | 结果 |
| --- | --- |
| 默认字号 × 简体／繁体 OpenCC／台湾词组／香港 | 四次完整复制均与独立预期逐字节一致，各 115 字节、两个 CRLF |
| XXXL × 同上四个预设 | 四次完整复制均与独立预期逐字节一致，各 115 字节；长预设名换行，滚动后复制／分享完整可见且可点 |
| 默认字号，台湾，Share Result → 系统 Copy | 用 devicectl 写入原文并读回确认与结果不同，再点 Copy；读回完整 115 字节，等于台湾预期 |
| XXXL，台湾，Share Result → 系统 Copy | 同样确认操作前的原文哨兵；读回完整 115 字节，等于台湾预期 |
| XXXL，Done | 返回 Files；磁盘源文件逐字节不变，未被结果覆盖 |
| XXXL，重新打开扩展 | 台湾预设仍选中，证明选择保留 |
| XXXL，Cancel | 返回 Files 原文件分享面板；源文件逐字节不变 |

首次分享复制只用了 `simctl pbcopy` 写哨兵，后来发现该命令退出 0 却未改变
Device Hub 下的剪贴板，所以首次结果不足以排除旧值，不计为通过。
改用 `devicectl device pasteboard copy --device <UDID> --file <input.txt>`，
立即以 `simctl pbpaste` 读回确认后，重新完成上述两种字号的分享复制。
两次最终输出 SHA-256 均为
`c2b9d3c9b340d1aa119603fdfe518dae1b19075582c6e3e0f4713e361f40322c`。
有效证据为 `share-retest-{default,xxxl}-{before,after}.txt` 和
`share-retest-results.json`；保留首次无效哨兵记录，避免混用。

XXXL 导航栏标题按系统行为截断，Cancel、Done 均完整显示。
额度未做运行前后读值；沿用既有逻辑回归，不能以本轮界面操作声称额度已重验。

## 证据与边界

仓库外本机目录标识：`OpenCCman/29-ipad-action-20261106`。保留实际安装产物
哈希、初始模拟器状态、375×514 AX 树、默认／XXXL 关键画面、输入／独立预期／
八份复制输出、两份系统分享复制输出及逐字节比较 JSON。不是远程附件链接，未上传。

本次不重跑历史全套检查或 App 构建；只更新文档并执行 `git diff --check`。
仍未验证：真机、iOS 15、VoiceOver 体验、最终分发签名包、第三方宿主实际应用
回传结果，以及窄窗下 10 MiB 负载。既有大文件与容量记录保持原来源和范围。
