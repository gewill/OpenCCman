# 输入、阅读与任务连续性补验（2026-10-29）

关联 #280 / #282；两项继续开放。本轮未复现需要修复的产品缺陷，仅新增验收记录。
本记录接续[本机验收与窄窗修复](local-acceptance-2026-10-29.md)，不覆盖其未验证边界。
精简原生快照、业务结果、失败摘要及原件 SHA-256 见[结构化证据](input-task-followup-2026-10-29.json)。

远端精选媒体与逐项结论：[用户中心／Mac 入口](https://github.com/gewill/OpenCCman/issues/280#issuecomment-6497095933)、
[输入／阅读／普通转换](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6497120076)、
[移动文件中断／错误态](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6497162622)。
全部附件正文已回读，副本哈希／字节数／复用 URL 记录在 JSON；不在正文保留本机媒体路径。

## 候选与 CI

- #288 已 squash 到 develop `3a3855c2d298ed91db66afe5ac15a1f0dacfeb92`；
  [合并后的 push CI 40862993653](https://github.com/gewill/OpenCCman/actions/runs/40862993653)
  为 completed / success，App Regression、App icon 均 success，其他按条件跳过。
- 本轮开始时工作区干净，App / 测试源码无改动。复用上轮两端 delivery build 的隔离 Debug QA 2.1(30)，
  Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`。原构建发生于 `f6f06e4` 的脏候选：
  该候选改动的六个源码／测试文件 SHA-256 已逐一与本次提交核对相同，其余源码由 Git 差异确认未变；
  不把原构建基线 `f6f06e4` 冒充完整候选身份。
- 实际执行代码 `OpenCCman.debug.dylib`：iOS
  `f69b7bbea0700611e338f4bf5ee3116b07508c6d9e9967905abd1b063ba7534e`；Mac
  `9f226919e7e888996cc2c0f0b34bf94c720d048006f5979dd303e101cbd0da9e`。
  CFBundleExecutable 是启动壳，未仅以它判断代码身份。已安装 iOS bundle 的 141 文件清单与冻结包完全相同。
- Xcode 27.1 (27A9275)，`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`，
  devicectl 651.13.5，AXe 1.8.0。Duo 专用模拟器 iOS 27.1，
  UDID `4CAD3041-0744-41A6-8B4E-F934CA9F0778`，初始 Shutdown。
  本轮没有重建 App，没有分发签名、TestFlight、交易或部署。

## 实际运行结果

除 Customer Center 另验 XXXL 外，新增场景均为英语／默认 large。
尺寸为 App 原生窗口实测点数；宿主可调窗口不等同物理内外屏、折叠姿态或系统左右分屏。

| 场景 | 前置与操作 | 实际结果及适用范围 |
| --- | --- | --- |
| 中文 IME marked text | 在真实软键盘选简体拼音，逐键输入 nihao；保持未提交，原生→950×669→400×750→中间尺寸→原生 | 同一 scene / UITextView、焦点、marked=true、[28,0] 光标及全部 28 UTF-16 保持。请求 720×600，UIKit 实测 **720×540**；返回 466×678 后仍保持。实际点候选“你好”、收键盘并转换后，原文／结果各 24 字且全文正确 |
| 非零选区 | 双击“二极管”实际选中 [6,3]，原文／结果各 24 字；466×678→950×669→400×750→466×678 | 同一 scene、原生编辑器、焦点、[6,3] 选区和两份全文保持；不是仅验证空选区或开头光标 |
| 中段阅读位置 | 120 行编号合成文本，2879 字；实际粘贴、转换、结果 Scroll Down 4 次 | 全文等于预期；宽态 offset 1444→窄态 1598→宽态 1444，首个完整可见行仍为第 67 行（第 66 行部分可见）。同一编辑器，换行改变时保留本次阅读锚点；不代表任意位置都通过 |
| 普通转换中缩放 | 22 字非空原文、非 Pro、日计数空；既有 QA 2 秒延迟；实际 Convert | busy trace 真实经过 466×678、950×669、400×750，同一模型／scene／编辑器；最终全文正确，busy false→true→false，日计数仅变为 1。延迟用于观察状态，不作为吞吐或 C++ 长任务性能结果 |
| 移动文件取消 | 67,108,877 字节合法 UTF-8；实际观察 Converting，再 GUI Cancel | Task stopped；源 SHA 保持，无 ready／store 文件，资源 begin/end 成对且后台任务、idle override 全部释放 |
| 移动文件真实后台 | 同一合法输入，实际 Convert→Device Hub Home→重开 | 开始时 Converting；after_end 的 app_active=false 且资源全部释放，重开 Task stopped。终态未单独保存完整 store 目录快照，不从后续场景倒推当时目录为空 |
| 移动文件真实锁屏 | 103,809,021 字节合法输入，实际 Convert→Controls / Lock→返回 App | 看到锁屏、app_active=false、资源全部释放；返回 Task stopped，源 SHA 保持，无 ready／store 文件。仅未见密码提示，密码配置未查询；没有 protected-data-unavailable 通知，不代表保护数据／解锁恢复通过 |
| 非法 UTF-8 与错误态缩放 | 合法 64 MiB 文件末尾加 0xFF；实际转换；重启模拟器后错误态 950×669→400×750→466×678 | 明确报 invalid UTF-8，错误与 Retry recovery 保持；实际 Retry recovery 清除错误，再 Done 回首页。恢复扫描没有重新转换坏文件；此前源 SHA 与空 store 已核对。此项是失败终态缩放，不是 Preparing／Cancelling 中缩放 |
| Customer Center | 非空 22 字原文／结果；More→Settings→Customer Center；large、XXXL 分别宽→窄→原生 | 实际呈现 No subscriptions found，Dismiss 可达；实际 Dismiss→Settings→Back，原文／结果全文保持。导航重建原生编辑器，不宣称其身份跨路由保持；未触发购买、恢复或 Copy |
| Mac 零主窗口命令 | 同一隔离进程，Cmd-W 后用只读 AppKit 确认可见主窗口为 0、App active；再分别 ⌘, / ⌘P | 两次均重开 1 个主窗口并进入对应 Settings / Pro；Back／Restore 可见，未操作 Restore。有前后窗口计数、AX 和截图，**没有从零窗口到重开全过程录像** |

移动文件均沿用既有 `-qa-enable-mobile-large-files -qa-mobile-file-pro -qa-mobile-file-resource-trace`，
首页稿件为空，不宣称非空稿件在这些用例中保持。生产／实验容量开关仍 false。
99 MiB 输入只为留出执行锁屏菜单的时间，不扩展容量／性能矩阵。

## 源码依据与可复跑步骤

固定候选源码：
[普通转换及既有 2 秒 QA 延迟](https://github.com/gewill/OpenCCman/blob/3a3855c2d298ed91db66afe5ac15a1f0dacfeb92/OpenCCman/Scene/HomeViewModel.swift#L257-L285)、
[移动文件 QA 门控和资源记录](https://github.com/gewill/OpenCCman/blob/3a3855c2d298ed91db66afe5ac15a1f0dacfeb92/OpenCCman/Services/MobileFileRuntime.swift#L8-L44)、
[真实后台／保护数据通知处理](https://github.com/gewill/OpenCCman/blob/3a3855c2d298ed91db66afe5ac15a1f0dacfeb92/OpenCCman/Services/MobileFileLifecycle.swift#L48-L68)、
[移动文件错误与恢复 UI](https://github.com/gewill/OpenCCman/blob/3a3855c2d298ed91db66afe5ac15a1f0dacfeb92/OpenCCman/View/MobileLargeFileTaskView.swift)、
[Mac 命令入口](https://github.com/gewill/OpenCCman/blob/3a3855c2d298ed91db66afe5ac15a1f0dacfeb92/OpenCCman/OpenCCmanApp.swift#L97-L108)、
[窗口重开／延后通知](https://github.com/gewill/OpenCCman/blob/3a3855c2d298ed91db66afe5ac15a1f0dacfeb92/OpenCCman/AppDelegate.swift#L127-L160)。
源码解释预期，运行记录才证明本次结果。

1. 按 [CI 文档](../../CI.md#iphone-duo-的本地-271-构建入口)准备同源码 QA 包，
   先核对工具版本、目标 UDID、初始状态及占用，记录实际 bundle 和 dylib 哈希。
   单独复用一个专用模拟器，默认字号 large；不安装到正式 App 数据域。
2. 输入样例为“鼠标里面的硅二极管坏了，导致光标分辨率降低。”；
   通过系统键盘配置真实简体拼音，再逐键输入 nihao。
   用只读原生查询记录 markedTextRange、selectedRange、isFirstResponder、全文哈希、scene 和编辑器身份。
   marked 状态不由 setter 构造；通过实际候选点击提交“你好”，最后与转换全文比较。
3. 宿主 start 950×669、set 400×750、请求 720×600、结束会话；
   每一步都另读 App 实际 window。预期与实测不符时保留脚本失败，按实际尺寸记录观察。
   复现非零选区时省略中间尺寸，最终必须等原生窗口实测回到 466×678。
4. 阅读样本按 `第001行：汉字转换，鼠标里面的硅二极管坏了。` 至第 120 行生成，以换行连接；
   通过 App 粘贴按钮和实际 Allow Paste 导入，全文比对转换预期。
   使用真实 Scroll Down，再记录第一个完整可见行、offset、全文和编辑器身份。
5. 普通转换以既有 `-qa-delay-conversion` 启动；等待 native busy 后才开始缩放，
   仅在任务期间读取已有 QA trace，完成后核对全文和日计数。未在 busy 期间挂 LLDB。
6. 移动文件使用自有合成 UTF-8 文件；资源事件按 before_begin / after_begin / after_end 核对。
   将夹具放入隔离 QA 沙盒 Documents，以 `-qa-import-mobile-file <沙盒绝对路径>` 进入真实确认页，
   同时使用上文三个 QA 参数；原文重复单元为 `汉字转换🌏\n`（UTF-8 17 字节），
   64 MiB 与 99 MiB 夹具分别重复 3,947,581 / 6,106,413 次，字节数和哈希见 JSON。
   取消、Home、Lock 必须看到真实页面／应用状态及业务终态，不以 AXe 返回替代。
   非法输入用同一合法文件追加单个 0xFF；恢复入口的扫描不等于重转成功。
7. Mac 各入口分别关闭主窗口，读 `NSApp.windows` 的 visible / canBecomeMain 计数及 active；
   零窗口计数与命令之间不调用会激活／重开的 UI 观察。随后命令、再读窗口计数并核对目标页面。

原生 LLDB 查询只读，不设置稿件、marked、选区、offset 或窗口；完整日志保留查询及编译错误。
外部采集脚本与原件在结构化证据中逐文件登记 SHA-256。

## 失败、环境限制与证据边界

- IME 两次采集脚本把 720×600 当成原生实际尺寸，分别超时／断言失败；
  CoreDevice 响应虽称 720×600，UIKit 实测为 720×540。保留失败，只有实测尺寸的状态连续性计入。
- 远程 AX setValue 曾只改变代理值、没有改变 UITextView；该准备步骤废弃。
  最终实际 App Paste／Allow Paste 后全文与夹具一致。一次宿主剪贴板时序不一致的准备也未计入。
- 多次 AXe 自动 tap 没有建立可观察的 converting；改用 Device Hub GUI 并确认真实进度，原因未确定。
  AXe Home 返回后仍在前台的一次任务不算后台验收，其正常完成输出另做全文哈希对照。
- 实际锁屏后的返回可见且可操作，但 CoreDevice 仍报 locked 24001；
  后续 set 又报无会话 24003。lockState 查询在该设备不受支持（1001）。
  不宣称划动已恢复 CoreDevice 解锁状态；关闭并重启本任务模拟器后才成功补验错误态缩放。
- 普通转换第一轮 observer 先缩放，实际 Convert 未触发，busy 超时；未计通过。
  后一轮先等待 native busy 的受控观察单独通过。Mac 首次观察可能重开窗口的尝试也未计通过。
- Customer Center 公共副本遮盖 QA 匿名 User ID；原件独立保留。
  视频不加速、无音频，压缩副本 15 fps 仅供动作展示，不用于帧率／性能判断。
  宿主虚拟录屏固定起始画布，窄态底部可能被裁去，完整窄态 PNG 补充；不能据视频宣称全屏可见。
- 所有媒体位于仓库外，原件与副本独立；上传副本以 SHA-256 登记并复用远端 URL。
  Mac 零窗口用例缺连续录像已单独标明。没有因截图可见而扩大交互通过范围。
  已在当前授权 GitHub 会话确认新图片实际加载、视频 readyState=4；未声称匿名访问权限通过。

## 继续开放的验收

本轮缩小了缺口，未满足 #280 / #282 的全部关闭标准：

- 实际内外屏、旋转、书本／桌面姿态、激活 division、左右系统分屏和真实溢出菜单矩阵；
  本机未执行的系统姿态不写成“工具不支持”。
- 完整姿态 × 英／简／繁 × 默认／XXXL × 动作矩阵；本轮 Customer Center 双字号不替代全矩阵。
- 普通导入进行中、其余配置过期／导出可用性组合；移动文件 Preparing／Cancelling 中缩放、非空稿件全程保持。
- 密码保护数据不可用／解锁恢复，冷启动转场与正向未读 What's New，真实 provider 成功保存。
- 最终签名分发包及 Duo 真机；最低系统 #16、交易 #14 / #71、生产开放与容量 #260 / #268 继续独立。
  VoiceOver 体验未验证，不新增专项门槛。

## 收尾

已恢复专用模拟器 large、原 English (US)／Emoji 键盘列表、Capture Keyboard off 和原设备剪贴板，
终止本任务 App、录制和宿主缩放进程，指定 UDID shutdown 后重读确认 Shutdown。
其他项目的 Booted 设备 `834B95AE-438F-4D77-B189-F489C1F50346`、共享 Device Hub 均保留。
本轮启动的隔离 Mac QA PID 29001 已退出；自己的合成夹具保留用于复跑。
未批量关闭模拟器、未触碰用户稿件或正式 App。
