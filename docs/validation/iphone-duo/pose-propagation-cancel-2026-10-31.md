# 方向请求丢失的 guest 内部定位，以及开合期间实际 Cancel（2026-10-31）

#298 已 Squash 合入 develop：`81b1baf8cf21b8e339a90a2b625a60bd32cc4b74`。
[精确合并提交 push CI](https://github.com/gewill/OpenCCman/actions/runs/41178598114) App Regression SUCCESS。
本轮从干净的 `codex/282-vertical-request-root-cause`（基于上述提交）开始，只补证据：
未修改产品代码、工程、依赖、方向 mask、已安装的 sim-use 或生产功能开关，未打包、分发或部署。

[机器索引](pose-propagation-cancel-2026-10-31.json)保留命令、原件 SHA、分类统计、诊断源码和离线校验脚本。
App tree `a9bc63c6f8f6ea12ea3b497c5528cb4bf35a0637`、工程 tree `44b0dad8d0d71e3912dea0f65eb1fe4a6e2ac495`
与上轮相同，复用 Debug QA 2.1(30)（SDK27.1、Xcode27.1 27A9275），已安装 dylib SHA-256
`a28c756e35b1e7e54b8160e3e50ca77b6531518340d516cb45c424a04d7e2bd3` 本轮重新读取。
宿主控制工具：进程级 Xcode27.2(27B52)、sim-use0.16.0、AXe1.8.0；隔离 Duo iOS27.1(24A94425)，
UDID `4CAD3041-0744-41A6-8B4E-F934CA9F0778`，初始 Shutdown，没有其他 Booted 设备。

## 方向：报告已进入 guest，界面更新在 SpringBoard 内被跳过

独立 UIKit 探针 `org.gewill.OpenCCman.OrientationInputQA`（mask26，不含 OpenCCman 业务）。
每组依次执行 open → 内屏 portrait → half → closed → 外屏 portrait，遇到第一次未确认即停止，
再做「同值重发 → 换值 → 原值」的对照。同时用 `simctl spawn … log stream` 抓取 guest 日志。

| 轮次 | 结果 |
|---|---|
| run1 | 8组、16次旋转全部确认 |
| run2 | 第3组内屏 portrait 未确认；同值重发仍未确认；landscape-left 再 portrait 恢复 |
| run3（抓取 SpringBoard 全部日志） | 第1组外屏 portrait 未确认；对照结果同 run2 |

日志给出的链路：宿主 vendor HID 报告 → dtuhidd `avpCustom(0x500)` 挂起并派发 →
SpringBoard 内的 CoreMotion `CLDeviceStateNotifier` → `CMMagicPoseEvent` →
`DevicePose` 按外屏/内屏比较方向 → `DeviceOrientationUpdateDeferral` 更新界面方向。

两次失败的共同特征：

- 报告已送达，CoreMotion 发出了 MagicPose，`DevicePose` 打出了 `surface orientation changed`。
- 但两块屏幕都**没有**出现 `DeviceOrientationUpdateDeferral … Device pose changed`，界面方向未更新。
- 这次的值并没有在 `DevicePose` 中生效：run2 随后发出的 portrait 没有产生变化日志，接着的原值显示 `Po -> Ll`；
  run3 随后发出的值显示 `cover Ll -> Lr`，起点都是失败前的旧值。
- CoreMotion 已经记下新值，所以同值重发全部被它自己跳过：
  `New event is identical to previous event, skipping!`（run2 3次，run3 失败后3次）。
  换成不同的值会让 CoreMotion 和 `DevicePose` 重新比较，原值随之得以生效。

这解释了此前「同值无效、换值恢复、等待也不恢复」的现象，而且外屏、内屏都会发生。
只看方向变化（不含开合）的事件：共 25 次，丢 2 次，这 2 次都在同一毫秒内伴随
`Transition style .fade -> .continuousSnapshot`；但出现同样切换的另外 18 次都正常更新。
因此只能算相关条件，**SpringBoard 为什么跳过更新仍未证明**，也不能估计失败率。
开合事件通过显示切换的延迟释放来更新方向，不计为丢失。

对产品的影响：独立探针可以复现，问题位于 iOS 27.1 模拟器 runtime 的 SpringBoard 和 CoreMotion 内部，
不在 OpenCCman、传输层或 sim-use 的数值换算中。没有改方向 mask，也没有加入盲重试。
自动化如需恢复，应先发一个不同的值再发目标值，并记录为工具绕行，不能当作产品通过。
真机 Duo 是否存在同样的问题未验证。

## 普通任务：受控等待期间开合后实际按下 Cancel

英语、系统默认字号，启动参数 `-qa-delay-conversion`，在实际转换前等待 2 秒
（[HomeViewModel.swift:265–279](https://github.com/gewill/OpenCCman/blob/81b1baf8cf21b8e339a90a2b625a60bd32cc4b74/OpenCCman/Scene/HomeViewModel.swift#L265-L279)）。
因此本节证明的是等待状态下的取消，**不代表自然慢 I/O 或转换器内部执行期间的取消**。
开合报告由 vendor 常驻连接发送，每个用例一条；点按用 sim-use `tap --id workspace-convert`，按显示屏路由。

| 用例 | 实际结果 |
|---|---|
| C1 内屏首次转换 → 闭合 → 外屏竖向栏 Cancel | 外屏窗口 466×678 仍为 busy 时按下；原稿保留，结果为空，立即恢复唯一的 Convert，Export 禁用；等待 3 秒后仍无结果；额度即时与延迟读数均为 8 |
| C2 外屏已有结果再转换 → 展开 → 内屏竖向栏 Cancel | 内屏窗口 951×669 仍为 busy 时按下；原稿保留，结果为空，恢复 Convert；按设计显示「上次成功结果仍可导出」且 Export 可用（[WorkspaceComponents.swift:254–262](https://github.com/gewill/OpenCCman/blob/81b1baf8cf21b8e339a90a2b625a60bd32cc4b74/OpenCCman/View/WorkspaceComponents.swift#L254-L262)）；额度保持 9 |

C2 之前做了一次真实转换：plist 即时读数为 8，4 秒后为 9。这是延迟落盘，不能把即时磁盘值当作 App 内的额度。
取消后的结果与「点到 Convert」不可能同时成立：后者会让按钮变成 Cancel、随后出现结果，并且额度加 1。

| 外屏 Cancel 后 | 内屏 Cancel 后 |
|---|---|
| ![外屏取消后](https://github.com/user-attachments/assets/eefe3933-61ea-497a-ad90-8c4240b15831) | ![内屏取消后](https://github.com/user-attachments/assets/229c3bfe-44d5-463c-87b0-b1e4b12691fe) |

[C1 视频](https://github.com/user-attachments/assets/7b38791a-6c83-4c60-a788-5f787b273084) /
[C2 视频](https://github.com/user-attachments/assets/ec722234-4425-4d70-a56b-1ebc8dd4b9fe)：
只录目标屏，已按内容方向转正并压缩；C1 开头约 1.2 秒黑帧是目标屏尚未激活。
外屏截图只显示原稿区，结果为空由 AX 核对。4 个附件均已从远端下载，SHA-256 与本地副本一致。

#280 增量：外屏和内屏的竖向栏 Cancel 都实际执行过一次，执行后恢复 Convert；未借此宣称溢出或全部路由已通过。

## 失败尝试与读数干扰

- 第一次尝试用 `sim-use fold` 开合，耗时约 2.3 秒，2 秒等待已经结束，第二次点按变成了一次新的真实转换。
  额度 3→5、6→8 都是两次成功转换各计一次，不是取消结果，不计为通过。
- 第二次尝试因脚本比较了 tuple 和 list，在任何点按之前就中止。
- 第三次尝试用 axe 坐标点按，内屏活动时点到了主显示屏（外屏），没有开始转换。
- 三次尝试的原件都留在索引的 `cancel/attempt*` 下。

## 复跑、收尾与未验证

离线核对：在 JSON 的 evidence_root 执行
`python3 verify-pose-cancel.py <仓库>/docs/validation/iphone-duo/pose-propagation-cancel-2026-10-31.json`（只读）。
复跑须使用独立的 QA 构建和指定 UDID，换新的输出目录，不覆盖历史原件；guest 日志时间为 +08:00。
诊断流程有上限（每轮最多12组/420秒），设 12 GiB 磁盘保护，不重启共享服务。

本任务只启动了上述隔离 UDID。日志流、录像和 vendor 连接全部结束、保存日志后，关闭该设备并复读到 Shutdown，
没有其他 Booted 设备。

SpringBoard 丢更新的具体原因、自然慢 I/O 与转换器执行、实际导出文件、完整姿态/三语/XXXL/溢出矩阵、
左右分屏、连续尺寸、IME/阅读位置、What's New/Customer Center/冷启动、最终签名包与 Duo 真机仍未通过；
VoiceOver 体验未验证。交易、最低系统、大文件仍沿用原 Issue。#280/#282 保持开放，不更新历史46项盘点。

[远端 #282 证据](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6540649950)。
