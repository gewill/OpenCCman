# #93：模型传递与观察工具对照

本轮排除了“必须通过 EnvironmentObject 才会出现持有”的假设，并发现 CUA 查询会改变这个最小复现的释放结果。**不据此重写产品模型，也不将已有三轮日志直接当作无界生产泄漏。** 产品源码、依赖锁、iOS 14／macOS 11 下限没有修改。

## 手动窗口对照

两个新进程均使用本机 macOS 27.0 (26A428)、Swift 6.4 的 Swift 5 模式、arm64／-O／macOS 11 部署目标，420×180pt 固定内容、English／Light。实际编译源码及哈希见各目录的 Probe.swift 和 preparation.json。生成时以 develop `6a65b047bd14b17e83c7b412aeca46d68f37dbae` 为基础，有明确标记的诊断脚本修改。

| 对照 | 第二窗口关闭 +5/+20 秒 | 全部关窗 +20 秒 |
|---|---:|---:|
| StateObject → 子视图 EnvironmentObject → Text | 2／2 个活模型 | 2 |
| StateObject → 显式传入子视图 ObservedObject → Text | 2／2 个活模型 | 2 |

两份源码除传参路径和诊断标题外相同，见 [差异](manual-source-diff.patch)。没有第三方依赖、业务通知订阅、转换任务或编辑器。原生 File/New Window 创建第二窗口，CUA 查询确认窗口编号 2 后用 Cmd-W 关闭；等待窗口数回到 1 后取首个 +5/+20 秒样本。确认仍是窗口 1，再关闭最后窗口，无 UI 查询观察 +20 秒，最后 Cmd-Q 退出。完整原始数据在 text/ 和 observed/，未裁掉失败结果或尾部样本。

[两组真实操作视频](https://github.com/gewill/OpenCCman/issues/93#issuecomment-5683476575) 通过 gh 上传，只录对应合成应用、无音频。这是诊断交互对照，不是产品 UI 修复前后图；活对象数量由弱引用记录器提供，不能从画面推断。录像会影响绝对性能，本节只比较生命周期计数。

[Apple StateObject](https://developer.apple.com/documentation/swiftui/stateobject) 将其定义为容器持有的状态来源；[ObservedObject](https://developer.apple.com/documentation/swiftui/observedobject) 可用于接收上层传入的模型。本实验保留根 StateObject，只改变模型的传递方式，不把改用 ObservedObject 本身当作所有权修复。

## 观察调用的影响

首次自运行原型使用显式 WindowGroup id、openWindow 和 performClose，未查询第二窗口就很快将其关闭，+20 秒只剩一个模型；全部关窗后仍为一个。它的窗口创建方式、时序与上面的菜单操作不同，保留在 auto-text/，**不能单独据此归因 AX**。

随后固定并预先记录 [新协议](ax-control/protocol.json)：同一二进制、同一窗口组和关闭方式，第一窗口保持 10 秒、第二窗口保持 10 秒，关第二窗口和最终窗口后分别记录 +5/+20 秒。两轮新进程均先通过 CUA getApp 读取第一窗口；区别仅为是否在第二窗口存在期间额外调用一次 CUA getAXState。

| 同一二进制的固定时序对照 | 关第二窗口 +20 秒 | 全部关窗 +20 秒 |
|---|---:|---:|
| 不查询第二窗口 | 1 个活模型／1 个窗口 | 1 个活模型／0 窗口 |
| 额外查询一次，返回 lifetime-AppWindow-2 | 2 个活模型／1 个窗口 | 2 个活模型／0 窗口 |

证据见 ax-control/no-ax/ 和 ax-control/one-ax/；两次均没有录像、heap 或 memgraph 工具。查询后的 shell 日志快照是在更晚时刻获取的，不把该快照时间冒充调用时间；当次 CUA 返回的窗口编号 2 是查询对象证据。两轮程序自行退出，整个窗口时序由相同编译代码执行。二进制 SHA256 保存在清理记录中。

这是单次成对、单系统结果，足以说明这次 CUA 观察调用会影响该最小对照，但尚未分离工具可能附带的激活、AX 连接保持等行为。不能推广为所有原始 AX API、VoiceOver 或真实用户都会导致泄漏；也不能以这两个最小程序证明生产 App 的持有全部来自工具。既有 #93/#90 的数值保留，解释必须带上观察方法。

## 可重复的自动诊断

新增 `--variant observed`，原有三个手动变体保持原有源码。准备器仍只构建、不启动；`--automatic` 仅为隔离诊断增加 macOS 13+ 的 openWindow 测试驱动和独立 bundle，不改变产品最低系统。自动驱动不持有模型或窗口，OpenWindowAction 在创建第二窗口后立即释放；只将窗口 ObjectIdentifier 留作识别，每次 tick 的强窗口引用随调用结束释放。

```sh
python3 scripts/prepare-minimal-window-lifetime.py --variant observed --output .build/observed
python3 scripts/prepare-minimal-window-lifetime.py --variant text --automatic --output .build/automatic-text
```

自动 fixture 可通过正常界面启动并在约 60 秒后自行退出。不要对它的第二窗口额外读取 AX，除非明确执行观察工具对照。它使用公开 API 操作自己的真实 WindowGroup，没有手写 NSWindow/NSHostingView 代替，也不操作外部应用。

CI 专用启动器 `scripts/diagnose-window-lifetime.py --output ...` 拒绝非 GitHub macOS runner 环境；每个自运行进程有超时，并且只终止它自己启动且尚未退出的子进程。普通 PR 的 App Regression 保持必跑；手动输入 `diagnose_window_lifetime=true` 才运行 macOS 15 上的两种对照。令牌只读，Action 固定 SHA，全部生成源码、构建日志、运行日志和失败记录保留为 artifact。

**CI 成功只代表原生窗口变化和观察间隔完整，不代表模型已经释放。** 校验器要求实际 2→1→0 窗口、准确事件顺序和最少等待时间；模型计数是实验结果，不把预期的持有现象伪装成回归通过。测试覆盖缺少终点、窗口重开、提前采样和驱动失败。较早系统结果如下；本地 macOS 27 数据仍不能代替最低系统或真实产品验收。

## macOS 15 CI 结果（2026-09-16，UTC+8）

[手动诊断 34992146346](https://github.com/gewill/OpenCCman/actions/runs/34992146346) 在候选 `964c093d382a633c5199d11646716b3734155858` 完成。macOS 15.7.9 (24G830)、Xcode 26.3 / Swift 6.2.4、arm64／Swift 5／-O。两个程序均由隔离 runner 启动，没有通过 CUA 读取第一或第二窗口。原始数据、生成源码、构建和进程日志保留在 [ci-macos15](ci-macos15/)。下载后重新核对源码及原始日志 SHA256，并用当前校验器再次验证完整窗口时序。

| CI 变体 | 第二窗口关闭 +5/+20 秒 | 最后窗口关闭 +5/+20 秒 | 退出 |
|---|---:|---:|---|
| 环境对象 | 1／1 个活模型 | 0／0 | 正常 |
| 显式 ObservedObject | 1／1 个活模型 | 0／0 | 正常 |

CI 的 text 生成源码与本地固定时序 AX 对照逐字节一致；但系统、编译器、硬件、启动方式及首次窗口是否被查询不同。**不能将 CI 的 0 与本机的 1／2 直接归因为系统版本。** 本结果证明这两种模型传递方式在该较早环境和无 CUA 查询协议下都能释放；同时为后续复测提供可重复入口。它不证明实际 OpenCCman 多窗口／活动关闭已经通过。

## 清理及剩余范围

所有本轮已启动的进程都已退出；对应私有偏好字典恢复，bundle 注销并改名 inactive。未启动的 build-only 产物不是运行验收。VoiceOver 测试前后均关闭，没有操作其他受保护的应用／设备／发布页面。各数据文件 SHA256 在 checksums.json。

下一步是为真实 OpenCCman 的多窗口验收排除观察工具影响，并在同机同编译器下扩展对照。持有链归因、修正路径的 1/10 MiB 多文稿循环、活动任务中关闭、真实输入法／VoiceOver、系统入口和最低系统／签名验收仍由 #93、#18、#19 等跟踪，不因本轮诊断自动关闭。
