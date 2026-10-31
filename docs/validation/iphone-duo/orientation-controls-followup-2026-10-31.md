# Duo 方向控制对照与 XXXL 导入面板补验（2026-10-31）

关联 #280 / #282，继续开放。**同一竖向请求未确认已在最小 UIKit App 复现，并非 OpenCCman / SwiftUI 独有；共享仿真控制链路是后续重点，具体内部原因仍未知。** 本轮不改产品代码或方向配置；新增英语/XXXL 系统导入面板跨折叠取消切片，未完成实际文件选择和导入。

## 合并、来源与环境

#295 当前 HEAD `c4e6c07705c7c407b378ee403143ef72ef873e7c` 的既有独立 Standards / Spec 各零发现；重读确认无新提交、无审核提交或未解决线程，App Regression / App icon 均 SUCCESS（run `41163905965`）。按该 HEAD squash 合入 develop **`9c71b9f9684f8c66c69ac6cee791b4d89e757d69`**；单父 `4ea9f9dac637880abe76f49a2ec518c5c7983fc0`，完整 tree 与审核 HEAD 相同，远端一致。[精确合并提交 push CI](https://github.com/gewill/OpenCCman/actions/runs/41166018550) 两项均 SUCCESS。可选诊断跳过不计通过，本地审核不冒充外部 GitHub APPROVED。

本轮从上述干净提交开始。复用 [既有 QA 包](route-return-followup-2026-10-30.md)：App tree `a9bc63c6f8f6ea12ea3b497c5528cb4bf35a0637`、工程 tree `44b0dad8d0d71e3912dea0f65eb1fe4a6e2ac495`，安装包 dylib SHA-256 `a28c756e35b1e7e54b8160e3e50ca77b6531518340d516cb45c424a04d7e2bd3`。实际产品构建仍为 Xcode 27.1 (27A9275) / iphonesimulator27.1、Debug 2.1(30)、`org.gewill.OpenCCman.WhatsNewUITests`；未重建产品。

主机 macOS 27.2 (26B123)；CLI 进程级固定 Xcode 27.2 (27B52) / devicectl 651.32，sim-use 0.16.0、AXe 1.8.0，全局选择不变。专用 Duo `4CAD3041-0744-41A6-8B4E-F934CA9F0778` / OpenCCman 282 Settings QA 20261029，iOS 27.1 (24A94425)，初始 Shutdown、无其他 Booted，仅启动这一台。磁盘保护下限 12 GiB。

## 方向：新的可证伪对照

有界计划最多 8 组 / 240 秒，顺序沿用 [#295 的探测](orientation-readback-followup-2026-10-31.md)。实际约 70.22 秒，前两组完成，**第三组闭合后外屏 portrait 未确认**，立即停止变更并只读约 8 秒；不是整个探测通过，也不估计失败率。

| 对照 | 实际结果 | 判断边界 |
| --- | --- | --- |
| 第三组外屏请求 | `ok=true/confirmed=false`；活动 id1、rot270 / landscape-right，displays 的 currentDeviceOrientation 为 landscapeLeft | 本轮确实复现旧收尾的外屏症状，但不证明历史记录同一内部根因 |
| 无新动作的等待 | 14 次官方 displays 查询，跨度 7.941958 秒，全为上述状态、未锁屏 | 该等待区间内未自行恢复 |
| 官方绝对方向 set/get | `orientation set portrait` JSON v5 outcome=success，后续 orientation get 也为 portrait；4次独立 displays 及实际 App 窗口仍为横向678×466 | 两个查询面没有一致；不能用 set/get 回执代替实际显示和 App 几何，也不能据此确定某个内部缓存错误 |
| Home 对照 | 后续确认 SpringBoard/rot0；返回同一 App 仍 rot270。第二次在已确认 Home 请求 portrait 得 confirmed=true，返回原 App 仍横向 | Home 当时已经竖向，不算一次真实旋转；它的达标不能替原 App 背书，亦不证明 Home 动作本身修复了底层状态 |
| 独立 UIKit App | portrait 请求同样 confirmed=false，布局日志678×466、supported mask26（portrait/左右横向），displays 仍rot270 | 排除“只发生在 OpenCCman / SwiftUI”的解释；不是对所有 App/系统的普遍结论 |
| 改变方向值后再请求 | 在探针内先 landscape-left，再 portrait，两次 confirmed=true；布局466×678、interface=1，独立截图及 displays rot0。返回原 OpenCCman 也为portrait | 支持本次改变控制状态后恢复的观察；没有证明去重、丢包、时序等具体机制或永久修复 |

UIKit 对照是仓库外新建、编译、ad-hoc 签名和安装的最小 `org.gewill.OpenCCman.OrientationControlQA`，不含 OpenCCman 业务，仅一个 UILabel 和 UIScene/UIViewController。使用 Xcode 27.2 的 **iphonesimulator27.2 SDK**，目标 iOS15/arm64 Simulator；与产品27.1 SDK区分。JSON 收录完整源码、Info、编译命令与源/二进制哈希；真实运行结果不以“编译成功”替代。探针仍不是正式分发或真机候选。

[上游固定版本 E53–E56 与未决问题18](https://github.com/lycorp-jp/sim-use/blob/5b543dceaf0f146bdbdc949545a26633f3de62a7/docs/ai/010-display-routing/000-plan.md)保留类似方向报告无效果问题。结合本轮两App对照，后续应继续检查公共仿真控制/guest方向状态和读取面之间的交界；不凭通用 advisory 修改本产品方向掩码，也不把“换方向再请求”当隐藏失败的无限重试策略。

## XXXL 系统导入面板

英语，系统 extra-extra-extra-large（非 AX）。内屏实际951×669 pt，从可见 Import TXT 单次打开系统面板；首次采样仍是底层工作区，后续只读截图确认面板已经出现，没有重放点击。On My iPhone 列表显示为空。

面板保持打开闭合后，活动外屏 id1、portrait、466×678 pt；Search、关闭X等可见，系统栏位于右边。部分 AX 树只列 Search/Group、漏掉 X；按新鲜截图对应的418,198 pt只点一次 X，实际关闭并返回原稿。再展开内屏，两栏原文和结果均保持。外屏返回截图只显示原文，结果全文由 AX 与重新展开画面共同核对，不声称当时两栏同时可见。

本轮仅完成面板打开、姿态变化、取消和返回；**没有完成实际文件选择/读取或导入进行中切换**。87字节fixture已放入 QA 私有 Documents，但没有在当前列表可见或选中；安装包未声明 UIFileSharingEnabled / UISupportsDocumentBrowser / LSSupportsOpeningDocumentsInPlace，私有路径不等价于面板可见位置。未为测试修改产品能力或把“列表为空”直接归因成产品缺陷。

独立核对 **18份指定全文快照**，原文“鼠标里面的硅二极管坏了，导致光标分辨率降低。”与结果“鼠標裏面的硅二極管壞了，導致光標分辨率降低。”各22 UTF-16 / 66 UTF-8字节。指定列表见JSON；同一model/scene/两个UITextView身份保持，四次返回launch读回与初次PID一致。没有重启原App，亦不宣称选区/marked text或中段阅读通过。

## 保留的失败和工具边界

- bootstatus 返回0却写 Data Migration Failed；初次AX远程automation session超时。随后 sim-use UI 与新的 AX 观察确认App可用，再填示例并实际转换；没有把启动回执当就绪，没有重启共享服务。
- `home-control.py` 在Home后立即读到旧App，前置断言停止；后续只读观察才确认SpringBoard。`app-absent-control.py` 的最初全文前置检查遇到系统页而停止，**未执行其后终止App的实验**；不能把脚本里的计划命令当已执行。
- 名为 `normal-control.py` 的实验返回App时仍是横向，没有满足正常竖向前提，不能据此比较“正常状态官方 set”与失败状态。其余日志仍保留。
- `import-open-inner.mp4` 初始短片/截图采样早，未完整覆盖面板出现，不精选为打开全过程证据。原始记录保留，实际面板以之后明确显示屏截图确认。
- `probe-before.png` 在前台切换动画中，未当稳定布局截图上传。精选方向录像也沿用起始横向固定画布，末尾竖向内容侧置；真实竖向由独立截图/布局/显示读回证明。它不用于动画时序或流畅度指标。
- 独立校验脚本 `verify-controls.py` 默认只读，显式 `--write` 才写结果；其 passed 仅覆盖列出的观察，不将原探测/前置失败改写为通过。

## 精选证据与复跑

[Issue #282 补证评论](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6538792430)。七个附件上传一次，远端逐项字节/SHA-256均与本地副本一致，总计 **1,400,381字节**。

![App外屏未确认](https://github.com/user-attachments/assets/f9d9fc29-694e-4463-a838-e1135afff783)

![最小UIKit恢复竖向](https://github.com/user-attachments/assets/f4dc7ff7-de0d-4d96-bfc8-2cc7367ab6a0)

| XXXL内屏系统导入面板 | XXXL闭合后外屏面板 |
| --- | --- |
| ![内屏](https://github.com/user-attachments/assets/81a8c740-02e6-408e-945c-48352e3e310e) | ![外屏](https://github.com/user-attachments/assets/5ed50da3-8604-49ef-a0ca-f83700f996a8) |

![取消并重新展开](https://github.com/user-attachments/assets/8ce303a6-844a-420b-adf8-f467e8b14784)

方向恢复对照（固定画布，末尾内容侧置）：

https://github.com/user-attachments/assets/148f3f99-31a8-4dfb-9aa9-d2be4747b99b

XXXL外屏取消返回：

https://github.com/user-attachments/assets/30e8a92f-bdc8-4895-bc52-7d98f5bab5ba


五张 PNG 长边1600px，逐张核对文字、系统按钮和返回状态；两段完整原片生成 H.264/15fps/无音轨/长边1280px副本，先 setpts 归零再处理，实际视频轨起点均为0。方向片约6.73秒、取消片约3.73秒，均全解码无告警、完整播放到尾并读回时间轴，首尾帧另核对。取消片只含外屏关闭操作，不是连续双屏开合录制。没有产品视觉改版，不制造改版前后图。

仓库外保留 `diag.py`、方向探测、官方/Home/探针对照、录制与独立校验脚本，部分编排经主机stdin/CUA完成，不声称都有执行时脚本快照。复跑先检查指定UDID、初始状态、使用者、工具链和磁盘，再做有界序列；失败后先只读，任何下一次改变方向/前后台操作均单独记录。最小探针的完整source/Info/编译命令在JSON中，复制到新的仓库外目录时替换路径和明确设备，不操作他人实例。恢复后继续用实际显示ID及App窗口确认，不能只读orientation set/get回执。

## 收尾与剩余

恢复 large，closed/portrait 官方读回后终止QA App并指定UDID shutdown；最终所有设备 Shutdown。探针安装和源/二进制保留用于复跑，设备关闭后没有运行中占用。没有启动其他设备或杀共享服务。

上一轮未确认到尾的取消录像，本轮后续读回已到8.133秒且暂停，关闭后又见旧打开片，关闭它后恢复先前 before-return-gap 窗口；旧 Device Hub 的 Window 菜单仅列既有 BuZhan 窗口，本轮未新建Device Hub窗口或启动BuZhan。两份新录像均完整播放后，关闭导入录像及重新选择播放器发生超时，**本轮播放器窗口是否全部关闭未确认**，不盲关先前窗口。

只新增证据文档和仓库外诊断探针，不改App/工程/依赖/生产开关/容量，不重复产品构建。完整三语/default/XXXL/姿态/左右分屏/溢出/连续尺寸/普通导入转换进行中/IME/阅读/所有弹层任务矩阵，最终签名包及Duo真机仍未通过。最低系统#16、交易/RevenueCatUI #14/#71、容量及开放#260/#268不计通过，VoiceOver体验未验证。#280/#282不关闭，不分发或部署。
