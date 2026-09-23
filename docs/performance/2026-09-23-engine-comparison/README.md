# #18：同机旧／新 OpenCC 应用对照（2026-09-23）

本次把**同一份 OpenCCman 应用源码** `65196b5fbc8a90cc3123db7b53217c9c024249c9` 分别锁定到旧 wrapper `53f200cebe40eade3ebda025b0e8980e08cf23fa`（OpenCC 1.2.0）和当前 wrapper `6eded293f5c84c064f332cbc2832391165c82dda`（OpenCC 1.4.2），在同一台 Mac 上构建独立 Release 诊断包，并交错运行各五个新进程。两份构建的 Swift/Python 源码哈希完全相同，只有工程中的 wrapper revision 不同；`Package.resolved` 中其他依赖一致且构建时校验了 checkout SHA。Xcode 27.0 (27A266a)、macOS 27.0 (26A428)、Apple M4 Pro / 48 GiB、arm64。诊断包为 ad-hoc 签名、独立 bundle ID 和偏好，**不代表签名商店包**。

## 正确性边界

默认七配置语料包含 U+0000。旧 wrapper 在第一组配置 `2` 输出 63 字节，恰为输入在 NUL 前的字节；固定答案要求 70 字节，因此旧版的默认样本以 `Known-answer fixture mismatch` 失败。当前 wrapper 同输入输出完整 70 字节。两者输入 SHA-256 均为 `55164e9d0297a5e6fd31a24676c918c8d401170e3f94a1683df1a0ca1a355781`；旧输出 SHA-256 `8d48a8888e551969d861d02fbc995efa89b19dfdc0b4c8fd16cb09e02dfec8df`，与 NUL 前 63 字节的 SHA-256 一致。保留[旧版失败样本](nul-boundary/old/run-01.json)及[新版完整样本](nul-boundary/new/run-01.json)，失败样本**没有**输入性能比较器。

为测量两版都能正确执行的共同路径，诊断入口新增显式 `--comparison-no-nul` 配置：只从这组七配置小语料移除 U+0000，其余 256 KiB、1/5/10 MiB 语料及各阶段不变。默认固定答案和 U+0000 回归仍保留。两版共同语料的七组答案、输入和输出 SHA-256 均逐次一致，完整比较器通过。这组性能数据不覆盖含 NUL 输入在旧版的行为。

## 结果

下表为五个独立进程的中位数；旧→新，时间单位 ms，内存为 MiB。完整范围及每阶段数据见 [comparison.json](comparison.json)，原始五轮样本分别在 [旧版](old-common/) 与 [新版](new-common/) 目录。`model_completion_ms` 是真实模型 `translate()` 到结果发布，不含屏幕呈现；`process_start_to_root_layout_ms` 包含诊断器的窗口 reopen 握手，不能称为冷缓存启动或首帧时间。

| 阶段／指标 | 旧版 | 新版 | 观察 |
|---|---:|---:|---|
| 新进程到根布局 | 460.59 | 479.66 | +4.1%；范围分别为 434.78–1071.16、452.72–1627.59，不能据此判断启动回归 |
| 首次 256 KiB 模型转换 | 75.34 | 50.82 | −32.5% |
| 热转换第 1 次，256 KiB | 57.90 | 21.37 | −63.1% |
| 热转换第 5 次，256 KiB | 57.30 | 22.43 | −60.8% |
| 1 MiB 模型转换 | 164.84 | 27.13 | −83.5% |
| 5 MiB 模型转换 | 793.17 | 94.65 | −88.1% |
| 10 MiB 模型转换 | 1580.67 | 184.43 | −88.3% |
| 七配置使用后的 RSS | 141.42 | 177.23 | **+35.81 MiB**；新核心在这段有明确内存代价 |
| 10 MiB 转换后的 RSS | 303.73 | 309.11 | +5.38 MiB；此前阶段的峰值已包含在内 |
| 两轮托管窗口关闭后的进程峰值 RSS | 331.45 | 333.33 | +1.88 MiB；不是原生 WindowGroup 生命周期证据 |

比较器在早期转换／七配置阶段标记约 30–36 MiB RSS 增量待调查；在 10 MiB 与全协议峰值阶段差距缩小。此结果不证明内存泄漏，也不能把内存变化直接归因到某一个分配器或词典。完整协议两轮托管窗口结束时额外模型计数均为 0。七配置小输入有个别选项的新模型完成时间比旧版高数毫秒；大文件与热转换收益不能推广到每个选项和每种文稿。

## 复现与证据

`scripts/benchmark-app.py` 复制当前源码和依赖到仓库外目录、锁定完整 wrapper SHA、构建 Release 并校验签名后的应用、源码哈希、依赖 checkout 和机器环境；`--reuse-build` 拒绝条件漂移。两版 `metadata.json` 记录基线提交、测量入口的当时工作区状态、源码及构建哈希。测量入口和驱动在本 PR 中新增了共同语料开关，因此本次快照的 `source_status` 有这两个未提交文件；**两边哈希一致**，并非两份不同的工具。提交该工具不改变已封存的测量快照。

```bash
python3 scripts/benchmark-app.py --output /tmp/old --build-only --comparison-no-nul \
  --packages /path/to/SourcePackages \
  --engine-revision 53f200cebe40eade3ebda025b0e8980e08cf23fa
python3 scripts/benchmark-app.py --output /tmp/new --build-only --comparison-no-nul \
  --packages /path/to/SourcePackages
for i in 1 2 3 4 5; do
  python3 scripts/benchmark-app.py --output /tmp/new --reuse-build --samples 1 --start-index "$i"
  python3 scripts/benchmark-app.py --output /tmp/old --reuse-build --samples 1 --start-index "$i"
done
python3 scripts/compare-app-performance.py /tmp/old /tmp/new
python3 -m unittest discover -s Tests/Benchmarks -p 'test_*.py'
```

本次实际顺序为新版→旧版逐轮交错；不与编译、录屏或其他应用性能任务并行。比较器验证每轮前台可见窗口、七组配置、正确性、完整阶段、同一语料、同一工具与环境、其他依赖不漂移。Python 测试 110 项通过，`git diff --check` 通过。原始 JSON 保存全部五轮，没有剔除启动较慢的样本。

## 仍需完成

- 对七配置后约 35.8 MiB 的 RSS 增量用单独的 Instruments 运行定位；采样运行不可与这份无采样基线混用。
- 最终签名 2.0 产物的真实启动、显示完成、原生 WindowGroup 生命周期，以及 iPhone/iPad 与最低系统验收仍需独立证据。当前结果只支撑同机 Mac 诊断包的模型与阶段对照，#18 暂不关闭。
- 不把协议里的新进程称为冷缓存启动；OS/file cache 未清空，启动指标包括外部 reopen 握手。
