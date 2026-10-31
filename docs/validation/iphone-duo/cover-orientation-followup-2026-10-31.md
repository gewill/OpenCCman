# 外屏方向排查与安全区补验（2026-10-31）

关联 #280 / #282，继续开放。#293 已审核并 squash 合入 develop；本轮新增外屏两侧系统栏、XXXL 设置操作和原生 Device Hub 对照。**旧收尾的竖向请求未确认仍未定位根因**，没有将重放成功写成永久修复，也没有确认需要修改 App 的新缺陷。

## 合并、源码与环境

#293 固定 HEAD `deac4a918dc20e09caf75116c7c7df34af0e6f57` 的既有独立 Standards / Spec 审核均零发现；本轮重读确认 HEAD 未变、无未解决审核线程，App Regression / App icon 均 SUCCESS（run `41059593458`）。按 expected HEAD squash 合入 develop **`3298dae37b43cfb52f3d1377e7aa858a94e5a442`**；核对单父为 `d036dbd`、完整 tree 与审核 HEAD 相同、远端 develop 一致。[精确合并提交 push CI](https://github.com/gewill/OpenCCman/actions/runs/41158224339) 两项检查均 SUCCESS。可选手动诊断跳过，不计为通过；既有本地独立审核不是外部 GitHub APPROVED。

验收从上述干净提交开始，App tree `a9bc63c6f8f6ea12ea3b497c5528cb4bf35a0637`、工程 tree `44b0dad8d0d71e3912dea0f65eb1fe4a6e2ac495` 未变。复用 [#292 的 QA 包及构建来源](route-return-followup-2026-10-30.md)，独立核对安装包 dylib SHA-256 `a28c756e35b1e7e54b8160e3e50ca77b6531518340d516cb45c424a04d7e2bd3`。Debug 2.1(30)、`org.gewill.OpenCCman.WhatsNewUITests`，实际构建为 Xcode 27.1 (27A9275) / iOS Simulator 27.1 SDK；本轮未重建，不把 27.2 运行工具链当产物 SDK。

主机 macOS 27.2 (26B123)，CLI 进程级固定 `/Applications/Xcode-27.2.0.app/Contents/Developer`，Xcode 27.2 (27B52)、devicectl 651.32、sim-use 0.16.0、AXe 1.8.0。无覆盖的全局选择仍为 `/Applications/Xcode.app/Contents/Developer`，未切全局。专用 Duo `4CAD3041-0744-41A6-8B4E-F934CA9F0778`，iOS 27.1 (24A94425)，初始 Shutdown；本次 bootstatus 为 Finished。仅启动这一台。

## 方向排查：已证实与仍未知

1. 安装包的 iPhone 方向配置含 portrait 和两个横向，源码未发现新的方向锁定实现。当前包实际能在外屏 678×466 与 466×678 pt 间变化；“App 固定不支持竖向”不符合本轮证据。
2. 原顺序“内屏 portrait / half 130° → closed → portrait”在英语/default 下完成一次带中间观察的重放，再完成三次闭合后立即请求竖向。四次外屏请求均 `confirmed=true`，原文和结果均保持；不据此估算稳定成功率。
3. 三次立即重放中，第二次**内屏** portrait 命令曾 `ok=true` 但 `confirmed=false`、仍报 landscape-left。随后 half 操作读到 portrait；其间发生了姿态操作，不能证明只等待就会恢复，亦不能直接归因 App 拒绝或某个传输根因。另两组观察实验多次从已经 portrait 的内屏开始，不算新的真实旋转覆盖。
4. 繁体/XXXL 重放时，CLI 的 More → 设置点击返回 0，但页面仍是首页，后续找不到 Back，脚本停止。这次路由未通过。之后从已确认的同一内屏 portrait / half 首页闭合并请求外屏 portrait，得到 `confirmed=true`；六次只读姿态观察和两次官方 CoreDevice orientation get 均保持 portrait。它没有完整复现上一轮全部菜单历史。
5. 另向 Xcode 27.2 的明确 App 路径取得原生 Device Hub，在本轮新建的专用窗口操作 Open、Rotate Right、Partially Open、Closed 和 Rotate Right。独立读回内屏 portrait、外屏 landscape-right → portrait，原文和结果保持。GUI 的相对旋转按钮不是 CLI 的同一个绝对方向请求；两条通道各自记录，不互相冒充。

sim-use 的[固定版本实现](https://github.com/lycorp-jp/sim-use/blob/5b543dceaf0f146bdbdc949545a26633f3de62a7/Sources/iOSSimBackend/Sim/PostureController.swift)会发送方向报告、有限等待/校正/重发，未达目标时统一返回含“frontmost app or display does not accept”措辞的 advisory；这段通用文案不是针对 OpenCCman 的根因诊断。当前证据只能将后续排查重点放在姿态切换、方向报告与读回的交界；**尚不能确认历史失败究竟来自丢失报告、时序、工具校准还是其他环境状态**，因此保留未解决项，不修改产品方向配置。

默认 sim-use 截图在已闭合外屏活动时曾得到 2007×2853 的闲置内屏黑帧；CoreDevice 当时明确显示 LCD/id 1 active、LCD-1/id 3 inactive。保留失败原图，后续先读活动显示屏，再用 `simctl io <UDID> screenshot --display=<实际 ID>`；录像同样显式指定显示屏。没有将黑帧当 App 黑屏，也未定位工具内部选屏原因。

## 新增可独立验收的切片

| 场景 | 实际结果 | 边界 |
| --- | --- | --- |
| 英语/default，外屏 landscape-right | 678×466 pt，safe area [82,84,34,0]；系统栏实际在左，设置/更多/转换 frame 完整在窗口内；More 六组完整 enabled，Help → Back 完成 | 不是左右分屏；没有触发系统自动溢出 |
| 英语/default，外屏 landscape-left | 678×466 pt，[82,0,34,84]；系统栏在右，正文与栏分开；More 六组完整 enabled，Settings → Back 完成 | 仅此方向和页面切片 |
| 英语/default，外屏 portrait | 466×678 pt，[82,0,34,84]；Pro → 关闭完成 | 仅进入和关闭，未操作购买、恢复或用户中心业务 |
| 英语/XXXL，外屏设置底部 | 真实 swipe 使 Taiwan Idiom 的 y 从约 701.33 变为 572 pt，44pt 控件完整进入可见区；点击后蓝色选择与独立偏好值为 Taiwan Idiom | 语义查找遗漏目标后才用新鲜 AX 唯一 enabled frame 回退；不是单凭动作返回成功 |
| 同一 XXXL 设置 sheet 保持打开，两个横向及竖向 | 三个姿态均仍有 Custom 设置内容、完整 enabled Done；三次偏好读回均为 Taiwan Idiom；之后实际 Done 返回原稿 | 横向系统栏可以省略页面标题，不将标题必现作为产品标准；不是所有设置逐项验收 |
| 设置变更后的已有结果 | 原文/结果完整，提示“Settings changed. This result uses the previous conversion settings.”；Export TXT 保持 enabled，符合保留成功快照的既有行为；随后 UI 恢复预设并读回 Not convert | 本轮没有完成真正文件导出、保存或字节验收 |
| 繁体/XXXL，外屏原生转发操作 | More → 设置 → 返回实际完成，并重复一次录制；设置标题、Back、回到原稿均有原生读回 | CLI 的先前失败不改写为通过；不代表内屏原菜单历史重放完成 |

独立复核脚本重新解析 **27 份指定原生 AX 全文快照**，均精确等于固定原文/结果，各 22 UTF-16、66 UTF-8 字节；不以字符数代替全文核对。英语三次及原生繁体一次，共 **4 组返回前后结果 Y** 差值均小于 1pt。路由页没有编辑器，不纳入全文计数；不声称跨路由保持 UITextView 身份、中段阅读位置或 marked text。

已有结果的导出语义依据：[HomeViewModel 的配置比较与快照](https://github.com/gewill/OpenCCman/blob/3298dae37b43cfb52f3d1377e7aa858a94e5a442/OpenCCman/Scene/HomeViewModel.swift#L61-L67)、[ResultPane 的快照门控和设置变更提示](https://github.com/gewill/OpenCCman/blob/3298dae37b43cfb52f3d1377e7aa858a94e5a442/OpenCCman/View/WorkspaceComponents.swift#L249-L264)、[HomeScene 使用已有快照导出](https://github.com/gewill/OpenCCman/blob/3298dae37b43cfb52f3d1377e7aa858a94e5a442/OpenCCman/Scene/HomeScene.swift#L137-L140)。没有为错误测试假设禁用既有功能。

## 未完成尝试与探测脚本限制

原始探索 harness **没有整体通过**。上表是之后独立按原始观察校验的切片，不能把独立断言成功改写为原 harness 成功。

- 一次初始化用了不存在的示例 ID，在派发动作前停止；改用实际控件树提供的 `source-fill-example`。
- XXXL r1：实际滚动完成，语义 Taiwan Idiom 查找明确无匹配、未派发，停止。r2 重新读 AX 唯一可见 frame 点击，偏好变化确认；随后错误要求横屏设置标题为 Heading，停止。
- r3：恢复预设后过早读取磁盘偏好，仍见旧值，停止；随后只观察读到 Not convert。之后采用有界只读等待，不重复点击“追值”；最终恢复也记录了多次旧值再变为 Not convert。
- r4：实际滚动、选择、三方向 sheet 和 Done 已完成；后续错误断言“配置变化必须禁用已有成功结果导出”，停止。依据上述源码和实际提示/全文/Export 状态，确认该断言不符合既有快照语义，未修改 App。独立复核不包含这个错误预期，也不宣称 r4 全程通过。
- 另一次尝试按处于固定摘要覆盖区的 Export AX frame 点击，实际打开设置；未进入系统文件面板，不计导出通过。之后确认偏好、恢复预设并返回。AX frame 在窗口内并不自动代表当时可点击。
- 繁体 CLI 的菜单设置动作未导航，Back 前置检查阻止了继续；原生转发的新一轮才完成外屏设置返回。原生内屏方向变化期间，Device Hub AX 一度未列出 App 栏项目，未盲点。

外部 `qa.py` / `probe.py`、实际执行的 `settings-r4.py` 和未完成的 `cleanup-replay.py`、动作日志、AX、trace、独立复核脚本和失败媒体均保留。部分早期编排直接经主机 stdin 执行，不声称所有早期编排都有执行时脚本快照；最终辅助脚本与动作命令均有索引。详见 [JSON 证据索引](cover-orientation-followup-2026-10-31.json)。

## 精选证据

[Issue #282 补证评论](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6537844806)，上传一次后复用链接。

| 左侧栏菜单 | 右侧栏菜单 |
| --- | --- |
| ![左侧栏](https://github.com/user-attachments/assets/709176ed-8151-4fd1-9c3d-559a69bca407) | ![右侧栏](https://github.com/user-attachments/assets/8b5bf1fa-9899-44ae-9eb4-499b2f803b63) |

| XXXL 滚动后选择前 | 实际选择后 |
| --- | --- |
| ![选择前](https://github.com/user-attachments/assets/27509e02-ee1a-48fe-b269-e7ac45671091) | ![选择后](https://github.com/user-attachments/assets/c47da90b-b326-4798-8e76-e94ef5a9bcd4) |

![XXXL 横向 Done](https://github.com/user-attachments/assets/973dba85-f9eb-479c-943e-1e40d98be2c3)

XXXL 滚动与选择（前14秒）：

https://github.com/user-attachments/assets/a6e4a5b3-ba5c-4872-a841-b65991688ecd

繁体原生设置进入/返回（完整）：

https://github.com/user-attachments/assets/35b5b977-de95-400d-bbfe-8448ee427d72

五张 PNG 副本等比缩至长边 1600px，逐张核对文字、菜单和选中态。这是同一版本的方向/选择状态比较，不是产品改版前后对照。两份 H.264 / 15fps / 无音轨副本长边 1280px，分别为 XXXL 原片的**前 14 秒，仅含滚动与选择**，及 **20.93 秒完整原生繁体设置返回**。14 秒片段不包含后续旋转、返回或 harness 停止；完整原片保留。两份副本均完整播放至尾、完整解码无告警，不用于动画时序/流畅度指标。七个附件共 **2,454,057 字节**，远端字节核验另列 JSON。

## 收尾、剩余项与复跑

本任务设备恢复 large，实际读回 closed 外屏 portrait 后终止 App，指定 UDID shutdown 并确认 Shutdown。本轮创建的 Device Hub 专用窗口关闭，共享 GUI 进程和既有窗口保留；仅关闭两份新建 QuickTime 窗口，保留先前文件。录像均结束。

起初保留了其他任务 Booted 的 BuZhan Duo；**用户随后明确要求关闭 iPerfman / OpenCCman 以外的模拟器**，因此按该新授权单独关闭 `7F593A7C-4954-4B3A-AFDF-BED3F0E41BFD`，确认 Shutdown。iPerfman 没有 Booted 实例。最后重读没有任何 Booted 设备；没有使用 shutdown all、退出共享服务或删除设备/runtime。

复跑方向问题时，用同一 QA 包、明确 UDID / Xcode，记录请求前后的活动显示屏、方向、实际窗口、稿件全文。先做内屏 portrait / half → closed → portrait；若 `confirmed=false`，先只观察 CoreDevice / AX，保存未确认结果，再决定是否用原生按钮作独立对照，不以反复发送直到成功消除失败。设置切片用英语 XXXL 打开 sheet、真实滚动到底部、选择 Region，再旋转并核对 Done、Custom 和偏好；等待持久化只读回，不反复点击。

本轮只补文档与仓库外探测/采集辅助，不改 App、工程、依赖、生产开关或容量。文档检查和独立观察校验不替代新产品构建；本 PR 的 App Regression 仍须独立通过。旧方向根因、完整三语/姿态/左右分屏、真实系统溢出、连续尺寸、进行中的普通导入/转换、全部 IME/阅读/弹层与任务矩阵，以及最终签名包和 Duo 真机仍未通过；最低系统 #16、交易/RevenueCatUI #14/#71、容量与开放 #260/#268 沿原 Issue。VoiceOver 体验未验证。不关闭父 Issue、不分发或部署。
