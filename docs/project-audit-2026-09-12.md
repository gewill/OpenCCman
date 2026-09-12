# OpenCCman 项目审查与性能优化记录

日期：2026-09-12。基线：`cc8c7e8`，审查前工作区干净。检查了全部 **43 个原有 Swift 文件、3956 行代码、88 个受 Git 跟踪文件**，以及锁定依赖中与实际调用有关的实现。新增一个共享转换服务。未改依赖版本、部署目标或付费产品标识。

这是源码审查、独立行为回归和局部性能测量的记录；不把“未发现问题”解释为所有运行环境均无缺陷。依据以 Apple 官方文档、依赖锁定提交及可复现行为为准，没有把技能中的通用经验数字当作本项目的测量结果。

**项目结构与关键流程**

| 范围 | 路径/职责 | 核查结果 |
|---|---|---|
| 启动与系统集成 | OpenCCmanApp、AppDelegate；SwiftUI WindowGroup、状态栏、NSServices、权限 | 修复线程隔离、窗口通知目标、菜单快捷键配置 |
| 转换主流程 | HomeViewModel、HomeScene；参数→OpenCC→结果→额度/评分 | 修复分块丢字/格式改变/词组断开、重入、泄漏、取消、错误展示、全文浏览 |
| 全局快捷键 | GlobalShortcutService、ShortcutSettingsScene | 修复后台转换、监听累积、剪贴板恢复与权限刷新 |
| 购买与额度 | IAPManager、ProScene、TestNumbersPerDayManager、ReviewHandler | 修复套餐选择、恢复行为、资格缓存、日计数、Scene 评分 |
| 路由与偏好 | RootView、SettingsScene、ChangeLanguageScene、ChangeColorSchemeScene、PickableView | 每窗口持有模型；修复跨页面输入丢失、多窗口勾选不同步 |
| 通用视图 | SegmentView、MyAppView、ProAlertView、CardReflectionView、BackButton、AlertView、CellButton、LoadingView | 选择控件补原生按钮及选中语义；其余未发现足以支持必要修改的问题 |
| 内容页面 | HelpScene、FeedbackScene、OpenSourceScene | 补实际依赖缺失的开源声明；其他流程未发现确认缺陷 |
| 数据与辅助 | Constants、MyAppModel、UserDefaultsKeys、OpenSourceModel；Styles、ButtonStyles；全部 extensions | 核查枚举/默认值、日期、剪贴板、字符串、格式化、可用性；仅修改涉及确认问题的实现 |
| 工程与资源 | pbxproj、workspace、Package.resolved、plist、entitlements、三语 strings、两份 xcstrings、assets、README、LICENSE、gitignore | 资源引用/格式通过；补 UserDefaults 隐私 API 使用理由；删除无实际调用的 Apple Events 权限 |

**确认的问题与处理**

1. **分块导致正文丢失、顺序/换行改变、词组转换错误。** `前段\n\n` 后接 4001 个汉字时，旧分支直接清空未输出的前段；4000 字硬边界可切断“鼠标”；前后空段被过滤；片段拼接额外插入单换行。改为后台全文转换，保留上下文。独立回归已复现旧实现错误并验证修复结果。
2. **大文本反复发布完整结果。** 原流程每段回主线程累加 `@Published resultText`。新流程仅完成后发布一次结果；转换中显示不定进度指示，完成后显示 100%。不伪造 OpenCC 未提供的字节级处理进度。
3. **重复操作并发混写。** 模型守卫与按钮禁用共同防重入；持有任务以支持取消；取消后的旧任务不能覆盖新结果、显示旧错误或消费额度。空字符串不启动任务，连续触发额度限制不会把提示再次隐藏。
4. **模型引用环与页面重建。** 原 `assign(to:on:self)` 与自身存储的 cancellable 形成环，HomeScene 又自行创建 ObservedObject。改用 `assign(to: &$options)`，由每个 RootView 的 StateObject 持有模型；页面切换保留草稿，窗口生命周期结束时取消转换。弱引用释放测试通过。[Apple Combine 生命周期](https://developer.apple.com/documentation/combine/publisher/assign(to:))、[StateObject](https://developer.apple.com/documentation/swiftui/stateobject)。
5. **依赖创建与 C 字符串边界。** 所有入口共享缓存并串行创建转换器；应用当前只有七种有效选项组合。U+0000 会被依赖的 C 字符串接口视为结束，应用层按该分隔符分别转换后原样连接，避免静默丢弃后文。主页与同步服务使用同一处理。
6. **结果无法完整浏览、转换错误不可见。** 结果 Text 被限制到 300pt，且没有内部滚动。改为只读 TextEditor，保留选取/复制与内部滚动；原生 isEditable 关闭编辑，源输入保持可编辑。错误绑定到可见 alert。未以此宣称已测得 UI 帧率改善。[Apple TextEditor](https://developer.apple.com/documentation/swiftui/texteditor)、[NSTextView.isEditable](https://developer.apple.com/documentation/appkit/nstextview/iseditable)、[UITextView.isEditable](https://developer.apple.com/documentation/uikit/uitextview/iseditable)。
7. **多个窗口一起响应菜单/服务。** 通知携带目标 NSWindow；Root 和模型按窗口身份过滤。模型不再随首页卸载而消失；输入与转换菜单会导航到首页，避免后台扣额度但无可见结果。Root 使用 onReceive 管理订阅，不再在每次 onAppear 累积 cancellables。窗口尚未绑定时保留最新待投递请求，窗口就绪后延后一轮投递；窗口引用使用弱引用，避免保留已关闭窗口。
8. **快捷键破坏剪贴板。** 原逻辑只保存字符串、提前清空，并有两次可能互相覆盖的延迟恢复。现在保存全部项目/表示格式，用 changeCount 判断变化与恢复所有权；相同文本也能识别新复制。恢复时若已有后续复制，则保留新内容。[Apple NSPasteboard.changeCount](https://developer.apple.com/documentation/appkit/nspasteboard/changecount)。
9. **全局快捷键监听累积、同步转换阻塞与误粘贴。** handlers 只注册一次；切换开关使用 SDK 提供的启用属性；一次动作完成前不再重入。转换在 actor 中完成，事件投递到原 PID，目标 App 改变时放弃替换。移除原文及转换结果日志。菜单快捷键跟随录制值，并按依赖要求处理菜单打开期间的全局监听。[KeyboardShortcuts 2.4.0](https://github.com/sindresorhus/KeyboardShortcuts/blob/2.4.0/Sources/KeyboardShortcuts/KeyboardShortcuts.swift)。
10. **权限状态过期及权限声明不符。** 操作前、应用激活和设置出现时刷新辅助功能权限；用户可在权限失效时关闭全局快捷键。移除没有 Apple Event 调用支撑的 automation.apple-events，并删除“sandbox 必定可靠”的注释。[Apple entitlement 定义](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events)。
11. **购买的套餐与点击卡片不一致。** 原循环总购买 `packages[0]`。现在传入当前卡片 package，采用 current Offering（无 current 时才回退指定 offering）；用户取消不作为错误处理。[RevenueCat Offering](https://www.revenuecat.com/docs/getting-started/displaying-products)。
12. **自动恢复购买与断网误降级。** 日常检查仅获取 CustomerInfo；恢复只在用户明确点击时调用；nil 信息表示查询失败，不等于 Pro 失效，也不推进成功检查时间。添加 PurchasesDelegate，同步 SDK 获得的有效资格变化；代理地址在 configure 前设置。[恢复购买](https://www.revenuecat.com/docs/getting-started/restoring-purchases)、[资格更新](https://www.revenuecat.com/docs/customers/customer-info)、[初始化配置](https://www.revenuecat.com/docs/getting-started/configuring-sdk)。
13. **日计数重复创建格式器与跨日双写。** 缓存固定公历、POSIX locale 的日期格式器；新增计数直接写今日单项字典。覆盖第 11/12 次门槛、午夜跨日、Pro 豁免、单次持久化。iOS 评分定位到前台 UIWindowScene，macOS 只在应用活跃时请求。[Apple QA1480](https://developer.apple.com/library/archive/qa/qa1480/_index.html)、[Scene 评分](https://developer.apple.com/documentation/storekit/skstorereviewcontroller/requestreview(in:))。
14. **多窗口选择状态与标准操作语义缺失。** PickableView 在外部偏好变化时同步勾选；Segment/Pickable 用 Button 替代单独的 onTapGesture，保留原样式并提供 selected trait。[Apple 按钮语义建议](https://developer.apple.com/documentation/swiftui/view/ontapgesture(count:perform:))。
15. **交付信息遗漏。** 增加 UserDefaults 所需的 PrivacyInfo.xcprivacy 与 CA92.1 理由，并加入资源；补 ColorVector、MSDisplayLink、KeyboardShortcuts 锁定版本的 MIT 全文；补新增错误标题的三语本地化。[Apple 隐私清单](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)。

**性能证据**

| 测量 | 基线 | 当前 | 方法与限制 |
|---|---:|---:|---|
| 48 万字符 / 1,360,000 UTF-8 字节处理 | 460.77 ms | 154.04 ms | 本机 Release、同一预热转换器、5 次中位数；包含旧分块/转换/拼接及新完整转换，不含 SwiftUI 渲染或用户交互 |
| 同输入通过入仓基准脚本复测 | 479.85 ms | 161.29 ms | 独立 SwiftPM 可执行程序、5 次中位数；耗时下降约 66%，波动不影响发布次数或结果正确性 |
| 上述输入的非空结果发布次数 | 121 | 1 | 由实际片段数和最终发布路径确定；核心回归同时观察发布次数 |
| 2,000 次额度查询 | 37.08 ms | 1.95 ms | 独立日期/计数微基准；不是整应用速度，时间受本机环境影响 |
| 跨日计数持久化 | 2 次 | 1 次 | 真实生产源码配隔离存储替身验证写入次数 |

48 万字符样本的数据处理耗时约下降 **67%**。未测量端到端启动时间、FPS、峰值 RSS、电量或真实设备耗时，因此没有给出这些指标的改善比例。

**验证与复现**

在项目根目录运行：

```sh
python3 scripts/check-core.py
python3 scripts/check-core.py --benchmark
bash scripts/check-quota.sh
bash scripts/check-pasteboard.sh
git diff --check
```

- Core：实际 HomeViewModel/ChineseConversionService 源码，真实 Combine、SwiftUI、OpenCC、SwiftyUserDefaults；依赖 revision 从项目 Package.resolved 读取。7 组选项 × 8 类样本，加 U+0000 同步/异步一致性、模型释放、防重入、单次发布、取消替换、空输入与额度守卫。评分与额度副作用使用测试替身，不能由此推导 StoreKit 的真实行为。
- Benchmark：保留 cc8c7e8 原分块函数作对照；校验三个旧缺陷在基线失败、当前与 OpenCC 一致，再运行相同输入的五次处理测量。可传 `--opencc-path`、`--defaults-path` 使用已有锁定提交的本地 checkout，减少重复下载。
- Quota：生产文件原样编译；隔离 UserDefaults suite 和时钟，真正跨过 23:59:59→00:00:00。
- Pasteboard：抽取并编译生产 PasteboardSnapshot；只用独立命名剪贴板，覆盖多项目文字/RTF/图片/文件 URL、空内容、相同文本、新复制保护，不操作系统通用剪贴板。
- 全部应用 Swift 文件语法解析、工程/Info/entitlements/privacy plist、三语 strings、资源 JSON、diff 格式检查通过。
- macOS 11/iOS 14 部署目标下，评分与结果编辑器做了真实 SDK 定向类型检查。选择控件、AppDelegate/全局服务的定向检查对部分第三方接口或样式使用替身；它们不能替代完整应用链接或运行时 UI 测试。
- 没有运行 Xcode Build、模拟器、真实付款、签名应用跨 App 自动化，也没有安装/升级依赖或修改发布后台。

**仍需后续验证或依赖修复的边界**

- **SwiftyOpenCC 原生资源释放缺失仍在依赖内部。** 锁定提交 ChineseConverter 调用 CCConverterCreate，却没有 deinit 调用 CCConverterDestroy；C++ 实现使用 new。应用缓存将当前七组选项的创建次数限定在可复用集合，不能声称修好了上游析构。锁定 WeakValueCache 也有锁外读/锁内写，本项目已统一串行创建入口。[锁定 ChineseConverter](https://github.com/gewill/SwiftyOpenCC/blob/53f200cebe40eade3ebda025b0e8980e08cf23fa/Sources/OpenCC/ChineseConverter.swift)、[C++ 包装](https://github.com/gewill/SwiftyOpenCC/blob/53f200cebe40eade3ebda025b0e8980e08cf23fa/Sources/copencc/source.cpp)、[缓存实现](https://github.com/gewill/SwiftyOpenCC/blob/53f200cebe40eade3ebda025b0e8980e08cf23fa/Sources/OpenCC/WeakValueCache.swift)。
- **NSServices 仍按同步协议返回。** 服务方法必须在返回前写回结果，因此其大文本转换仍可能占用服务线程；没有用阻塞等待异步任务来伪装优化。[Apple Services](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/providing.html)。
- **取消不能中断正在运行的 OpenCC C++ 调用。** 取消检查防止排队任务继续执行和旧结果回写，但已经进入原生同步计算时，需等该调用返回。
- **CGEvent 复制/粘贴没有事务完成与来源标识。** 粘贴仍保留 800ms 容许时间；同 App 内选区改变、捕获期间用户复制、后台剪贴板工具写入，无法只凭 PID/changeCount 完全判别。需要签名 sandbox/TCC 环境与实际目标 App 验证。没有把独立剪贴板测试等同于跨 App 端到端测试。
- **全部窗口关闭后的自动创建仍未实现兼容路径。** 最新请求会留在内存中，用户重开窗口后再投递；没有为 macOS 11 添加未经验证的创建窗口 selector。冷启动投递槽已通过类型检查，完整冷启动/闭窗重开仍需运行验证。
- **真实购买/恢复/退款/跨设备资格**仍需 StoreKit Sandbox 验证；RevenueCat 接管交易验证、监听和完成，未误报业务层缺少 Transaction.finish/updates。隐私清单也不代替 App Store Connect 的实际隐私问卷。
- **额度范围存在产品规则边界。** 现有日限额用于主页转换，macOS 自动转换入口原本未执行此门槛；没有在缺少产品规则时改变这些入口的付费行为。多个独立窗口临近额度上限时同时开始任务，也不构成跨任务额度预留协议。
- **完整 UI/构建验证未执行。** TextEditor 的 Introspect 运行时匹配、键盘焦点/VoiceOver、所有窗口关闭后的重开流程仍需实际运行。原依赖也存在 Swift 6 语言模式警告，但项目当前使用 Swift 5 模式；未为消除升级预警强行迁移。
- SwiftUIOverlayContainer 当前无直接 import/使用；尚无测量证明删除它能改善运行性能，因此保留锁定依赖，记录为后续清理候选。

**覆盖清单**

原有 Swift 文件全部进入审查分区：

```text
AppDelegate.swift · OpenCCmanApp.swift · Constants.swift · IAPManager.swift
Helpers/ReviewHandler.swift
Services/GlobalShortcutService.swift
Model/OpenSourceModel.swift · MyAppModel.swift · TestNumbersPerDayManager.swift · UserDefaultsKeys.swift
Scene/OpenSourceScene.swift · HelpScene.swift · HomeScene.swift · ChangeLanguageScene.swift
Scene/ChangeColorSchemeScene.swift · ProScene.swift · FeedbackScene.swift · ShortcutSettingsScene.swift
Scene/RootView.swift · SettingsScene.swift · HomeViewModel.swift
View/LoadingView.swift · CellButton.swift · AlertView.swift · BackButton.swift
View/CardReflectionView.swift · ProAlertView.swift · PickableView.swift · SegmentView.swift · MyAppView.swift
Styles/ButtonStyles.swift · Styles.swift
extensions/UIApplicationExtensions.swift · DateExtensions.swift · IntExtensions.swift
extensions/BundleExtensions.swift · DoubleExtensions.swift · BoolExtensions.swift
extensions/ColorExtensions.swift · StringExtensions.swift · ImageExtensions.swift
extensions/SKProductExtensions.swift · ViewExtensions.swift
```

覆盖清单以项目源码为边界；第三方依赖审查集中于已使用 API、配置、许可证和已定位的问题，没有声称审计了每个依赖的全部实现。
