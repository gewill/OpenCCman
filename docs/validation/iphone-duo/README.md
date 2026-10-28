# iPhone Duo 核心适配候选（2026-10-28）

关联 #277–#282；这是首个开发候选，不是这些 Issues 的关闭记录。依据
[指南固定版本](https://github.com/gewill/dev-standards/blob/3089d379d421566db7b367665cad196224466cf7/iphone_duo_readiness_guide.md)。
日常分支从 develop `b8eca56b019d8718a41603b057c3b9f0839c1941` 创建，PR 回 develop。
商店素材 #283 仍按其生效条件单独处理。

## 实现边界

- 所有 iOS 窗口共用 WorkspaceSurface；根据当前容器宽度和既有 760/720pt 滞回决定双栏，
  不再由 phone/pad idiom 限制。Source/Result 保持同一 ZStack 子树，保留用户布局偏好。
- iOS 路由使用 NavigationStack（iOS 16+）或 NavigationView.stack（iOS 15），
  保留 SwiftUIRouter 的路径所有权。转换／取消、设置、更多、返回、关闭提供系统栏语义、图标和本地化标题。
  背景可以延伸；交互内容仍遵守各边独立的 safe area。
- iOS Pro 提示使用首页单一系统 alert 入口，保留取消和打开 Pro sheet；Mac 自绘提示保留。
  系统栏承担主要操作；正文内导入、导出、分栏手柄和移动文件操作的真实折叠区避让仍待采证。
- Debug、专用 QA Bundle ID、27.1 SDK 编译条件和显式 `-qa-duo-trace` 四重门控下，
  probe 记录真实 division reserved regions、窗口／容器／safe area、scene／模型、
  原生 UITextView 身份／选区／焦点／滚动位置。不记录稿件文字；沙盒 tmp 的
  `duo-layout-trace.jsonl` 每进程重新准备、上限 512 KiB。Release 和普通构建不包含该 probe。
- 修正已有 QA 额度准备：不再依赖异步发布说明已加载。正式额度、转换、购买、容量和生产开关未改。
  部署下限保持 iOS 15 / macOS 12，Package.resolved 未改，CI 和 Xcode Cloud 未升级。

## 工具与来源

主机 macOS 27.2 (26B123)，显式 Xcode 27.1 (27A9275)，devicectl 651.13.5。
所选 Xcode 实际附带 iOS Simulator 27.1、macOS 27.0 SDK；两个平台分别核对，不能把工具链小版本当成 macOS SDK。
隔离模拟器 `OpenCCman Duo QA 277` / `D4FE3CC7-4DBF-4333-84A7-FEA788DBD897`，
iOS 27.1 (24A94425)，专用包 `org.gewill.OpenCCman.WhatsNewUITests`。
未使用正式安装、用户稿件或真实交易。

构建记录绑定基线 SHA + 实际脏工作区 diff/未跟踪文件哈希，不以基线 SHA 冒充候选源码。
[精简证据](evidence.json)包含候选构建、相关源码逐文件哈希、测试摘要和实际元数据；
完整日志、xcresult、原图、录屏及上传副本索引在仓库外保留。媒体查看关联 PR 的 UI 证据评论。

## 已运行结果

| 场景 | 实际结果 | 适用范围 |
| --- | --- | --- |
| 27.1 构建入口 | iOS arm64、macOS arm64/x86_64 Debug 均通过 | 生成 plist、Mach-O SDK、最低系统、设备族、方向、scene、LaunchScreen、indirect input；未签名 QA 包 |
| 布局和相关回归 | 布局滞回／宽度往返、工程解析、标签、应用语言、额度、Pro 权益通过；产物校验 6 项通过 | 本地脚本，非真机或分发验收 |
| 默认字号 large（candidate-build-05） | 5 通过、0 失败、1 条需宿主缩放的用例跳过，91.242 秒 | 英／简／繁示例转换、设置 sheet→Help→返回后稿件／结果保持；中文字符＋Emoji 输入、键盘关闭、实际转换；英文限额提示取消与 Pro sheet 关闭 |
| XXXL（candidate-build-06） | 同上 5 通过、0 失败、1 跳过，91.500 秒 | 系统 extra-extra-extra-large，非 AX；结束恢复 large。截图核对三语设置／帮助与英文提示 |
| 宿主真实缩放 | 独立启用外部缩放测试，1 通过、0 失败、0 跳过，15.744 秒 | 非空原文／结果、键盘焦点存在，466×678→950×669→400×750；实际窗口和编辑器 frame 验证横纵切换 |
| 原生连续性 | 同一 scene、模型及两个 UITextView 身份保持；22 个 UTF-16 原文／结果与已聚焦选区 [0,0] 保持，焦点 true、offset [0,0] 保持 | 只证明本次短文和光标位置；不是中文 marked text 或中段阅读位置验收 |
| 空稿件前后对照 | 相同模拟器／SDK／英语／默认字号，950×669、400×750 的请求尺寸均实际生效 | 基线 b8eca56 与 candidate-build-06；宽窗口由纵排变双栏，窄窗口继续纵排 |
| 不对称 safe area | 外屏 466×678 下容器 382×562，insets [top:82, leading:0, bottom:34, trailing:84]；系统竖向栏与正文分开 | 当前外屏窗口；未证明左右分屏或所有方向 |

原生连续性日志中 division 数组均为空，不能据此宣称已验证激活折叠区。
candidate-build-05 到 06 仅修正显式侧栏选择的意图值，并恢复 Mac 帮助页原有底部背景行为；
默认字号记录不冒充 06 的完整重跑。06 另完成默认字号实际缩放与空稿件前后对照。
缩放录像仅覆盖宽→窄；录制画布沿用起始宽窗口，完整窄态以 XCT 截图为准。
Pro 视频只说明取消、打开和关闭；RevenueCat 无可用 offerings 的错误文案仍存在，不代表商品、购买或恢复验证。

首次 Pro UI 测试的额度前置条件未生效，保留为失败记录；修正 QA 前置后两档字号通过。
早期产物检查因 iPhone 方向键后缀和 macOS SDK 版本假设误报，已修正校验并保留失败报告；
只把修订后完成的构建计为通过。一次 UI 测试为避免与其他项目构建重叠被主动中止，不计结果。
一次空稿件截图 sweep 在 App 尚未进入前台时失败，确认前台后新建运行成功，没有覆盖原记录。

## 复跑

构建命令与校验参数见 [CI 文档](../../CI.md#iphone-duo-的本地-271-构建入口)。
每次 Xcode 调用前先检查 `pgrep -lx xcodebuild`，有其他构建则等待；不终止无关进程。
安装该入口生成的专用 QA App 后，在上述模拟器运行：

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer \
  xcodebuild -project Tests/UI/WhatsNewPresentation/WhatsNewPresentation.xcodeproj \
  -scheme WhatsNewPresentationTests \
  -destination 'platform=iOS Simulator,id=<dedicated-duo-udid>' \
  -derivedDataPath '<outside-checkout>/uitests' -parallel-testing-enabled NO \
  -resultBundlePath '<new-evidence-directory>/duo.xcresult' \
  -only-testing:WhatsNewPresentationTests/DuoReadinessTests CODE_SIGNING_ALLOWED=NO test
```

XXXL 用 `simctl ui <udid> content_size extra-extra-extra-large`，完成或失败均恢复原值。
宿主用例默认明确跳过：先 build-for-testing，在生成 xctestrun 的测试目标 EnvironmentVariables
加入 `OPENCCMAN_DUO_EXTERNAL_RESIZE=1`，再 test-without-building 仅运行
`testHostResizeKeepsNativeDocument`。复制 xctestrun 到证据目录时，将 `__TESTROOT__` 正确解析到实际 Products，
不能让 Runner 路径随复制失效。
测试输出 READY_FOR_RESIZE 后，以实际 `devicectl device appResize start --preferred-size 950x669`
启动本设备会话；READY_FOR_COMPACT 后用 `appResize set --preferred-size 400x750`。
结束该次宿主会话，收集 QA 沙盒 trace 和 xcresult；未驱动真实缩放不能计为通过。
这些命令的支持范围已以本机帮助核对，不能套用为真机或真实 Duo 姿态控制。

## 保持开放的验收

#278：CI 27.1、旧 SDK 编译及最低系统实际运行、最终签名产物仍未覆盖。
#279/#280：普通 iPhone/iPad/Mac 实际 UI、系统最低版本、左右分屏／完整溢出菜单与路由矩阵仍待验收。
#281：书本式／桌面式／展开闭合、真实激活 division 与正文关键操作、三语 Pro 提示尚未完整验收。
#282：真实内外屏与旋转、IME marked text、非零选区／中段滚动、长任务／导入导出／保存、
What's New／Customer Center／启动交接及最终签名包仍未覆盖。
Duo 真机与 VoiceOver 体验未验证；交易仍留 #14/#71，最低系统留 #16，移动文件生产开放与容量留 #260/#268。
本轮不关闭任何 Issue，不合并、不打包分发、不部署。
