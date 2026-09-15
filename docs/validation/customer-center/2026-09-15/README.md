# #71：Mac 三语、浅深色与独立窗口验收

本轮完成 Mac 兼容用户中心的三语 × 浅深色六组默认字号运行检查，以及帮助返回、刷新后离开和两窗口原稿保留。没有修改产品代码；#71 继续开放，不以 Mac 兼容页替代 iOS 官方 Customer Center 或真实交易验收。

[六组真实截图与交互视频](media.md)已通过 `gh issue comment --attach` 上传并[发布到 #71](https://github.com/gewill/OpenCCman/issues/71#issuecomment-5680783747)。表格比较同一版本的语言／外观状态，没有将其称为代码修改前后。视频仅捕获隔离应用窗口，无音频或麦克风；其他应用区域为黑色。六张截图及视频代表帧已检查。

## 来源与条件

- 本机 macOS 27.0 (26A428)，900×450pt，默认字号，基础权益隔离偏好。
- Mac app 来自 [App Regression 34971934515](https://github.com/gewill/OpenCCman/actions/runs/34971934515)，PR #94 head `406d887974644260a9f40b59e83edad1128b56f4`，Xcode 26.3 Debug；PR 已合并为 `68350cb487f6006b42d0c329354cbfbe553b4b53`。普通 pull_request checkout 的构建来源为该 PR 合并候选，head 用于标识候选，不声称工作流直接 checkout head。
- 下载 zip 的 SHA-256、截图和视频哈希、平台及结果在 [results.json](results.json)。未升级依赖或修改依赖缓存。
- 为防止干扰正在等待人工验收的另一份 app，本地副本改用 `org.gewill.OpenCCman.CustomerCenterVisualAudit`，移除 plist 的 NSServices，ad-hoc 重签。两个全局快捷键在本副本偏好内设为 `false`；这是锁定的 KeyboardShortcuts 2.4.0（`1aef85578fdd4f9eaeeb8d53b7b4fc31bf08fe27`）用于显式取消默认快捷键的存储值。不是修改系统快捷键。
- 未启用菜单栏图标，没有执行恢复／购买，没有发送反馈或打开反馈链接。SDK 可执行正常状态查询；本记录不包含 CustomerInfo、匿名 ID、收据或交易资料。

## 实际观察

| 项目 | 结果与范围 |
|---|---|
| English / 简体 / 繁体 × light / dark | 六组标题、一次性终身说明、恢复／刷新／反馈按钮随应用内语言切换；默认字号未观察到文字截断 |
| 兼容说明 | 三语均说明一次性购买、无需续订；不证明真实 lifetime 交易被识别 |
| 用户中心 → 帮助 → 返回 | 可达且返回用户中心，没有打开外部链接或发送消息 |
| 刷新后离开 | 返回设置正常；不将此断言为已覆盖延迟回调／网络错误竞态 |
| 多次语言／主题和用户中心导航 | 首窗口合成原稿仍为 `用户中心验收\n繁體／简体 é 👩🏽‍💻\n保留此原文。` |
| 第二原生窗口 | 独立原稿 `第二窗口：Independent draft B` 在设置／用户中心往返后保留；关闭第二窗口后第一窗口原稿未变 |
| 主页额度 | 没有转换；结束时 `testNumbersPerDay` 键仍不存在，`isPro == false`。只证明本次导航没有计次 |

两次快速返回主页后的即时 AX 读取返回临时 failure；重新读取同一进程后得到完整主页和原稿，没有重启或重做应用动作。不能把瞬时观察错误当成产品崩溃，也没有用它跳过正文核对。

原稿保留结论来自真实 AX 文本和视频；本轮没有执行文件导入／转换／导出，不宣称完整文件字节路径通过。

## 移动端与后续

[手动工作流 34972276754](https://github.com/gewill/OpenCCman/actions/runs/34972276754)的 App Regression 与 iOS Simulator build 均通过，来源为 UI 候选 `12375b815b62ff127e1ce21d8947c4b4aed6e35d`。下载包内 source SHA 和 bundle 已核对，最低声明 iOS 14.0；见 [ios-build.json](ios-build.json)。这不是 develop 的最终发行包。

本机旧 Simulator 当前不能打开，Device Hub 的 UI 请求超时。没有在本轮安装或启动这个新包，未将构建成功记作 iPhone／iPad 运行通过。为本轮启动的 iPad `B5A3C81A-D1BF-4F70-AEB3-F7DEB8122C43` 已恢复原来的 Shutdown；原有手机人工验收环境未动。

移动端中文复测还应关注一个源码层面的风险：应用将所选语言写入 SwiftUI environment，`IAPManager.configure()` 目前没有设置 RevenueCat 的首选语言；锁定 SDK 的 Customer Center 配置请求通过 HTTPClient 的 `X-Preferred-Locales`，而官方视图使用返回配置中的本地化字符串。Mac 兼容页通过不代表这个链路已通过。

- 锁定 SDK [HTTPClient 首选语言请求头](https://github.com/RevenueCat/purchases-ios-spm/blob/155ea739f45f54189ca83ee9088b373c1415d98b/Sources/Networking/HTTPClient/HTTPClient.swift#L107)。
- SDK 提供 [overridePreferredUILocale](https://github.com/RevenueCat/purchases-ios-spm/blob/155ea739f45f54189ca83ee9088b373c1415d98b/Sources/Purchasing/Purchases/Purchases.swift#L1587) 和初始化配置的首选语言入口；本轮只读检查，没有实现或宣称运行时修复。
- [官方 Customer Center 配置文档](https://www.revenuecat.com/docs/tools/customer-center/customer-center-configuration)说明后台 Localization 可自定义文案；后台文案候选仍待单独确认，未保存。

剩余验收：iOS 官方页三语／深色／最大字号／VoiceOver、系统语言与应用语言不同的切换、购买和无购买状态、错误／重试、转换或导入执行中切换、弹窗互斥、最低系统与签名包。#14、#16、#20、#34 的边界保持不变。

## 恢复

本轮 Mac PID 28362 已退出，隔离偏好由启动前导出的 plist 恢复，临时 app 注销并改为 inactive。录制已正常结束（287.992 秒，H.264 1920×1080，无音轨）；VoiceOver 开始和结束均为关闭，测试中未启用。没有推送 build 分支或触发 Xcode Cloud。
