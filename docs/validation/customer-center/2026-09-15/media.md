## #71：Mac 兼容用户中心三语／浅深色运行验收

2026-09-15；macOS 27.0 (26A428)，900×450pt，默认字号，基础权益隔离测试身份。来源为 PR #94 的 CI 验收包（head `406d887974644260a9f40b59e83edad1128b56f4`，run 34971934515，Xcode 26.3 Debug）；该 PR 已合并。本次没有 UI 代码修改，以下为同版本的语言／主题组合，不是修改前后或设计图。

| 语言 | 浅色 | 深色 |
|---|---|---|
| English | ![English light](https://github.com/user-attachments/assets/4a6cc549-b174-4b9a-b3db-1b0e718f4364) | ![English dark](https://github.com/user-attachments/assets/246e37e3-1e62-4520-8da1-eda7f0a5d868) |
| 简体中文 | ![简体浅色](https://github.com/user-attachments/assets/160e2dde-2a52-47fb-8af7-599527c51254) | ![简体深色](https://github.com/user-attachments/assets/ef38a08f-6689-4700-a9ac-af98b0572dc1) |
| 繁體中文 | ![繁體淺色](https://github.com/user-attachments/assets/1e820811-46f4-49e5-bd2c-9ce031fbcea1) | ![繁體深色](https://github.com/user-attachments/assets/75232c24-dc0e-4a3a-9e79-a78cbcb791f9) |

标题、一次性终身购买说明、恢复／刷新／反馈标签随应用内语言更新；这六个默认字号界面未观察到文字截断。帮助页往返和刷新后离开可达。第一次窗口的中文／组合字符／Emoji 原稿在全部导航后保留；第二窗口的独立原稿在用户中心往返后保留，关闭第二窗口后第一窗口原稿未变。导航没有产生主页计次。

视频记录了语言／主题切换、帮助返回、原稿保留和第二窗口往返。仅捕获本轮隔离应用，无音频／麦克风，其他应用区域为黑色；紫色指示是系统录屏提示。

没有点击恢复或购买按钮，没有发送反馈。原生 Mac 是应用兼容页，不是 RevenueCatUI 官方组件；不能据此宣称 iOS 官方页、真实交易、网络错误／重试、最大字号、VoiceOver、转换中切换或最低系统验收通过。

本轮诊断应用已退出、隔离偏好恢复、临时注册撤销，VoiceOver 读回关闭。iOS 新验收包（source `12375b815b62ff127e1ce21d8947c4b4aed6e35d`，run 34972276754）已构建并下载，但 Simulator 不可打开／Device Hub UI 超时，未将这一步计为移动端运行通过；为本轮启动的 iPad 已恢复 Shutdown，未动已有手机验收状态。#71 继续开放。

https://github.com/user-attachments/assets/fa40b6f2-c935-449d-9886-ad90297a0cd1
