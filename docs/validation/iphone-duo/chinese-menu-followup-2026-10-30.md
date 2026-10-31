# 中文半折叠菜单与返回补验（2026-10-30）

关联 #280 / #282，继续开放。本轮无产品缺陷复现，只补证据并更正上一轮工具链记录；不修改 App、工程、依赖或生产开关。

## 合并、源码与产物

#292 的固定 HEAD `6616fcc44fe9d0af5171d46d932c418a2a082e28` 已有 Standards / Spec 两轴零发现，当前 HEAD 的 App Regression / App icon 均成功，无未解决审核线程。按 expected HEAD squash 合入 develop `d036dbd7f23d4e8a8036c72aeffca89e0d35a83d`，核对单父、tree 与审核 HEAD 相同、远端 develop 一致；[精确合并提交 push CI](https://github.com/gewill/OpenCCman/actions/runs/41056021843) 两项均成功。可选手动任务跳过，不算该项通过；不是外部 GitHub APPROVED 或分发。

验收开始时只有文档勘误未提交，App tree `a9bc63c6f8f6ea12ea3b497c5528cb4bf35a0637` / 工程 tree `44b0dad8d0d71e3912dea0f65eb1fe4a6e2ac495` 与合并提交相同。复用 [#292 的既有构建](route-return-followup-2026-10-30.md)，并独立核对当前安装包的 dylib SHA-256 为 `a28c756e35b1e7e54b8160e3e50ca77b6531518340d516cb45c424a04d7e2bd3`。QA Debug 2.1(30)、Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`，SDK 为 iOS Simulator **27.1**；没有新构建，也不把基点 SHA 单独当成历史脏树构建来源。

主机 macOS 27.2 (26B123)，运行 CLI 进程级固定 Xcode **27.2 (27B52)** / devicectl 651.32，sim-use 0.16.0、AXe 1.8.0；runtime iOS 27.1 (24A94425)。专用 Duo `4CAD3041-0744-41A6-8B4E-F934CA9F0778` 初始 Shutdown，另一个项目的 BuZhan Duo 初始 Booted，保留不动。专用设备 bootstatus 再次写有 `Data Migration Failed`，没有把其退出 0 当迁移成功；实际启动、示例填入与转换后才进行验收。

工具链勘误：上一轮重启后的 `xcode-select -p` 继承了 `DEVELOPER_DIR`，其输出不能证明全局选择改变。本轮移除覆盖读回仍为 `/Applications/Xcode.app/Contents/Developer`；本任务没有执行全局切换。已更正旧 MD / JSON 的解释，保留原采集文件与哈希。

## 本次完整通过的四组

先请求 native open / half 130°，随后仅旋转同一内屏；各组 trace 均记录 active division。默认为 `large`，XXXL 为 `extra-extra-extra-large`，不是 AX1–AX5。四组是独立场景，不是相同背景布局的字号前后改版对照。

| 场景 | 实际方向/窗口 | safe area [上,左,下,右] | 本轮结果 |
| --- | --- | --- | --- |
| 简体/default | landscape-left，951×669 pt | [82,0,34,84] | 六组菜单及子项、侧栏、三条路由返回通过 |
| 简体/XXXL | landscape-right，951×669 pt | [82,0,34,84] | 同上；首个未完成尝试单独保留 |
| 繁体/default | landscape-right，951×669 pt | [82,0,34,84] | 同上；初始化失败尝试单独保留 |
| 繁体/XXXL | portrait，669×951 pt | [82,0,34,0] | 同上；More 采用有业务读回的 AX frame 回退 |

横屏 division probe 局部 frame `[455.5,-82,40,669]`，竖屏 `[0,373.5,669,40]`；不将局部坐标当全部关键控件避让证明。反向横屏仍观察到右侧系统竖栏，竖屏为顶部横栏；未验到系统左侧条、左右分屏或实际系统工具栏溢出。

每组实际执行：

- 布局：选择上下→左右→上下。横屏确实左右/上下重排；竖屏左右偏好显示“目前空間使用上下配置；空間足夠時將恢復左右配置。”，不是强制竖屏显示两栏。
- 面板大小：均分→扩大原文→扩大结果→恢复均分；原文实际高度增加并恢复。四组均有几何断言，不用 iOS AX 分隔条的 `nan` 当百分比通过。
- 侧栏：真实显示/隐藏，源编辑区 x 在 40 / 312 之间变化；后续隐藏后继续返回验收。菜单选择状态不替代实际布局变化。
- 帮助/会员/设置：进入对应标题页面，再用各自 Back 返回。会员只进入/返回，Restore disabled，没有购买/恢复，也未验证 Customer Center 业务。

六组菜单均 enabled、完整 frame 位于对应实际窗口内；截图可读，动作后再读业务结果。**54 份选定原生 AX 快照**分别核对精确原文/结果，均为各 22 UTF-16 / 66 UTF-8 字节及相同全文 SHA。**12 次路由返回前后结果 Y 比较**全部差值小于 1 pt，无 #292 的新增间距。路由页本身没有编辑器，不纳入全文计数；不声称跨路由保持 UITextView 对象身份或中段阅读位置。

复跑和结果断言脚本、每次动作/原始 AX、实际 trace、失败记录、media 哈希与远端读回信息见 [JSON 索引](chinese-menu-followup-2026-10-30.json)。trace 会滞后，当前动作/比例以对应 AX 和实际 frame 为准。

## 精选证据

[Issue #282 补证评论](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6523308477)，上传一次后跨 Issue / PR 复用链接。

| | 默认 | XXXL |
| --- | --- | --- |
| 简体 | ![简体默认](https://github.com/user-attachments/assets/c12db7c0-1a04-4b72-bebe-be6ba1545bf6) | ![简体XXXL](https://github.com/user-attachments/assets/83e04ed0-4a1c-47d4-8ab2-8bc83abb06cb) |
| 繁体 | ![繁体默认](https://github.com/user-attachments/assets/11073d9a-a0ce-457a-93e6-886d995ab687) | ![繁体XXXL](https://github.com/user-attachments/assets/69530968-1078-4ae2-8a9a-9119fd90cdca) |

简体 XXXL 全过程，79.33 秒：

https://github.com/user-attachments/assets/e60ee493-d3df-49db-81d9-219feb5b19f7

繁体 XXXL 全过程，98.13 秒：

https://github.com/user-attachments/assets/e070842e-3bf1-4da5-bdc7-34c5cf70f03c

四张 PNG 副本从原图等比缩至长边 1600px，逐张核对文字/布局。两段视频从原片生成 H.264 / CFR 15 fps / 无音轨副本，长边 1280px；简体横屏仅旋转至可读方向，不剪动作。两份副本均在系统播放器从 0 播放至尾，完整解码无告警；原片完整解码返回 0，但有 null mux 时间戳告警，原件保留，不用于动画/时序指标。六个附件共 **4,003,952 字节**；远端展示四图两视频，正文无本机死链，全部远端字节与上传副本 SHA-256 一致。

## 未完成尝试、收尾与边界

三次尝试未完成，不抹去、不计为通过，也未直接归因产品：

1. 简体 XXXL：菜单关闭后过早复用控件树，未找到 More，脚本停止。刷新后目标恢复；后续在目标缺失时先做有界观察，不盲目派发。
2. 繁体默认：App 尚未前台，填入未命中；初始化脚本没有及时停止，后续全文断言阻止误报。修正为前台/目标 enabled/示例与结果全文前置检查后新建运行。没有删掉全文断言。
3. 繁体 XXXL 竖屏：AXe 和截图可见 More，sim-use 树却未包含它，语义 tap 明确返回未找到目标。只在这种没有派发动作的结果下，重新读取 AXe 的唯一 enabled frame，按中心坐标点击，再核对六组菜单和操作结果。不是“动作发送成功即通过”。

本地 runner 在迭代前保留后续版本副本；第一版复跑参考由后续代码还原，不冒充执行时源码快照。运行证据与独立的全文/布局/返回几何断言保留，产品源码与包哈希来源不受这些 harness 调整影响。

所有录像已结束。恢复系统字号 large、确认闭合、终止 QA App 后精确 shutdown，回读专用 UDID 为 Shutdown；初始 Booted 的 BuZhan Duo 仍 Booted。收尾闭合后请求 portrait，工具返回 `confirmed=false`，仍报告外屏 landscape-right；**不将该请求记作旋转通过或宣称已恢复竖向**，原因尚未定位，留在 #282 后续姿态验证。只关闭本轮两个 QuickTime 回放窗口，保留原有 `before-return-gap.mp4` 窗口；未操作共享 Device Hub / 服务或全局 Xcode。

未完成完整三语×姿态/方向/字号笛卡尔矩阵、左右分屏、系统左侧条/实际溢出、全部弹层/输入/阅读/任务跨尺寸、导入/Preparing/Cancelling/保护数据、最终签名包及真机；最低系统 #16、交易/RevenueCatUI #14/#71、容量 #260/#268 等维持原归属。VoiceOver 体验未验证，不新增专项阻塞。没有发布、分发或关闭 Issue。

本轮为文档/证据变更，仅核对来源、链接、原始证据哈希和断言、附件读回及 `git diff --check`；未重复既有双端构建/产品回归。新 PR 的必需 CI 与审核单独跟踪，不复用 #292 的绿灯作为新 PR 检查。
