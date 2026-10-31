# 方向通知对照与真实文件导入补验（2026-10-31）

关联 #280 / #282，保持开放。英语默认字号与 XXXL 新增**标准系统文件面板实际选择、导入、旧结果失效、展开保持及单次转换**。方向未确认仍复现；同值报告连接保持6秒仍无效，换值后才变化，**具体内部忽略层和去重机制未定位**。本轮没有需要修改产品代码的新缺陷。

## 合并、构建与工具来源

#296 的审核 HEAD `e590d94036b2d34f75999d9cce2a35578b064938` 未变，既有独立 Standards / Spec 各零发现；重读无审核提交或未解决线程，App Regression / App icon 均 SUCCESS（run `41167409485`）。按该 HEAD squash 合入 develop **`0d5a6e5ce88d95d8e582ebbad000248bd37df34e`**，单父 `9c71b9f9684f8c66c69ac6cee791b4d89e757d69`、完整 tree `59646f52cf274bb7a2d8b5e0de9a2d29b5d347d6` 与审核 HEAD 相同、远端一致。[精确合并提交 push CI](https://github.com/gewill/OpenCCman/actions/runs/41168079130) 两项均 SUCCESS。可选手动诊断跳过不计通过，本地审核不是外部 GitHub APPROVED。

验收从干净的上述提交开始，证据目录沿用审核 HEAD 名称，实际来源以 JSON 绑定为准。复用[既有 QA 产物](route-return-followup-2026-10-30.md)：App tree `a9bc63c6f8f6ea12ea3b497c5528cb4bf35a0637`、工程 tree `44b0dad8d0d71e3912dea0f65eb1fe4a6e2ac495`、安装 dylib SHA-256 `a28c756e35b1e7e54b8160e3e50ca77b6531518340d516cb45c424a04d7e2bd3`。产品仍为 Xcode27.1 (27A9275) / iphonesimulator27.1、Debug 2.1(30)、`org.gewill.OpenCCman.WhatsNewUITests`，没有修改或重建产品。

主机 macOS27.2 (26B123)，进程级 Xcode27.2 (27B52) / devicectl651.32，sim-use0.16.0、AXe1.8.0；全局 xcode-select 未改。专用 Duo `4CAD3041-0744-41A6-8B4E-F934CA9F0778`，iOS27.1 (24A94425)，初始 Shutdown、其他设备也无 Booted，仅启动这一台；磁盘保护下限12GiB。仓库外新建 UIKit 方向/文件提供探针使用 **27.2 Simulator SDK**，目标 iOS15/arm64；不把运行工具或探针 SDK 当产品 SDK。

## 方向：报告、通知与布局分开看

先核对[最新发布](https://github.com/lycorp-jp/sim-use/releases/tag/v0.16.0)仍为0.16.0；[固定实现到当前 main 的差异](https://github.com/lycorp-jp/sim-use/compare/5b543dceaf0f146bdbdc949545a26633f3de62a7...c02295edfd2f442249b869096dda3dc7bfcd308d)只涉及发布签名/说明等，没有方向实现修复。未升级或替换已安装工具、插件或 Skill。

本轮独立 UIKit 探针增加 UIDevice 方向通知与布局 JSONL，并明确返回支持 mask26。它不含 OpenCCman 业务；新增观测可能影响时序，结论只覆盖本次配置，不比较历史失败率。

1. 省略内屏竖向请求的有界序列（最多6组/180秒）实际6组、约61.26秒，闭合时外屏已为rot0；之后 portrait 的 confirmed=true **不算六次真实外屏旋转**，不能据此消除旧失败。
2. 另一个有界序列加入内屏 portrait：open → inner portrait → half130 → closed → cover portrait。前三组完成，第四组内屏 portrait 未确认；17条命令、约67.97秒后停止变更。接着13次连续官方 displays 只读查询，跨度7.461227秒，始终活动id3、rot90 / landscape-left，未锁屏。不是整个序列/矩阵通过，也不证明与历史外屏失败同一内部原因。
3. 在该失败状态，使用仓库外宿主 helper 的同一 vendor 格式，**每次只发一份报告，连接在 barrier 回复后保持6秒**。内屏目标portrait对应的原始provider值为landscape-left；不能把原始值名称直接当界面方向。如下表。

| 输入/阶段 | 独立显示与探针结果 | 结论边界 |
| --- | --- | --- |
| 再发同值，保持6秒 | rot90、951×669、interface4；JSONL仍81条，最后一条完全不变 | 本例加长固定连接时间仍无效；barrier成功不证明guest消费，不能宣称已排除全部传输时序问题 |
| 换为landscape-right，保持6秒 | rot180、669×951、interface2；84条 | 原先假设“mask26不接受倒置，所以界面不会改变”被实测否定；不能拿此步证明恢复不需要中间界面变化 |
| 回到原值，保持6秒 | rot0、669×951、interface1；85条，出现新的方向通知 | 本次新值后原目标恢复；仍未证明哪个组件去重/丢弃同值，也不是永久修复 |

探针的 `UIDevice.orientation`、`UIWindowScene.interfaceOrientation` 与 CoreDevice `displays.orientation.currentDeviceOrientation` 分别记录；它们可能属于不同参考系，不因数字/名称不同就认定某个API缓存错误。没有凭通用 advisory 改产品方向掩码或增加盲重试。

宿主 helper 仅用于明确 UDID 的私有 CoreSimulator/XPC 桥接对照，未编入或分发到产品。其 wire格式参考[固定上游 VendorDefinedHID](https://github.com/lycorp-jp/sim-use/blob/5b543dceaf0f146bdbdc949545a26633f3de62a7/Sources/iOSSimBackend/HID/VendorDefinedHID.swift)；完整源码、编译命令、二进制哈希及 Apache2 LICENSE / NOTICE 随 JSON 保存。它的三次 barrier 成功是发送/同步层证据，实际效果仍由日志、布局与画面判断。

## 真实文件导入：英语 default / XXXL

[#296 的列表为空](orientation-controls-followup-2026-10-31.md)没有被当成 App 缺陷。按 [Apple File Provider 的本地共享规则](https://developer.apple.com/documentation/fileprovider)，仅在独立探针 `org.gewill.OpenCCman.OrientationInputQA` 声明 UIFileSharingEnabled 与 LSSupportsOpeningDocumentsInPlace，并由其生成自己 Documents 中唯一的87字节输入；诊断日志留在tmp。**没有给 OpenCCman 开共享能力，也没有把其他私有QA文件暴露到浏览器。** 提供方进程结束后，系统面板实际显示 Duo QA Input 文件夹和文件。

原产品沿[标准 fileImporter 回调](https://github.com/gewill/OpenCCman/blob/0d5a6e5ce88d95d8e582ebbad000248bd37df34e/OpenCCman/Scene/HomeScene.swift#L59-L64)接收选择URL，没有使用 QA 导入路径参数或直接写 ViewModel 文本。输入为 `Duo import 20261031` + 换行 + 固定简体示例 + 换行，文件SHA-256 **`28d55e93ef72a9d44f34c8e47ef83c5d4c1d414164212a0acfca4cab65d8dd1c`**；其内容/87字节在实际提供方路径完整核对，结束后仍一致。

| 场景（两档各一轮） | 实际操作与结果 |
| --- | --- |
| 面板内外屏切换后选择 | 内屏669×951打开Importer；默认字号先进入Duo QA Input文件夹，XXXL直接恢复该目录。保持面板闭合至外屏678×466，在新鲜画面的唯一87字节条目上单次选择；没有按动作回执直接判通过 |
| 导入完成、尚未转换 | 实际原文替换成新文件全文43 UTF-16 /87 UTF-8字节，完整文件名显示；旧结果为0长度、Export disabled。符合[replaceSource清空旧结果/快照](https://github.com/gewill/OpenCCman/blob/0d5a6e5ce88d95d8e582ebbad000248bd37df34e/OpenCCman/Scene/HomeViewModel.swift#L318-L325)与[Export快照门控](https://github.com/gewill/OpenCCman/blob/0d5a6e5ce88d95d8e582ebbad000248bd37df34e/OpenCCman/View/WorkspaceComponents.swift#L249-L254) |
| 未转换态重新展开 | 新稿和空结果保持，同一model/scene/两UITextView身份；不是导入/转换正在运行时切换 |
| 实际单次转换 | 仅一次Convert得到完整预期繁体结果43 UTF-16 /87 UTF-8字节，Export enabled；两档QA偏好计数均为导入前1→导入后1→转换后2，未自动/重复计次 |

指定 **16份全文/trace快照** 独立核对，名单见JSON；每档内模型、scene、两个编辑器身份保持。两档之间刻意终止/重启QA App复位夹具，模型不同，不声称跨重启保稿。默认/XXXL为系统large / extra-extra-extra-large，非AX档位。

结果字符串 SHA-256 **`c161427b1f0a90f0147c79e73ee248c19a595dfc5da4850e0f1712af4605c907`**，这是AX全文所得的字符串校验，**不是本轮已保存的导出文件**。没有重复 #295 的保存验收，也没有验证I/O或转换执行中的开合。XXXL系统网格缩略文件名，目录只有一项；选择后App内完整文件名、全文正确，不扩大为多个相似文件名辨识通过。外屏截图/选择视频未同时显示结果区，结果由原生全文与展开后画面共同证明。

## 失败、校验和媒体边界

独立 `verify-hid-import.py` 默认只读，只有显式 `--write` 才落报告；passed仅覆盖指定观察，不覆盖原harness整体或根因结论。

- 新提供方启动后立即读fixture曾未找到；在明确UI就绪后只读确认87字节，无重新安装、重放业务。
- 首次default选择已经成功，但harness将空编辑器AXValue=null与空字符串直接比较，14次只读均见新稿/空结果后停止在转换前。保留初版helper；后续只归一空AX值，并以native trace result_characters=0、Export disabled交叉核对，从当前已导入状态继续，**没有再选文件**。修的是测试读取逻辑，未改产品。
- 省略内屏请求的六组没有真实外屏旋转；倒置不改变界面的预期被否定。没有删除不利结果、把独立校验写成原探测成功，或把更长固定等待当修复。
- 系统面板AX曾为空/漏项；坐标仅在明确活动显示屏、新鲜画面和唯一测试条目下使用，动作后以实际业务状态验证。部分早期编排经stdin/CUA完成，不声称都有完整执行时脚本快照；实际辅助脚本、动作日志与失败摘要保留。

[Issue #282 补证评论](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6539164772)。九附件上传一次并复用链接，远端逐项字节/SHA-256一致，共 **1,473,742字节**。

![诊断探针最终竖向](https://github.com/user-attachments/assets/51b63451-82d2-40dc-a864-6fcfaa15e894)

| 默认字号外屏选择前 | XXXL外屏选择前 |
| --- | --- |
| ![default](https://github.com/user-attachments/assets/34002117-8fb2-456b-b1d3-43c601496c79) | ![XXXL](https://github.com/user-attachments/assets/db8b389b-bbf9-4d08-afcd-37771210320f) |

| 默认字号导入后转换 | XXXL导入后转换 |
| --- | --- |
| ![default](https://github.com/user-attachments/assets/b890a9f8-ecdd-4408-a221-bdd2c4bda71b) | ![XXXL](https://github.com/user-attachments/assets/1c82bc6f-ce5a-46d8-bc80-bc7b1cc33d1d) |

方向连接/换值完整对照（末尾侧置）：

https://github.com/user-attachments/assets/bdb26d76-7681-47fe-bcf7-a5f4c64510fb

default选择并导入（前6秒）：

https://github.com/user-attachments/assets/dee4ca2e-93dd-447e-9388-9af2ea1f7e23

XXXL选择并导入（完整）：

https://github.com/user-attachments/assets/7c61cd58-0809-428e-81eb-8b22507670ae

XXXL单次转换（完整）：

https://github.com/user-attachments/assets/ae2ee812-fdf9-41c9-bb20-495a4c48f8b3



五张PNG长边1600px，逐张核对文字、文件名、按钮和返回结果；四段H.264/15fps/无音轨/长边1280px副本，全解码无告警、完整播放到尾读回时间轴，并核对首尾帧。方向对照完整25.6秒；default选择仅取归零时间戳后的前6秒，包含选择和导入返回，后续错误等待保留在原片；XXXL选择约4.33秒、转换4.4秒完整。它们是串行切片，不是连续双屏开合视频。方向片固定于起始横向画布，最终竖向内容侧置；真实姿态以独立截图/原生读回确认，不作动画时序/帧率指标。

## 复跑、收尾与剩余

先核对源码/产物哈希、指定UDID、初始状态/使用者、进程级工具链和磁盘。按仓库外脚本的有界序列，在首次未确认后停止变更并只读；明确区分报告值、barrier回执、方向通知和实际界面。诊断helper完整源与Info/命令在JSON，复制到新证据目录需替换路径；它不是产品支持方案，不用于他人设备。

导入重跑以独立QA提供方生成同一87字节文件，经正常面板逐项观察、选择，再读原文、结果、文件名、Export状态和QA计数；等待偏好落盘只读，不用重放动作追值。仍保留未实测：完整三语/姿态/左右分屏/溢出/连续尺寸、I/O及转换进行中切换、完整IME/阅读/全部弹层任务矩阵、最终签名包与Duo真机。最低系统#16、交易/RevenueCatUI #14/#71、容量和生产开放#260/#268沿原Issue，VoiceOver体验未验证。

本任务探针在产品验收前已终止；结束时恢复large，实际读回closed/id1/portrait后终止QA App并指定UDID shutdown，最后所有设备Shutdown。全部录制已结束。四个本轮QuickTime窗口已逐个关闭并读回原before-return-gap窗口，原窗口保留；上轮残留probe-recovery窗口也按明确归属关闭，本轮未新建Device Hub窗口或中断共享GUI/服务。探针安装/夹具与仓库外证据保留供复跑。

只更新证据文档，不改App/工程/依赖/容量/生产开关，不重复产品构建。当前文档PR的CI/审核独立记录；#280/#282不关闭，不分发或部署。
