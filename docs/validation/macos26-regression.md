# macOS 26 单次回归（#98）

#98 的 macOS 27 修复已有运行证据，但 macOS 26 的回归未验收。本入口让手动运行选择 macOS 26，复用全部 App Regression 与可选 iOS Simulator 构建，不为日常 PR 建立矩阵。

```sh
gh workflow run app-regression.yml --repo gewill/OpenCCman \
  --ref <candidate-branch> -f regression_system=macos-26 -f build_ios_validation=true
```

只允许解析到 GitHub 的 `macos-15` / `macos-26` 标签；任何其他输入均回退 macOS 15。Xcode 固定 26.3，记录 `sw_vers`、工具链、源码 SHA 和依赖锁哈希。构建后验证锁文件无漂移，保留 iOS 14/macOS 11 下限。

参考 [GitHub 官方镜像清单](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)：2026-09-16 查询时 macOS 26 镜像包含 Xcode 26.3，实际运行以 job 日志为准。

## 2026-09-16 实际结果

[run 35066656999](https://github.com/gewill/OpenCCman/actions/runs/35066656999) 成功，实际源码 `a12d94f3fcab33eb410cfb37f03032f51208b044`。两个 job 均在 macOS 26.6.2 (25G83)、Xcode 26.3 (17C529) 运行。

- 完整 App Regression 通过：包括真实转换/文件/配额、窗口几何与重开队列、1/5/10 MiB 重排、原生编辑器身份/选区/marked range/撤销、只读结果和 TextKit 1 初始化、Pro 与本地 StoreKit。
- macOS 完整构建（arm64/x86_64）及 iOS Simulator arm64 编译均成功，构建后的依赖锁检查通过。
- [检查节选](macos26-regression/checks.log)、[实际 job 与每步状态](macos26-regression/run.json)、[完整日志校验和](macos26-regression/provenance.json) 已归档。没有通过渲染或手动操作的新 UI 证据。
- 后续整合 #116 仅保留两个工作流入口与其条件，产品源文件没有变化；整合后的 PR 必需检查仍需通过。

原生编辑器/窗口适配检查与 iOS 编译不能替代真实系统入口、设备 UI、VoiceOver、最低系统或签名发行包验收；#98 的 #19/#57 关联项继续独立保留。
