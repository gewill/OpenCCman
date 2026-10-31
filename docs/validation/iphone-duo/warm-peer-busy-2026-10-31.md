# 预热连接对照与普通任务受控等待验收（2026-10-31）

#297 已 Squash 合入 develop：`07c2b81ab73e8fa29c4f99ce27f5cecf7892ec98`，父提交
`0d5a6e5ce88d95d8e582ebbad000248bd37df34e`。被审 HEAD `8239cf8` 和 squash tree 相同
（`1289c556eeff0470e9399bd496dda1b8fa0f9b6c`）。[精确合并提交 push CI](https://github.com/gewill/OpenCCman/actions/runs/41171061706)
SUCCESS；[合并核对](https://github.com/gewill/OpenCCman/pull/297#issuecomment-6539455602)含审核回链。
本轮只补证据，未修改产品代码、工程、依赖、方向 mask、已安装 sim-use 或生产功能开关，未打包分发/部署。

[机器索引和诊断源码](warm-peer-busy-2026-10-31.json)保留命令、原件 SHA、全文校验、trace、
实际构建身份、宿主 helper 源码及 Apache-2.0/NOTICE。相对上轮产品树/工程树未变，复用同一
Debug QA 2.1(30)：SDK27.1、Xcode27.1(27A9275)；dylib SHA-256
`a28c756e35b1e7e54b8160e3e50ca77b6531518340d516cb45c424a04d7e2bd3` 本轮重新读取确认。
宿主命令使用进程级 Xcode27.2(27B52)、devicectl651.32、sim-use0.16.0、AXe1.8.0；
隔离 Duo iOS27.1(24A94425)，UDID `4CAD3041-0744-41A6-8B4E-F934CA9F0778`。
未将宿主 Xcode27.2 写为产品构建工具链。

## 方向对照：预热连接仍不能直接恢复

独立 UIKit 探针、mask26，无 OpenCCman 业务参与。最多6组/180秒、首个 confirmed=false 即停；
实际7条命令/30.08秒，在第2组 inner portrait 失败。随后14次纯官方读取，仍 active3/rot90、未锁方向。

任务专用 vendor XPC 连接先完成**空 barrier**，等待2秒，然后始终在同一连接发送下表4条报告。
ready 只表示宿主完成该准备，barrier只表示回执，不代表guest消费。每条之后观察3秒，无自动重试。

| 步骤 | 原始值 | 原生显示/探针实际结果 | 日志 |
|---|---|---|---|
| 连接前/预热但尚未发报告 | 无 | rot90 / interface4 / 951×669 | 累计106，进程event21 |
| 原请求 | landscape-left，内屏竖向映射 | 不变 | 不变 |
| 预定同值对照一次 | landscape-left | 不变 | 不变 |
| 改值但对应当前横向 | portrait | 不变，未经过可见中间旋转 | 不变 |
| 再发原请求 | landscape-left | rot0 / interface1 / 669×951 | 累计109，进程event24 |

预热/保持连接仍不足以恢复；**可见的中间旋转不是本次恢复的必要条件**。
值变化经过输入链路后原请求恢复，支持继续调查输入值处理/链路状态；并未证明内部去重、具体丢弃组件或永久修复。
探针的 UIDevice.orientation、interfaceOrientation 与 CoreDevice 方向使用不同参照，不混写为同一数值。
当前仅覆盖内屏失败，本轮不补写外屏失败已修复。宿主私有API helper只在归属明确的隔离模拟器诊断，未进入产品或系统工具。

![探针最终实际竖向](https://github.com/user-attachments/assets/b92f2442-3d94-491e-a42a-6c792b41b694)

[完整方向预览](https://github.com/user-attachments/assets/7d7d4651-fdf4-4491-aeb6-24c9d8862cbc)：固定初始画布，最后竖向内容侧转，以截图/原生读数判方向；
源18.365秒，压缩预览19.8秒，包含片尾静帧停留，不用于动画/时序分析。原视频和报告时戳保留。

## 普通任务：仅受控 QA 等待期间的连续性

英语/系统large默认字号。使用已有 `-qa-delay-import` / `-qa-delay-conversion`，
源码 [HomeViewModel.swift:267–279](https://github.com/gewill/OpenCCman/blob/07c2b81ab73e8fa29c4f99ce27f5cecf7892ec98/OpenCCman/Scene/HomeViewModel.swift#L267-L279)
与 [368–379](https://github.com/gewill/OpenCCman/blob/07c2b81ab73e8fa29c4f99ce27f5cecf7892ec98/OpenCCman/Scene/HomeViewModel.swift#L368-L379)
在实际转换/读取前等待2秒。因此这里证明任务所有权/等待状态跨开合保持，**不代表自然慢I/O或实际转换器内部执行中的完整验收**。

真实系统 Import TXT 选择独立QA provider的 `duo-input-20261031.txt`，87字节/43 UTF-16字符，未用 `-qa-import` 绕过。
相对[上轮真实导入](hid-input-followup-2026-10-31.md)，本轮新增的是进行中开合；没有重复默认/XXXL完整导入矩阵。

| 阶段 | 实际窗口/状态 | 最终业务结果 |
|---|---|---|
| 内屏选文件后发送一次hinge0 | 外屏678×466出现加载/Cancel，旧稿22字符仍在 | 稿件43/结果0，完整文件名，Export disabled，额度2 |
| 一次Convert，新trace busy=true触发一次hinge180 | 先678×466/busy=true，再669×951/busy=true | 稿件43/正确繁体43，Export enabled，延迟落盘额度3 |

转换的宿主观察间隔：首次busy记录到新窗口busy记录约0.788秒，到完成约2.199秒；
这是本机轮询观察时刻，非App内精确性能时戳。trace的busy只表示isLoading，**不表示isImporting**，
见 [WorkspaceKeyboardProbe.swift:68](https://github.com/gewill/OpenCCman/blob/07c2b81ab73e8fa29c4f99ce27f5cecf7892ec98/OpenCCman/View/WorkspaceKeyboardProbe.swift#L68)。
导入进行中由加载/Cancel视频帧与稿件变化交叉确认，未误用busy=false判导入闲置。

5份指定全文/trace快照独立核对，同一model/scene/两UITextView身份保持；输入SHA-256
`28d55e93ef72a9d44f34c8e47ef83c5d4c1d414164212a0acfca4cab65d8dd1c`，结果SHA-256
`c161427b1f0a90f0147c79e73ee248c19a595dfc5da4850e0f1712af4605c907`。
结果hash来自AX全文，本轮未保存实际导出文件。未声称跨进程保稿，重复验收前刻意重启QA App。

#280 增量：外屏实际左侧竖向栏在导入中Convert禁用；内屏转换中AX只有一个启用的workspace-convert/Cancel，结束恢复Convert。
未实际按下Cancel，亦未借此宣称溢出/所有路由通过。

| 外屏导入等待 | 内屏转换等待 | 转换结束 |
|---|---|---|
| ![导入等待](https://github.com/user-attachments/assets/ae7ca530-81c5-4029-9210-ec058c77ef1f) | ![转换等待](https://github.com/user-attachments/assets/90afc30e-9a37-48da-af04-73a1e6a6d5bc) | ![完成](https://github.com/user-attachments/assets/1c60f39a-0c78-4ce1-958c-2ae606bfdcc2) |

[导入切至外屏](https://github.com/user-attachments/assets/25631056-d3f0-4245-b859-0ba37b02a385) / [转换切至内屏](https://github.com/user-attachments/assets/97d12f51-2244-4456-ade9-cd30ab488e74)。
分别只录目标显示，初始黑帧为目标尚未激活，非双路连续录制。按目标内容转正/缩放，未裁去动作与结果；
原件保留，预览均完整解码和QuickTime播放至结尾，4张截图逐图检查。7附件共1,647,057字节，远端逐份下载SHA/字节一致。

## 读数干扰与失败尝试保留

第一轮即时读取偏好plist得到1→1→1，随后重启前已落盘为2；不能把即时磁盘值当成App内同步额度。
QA标志 `-qa-mark-whats-new-read-at-launch` 若再次执行RootView.onAppear会复位额度
（[RootView.swift:113–130](https://github.com/gewill/OpenCCman/blob/07c2b81ab73e8fa29c4f99ce27f5cecf7892ec98/OpenCCman/Scene/RootView.swift#L113-L130)），
但**本次实际复位没有被证明**。初始因果推断已更正；第一轮原视频/trace/即时读数仍留索引。

移除此标志后，独立第二轮：重启前2→启动后2→导入后2→转换即时磁盘2→稍后3。
以完整结果和延迟持久化回读交叉核对一次成功转换/一次计次，未以反复点击取得绿色结果。
等待后的计数验证不推出转换瞬间的精确落盘时间。

即时hinge后原生读数尚指向旧显示，随后截图为黑色；这些原件保留，未选作加载画面的证据。
PIL和libwebp不可用，未安装依赖，采用PNG；第一次收尾预检把compile-peer命令对象误当成peer事件列表，
校正筛选后才执行shutdown，无误关设备。以上均见JSON/harness-limitations，不改写成产品缺陷。

## 复跑、收尾与未验证

离线核对：在JSON的evidence_root执行 `python3 verify-warm-busy.py`（默认只读）；
复跑须独立QA构建/夹具、指定UDID/工具链，先保存旧trace并以新前缀/新目录采集，不能覆盖历史原件。
JSON保留helper和相关脚本全文以便复核，≤8报告、输入等待上限90秒、单barrier8秒、12GiB磁盘保护；
无自适应重放、无共享服务重启。后续如改变产品树须重验受影响范围，不能套用本轮包证据。

本任务初始所有设备Shutdown，仅启动上述隔离UDID；所有recorders/peers结束，保存日志后仅关闭该设备，
回读Shutdown，其他booted=[]。本轮4个QuickTime录像窗口已关，原有before-return-gap窗口保留。

完整姿态/方向、自然慢I/O、取消动作、系统实际溢出、左右分屏、连续尺寸、IME/阅读、
What's New/Customer Center/冷启动、三语/XXXL剩余矩阵和最终签名/Duo真机仍未通过；VoiceOver体验未验证。
交易/最低系统/大文件仍沿原Issues，不开放功能、不关闭#280/#282，不更新历史46项盘点为全量新结果。

[远端#282证据](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6539450519) /
[#280增量回链](https://github.com/gewill/OpenCCman/issues/280#issuecomment-6539466279)。
