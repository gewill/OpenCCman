# 原生姿态与真实文件保存补验（2026-10-29—30）

关联 #280 / #282，两项继续开放。本轮未确认需要修改产品代码的缺陷；
结果仅覆盖下列模拟器、英语和默认 large，不代替完整矩阵或最终签名包。
接续[输入、阅读与任务连续性](input-task-followup-2026-10-29.md)，
原生布局、原文／结果哈希、作业、保存文件及失败口径见[结构化证据](pose-file-followup-2026-10-30.json)。

远端精选证据：[原生姿态／设置返回](https://github.com/gewill/OpenCCman/issues/280#issuecomment-6502246435)、
[真实保存／非空稿件／受控转换中闭合](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6502276286)。
6 图、4 视频的副本哈希／字节数与复用 URL 已登记；正文回读无本机路径残留。

## #289 审核与合并

- 固定 HEAD `10e0d7ab54d9ed9ef0a5e613f97a920142e75c7e`，相对 `3a3855c` 审核三个文档文件。
  Standards / Spec 分别由独立只读子审查完成，均 0 项阻塞；主审另核对 99 份登记原件、
  20 个上传副本、六个候选变动源码哈希、JSON、相对链接及 diff 空白检查。
- 当前 HEAD 的 App Regression / App icon 均 success，无未解决 review thread。
  仓库单人维护约定不要求额外审批者；这不是外部 GitHub APPROVED review。
- 按 expected HEAD squash 合入 develop `bccf2614d591dfebd09dc25c2e96405bc29476e3`；
  单父提交且 tree 与审核 HEAD 完全相同。
  [合并后 push CI 40900726929](https://github.com/gewill/OpenCCman/actions/runs/40900726929)
  completed / success，App Regression、App icon 均通过。
  [审核及回读记录](https://github.com/gewill/OpenCCman/pull/289#issuecomment-6500748625)。

## 来源与 QA 配置分界

从干净的上述 develop 提交创建 `codex/282-import-save-followup`。
本轮 App／测试／工程源码未改，未执行新的 Xcode 构建；复用此前两端 delivery QA 包的 iOS 产物。
App、Tests、工程 Git tree 及六个候选变动文件哈希另列 JSON，确认 #289 只有文档变化。
Xcode 27.1 (27A9275)、devicectl 651.13.5、iOS Simulator 27.1，
隔离包 `org.gewill.OpenCCman.WhatsNewUITests` / 2.1(30)，
实际代码 `OpenCCman.debug.dylib` SHA-256 仍为
`f69b7bbea0700611e338f4bf5ee3116b07508c6d9e9967905abd1b063ba7534e`。

验收分成两个产物配置，不能混作同一个完整 bundle：

1. 原始冻结包，PID 49579：原生姿态、旋转、更多／设置／返回；原文／结果各 22 UTF-16。
2. 独立 QA 包副本，PID 55132：沿用
   [既有 UI 脚本](https://github.com/gewill/OpenCCman/blob/bccf2614d591dfebd09dc25c2e96405bc29476e3/scripts/check-whats-new-ui.sh#L76-L99)
   的前置，只在副本 Info.plist 设置 `UIFileSharingEnabled=true` 和
   `LSSupportsOpeningDocumentsInPlace=true`。141 文件清单仅 Info.plist 改变，dylib 完全相同。
   原包没有在 Files 暴露 QA Documents，空的本地目录不是导入缺陷。
   重装后数据容器路径改变，已重新查询并确认夹具保留。

文件场景适用于这个文档共享 QA 配置；不宣称正式包也提供相同的 App 本地目录。
生产／实验容量开关仍 false，仍沿用现有移动文件 QA 资格，不涉及购买或交易。
完成后已重新安装原始冻结包，141 文件清单完全恢复。未修改受控 Info.plist、构建配置或依赖。

## 本轮结果

| 范围 | 实际操作与结果 | 限制 |
| --- | --- | --- |
| 原生姿态 | Device Hub 实际 Closed 466×678 → Open 951×669 → Partially Open 951×669 → Rotate Right 669×951；非空原文／结果全文、模型、scene 和原生编辑器身份保持 | 英语／默认字号；是模拟器姿态，不是物理 Duo |
| 激活 division | 半展开宽态读到 active=true、frame [455.5,-82,40,669]；旋转后 [0,373.5,669,40] | frame 为 probe 本地坐标；仅证明区域激活，不代表全部正文控件避让完成 |
| 系统栏与路由 | 半展开旋转后实际 More 菜单包含 Editor layout / Pane sizes / Sidebar when wide / Help / Pro / Settings；实际 Settings，保持设置页时 Closed，再 Back，回到原 22 字稿件／结果 | 只执行 Settings / Back；未把菜单其余项目可见写成已执行。路由后不声称编辑器实例相同 |
| 普通导入 | 从非空稿件实际 Files 选择 59 字节 UTF-8 夹具；正确替换原文，旧结果／导出快照清空 | 既有 2 秒导入延迟；下面两次尝试未证明“导入进行中跨尺寸／开合”，保持未通过 |
| 普通结果保存 | 实际 Convert，再在系统 Files 保存 `duo-import-save-20261029-converted.txt`；新文件 59 字节，全文等于预期，SHA-256 `74cab6b6…94e09e` | 保存前确认目标不存在，未覆盖既有文件；仅本地 QA provider |
| 64 MiB 非空稿件流程 | 67,108,877 字节输入通过真实 Files 进入确认、转换、Ready；Ready 时闭合／再展开，同一结果继续可保存。实际系统 Save 后完整输出哈希正确、源文件未变、任务缓存为空 | 录像显示 **Ready 先于闭合**；不计转换中开合 |
| 99 MiB 转换中真实开合 | 既有 103,809,021 字节合法输入；同次 CUA 调用内实际 Convert → 读到 Converting 4% → 立即 Closed → 读到 Converting 50%；随后 Ready、再展开并实际系统 Save | 没有转换延迟钩子；使用较大合法输入只为观察动作，不是容量／性能矩阵。原生跨显示的连续录像不完整 |
| 非空稿件与资源 | 文件流程前、确认、Ready 闭合态、保存返回及最终闭合态，原文／结果均 21 UTF-16 且全文哈希相同；两项移动任务前后普通计次均为 `2026-10-29:5`；各自资源 begin/end 成对、结束时均释放且 app_active=true | 不把普通文本导入替换原稿的预期行为混入“稿件不变”；没有验证保护数据或真实后台 |

99 MiB 作业 ID `9D6CEB6A-EFDA-4563-8A56-F67C256F4FA5`，配置 rawValue=1；
完整 provider 输出 103,809,021 字节，SHA-256
`a710af359be8cf04aa4cf5ca4bc23865a4e6e2c6bdf2813d66f68ecb08f48602`。
64 MiB 完整输出 SHA-256
`0db3774607c8a773d848ddae3cffc85f779adc4306443b5c2c41e170de10b072`。
两者均独立读取系统实际保存文件比对，保存后任务目录无文件；实际保存原件另复制到仓库外证据目录。

## 失败与降级，不计为完整通过

- 首轮导入 observer 虽收到 950×669／400×750 的成功响应，快照仍先是 669×951，
  到 950×669 时导入已结束；`both_sizes_during_import=false`。
  原始脚本的 observed 只说明采集到状态，不是这个验收项通过。
- 第二轮“选文件后立即闭合”记录到 669×951 → 678×466，但 importing=true 只出现在后者，
  表明文件选择回调晚于闭合；只计文件面板开合后导入成功，不计导入中开合。
- 可调窗口停止后一次 CLI start 报 24001“没有前台应用”；同 PID 重新激活后可继续。
  旧画面／后台 AX 内容不能单独作为前台可交互证明。
- 混用 GUI / CLI 尺寸控制时出现黑屏，以及 GUI 宽高、原生窗口和采集画布不一致。
  原因未定位，不归因 App、不按命令成功计通过；结束该会话后改用实际姿态控件。
- 一次只读 LLDB 采集 25 秒超时，没有拿到原生快照，不用于结论。
  本轮后续使用现有只读 QA trace、App 原生 AX、实际 GUI 和文件结果，未注入状态。
- AXe More 返回成功未建立菜单，改用实际 GUI 指针并核对页面；没有按返回值算通过。
- bootstatus 报 Data Migration Failed，后续目标已 Booted 且 App 实际运行；不把 bootstatus 写为成功。
- 对 inactive display 启动的部分 recorder 没有产出媒体；屏幕开合期间原生单显示录像有黑帧／缺口。
  99 MiB 的动作前后 AX 与结果证明转换未因本次闭合停止，不能提升为完整跨显示视频验收。

## 可复跑依据

按[本机 27.1 构建入口](../../CI.md#iphone-duo-的本地-271-构建入口)准备同源码隔离 QA 包，
核对实际 dylib／bundle 清单；原生姿态场景先用原包，文件场景再按既有脚本建立仅两项 plist 不同的副本。
每次重装后重新查询 data container，不沿用历史 UUID。
预期行为对应固定候选的
[导入状态与替换](https://github.com/gewill/OpenCCman/blob/bccf2614d591dfebd09dc25c2e96405bc29476e3/OpenCCman/Scene/HomeViewModel.swift#L363-L425)、
[移动文件门控](https://github.com/gewill/OpenCCman/blob/bccf2614d591dfebd09dc25c2e96405bc29476e3/OpenCCman/Services/MobileFileRuntime.swift#L8-L44)、
[作业启动与完成](https://github.com/gewill/OpenCCman/blob/bccf2614d591dfebd09dc25c2e96405bc29476e3/OpenCCman/Services/MobileLargeFileCoordinator.swift#L134-L177)；
源码本身不替代运行结果。

- 普通导入使用 `导入中的汉字与软件。🌏\n保留换行和末尾。`，UTF-8 59 字节；
  预期普通转换输出 `導入中的漢字與軟件。🌏\n保留換行和末尾。`。
  `-qa-delay-import` 仅延长真实导入以便观察，不是自然耗时证据。
- 移动文件沿用 `-qa-enable-mobile-large-files -qa-mobile-file-pro -qa-mobile-file-resource-trace`；
  不传 `-qa-import-mobile-file`，从已有非空原文／结果通过实际 Files 选择文件。
  输入重复 UTF-8 单元 `汉字转换🌏\n`，17 字节，分别重复 3,947,581 / 6,106,413 次。
  输出单元 `漢字轉換🌏\n`，记录全文哈希、Ready journal、普通计次和资源事件。
- 受控开合在一次 UI 调用中先确认 Converting 再 Closed；动作后必须再次看到 Converting，
  不能仅凭“点击前曾在转换”推断切换发生于转换中。保存后另读 provider 文件和任务目录。
- 不同时让 GUI / CLI 各自建立并控制会话；这只是本轮失败后的实验约束，未作为跨项目工具规范发布。

## 继续开放与收尾

仍缺完整姿态／方向 × 三语 × 默认／XXXL × 动作矩阵、系统左右分屏、完整溢出和 division 关键动作；
普通导入进行中跨几何、其他结果过期／导出组合、移动 Preparing／Cancelling 中开合、保护数据、
冷启动交接及正向未读 What's New（当前 2.1 无卡片），均不因本轮局部结果关闭。
文件保存只覆盖本地 QA provider；正式签名配置、其他 provider 和 Duo 真机仍需独立验证。
最低系统留 #16，交易留 #14 / #71，生产开放／容量留 #260 / #268；VoiceOver 体验未验证。

已保存日志、实际文件和 UI 原件，精选副本独立压缩、完整播放并回读远端附件。
恢复原始 QA bundle 141 文件清单、large、GUI resize off，结束本任务 recorder／App，
指定 UDID `4CAD3041-0744-41A6-8B4E-F934CA9F0778` shutdown 后重读确认 Shutdown。
只对该 UDID 执行关闭；初始其他 Booted 设备在收尾时已非 Booted，本任务未操作它们。
共享 Device Hub 保留并恢复原侧栏选择。未分发、部署或提交商店。
