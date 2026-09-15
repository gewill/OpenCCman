# Xcode 27 / RevenueCat 兼容性

对应 [#107](https://github.com/gewill/OpenCCman/issues/107)。2026-09-16 的隔离实验确认：当前锁定 RevenueCat 5.64.0 的 `PaywallColor` 初始化器写法在本机 Swift 6.4 下报重声明；官方 5.78.0 的同一原文件通过类型检查。**这只验证该源文件的编译阻断，不代表整个 SDK、应用或购买流程已经通过升级验收。**

同时，本机 Xcode 27 SDK 的部署下限为 iOS 15 / macOS 12，与应用保留的 iOS 14 / macOS 11 不一致。因此当前继续使用已经验证的 Xcode 26 系列，GitHub 回归保持 Xcode 26.3；本任务不升级依赖、不改部署目标、不修改 Xcode Cloud 配置或启动打包。

## 来源与实验

- 应用基线：`51bcedaec5a64ae840fcf36f39bb217b65b91304`，`SWIFT_VERSION=5.0`，iOS 14 / macOS 11。
- 环境：Xcode 27.0 (`27A266a`)，Apple Swift 6.4 (`swiftlang-6.4.0.34.1`)。
- 旧版本：RevenueCat 5.64.0，SPM revision `155ea739f45f54189ca83ee9088b373c1415d98b`。
- 修复版本：5.78.0，SPM revision `629a56ecef190469914b8f0914bf0446363eb09f`。
- [官方修复 PR #6949](https://github.com/RevenueCat/purchases-ios/pull/6949) 在 2026-06-08 合并，将私有初始化器从 extension 移入主 struct 声明，抑制与公开初始化器冲突的 memberwise initializer 合成；[5.78.0 正式 Release](https://github.com/RevenueCat/purchases-ios/releases/tag/5.78.0) 同日发布此修复。这里只定位修复首次发布版本，不将其称为最新推荐版本。
- 源文件身份、完整 revision、Git blob 与 SHA-256 固定在 [来源清单](../../../Tests/Toolchain/RevenueCatInitializer/upstream-sources.json)。从官方取得的 5.64.0 文件与现有精确锁定 checkout 逐字节相同。

| 输入 | Xcode 27 类型检查 | 解释 |
|---|---|---|
| 依赖无关的最小样例，初始化器位于 extension | exit 1，同一重声明错误 | 排除购买配置、SwiftUI 视图与应用模型作为此编译错误的必要条件 |
| 最小样例，初始化器移入 struct | exit 0 | 验证官方改动所针对的语言结构 |
| 官方 5.64.0 原始 PaywallColor.swift | exit 1，同一重声明错误 | 不仅是人工简化样例的问题 |
| 官方 5.78.0 原始 PaywallColor.swift | exit 0 | 修复后的这个源文件可编译；没有链接或运行整个 SDK |

检查使用 Swift 5 语言模式，与应用设置一致；目标 `arm64-apple-macosx12.0` 只作用于诊断命令，便于将初始化器问题与 SDK 部署下限分离。没有修改依赖缓存、全局 xcode-select、应用工程或 Package.resolved。独立临时 module cache 用后删除。检查环境时虽然发现共享 DerivedData 为 31 GiB，但本实验使用全新私有 cache 且稳定复现，不能仅凭目录大小认定缓存损坏或清理其他任务的数据。未操作模拟器、Device Hub 或正在使用的 Xcode。

[机器可读结果](2026-09-16/results.json) 包含版本、SDK 声明的有效部署目标、四项命令/退出码、源文件哈希。原始诊断日志与结果在同目录。编译器输出自带的行尾空格原样保留，仅对两个原始失败日志设置 Git whitespace 豁免；源码和文档仍检查空白。`expectationsMatched=true` 表示“旧模式失败、新模式成功”符合实验预期，**不是四项编译都成功**。没有本机 Xcode 26.3，因此未虚构同机旧工具链对照；现有 Xcode 26.3 应用 CI 的成功只作为独立的整体验证证据。

## 重现

从仓库根目录运行，输出必须是新目录：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
python3 scripts/diagnose-revenuecat-initializer.py \
  --expect-legacy fail --output .build/initializer-minimal
```

同时核对官方文件时，按清单的完整 SHA 下载，脚本检查输入字节哈希后再执行：

```bash
python3 - <<'PY'
import base64, json, pathlib, subprocess
manifest = json.loads(pathlib.Path('Tests/Toolchain/RevenueCatInitializer/upstream-sources.json').read_text())
output = pathlib.Path('.build/initializer-upstream')
output.mkdir(parents=True, exist_ok=False)
for label, source in manifest.items():
    endpoint = f"repos/{source['repository']}/contents/{source['path']}?ref={source['revision']}"
    response = json.loads(subprocess.check_output(['gh', 'api', endpoint], text=True))
    (output / f'{label}.swift').write_bytes(base64.b64decode(response['content']))
PY

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
python3 scripts/diagnose-revenuecat-initializer.py \
  --expect-legacy fail --output .build/initializer-comparison \
  --upstream-legacy .build/initializer-upstream/upstream-legacy.swift \
  --upstream-fixed .build/initializer-upstream/upstream-fixed.swift
```

命令只下载两个固定源码文件，不执行上游脚本。报告目录会保存输入副本和日志；仓库仅提交自写的最小样例、来源清单与日志，不复制上游 SDK。选择其他已安装工具链时只调整 `DEVELOPER_DIR`，如预期旧写法可编译则使用 `--expect-legacy pass`；结果不符返回非零，未知错误和超时不会冒充预期重声明。

## 采用条件与剩余工作

1. 保持现有 1.3 部署下限和已验证工具链。未来 Xcode Cloud 正式打包前单独核对其实际 Xcode/SDK 版本，不把 GitHub 的 26.3 设置当作 Cloud 的当前设置。
2. 如确需 RevenueCat 升级，单开精确 revision 的依赖 PR，评估目标版本累计变更。当前实验不证明 5.78.0 是应采用版本，也不自动升级到它。
3. 依赖候选须完成 macOS 与 iOS 全构建、现有回归、购买/恢复/权益更新、Customer Center 与旧系统降级入口。源文件 typecheck 不能替代这些工作。
4. Xcode 27 的最低部署目标是独立阻断。未获产品决策前不提高 iOS 14 / macOS 11；也不以覆盖构建参数作为已支持旧系统的证明。
5. 签名产物、TestFlight、真实购买及最低系统设备验收继续保留在 #14/#15/#16/#71/#107。此诊断交付不关闭 #107。
