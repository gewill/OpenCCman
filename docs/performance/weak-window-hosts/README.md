# #93：区分关窗后的窗口、宿主与模型

后续[分配栈定位](2026-09-16/allocation-stacks/README.md)已将宿主的一个直接强捕获闭包追到 AppKit 的视图初始化/通知注册路径；完整持有根因与实际应用关联仍未证明。

旧诊断只记录可见窗口与活模型，不能区分 NSWindow 未释放、宿主视图被保留，或只有业务模型仍存活。新增可选 `--observe-hosts`，每个原生窗口首次可见时记录弱 NSWindow 与初始 contentView，并用单调编号保持关闭后的身份。采样不读取正文、不调用 AX、不改 SwiftUI 视图结构、不注册额外通知；没有跨采样持有强窗口/视图。

这仍是新增观察条件：读取 NSApp.windows/contentView 可能影响系统行为，不能宣称完全无干扰。初始 contentView 存活不等于仍是当前窗口的 contentView；该标记追踪原对象而非后来可能替换的宿主。无此开关时的生成 Swift 源码与已归档固定时序对照逐字节一致。

## 复现

本地只构建，之后通过正常 UI 打开自己的诊断 app：

```sh
python3 scripts/prepare-minimal-window-lifetime.py --variant text --automatic --observe-hosts --output .build/host-observation
```

自动驱动仍使用原来的窗口组/时序，启动 10 秒、第二窗口可见 10 秒、每次关窗后 +5/+20 秒观察，随后退出。`--automatic` 仅诊断包要求 macOS 13；产品 iOS 14/macOS 11 不变。CI 可在已有 App Regression 手动入口同时启用 diagnose_window_lifetime 与 observe_window_hosts，在同个 job 顺序执行 text/observed 变体。

`diagnose-window-lifetime.py --observe-hosts` 要求全程包含 hosts，拒绝身份丢失/重复、已释放弱对象重新出现、缺少 +5/+20 秒记录或可见数不一致。保留宿主与模型本身是待分析结果，不硬编码为失败或泄漏。

## 已有内存图如何使用

对旧 `zero-window.memgraph` 离线使用 leaks --noContent --trace 复查，能看到 AttributeGraph 的 ChildEnvironment 到模型的明确 strong capture；上游路径还有未标注强弱的扫描边。诊断记录器已知 weak 的模型字段同样进入 reference trace，证明不能把所有可达路径当强持有链。

Apple 的 [Detect and diagnose memory issues](https://developer.apple.com/videos/play/wwdc2021/10180/) 将 reference tree 描述为推测所有权根的工具；[Analyze heap memory](https://developer.apple.com/videos/play/wwdc2024/10173/) 说明内存图/Leaks 快照会暂停目标。新观测因此分开记录窗口和宿主的实际弱引用状态，并把 heap capture 前后的样本分开解释。

## 本机结果与范围

macOS 27.0 (26A428)、Swift 6.4 / Swift 5 / -O / arm64，同一 ad-hoc 二进制、固定合成文字，两个新进程顺序运行。两轮都经 CUA 正常启动并读取首窗口，仅第二轮在第二窗口可见期额外读一次 AX；该次明确返回 lifetime-AppWindow-2，没有录屏。测试前后恢复隔离偏好，无全局设置修改。

| 条件 | 关第二窗 +20 秒：模型 / 窗口 / 初始宿主 | 最终关窗 +5 秒：模型 / 窗口 / 初始宿主 |
|---|---|---|
| 只读取首窗（PID 19340） | 1 / 1 / 1 | 1 / 0 / 1 |
| 额外读取第二窗（PID 20264） | 2 / 1 / 2 | 2 / 0 / 2 |

窗口/宿主数字来自逐个编号的 weak 引用；模型数字仍是原来的 weak 模型计数。未额外读取的第二窗口及其初始宿主均释放。额外读取的第二窗口本身也释放，但初始宿主仍活着。首轮最终 +20 秒与 +5 秒一致；第二轮在最终 +5 秒后采集 leaks 内存图，最终 +20 秒虽同样为 2 / 0 / 2，但属于经过 heap 工具的样本，不能并入纯观察对照。

两份完整日志均经过 require_hosts 校验，两个进程自行退出。生成源码、原始 +5/+20 秒样本、校验结果、二进制/数据哈希和清理记录见 [本机证据](2026-09-16/)。实际归档 preparation.json 标记基线 1d96edf + dirty；归档 Probe.swift 与实际编译文件逐字节相同，可用 source SHA 验证，不把未提交状态冒充已发布源码。

离线零窗内存图中，两份 ProbeModel 的扫描路径都经过 AccessibilityNode 和 PropertyList；其中一份可从 SwiftUICore 静态 ObservationCenter._current 经 invalidations、ObservationRegistrar 追踪，另一份归档了 AppGraph.shared 路径。[摘录](2026-09-16/reference-trace-excerpts.txt)保留原始边注释。路径混有未标 strong 的字典/数组/PropertyList 边，所以它是下一步定位方向，尚不是已证明的完整强持有链，也不能宣称 CUA 服务直接强持有模型。原始 memgraph 和完整扫描仅留本机，公开记录它们的 SHA256。

本轮进一步排除了“可见数为零只是因为 NSWindow 隐藏而一直存活”的解释：两个 NSWindow 的 weak 引用均已归零。余下需定位被保留宿主/无障碍状态的实际强所有者，并在较早系统和真实应用中验证同样的关联。这里是没有第三方依赖、业务通知或编辑器的最小 SwiftUI 程序；不能单独证明实际 OpenCCman 的全部持有根因。#93 和 #18 保持开放，没有产品生命周期修复或性能提升声明。


## macOS 15 独立 CI 复核

[35030849260](https://github.com/gewill/OpenCCman/actions/runs/35030849260) 成功，源码 `5be88362ebcf25cfc9d57fbe487887c6d69b91fc`、配置 Xcode 26.3、macOS 15 runner；text 与 observed 顺序执行，均无 CUA、录屏或 heap capture。下载后重新核对生成源码 SHA、原始日志 SHA 和完整 require_hosts 协议，而非只信 workflow 绿色状态。

| 变体 | 关第二窗 +5/+20 秒：模型 / 窗口 / 宿主 | 最终关窗 +5/+20 秒 |
|---|---|---|
| EnvironmentObject | 1 / 1 / 1 | 0 / 0 / 0 |
| ObservedObject | 1 / 1 / 1 | 0 / 0 / 0 |

两个进程退出 0；[源码、构建/进程日志与原始样本](2026-09-16/ci-macos15/)已归档。此结果说明两个变体在该协议下可释放，也校验新增弱观测器没有必然保留宿主。不能用它与本机的一次成对结果独立归因系统版本：编译器、运行环境和首窗 AX 查询条件均不同。原始强所有者、实际产品关联及必要修复仍未证明，Issue #93 保持开放。
