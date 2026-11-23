# #29 本地开发签名与 iPad 验收进度

2026-11-05。源码为干净的 `fdb3798843469a7a3af538f17507c232fa36806d`，
版本 2.2 (30)。本轮只新增验收记录，没有修改 App、扩展、工程或签名配置。
**开发签名核验通过；iPad 窄窗口交互未完成，#29 不具备关闭条件。**

## 环境与产物

- Mac：macOS 27.2 (26B123)，Xcode 27.1 (27A9275)，进程级
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。
- iOS Simulator：Debug、arm64、SDK 27.1，构建成功，98.096 秒。
- iOS 设备产物：Release、arm64、Apple Development 签名，构建成功，131.824 秒。
  这是本地开发签名的 Release configuration，不是 Archive、Distribution、
  TestFlight 或 App Store 产物；没有访问开发者门户创建或更新 profile。
- 两次成功构建的 axbuild 日志收集状态均为 `complete`，原生命令退出码为 0。
  设备构建有 7 条 warning，保留原始日志，没有将其描述为零告警。
- App 与扩展的最低系统均为 iOS 15；没有实际运行 iOS 15。

| 对象 | Bundle ID | Release 主程序 SHA-256 |
| --- | --- | --- |
| App | `org.gewill.OpenCCman.TextActionQA20261105` | `4dad22a46649fa396532bcb2b9966d63de490cee61e404debce55c26852cb9de` |
| Action 扩展 | `org.gewill.OpenCCman.TextActionQA20261105.TextAction` | `5b7bc237cfdea3b451fd872b3313531d707a81c4f2f8eb78f3c350d3fb174817` |

这些是主程序哈希，不是整个 bundle 哈希。模拟器 Debug 启动壳及 `.debug.dylib`
分别记录在本地 `artifact.json`，不拿 Release 主程序哈希代表模拟器运行来源。

## 可重跑的签名核验

使用本机已有的有效 Apple Development identity 和 iOS wildcard development profile。
profile 为 Xcode managed，截止日期 2027-05-21。团队信息、profile、证书匹配及
原始签名输出保留在本机证据中；仓库没有加入证书、profile 或设备列表。

以下命令中的目录、团队及 QA Bundle ID 应按运行机器替换；不要增加
`-allowProvisioningUpdates` 来把本地检查扩大为门户操作。

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project OpenCCman.xcodeproj -scheme OpenCCman -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$QA_DERIVED_DATA" \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  -jobs 2 ONLY_ACTIVE_ARCH=NO ARCHS=arm64 \
  OPENCCMAN_BUNDLE_ID=org.gewill.OpenCCman.TextActionQA20261105 \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$QA_TEAM" \
  'CODE_SIGN_IDENTITY=Apple Development' \
  'OTHER_SWIFT_FLAGS=$(inherited) -D OPENCCMAN_DUO_SDK' build

codesign --verify --strict --verbose=2 "$QA_APP"
codesign --verify --strict --verbose=2 "$QA_APP/PlugIns/OpenCCmanTextAction.appex"
codesign -d --entitlements :- "$QA_APP"
codesign -d --entitlements :- "$QA_APP/PlugIns/OpenCCmanTextAction.appex"
security cms -D -i "$QA_APP/embedded.mobileprovision"
security cms -D -i "$QA_APP/PlugIns/OpenCCmanTextAction.appex/embedded.mobileprovision"
```

实际核验：两份 `codesign --verify --strict` 均退出 0；App 和扩展各自有嵌入
profile，签名后的 `application-identifier` 与各自 Bundle ID 对应，team 一致，
`get-task-allow=true`。输出：

```text
PASS: App and Action extension development signatures and embedded profiles verified; get-task-allow=true; distinct matching app IDs.
```

首次尝试失败也保留：全局指定 `CODE_SIGN_STYLE=Manual` 和 Xcode managed
profile，导致 App/扩展拒绝手动签名，且把 profile 强加给不支持 profile 的
SPM resource bundles。改用上述 Automatic 参数、移除全局 profile 覆盖后成功。
没有为了通过而改工程或依赖。这是调用参数问题，不作为 App 缺陷。

## iPad 实际操作与阻塞

- 任务设备：iPad A16 / iPadOS 27.0，UDID
  `737A20AC-4B6E-4B43-9C2D-0306F6266B6C`，初始 Shutdown。
- 安装并启动上述 Debug 模拟器 QA 包，英语、默认字号；主工作区可见。
- 在此模拟器本地文件提供方写入隔离的 115 字节 UTF-8 TXT（含 CRLF），
  Files 中能看到该文件。执行文件的 Share 操作后，分享面板显示
  “Convert Chinese Text”入口。
- 未完成窄窗：拖动 Files 右下 resize handle 后未观察到窗口缩小。
- 未确认扩展执行：尝试点按入口后，CUA 返回的窗口已变成另一任务的
  Device Hub 窗口。随后菜单操作出现失效 element ID。停止继续点按，
  没有将发送成功或可见入口当作扩展转换通过，也未据此判断 App 缺陷。
- Device Hub GUI 曾使用 Xcode 27.2 路径；构建和 simctl 使用 27.1。
  本机多个同名 Device Hub 实例及并行窗口的目标绑定尚未排除，后续需先
  建立稳定的目标窗口，再验默认字号／XXXL 下的四预设、复制、分享及完成。

收尾：仅关闭本任务从 Shutdown 启动的上述 iPad，重读状态确认 Shutdown。
未退出共享 Device Hub、未关闭其他任务的模拟器。

## 证据与未验证范围

本机证据目录标识：`OpenCCman/29-ipad-action-20261105`（位于仓库外的
Codex ui-evidence 根目录）。包含源码与产物索引、模拟器构建日志、首次签名失败、
Automatic 签名成功日志及 `development-signature-verification.json`。
这是本机记录，不是远程可访问的附件链接；本轮没有上传媒体。

仍未验证：iPad 窄窗及 XXXL 交互、VoiceOver 体验、设备安装与运行、
最低系统、最终分发签名包，以及宿主实际使用回传结果的替换流程。
本次构建、签名核验和可见分享入口均不能替代这些项目。
