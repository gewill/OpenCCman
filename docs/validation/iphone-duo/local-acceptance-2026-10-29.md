# Duo 本机验收与窄窗修复（2026-10-29）

关联 #280、#282；延续 #287 合并后的剩余验收，不是 Issue 关闭记录。

## 候选与修复

#287 的 HEAD `3524d9a6f6e46aee0cb1395336415881f584176b` 两项检查通过，本次源码／证据审核无阻塞，
无外部正式 APPROVED。Squash 后 develop 提交为 `f6f06e4c85f8f4351bf7081602bd1af11e297076`，
与候选 tree 一致；[推送 CI 40837625119](https://github.com/gewill/OpenCCman/actions/runs/40837625119)成功。

在这个基线上，本机 Mac 150% 文字、窄窗口（原图 1496×1758px）中发现导入说明高度压缩：
末尾容量说明显示省略号。第一处应用改动是 `WorkspaceComponents.swift` 的 `fileImportHint`
增加 `.fixedSize(horizontal: false, vertical: true)`，按实际换行高度参与布局。
相同英语、150%、窗口尺寸、22 字原文／结果的前后截图确认说明完整显示；没有缩字。
随后普通 iPhone XXXL 英语菜单中，原 `Conversion sidebar when space permits` 被系统菜单截断；
仅将英语标题缩为 `Sidebar when wide`，保留宽度条件，简繁原文完整可读而未改。
Mac 最小窗口的 More 进入系统溢出菜单后，原工具栏绑定的 ⌘, 不再打开设置，应用菜单也缺少设置项。
同一条件下 ⌘P 也不打开 Pro。新增常驻 Settings（⌘,）和 Pro（⌘P）命令，复用既有
`AppDelegate.postWindowNotification` 的窗口归属／等待就绪机制，并移除 Mac 工具栏的重复绑定；
iOS 的键盘绑定保留。RootView 仅对目标窗口导航，已在相同路由时不重复进入，以保留阅读位置。
没有更改部署下限、依赖、额度、购买、容量或生产功能开关。

应用构建记录绑定上述基线及实际 dirty diff／逐文件哈希。Xcode Debug 的 `OpenCCman`
可执行文件是启动桩，其哈希在本次应用变化前后没有变化，不能独自证明代码身份。
本轮另保存实际 `OpenCCman.debug.dylib`、其他运行映像及完整 bundle 文件清单哈希。
测试 Runner 单独记录测试源码／二进制与 xctestrun；不把旧 Runner 或旧产品的通过写成新候选结果。

## 运行环境

Xcode 27.1 (27A9275)，显式 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`，
devicectl 651.13.5。iOS Simulator SDK 27.1、macOS SDK 27.0，应用下限仍为 iOS 15 / macOS 12。
隔离包为 `org.gewill.OpenCCman.WhatsNewUITests`；没有操作正式安装或真实购买／恢复。

| 设备 | UDID | 起始状态／归属 |
| --- | --- | --- |
| Duo / iOS 27.1 | `4CAD3041-0744-41A6-8B4E-F934CA9F0778` | Shutdown；本 chat 原有专用 QA |
| iPhone SE 3 / iOS 18.6 | `42C71610-575F-482E-A329-7637CD51D10F` | 本轮新建，Shutdown |
| iPad A16 / iPadOS 27.0 | `737A20AC-4B6E-4B43-9C2D-0306F6266B6C` | 本轮新建，Shutdown |

默认字号 large；XXXL 为 `extra-extra-extra-large`，不扩展 AX 字号。
每端串行复用设备；完整日志、xcresult、媒体原件／上传副本与索引保存于仓库外。

## 已完成的局部结果

- 两端新候选 Debug 构建通过；macOS 包含 arm64、x86_64。工程解析、应用语言、控件标签检查通过。
- iPhone SE 3、iPad A16、Duo 各在默认／XXXL 下完成三语：真实 More 菜单→Settings→Customer Center→Dismiss→Settings→Back→Pro→Back。
  返回原文／结果逐字相同，恢复按钮存在且启用；没有点击恢复或购买。用户中心为无订阅页面，
  不证明真实账户、商品或交易可用。每组另含当前版本发布说明负向用例，共 6 组×4 项＝24 项通过。
  该矩阵在英语菜单标题修复后运行；随后仅增加 Mac 条件编译的命令／幂等路由。
  最终 delivery 构建另在 Duo 默认／XXXL 各重跑英语导航，2 项通过，不冒称全部 24 项均重跑于最后的包。
- Duo 默认／XXXL：系统导入面板、导出面板、Pro 路由打开时，宿主真实拉宽至 950×669、
  收窄至 400×750，再结束本次会话、恢复外屏并关闭返回；每档 3 项通过，原文／结果逐字相同。
  关闭动作发生在恢复后的外屏，不冒称在 Resizable 显示器完成点击。
- 导入／导出面板的 probe 覆盖三个真实窗口尺寸，原生模型／scene 各保持一个。
  Pro 路由隐藏工作区，probe 只覆盖进入前和返回后；期间尺寸由 XCTest／CoreDevice 与截图交叉确认，
  不宣称期间的编辑器身份也被 probe 覆盖。
- 实际 Device Hub 交接：外屏 466×678 → 展开 951×669 → 旋转 669×951 → 半折叠两方向 →
  闭合 678×466 → 实际指针旋转恢复 466×678；原文／结果 SHA-256 均保持。
  半折叠分别记录水平／垂直的 `division.active=true`。这不是仅用虚拟窗口尺寸代替姿态。
- 半折叠内屏通过实际 Device Hub 指针打开 More，执行 Help 并返回，全文保持。
  截图与 trace 记录当时系统栏、导入及结果动作的位置；宽布局的转换页头跨越 division，
  不据此宣称所有控件完整外框均在折叠区之外。该短文场景不覆盖所有滚动位置、分屏或其他弹层。
- Mac 英语 100%／150% 常用及 原图 1496×1758px 的窄窗口实际查看、转换与设置返回，全文保持；125% 仅确认切换，
  最终恢复 100%。最小窗口由用户手动缩小后补验（300×412pt／600×824px，含系统标题栏），
  100%／150% 主操作、底部结果、设置字号与 Region Idiom 均实际滚动可达；工具栏真实溢出菜单可执行 Settings。

Mac 最小窗口另完成配置与导出业务验收：Region Idiom 改为 Taiwan 后，原结果与原文均保持，
旧结果提示出现，Export TXT 仍可打开；实际保存到隔离 QA 输出目录的文件为 66 字节 UTF-8，
SHA-256 `6c032e9769ec1bcd28f3b5c7a9541dc248e7625fc93d5993f23cb87be9f472cc`，
与修改配置前的结果逐字一致。恢复 Not convert 后提示消失；通过 AX 修改原文后，结果清空、
Copy Result／Export TXT 禁用。该操作是已提交文本的 UI 设值，不是 IME 组字测试。

## Mac 命令、窗口及结果一致性

最终 delivery Mac 包在最小窗口实际执行 ⌘P→Pro→Back、⌘,→Settings→Back，原文／结果仍为同一 22 字。
Pro 滚至底部后重复 ⌘P、设置滚到中段后重复 ⌘,，页面树／滚动值保持；不会重复压入路由。
设置命令还在双窗口运行：第二窗口输入独立标记后进入设置，第一窗口仍在原稿主页；
150%→100% 的偏好在第一窗口一致，返回第二窗口标记保持，然后关闭第二窗口。
双窗口运行在 Settings 命令候选；最终新增 Pro 命令及相同路由 guard 后完成上述单窗口复核。
尚未测试从已关闭全部窗口的状态调用命令，也未把现有唤醒实现的源码审查算作该项运行通过。

## 移动文件代表性功能补验

使用精确隔离 QA 包及现有 `-qa-enable-mobile-large-files -qa-mobile-file-pro`，没有打开生产开关。
输入为 11,534,347 字节合法 UTF-8：重复 `汉字转换🌏\n` 678491 次。
输入 SHA-256 为 `1f3ea34ddb19a123035e27206ff66acf45548b6c1ef335a777b17a50ce13cece`；
转换为 `漢字轉換🌏\n`，输出同样大小、SHA-256 为
`505727b79638105f950a70a8881ee6d42119362ae70a6a5f71dc5b1ce81d23e0`。

- 确认→取消；重启再导入同一文件仍需确认。确认页真实 950×669→400×750→466×678，状态保持。
- 实际开始转换，拉宽时 AX 捕获 Converting File，收窄时已 Ready；完成输出与 journal 的大小／哈希正确。
- 终止隔离进程后重新启动，恢复同一作业 `5E6305D5-7789-4EB2-ADD1-00522A166F95`；输出哈希及 mtime 保持。
- 实际 Save result 打开系统导出 picker；在 picker 打开时完成宽／窄／原生尺寸循环，随后真正取消。
  返回 Ready，保存入口再次出现、同一 journal 与结果保留。没有实际选择 provider 保存文件。
- 验后经任务自身删除确认清理隔离作业；ready journal 归零，原始输入 fixture 的哈希保持。
  资源 trace 的 after_end 显示 idle override／background ownership 均释放；不是运行中资源状态的同步采样。

该轮 iOS 实际运行映像与最终 delivery 的 SHA-256 相同，但完整 bundle 比较有
`Metadata.appintents/extract.actionsdata` 差异；不能称两个包逐字节相同。
只覆盖这一个功能输入，不证明容量矩阵、性能、Preparing／Cancelling／失败重试、运行中后台／锁屏。
首轮总流程因误查 Cancel 为 AXButton 超时，保留 failed 报告；后续按实际 AXGroup 定位，独立补验通过。

## 构建来源与复跑

最终 delivery：iOS `OpenCCman.debug.dylib` SHA-256
`f69b7bbea0700611e338f4bf5ee3116b07508c6d9e9967905abd1b063ba7534e`；
Mac 对应映像 `9f226919e7e888996cc2c0f0b34bf94c720d048006f5979dd303e101cbd0da9e`。
完整构建报告含原生命令、实际 dirty diff、依赖锁、plist／Mach-O SDK 与完整 bundle 文件哈希。
构建后五个应用文件及测试源码未再修改；提交前留存其哈希并核对测试 Runner 对应源码哈希，见[机器索引](local-acceptance-2026-10-29.json)。
早期姿态／弹层和 Mac 提示前后截图使用当时各候选，后续改动及适用范围在索引区分；不覆盖旧记录。

先使用 `scripts/build-duo-validation.py` 和明确的 Xcode 路径构建隔离 QA 应用，
再对已安装包生成测试 Runner 并以 `test-without-building -only-testing:WhatsNewPresentationTests/DuoReadinessTests/<case>` 定向运行。
三语导航及无卡片用例无需宿主握手。宿主弹层用例须在测试环境设置
`OPENCCMAN_DUO_OVERLAY_RESIZE=1`，依次观察 `OPENCCMAN_OVERLAY_READY/WIDE/COMPACT/VERIFIED`，
调用 `devicectl device appResize` 开始 950×669、设置 400×750、结束会话恢复原生尺寸；
只有实际窗口满足断言才推进。命令详细参数依本机 `--help`，不能用未核对的版本照抄。
完整原始宿主控制脚本与日志在本机外部证据索引保留，不把宿主环境专用入口当作普通 CI 已覆盖。

## 当前版本没有发布说明内容

`WhatsNewRelease.content(for:)` 仅配置 1.3、2.0；当前候选是 2.1(30)，返回 nil。
因此本轮实际验证未配置版本不自动弹出、不显示空的回看入口。
负向 XCTest 使用已有 QA active eligibility fixture；它不是实际前后台交接或最终签名首启的证明。
没有改版本号或注入历史卡片制造正向通过。当前候选无法执行的“卡片打开期间缩放”仍在 #282 保留，
待配置真实发布内容或明确的发布候选后补验。

## 失败与证据边界

- 首轮三个导航用例误以 `navigation-back` 定位 Pro 的返回控件而失败；实际标识是
  `pro-sheet-close`。修正测试后重新运行通过，没有修改产品路由。
- 一次测试 Runner 增量构建与其他项目构建重叠，已保留日志；未终止其他项目。
  后续本机批次在每次 Xcode 调用前检查占用，有占用则等待／停止。
- Device Hub 初次读取连续超时，后恢复；没有把超时计作产品缺陷。
- 一次宿主缩放在实际闭合横屏被 CoreDevice 24001 拒绝；中止自己的测试，保留失败记录。
  随后用实际指针旋转并由 window=466×678 确认竖向，再新建运行通过。
- AXe 两种 tap style 在本次半折叠内屏均未打开 More；Device Hub 实际指针完成相同动作。
  动作返回成功不计通过。若 AX 只聚焦而未执行旋转，必须读回实际窗口尺寸。
- Mac 初次修复后截图因菜单 Return 进入编辑器多了换行，不用于正式前后对照；
  恢复完全相同的原文、重新转换后另存 `after-v2`，保留最初记录。
- 同一模拟器同时录制两个 display 被 CoreDevice 1010 / EBUSY 拒绝；保留已有录制，未覆盖原件。
- 普通 iPhone 首轮一次 Restore 在加载时尚未启用；增加等待 enabled 条件后重跑，通过。
  首轮 iPad 英语点击 More 后菜单未出现，原因尚未建立；新默认／XXXL 批次通过，不称已定位根因。
- QA App 重装迁移了 Data Container，旧 fixture 绝对路径导致 NoSuchFileError；重新解析路径并核对输入哈希。
  这是测试准备错误，没有当作 App 导入缺陷。
- Mac ScreenCaptureKit 首版未初始化 AppKit 而失败；修正隔离捕获辅助程序后成功。
  捕获仅指定 QA bundle/window、无音频，使用既有权限，没有新增系统授权。
- 系统面板 AX 操作有时返回 AXError 但实际已打开；以新页面判断，不重复盲点。

## 保持开放

#280／#282 的完整关闭标准保持：所有姿态／左右分屏的动作与真实溢出菜单、完整连续缩放中间态、
IME marked text、非零选区／中段阅读、运行中普通任务及移动文件各状态、后台／锁屏、
适用弹层与首启交接、最终签名构建和真机仍须逐项以实际结果补齐。
不把这轮局部通过扩写为全面验收。最低系统归 #16，交易归 #14/#71，移动文件生产开放与容量归 #260/#268；
VoiceOver 体验未验证。本轮没有触发 Xcode Cloud、分发或部署。

## 本轮检查与收尾

最终源码的 `check-project.sh`、`check-app-language.py`、`check-control-labels.sh` 均 PASS，
`Tests/Regression/DuoBuildChecks.py` 6 项通过，`git diff --check` 通过。两端完整 Debug 构建成功，
不替代 PR 当前 HEAD 的 App Regression 或正式签名验收。

三台本任务专用模拟器已逐一确认 Shutdown；其他项目已启动的模拟器保留。
Mac 隔离 QA 恢复 100% 后退出；录制、测试及临时本地视频查看服务结束，未退出共享 Device Hub。
