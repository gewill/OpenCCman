# 登录时启动验证（2026-09-16）

- 工具：Xcode 27，macOS 27.0，CUA 界面与无障碍树。
- 同条件截图：英语、浅色、1024×768 捕获画面，默认字号。before 使用 develop c1efdb5 的原始 SettingsScene，保留本分支的最低系统与 RevenueCat 编译修复；after 使用本 PR 的设置源码。截图中的 1.3(30) 来自 develop，2.0 版本号由独立 PR #118 处理。
- 开关初始关闭，标签为 Launch at login；与既有设置使用相同 Neumorphic 行样式。未变更系统登录项或 VoiceOver。
- `xcodebuild -project OpenCCman.xcodeproj -scheme OpenCCman -destination 'generic/platform=macOS' -derivedDataPath /tmp/occ-login-build CODE_SIGNING_ALLOWED=NO build`：BUILD SUCCEEDED（最终界面）。
- `xcodebuild -project OpenCCman.xcodeproj -scheme OpenCCman -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/occ-login-ios CODE_SIGNING_ALLOWED=NO build`：BUILD SUCCEEDED；之后仅改动 macOS 条件块的布局及无障碍标签。
- macOS 12 arm64 独立源码 typecheck 通过。未取得 macOS 12/13 实机运行证据。
- RevenueCat 5.64.0 在 Xcode 27 出现 PaywallColor synthesized initializer 重复声明；固定至官方已修复版本 5.78.0 后构建通过。Package.resolved 语义对比只有 purchases-ios 改变。
- 固定上游源码与 MIT 许可证的 SHA-256 已通过 GitHub API 重新下载校验。

## 待验收（#119 保持开放）

- 签名应用在 macOS 13+ 注册、注销、系统设置拒绝/批准及返回应用后的状态刷新。
- 注销/重新登录后自动启动；关闭后不再自动启动。验收前后恢复原始登录项状态，并提供视频。
- macOS 12 实机隐藏入口；三语、深色及辅助功能实际交互。
- RevenueCat 升级后的真实购买/恢复/Customer Center 回归以及隐私审计更新。

上游实现记录错误到系统日志，当前没有额外的错误弹窗；不把界面截图等同于系统登录行为验收。
