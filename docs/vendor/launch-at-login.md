# LaunchAtLogin Modern 源码同步记录

上游与完整 revision、原始文件 SHA-256、许可证校验和见 [机器可读清单](launch-at-login.json)。按提交固定，不使用浮动 main 作为版本。

## 本地差异

直接集成到 SettingsScene.swift：限定 macOS；为 enum 和所有 extensions 添加 macOS 13 availability。开关使用应用三语标签，仅在 macOS 13+ 显示。未引入旧版 LaunchAtLogin 或修改依赖缓存。

## 升级步骤

1. 在独立 codex/ 分支比较清单 revision 与候选上游提交，审查 ServiceManagement 注册行为及许可证变化。
2. 下载候选原始源码与许可证，验证来源；保留上述必要 availability 修改，不直接覆盖应用设置代码。
3. 更新完整 revision、原始校验和及本地差异；在 PR 说明旧/新版本与行为变化。
4. 对 macOS 12 目标执行 typecheck 和完整构建；验证 macOS 13+ 开关及签名应用注册/取消、系统设置变化同步。macOS 12 不显示入口。
5. UI 变化附实际截图，交互变化附视频；未执行的登录重启验收明确保留在 Issue。

关联 OpenCCman #119。独立 typecheck 不能替代完整应用、签名和真实登录验收。
