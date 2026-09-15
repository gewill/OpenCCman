# 转换设置语言验收（#75）

2026-09-15。实现 PR [#76](https://github.com/gewill/OpenCCman/pull/76)，依赖窗口尺寸 PR #74。**部分运行验收通过；仍为草稿，不关闭 #75。**

## 问题与修复

Mac 应用内选择繁体中文后，窄窗转换设置 sheet 使用系统英文，主页仍为繁体。共享 Mac/iPad 工作区和 iPhone 工作区现在都在 sheet 内容边界显式传递当前 `locale`，沿用现有偏好与窗口业务对象。没有调整系统语言、商品、依赖或 iOS 14/macOS 11 部署下限。

## 来源与构建

| 项目 | 记录 |
| --- | --- |
| 修复前 | `7fc833c367c589b0046dd2c0148c20698d64588b`，#75 原始截图 |
| 本轮运行源码 | `6af5ded56b70c2fca46793ccfac9cdbce6e5ae9e` |
| Mac 构建 | [App Regression 34936101490](https://github.com/gewill/OpenCCman/actions/runs/34936101490)，通过 |
| iOS 构建 | [手动验收 34936108590](https://github.com/gewill/OpenCCman/actions/runs/34936108590)，App Regression 和 iOS Simulator 构建均通过；artifact 的 source-sha.txt 与本轮源码一致 |
| Mac 运行 | macOS 27.0 (26A428)，本地 ad-hoc 签名的隔离 Debug 应用 |
| iPhone | iPhone 15 Pro Max，iOS 18.6，430×932pt |
| iPad | iPad Air 11-inch (M2)，iOS 18.6，820×1180pt |

本机 Xcode 27 无法构建现有未升级依赖组合，因此使用 CI Xcode 26.3 的验收 artifact。iOS app 的 MinimumOSVersion 为 14.0，SDK 为 iphonesimulator26.2，arm64。构建成功不证明最低系统运行通过。

## 本轮已验证

- Mac：在同一进程通过应用设置依次使用繁体、简体、英文；每次返回主页再打开转换设置。标题、完成按钮、预设和高级选项与应用语言一致，原文保持不变。
- Mac：300×412pt 主窗口与 470×400pt sheet，深色、默认字号。所有选项经原生 AX 确认；截图只展示当时可见范围，sheet 内容可滚动。
- Mac：英文宽窗显示/隐藏侧栏，并切换上下/左右布局；侧栏为英文，原文保留。此项不是完整三语言布局矩阵。
- iPhone：繁体、浅色、默认字号的转换设置实际呈现正确，关闭后返回原文工作区。
- iPad：繁体、浅色、默认字号；打开→关闭→再次打开，设置保持繁体，原文保留。视频记录完整操作，不用于性能计时。
- 本地 `scripts/check-project.sh`、`scripts/check-control-labels.sh` 与 `git diff --check` 通过。

## 实际媒体

截图及 iPad 交互视频均由 `gh pr comment --attach` 上传。[完整三端证据评论](https://github.com/gewill/OpenCCman/pull/76#issuecomment-5675906078)。

| Mac 修复前 | Mac 修复后 |
| --- | --- |
| ![应用繁体但弹窗英文](https://github.com/user-attachments/assets/cbe1beeb-24e0-48ec-bdc0-1fb3e95dad50) | ![弹窗随应用使用繁体](https://github.com/user-attachments/assets/dce2a93b-129f-4dcb-bd8a-127bb2e71bf1) |

同机、同主题、同字号和窗口尺寸；系统语言未修改。窗口截图包含附着标题栏。

[iPad 设置关闭与重开视频](https://github.com/user-attachments/assets/47b42ad6-e929-48fd-a943-131f870ca09f)。

## 剩余验收

- [ ] iPhone/iPad 简体与英文，以及同进程修改语言后重新呈现。
- [ ] 多窗口语言同步及独立文稿、结果保留。
- [ ] 宽窗侧栏与窄窗 sheet 的完整三语言矩阵。
- [ ] 最低系统运行继续保留 #16；没有用模拟器或 ad-hoc Debug 代替签名发布包验收。

## 清理

本轮未开启 VoiceOver，未修改系统语言、主题或辅助功能设置。Mac 隔离偏好恢复后逐键比较与备份一致；退出验收应用。两台原为关机状态的模拟器已卸载本轮新增的隔离测试安装并关机；原有应用未修改。serve-sim 仅绑定本机，镜像页与 scoped helper 已关闭。没有触发 Xcode Cloud 发布。
