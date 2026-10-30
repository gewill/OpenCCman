# Duo runtime 恢复与路由返回间距修复（2026-10-30）

关联 #279 / #280 / #282，均不由本记录关闭。#291 已按审核 HEAD squash 合入 develop `fd9454a300a40a981b35d9404290d9739aed87d9`；其 [精确提交 push CI](https://github.com/gewill/OpenCCman/actions/runs/41014081145) 的 App Regression / App icon 成功。本轮恢复本机验收后发现一个共享工作区布局缺陷，修改两个面板的测量约束，并保留剩余矩阵。

## 来源与环境

基点为上述干净 develop。修复只在 `WorkspaceSurface.swift` 的 SourcePane / ResultPane 定宽后增加 `.fixedSize(horizontal: false, vertical: true)`，测量固有高度，避免路由隐藏/返回期间父级高度提议反馈到 `sourceSize` / `resultSize`。保留原有 ZStack、编辑器绑定、比例与导航结构，不改变转换、额度、文件、生产开关或依赖。定向对照支持该测量反馈判断，未定位 SwiftUI 内部的具体布局阶段。

主机 macOS 27.2 (26B123)；运行工具链显式 `DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer`，Xcode 27.2 (27B52)、devicectl 651.32、sim-use 0.16.0、AXe 1.8.0。专用 Duo `4CAD3041-0744-41A6-8B4E-F934CA9F0778`，iOS 27.1 (24A94425)。

为控制构建变量，修复前后均使用 **Xcode 27.1 (27A9275) / iOS 27.1 SDK** 的 Debug QA 2.1(30)，Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`；运行工具链 27.2 不等于产物 SDK 27.2。旧包 dylib SHA-256 `f69b7bbea0700611e338f4bf5ee3116b07508c6d9e9967905abd1b063ba7534e`；新包 `a28c756e35b1e7e54b8160e3e50ca77b6531518340d516cb45c424a04d7e2bd3`。新 Mac QA 同轮构建，arm64/x86_64、macOS 27.0 SDK。部署下限仍为 iOS 15 / macOS 12。

构建时为基点加两行产品改动的脏工作区，不能只用基点 SHA 标作修复包来源。[JSON](route-return-followup-2026-10-30.json) 保存构建报告、产品 diff SHA、源码文件 SHA、二进制哈希、原始证据索引及附件读回哈希。文档在构建后添加，不改变上述产品文件。

## runtime 修复经过与边界

1. 27.1 与 27.2 CLI 均报 CoreSimulator 401 / exit 145：`runtime path not found`。runtime 列表标可用、bundle 与 RuntimeRoot 存在；新建设备对照在分配 UDID 前也失败，故不能只归因旧设备数据。
2. 旧镜像登记 `AFC62602-E776-4163-876F-8E417715A6D7` 指向 MobileAsset 的 AssetData **目录**，signature Unknown；官方 verify 报 `-67054 a sealed resource is missing or invalid`。其状态随后重扫又变回 Ready，不能把一次 Unusable 当稳定状态。
3. 从现有 Restore DMG 用 `simctl runtime add` 新建独立管理镜像 `56AD1A54-B9D0-4892-87ED-1779399A6FD4`，Ready / Verified，保留原文件。重扫、显式 profiles、精确卸载旧镜像重扫均未恢复；dyld cache 检查返回 usable。
4. 核对没有 27.1 Booted 设备后，用官方 `runtime delete <旧 UUID> --keep-asset` 精确移除重复登记；原始资产、新验证镜像和设备数据保留。其他项目的 26.5 Booted 设备未受影响；随后仍报同一 401。没有强停共享服务或批量删除。
5. 官方 27.2 runtime 下载开始后只到约 102.5 MB / 8.05 GB，随后用户重启；没有完成结果文件，当前仍无已安装 27.2 runtime，未继续下载。只确认旧 27.1 环境在用户重启后恢复，不宣称某一步单独修复根因。
6. 重启后用户的 BuZhan Duo 已 Booted，本任务保留它，另启动自己的设备。boot 成功但 bootstatus 写有 `Data Migration Failed`；旧安装登记对应 App 文件不存在。保留数据，重新安装哈希一致 QA 包并实际打开、填示例和转换后，才确认本任务可继续。没有把 bootstatus 的退出 0 当作全部迁移成功。

全局 Xcode 路径在重启前为 Xcode.app，重启后读回为 Xcode-27.2.0.app；本任务没有执行全局切换，也不将用户当前选择回改。原生 Device Hub 的早期观察选中了既有 Xcode.app 进程，不能称为 27.2 GUI 验证；重启后未操作共享 Device Hub。

## 复现与修复验收

英语，内屏 landscape-left、原生半折叠 130°、真实窗口 **951×669 pt**。默认字号 `large`，XXXL 为 `extra-extra-extra-large`。trace 后续记录真实 active division `[455.5,-82,40,669]`，这是 probe 局部坐标，不作为所有内容避让通过的证明。外屏窗口 466×678 pt；不是模拟窄窗冒充姿态。

固定输入、结果各 22 UTF-16 / 66 UTF-8 字节。十三份选定 AX 快照均断言精确全文及全文 SHA；路由页自身没有编辑器，不将其算入全文断言。trace 有采样延迟，比例与当前全文以对应 AX 快照为准，不把滞后一帧的 trace 混作同一瞬间。

| 场景 | 结果与边界 |
| --- | --- |
| 修复前，隐藏侧栏、上下布局、等分，More → Help → Back | 原文/结果保持，但结果 Y `680.667 → 1801.000`，额外 `1120.333 pt` 间距；外层滚动进入空白。默认重复复现；XXXL 配合侧栏时也观察到返回后明显增距 |
| 修复后，同条件默认字号 Help 返回 | 结果 Y 仍为 `680.667`；原文/结果完整，滚动可读结果。第二次同条件返回仍一致 |
| 修复后 XXXL，上下布局、等分，Help / Pro / Settings 返回 | 结果 Y 保持 `705.333`；原文/结果完整。Pro 仅进入/返回，Restore disabled，不操作交易 |
| 默认/XXXL 六组 More 入口 | 在旧包执行布局、面板大小、侧栏、Help、Pro、Settings；新包补验相关入口及返回。名称可读，动作有后续 AX。仅一组英语半折叠切片，不扩写为所有菜单子项、全部姿态或系统溢出 |
| 新包 XXXL 面板比例 | 增大原文后原文编辑区 `180→198 pt`；增大结果一次恢复 `198→180 pt`，等分恢复两侧 180 pt。iOS AX 对分隔条值返回 `nan`，不能用它验证百分比/VoiceOver，采用实际几何和全文 |
| 新包侧栏/布局偏好 | 实际显示 inspector 后源编辑区 x=312/width=515，隐藏后 x=40/width=787；左右偏好在预算不足时保持上下回退，后续宽态能显示左右。动作文件中的 on/off 只是步骤标签，以实际画面/几何为准 |
| 新包 XXXL Settings → 原生 Closed → Back → Open | 设置返回仍是同一稿件和结果；外屏与再展开有独立快照。不是完整双显示连续录像，也未验 Customer Center 业务 |
| 新包 Mac 英语 300×412 pt、100%/150% | 实际示例转换、设置切换/返回、外层滚动后结果完整可读，50% 比例保留；沿用窄窗口，没有再次证明系统最小尺寸，也未扩为常用宽窗矩阵 |

路由返回会重新建立原生编辑器；本轮不声称跨路由保留 UITextView 对象身份。修复保留既有布局树结构，不以对象重建掩盖丢稿，本轮全文均独立核对。

## 精选证据

[Issue #282 的补证评论](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6517181441) 保存两图两视频。两张截图分别是同一语言/字号/姿态/布局/等分/隐藏侧栏、返回并外层滚动后的状态；滑动起点不同，不作为相同手势位移对照，定量结论来自滚动前的 frame。

| 修复前空白 | 修复后结果可读 |
| --- | --- |
| ![修复前](https://github.com/user-attachments/assets/fc624e96-ac13-47ea-a356-1bd17cb46b55) | ![修复后](https://github.com/user-attachments/assets/13e7dca9-fc17-4025-98b4-3b0d128c0ff4) |

修复前：https://github.com/user-attachments/assets/4117a867-8c35-4857-b21e-f5ba9c9451a0

修复后：https://github.com/user-attachments/assets/7f7399d5-16e6-47c0-bd3d-1b660ca045cf

分享视频从原片独立生成：旋转至可读方向、1280×900、H.264、CFR 15 fps、无音轨，26.33 / 8.87 秒；未剪动作。两份在系统播放器从 0 播放至尾，原片完整解码及抽帧。原片 null mux 检查有时间戳告警，CFR 副本无告警；不是动画流畅度/时序验收。PNG 原图已为 239,072 / 466,735 字节，保持字节不再缩小文字。四个附件总计 1,130,250 字节，远端展示为两图两视频，正文无本机死链；远端字节与副本 SHA 逐一相同，后续复用 URL。

AXe physical / simulator 两条 tap 在本次 Duo 未改变页面；改用 sim-use 后填入、转换和菜单选择均有业务读回，不将 AXe 的派发成功算通过。早期一份修复后探索录像的首个滑动误落分隔条并改变比例，已排除同条件对照；精选采用重新等分、重新定位后的 `after-return-clean` 原片。

## 验证、可复跑步骤与未完成项

本地已通过两端 QA 构建（`scripts/build-duo-validation.py`，报告见 JSON）及 `check-workspace.sh`、`check-workspace-editor.sh`、`check-project.sh`、`check-app-language.py`、`check-control-labels.sh`、`git diff --check`。这些检查各自有范围，原生 Mac 编辑器回归不等于 Duo UI 测试。没有为两行布局约束添加镜像实现的单元测试；本次回归以实际运行 App 的定向对照为依据。

重跑：使用对应 QA 包，英语/default，填示例并 Convert → 内屏横向/half 130° → More 隐藏侧栏、Stacked、Equal panes → 记源/结果全文与 frame → More/Help/Back → 比较 frame，再从外层空白/结果标题附近滚动。XXXL 重做 Help/Pro/Settings 返回、比例增减及外屏返回；Mac 用 100%/150% 设置返回后滚动读取结果。必须逐次观察实际窗口和业务值，不能只检查命令 0。

本轮未完成：完整三语与姿态/方向、左右分屏、实际系统溢出、键盘 IME/阅读位置的全矩阵、普通转换/导入进行中的尺寸切换、Preparing/Cancelling/保护数据、最终签名包与真机。最低系统 #16、交易/RevenueCatUI #14/#71、容量/开放 #260/#268、系统入口 #19 均保留；VoiceOver 体验未验证。没有修改这些关闭口径或发布/分发。

## 收尾

Mac 恢复 100%、保留稿件后退出，进程已核对消失；菜单栏图标/登录启动未改。本轮所有录像进程已结束，QA 专用 Duo 恢复 large / closed / portrait、终止 App 并精确 shutdown，回读 Shutdown。保留用户/其他任务仍 Booted 的 BuZhan Duo 与 iOS 26.5 iPhone 17 Pro。QuickTime 只操作本轮回放文件，未录制/截取它或其他 App 的窗口。
