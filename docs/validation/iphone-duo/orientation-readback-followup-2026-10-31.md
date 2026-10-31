# 方向未确认复现与系统导出面板补验（2026-10-31）

关联 #280 / #282，均继续开放。本轮没有确认需要修改 App 的新缺陷；补齐英语/default 下系统导出面板跨折叠的取消、保存及实际文件校验。方向失败已再次复现，**内部根因以及与历史外屏收尾失败是否同源仍未知**。

## 合并、源码与环境

#294 固定 HEAD `c6db8a8845e0f0bf07deb7bd789212d757df2c98` 的独立 Standards / Spec 审核均零发现；重读确认无未解决审核线程，当前 HEAD App Regression / App icon 均 SUCCESS（run `41160814916`）。按 expected HEAD squash 合入 develop **`4ea9f9dac637880abe76f49a2ec518c5c7983fc0`**，单父为 `3298dae37b43cfb52f3d1377e7aa858a94e5a442`，完整 tree 与审核 HEAD 相同，远端 develop 一致。[精确合并提交 CI](https://github.com/gewill/OpenCCman/actions/runs/41161569261) 两项检查均 SUCCESS。本地独立审核不是外部 GitHub APPROVED。

本次从上述干净提交开始，App tree `a9bc63c6f8f6ea12ea3b497c5528cb4bf35a0637`、工程 tree `44b0dad8d0d71e3912dea0f65eb1fe4a6e2ac495` 未变；复用 [#292 的 QA 产物](route-return-followup-2026-10-30.md)。安装包 dylib SHA-256 `a28c756e35b1e7e54b8160e3e50ca77b6531518340d516cb45c424a04d7e2bd3`，Debug 2.1(30)、`org.gewill.OpenCCman.WhatsNewUITests`，实际构建为 Xcode 27.1 (27A9275) / iphonesimulator27.1，本轮未重建。证据目录沿用审核 HEAD 名称；实际源绑定以 JSON 的 squash commit、tree 和产物哈希为准。

主机 macOS 27.2 (26B123)，CLI 进程级 `/Applications/Xcode-27.2.0.app/Contents/Developer`，Xcode 27.2 (27B52)、devicectl 651.32、sim-use 0.16.0、AXe 1.8.0。未改变全局 xcode-select。专用设备 `4CAD3041-0744-41A6-8B4E-F934CA9F0778` / OpenCCman 282 Settings QA 20261029，iOS 27.1 (24A94425)，初始 Shutdown，无其他 Booted；仅启动这一台。

## 有界复现与对照

外部探测固定最多 8 组 / 240 秒，初始未设置 DEBUG 或 NO_DAEMON，也未重启共享 daemon。每组按 closed-start → 外屏 portrait → open → 内屏 portrait → half → closed-end → 外屏 portrait；第一次未确认立即停止姿态/方向动作，再做纯只读观察。实际耗时约 172.28 秒，完成前 7 组，第 8 组内屏 portrait 未确认，**整个探测未通过**。

| 观察 | 实际结果与含义 |
| --- | --- |
| 第 8 组内屏请求 | 02:51:01.101761Z—02:51:08.244854Z，`ok=true/confirmed=false`；活动显示屏 3、rot90 / landscape-left、物理 landscapeRight，截图实际 951×669 pt |
| 停止动作后只读 | 17 次官方 CoreDevice displays 查询，02:51:08.338784Z—02:51:18.066911Z（跨度 9.728 秒），始终相同横向且未锁屏；期间无新的姿态/方向命令 |
| 独立进程对照 | `SIM_USE_NO_DAEMON=1 SIM_USE_DEBUG=1` 单次 portrait 仍未确认；日志显示两次发送方向报告且无效果。发送日志不证明 guest 收到；不支持“只由 daemon 缓存导致”的解释 |
| 原生相对旋转 | Device Hub Controls → Rotate Left 实际从 rot90 变 rot270 / landscape-right；并未直接到 portrait |
| 原 CLI 再请求 | 不改 App、源码和进程，原 stock portrait 随后 confirmed=true，官方读回 rot0，窗口 669×951 pt |

这排除了“该包固定不支持竖向”，并表明本次约 10 秒被动等待未恢复；改变方向状态后原请求可恢复。不能进一步宣称内部传输去重、丢包或具体传感器时序已定位，亦不能把最后一次成功当永久修复。没有添加盲重试或修改产品方向掩码。

上游固定版本 [sim-use 0.16.0 的方向实验记录 E53–E56 / open question 18](https://github.com/lycorp-jp/sim-use/blob/5b543dceaf0f146bdbdc949545a26633f3de62a7/docs/ai/010-display-routing/000-plan.md)也保留展开后方向报告无效果且原因未知的案例；E54 明确只读到状态不变无法区分拒绝与丢失。它是相关工具限制的佐证，不证明本次相同内部根因，其上游试验比例不是 OpenCCman 的失败率。原 advisory 的 App 不接受措辞仍不是针对本产品的诊断。

独立脚本精确核对 **21 份指定全文快照**，每份原文/结果各 22 UTF-16、66 UTF-8 字节；同一 probe model `AD79D884-C6A9-4715-AEFE-E4779C112D67`、scene `CBA8F365-49F6-49F4-93CC-82F05B293EE4` 与两个 UITextView 身份保持。指定列表见 JSON；路由/系统面板不含编辑器的快照不计入。这不是非零选区、marked text、中段阅读或全部矩阵验收。

## 系统导出面板的实际操作

固定原文“鼠标里面的硅二极管坏了，导致光标分辨率降低。”，结果“鼠標裏面的硅二極管壞了，導致光標分辨率降低。”，英语/default。

1. 恢复内屏竖向后，从实际可见的 Export（44×44 pt，未被固定摘要覆盖）打开系统文件面板。AXe / Device Hub 树仍返回底层工作区，但活动显示屏截图和 sim-use 树证实面板已打开。随后一次旧 Export ID 查找无匹配，没有重放点击。
2. 面板保持打开，内屏 portrait → 闭合外屏 landscape-right（678×466 pt）；文件名 OpenCCman-converted 保持，Save 和 X 实际可见。按新鲜画面只点 X 一次，面板消失、返回稿件，再展开内屏；全文保持。
3. 第二轮重新实际打开面板，闭合后只点 Save 一次，返回稿件。实际读取 App **Documents/OpenCCman-converted.txt**，66 字节，全文等于预期结果，SHA-256 **`6c032e9769ec1bcd28f3b5c7a9541dc248e7625fc93d5993f23cb87be9f472cc`**。保存前同名目标不存在；不是用预先存在的 tmp 导出快照充当保存结果。重新展开后稿件/结果仍保持。

UI 显示 Folder is Empty，但主机实际 Documents 已有 9 个旧 QA 文件；只断言同名目标不存在，不断言目录为空。最初按 Save 后 mtime 查找得到空列表并停止，该失败保留：导出复制保留了快照旧 mtime，不能以 mtime 作为保存完成门槛。新 Documents 文件 ctime 在 Save 后，最终以目标不存在前置、实际路径、完整字节和哈希确认；没有为找文件而重复 Save。旧 QA 文件与新 66 字节证据文件均保留。

另一次 Save ID 前置检查因部分树漏项而停止；之后新鲜截图证明可见再操作。树缺项不是控件不可点击的充分证据，动作返回也不是业务完成证据。系统面板外观/目录枚举差异的内部原因未定位。

## 证据与复跑

[Issue #282 证据评论](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6538299750)，八个附件只上传一次，全部远端字节/SHA-256 与本地副本一致，共 **1,507,756 字节**。

| 请求未确认 | 恢复竖向 |
| --- | --- |
| ![未确认](https://github.com/user-attachments/assets/de7244e5-d333-42ef-83fc-891bca023317) | ![恢复](https://github.com/user-attachments/assets/ae224ab3-2b12-41fd-bc22-b5ccf165199a) |

| 内屏文件面板 | 外屏保存前 |
| --- | --- |
| ![内屏](https://github.com/user-attachments/assets/0aa35f0f-1372-4978-9cf3-b41cacd3e33c) | ![外屏](https://github.com/user-attachments/assets/a2d3e990-c00b-4f24-9f40-aa713077b52f) |

![保存后展开](https://github.com/user-attachments/assets/eae9ae9a-e7a2-4141-bb7a-54ff8d182d4e)

内屏实际打开导出：

https://github.com/user-attachments/assets/e3998317-758d-4dcb-ac28-36b02c40ded5

外屏实际取消返回：

https://github.com/user-attachments/assets/56d4ba9a-ca16-471d-844d-e72d9f410ab7

外屏实际保存返回：

https://github.com/user-attachments/assets/30a37346-adb7-425d-8476-bee5c4da70b5



五张 PNG 等比长边 1600px，逐图核对文字、文件名、Save/X 和返回结果；是同版本状态比较。三段 H.264 / 15fps / 无音轨 / 长边 1280px 副本全解码通过。打开与保存片段已完整播放并读回到尾；取消片段播放至约 6.57 秒时仍运行，之后播放器窗口读取超时，**未确认到尾**。不将这次 UI 播放不完整记录改成通过。

裁剪请求依次为内屏原片 26—42 秒、外屏取消原片 40 秒起 8.1 秒、外屏保存原片 44—58 秒。输入时间戳使副本首帧分别从 3.2 / 5.066 / 2.4 秒开始，实际视频轨长度为 12.8 / 3.067 / 11.6 秒；播放器时间轴到尾约 16 / 8.133 / 14 秒，不能把请求区间当连续有效帧时长。三份末帧也独立核对，取消和保存均已回到稿件；没有用空白起始时间证明操作。系统拒绝同设备并行录制两个显示屏（Resource busy），因此它们是串行片段，不是连续双屏或动画时序证据。完整原片、失败方向请求、只读日志、部分树、无匹配与 mtime 失败均保留。

外部 `diag.py`、`rotation-probe.py` 和独立 `verify-final.py` 已实际运行并保留；部分 UI 编排经主机 stdin 和 CUA 执行，不声称都有完整执行时脚本快照。独立脚本的 passed 只覆盖指定观察，不能覆盖原探测/harness 的失败。JSON 提供原始文件大小/哈希、命令与源绑定，不将媒体加入 Git。

复跑先核对同包/UDID/工具链、磁盘保护（本次初始约30.78 GiB、下限12 GiB）与是否有使用者；从相同文字/配置执行有界序列。若未确认，立即停止方向/姿态变更，只读活动显示屏、rotation、physical orientation、锁屏、AX 和实际画面，再将独立进程/原生相对旋转作为分开的实验；不要连续重发直到成功抹掉失败。系统导出需核对文件名、目标前置状态、实际 Save 后的 provider 文件全文和哈希。

## 收尾与剩余项

设备恢复 large，官方读回 closed 外屏 portrait 后终止 QA App，指定 UDID shutdown，最后重读所有设备均 Shutdown。所有录制已结束。此次新建 Device Hub 窗口的 File → Close 动作、后续读取/重新绑定均超时，**GUI 窗口是否关闭未确认**；未重复盲关或杀共享进程。播放器保存片段关闭后也出现窗口读取超时，未确认其余本轮窗口是否仍在；先前用户窗口未主动关闭。

本轮只补验和文档，不改 App/工程/依赖/容量/生产开关，不重复产品构建；后续 PR 的 CI 独立记录。完整三语/default/XXXL/姿态/左右分屏/溢出、连续尺寸、普通导入/转换进行中、所有 IME/阅读/弹层任务矩阵以及最终签名包、Duo 真机仍未通过；本次只新增英语/default 系统导出取消与真实保存切片。VoiceOver 体验未验证。最低系统 #16、交易/RevenueCatUI #14/#71、容量和生产开放 #260/#268 沿原 Issue。不关闭 #280/#282，不分发、部署或对外发布产品。
